// Upload-a-file plan importer for the WMS back office.
//
// Since 0105 a file is read in the trading company's own words and checked
// twice (see _shared/document_reader.ts): its column headings are mapped
// through the company's learned headings, everyone's, and the AI; a PDF or
// photo is read by the AI and then re-read by an independent check; a cell
// holding both name and 品番 is split by rule and by the AI. Every line is
// then resolved to our product through the dialect dictionary
// (`resolve_notation_lines`). On commit the company's writing is kept on the
// line, our product is linked, and what was confirmed is learned — the
// dialects (`learn_notation_lines`) and the column headings
// (`learn_column_aliases`) — so the next file from the same company reads
// itself.
//
// Two-step, so the auto-read header can be reviewed and corrected before it is
// saved:
//   1. PREVIEW  POST multipart/form-data with dry_run=1
//        file / delivery_number? / supplier? / supplier_code? / delivery_date?
//      → parses the file (SheetJS for Excel, Gemini for PDF/image), auto-reads
//        the delivery-note header, and returns { header, lines, ... } WITHOUT
//        writing anything.
//   2. COMMIT   POST application/json with the (possibly edited) header + lines
//        → resolves the supplier, assigns a per-company reference, and stores
//          the plan. A single-step multipart POST without dry_run still works
//          (parse + save in one shot) for callers that don't need review.
//
// Whatever the company could not be read from, the plan is routed to a distinct
// "UNKNOWN" reference series and flagged needs_review so it stands out and can
// be reassigned by hand.
//
// Warehouse scope (UI spec §37). An imported plan has to land in a warehouse,
// and until now it landed in whichever one `fill_default_warehouse()` picked,
// because nothing here ever set `warehouse_id`. That was both a scope hole and
// a plain bug: an operator at the Kobe warehouse could upload a Kobe delivery
// note and watch it appear in Osaka's receiving list.
//
// So the warehouse is now resolved and checked before anything is written:
//
//   * `warehouse_id` supplied      -> must be one the caller can access,
//   * omitted, caller sees exactly one -> that one,
//   * omitted, caller is unscoped (admin) -> left null, so
//     `fill_default_warehouse()` still decides, as it did before,
//   * omitted, caller sees several -> 422, because guessing would silently
//     file a delivery against the wrong warehouse.
//
// The writes themselves stay on the service role: there are no INSERT policies
// for `authenticated` on delivery_plans / shipment_plans or their line tables,
// which is exactly why the check above has to be explicit.
import {
  accessibleWarehouseIds,
  adminClient,
  callerClient,
  clientCanAccessWarehouse,
  clientPermitted,
  notInScopeMessage,
  notPermittedMessage,
} from "../_shared/require_permission.ts";
import {
  type AliasRow,
  type Column,
  type Field,
  FIELDS,
  type Header,
  normalizeJan,
  normalizeText,
  readDocument,
  readSpreadsheet,
  type ReadLine,
  str,
  toInt,
  toNum,
} from "../_shared/document_reader.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const admin = adminClient(supabaseUrl);

const UNKNOWN_CODE = "UNKNOWN";
const isJan = (d: string) => d.length === 13 || d.length === 8;

// A 登録番号 is a T followed by 13 digits; normalize spacing/full-width so the
// same company always resolves to the same key.
function normalizeRegNo(v: unknown): string | null {
  const s = str(v);
  if (!s) return null;
  let out = "";
  for (const ch of s) {
    const c = ch.codePointAt(0)!;
    if (c >= 0xff10 && c <= 0xff19) out += String.fromCharCode(c - 0xff10 + 0x30);
    else if (c === 0xff34 || ch === "t") out += "T";
    else out += ch;
  }
  const m = out.replace(/[\s-]/g, "").match(/T?\d{13}/);
  if (m) return m[0].startsWith("T") ? m[0] : "T" + m[0];
  return out;
}

// deno-lint-ignore no-explicit-any
type Client = any;

/** The company, if it is already known — for reading its file in its own
 * words before anything is saved. Never creates one. */
async function findPartner(
  name: string | null, code: string | null, regNo: string | null,
): Promise<number | null> {
  if (regNo) {
    const { data } = await admin.from("delivery_suppliers")
      .select("id").eq("registration_number", regNo).maybeSingle();
    if (data) return data.id as number;
  }
  if (code && code !== UNKNOWN_CODE) {
    const { data } = await admin.from("delivery_suppliers")
      .select("id").eq("code", code).maybeSingle();
    if (data) return data.id as number;
  }
  if (name) {
    const { data } = await admin.from("delivery_suppliers")
      .select("id").eq("name", name).maybeSingle();
    if (data) return data.id as number;
  }
  return null;
}

// Find or create the supplier (company). Matches by 登録番号, then code, then
// name. When nothing identifies the company, routes to the shared UNKNOWN
// bucket so the delivery still gets a distinct, traceable reference series.
async function resolveSupplier(
  name: string | null,
  code: string | null,
  regNo: string | null,
): Promise<{ id: number; unidentified: boolean }> {
  const found = await findPartner(name, code, regNo);
  if (found !== null) return { id: found, unidentified: false };
  if (name || code || regNo) {
    const { data, error } = await admin.from("delivery_suppliers")
      .insert({ name: name ?? code ?? regNo, code, registration_number: regNo })
      .select("id").single();
    if (error) throw new Error(error.message);
    return { id: data.id as number, unidentified: false };
  }
  const { data } = await admin.from("delivery_suppliers")
    .select("id").eq("code", UNKNOWN_CODE).maybeSingle();
  if (data) return { id: data.id as number, unidentified: true };
  const { data: created, error } = await admin.from("delivery_suppliers")
    .insert({ code: UNKNOWN_CODE, name: "未確認（要手動確認）" })
    .select("id").single();
  if (error) throw new Error(error.message);
  return { id: created.id as number, unidentified: true };
}

/** One line per product: the same JAN (or the same 品番/name when there is no
 * JAN) listed twice adds up. */
function aggregate(lines: ReadLine[]): ReadLine[] {
  const map = new Map<string, ReadLine>();
  for (const l of lines) {
    const key = l.jan_code ||
      `${normalizeText(l.maker)}|${normalizeText(l.product_code)}|${normalizeText(l.product_name)}`;
    const m = map.get(key);
    if (!m) {
      map.set(key, { ...l, flags: [...l.flags], alternatives: { ...l.alternatives } });
      continue;
    }
    m.planned_quantity += l.planned_quantity || 0;
    if (l.amount) m.amount = (m.amount ?? 0) + l.amount;
    for (const f of l.flags) if (!m.flags.includes(f)) m.flags.push(f);
    m.spec ??= l.spec;
    m.tax_rate ??= l.tax_rate;
  }
  return [...map.values()];
}

/** Our product for each line, through the dialect dictionary (0105). */
async function resolveLines(
  supabase: Client, partnerId: number | null, lines: ReadLine[],
): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabase.rpc("resolve_notation_lines", {
    p_partner_id: partnerId,
    p_lines: lines.map((l) => ({
      jan_code: l.raw_jan_code ?? l.jan_code, maker: l.maker,
      product_name: l.product_name, product_code: l.product_code,
    })),
  });
  if (error) throw new Error(error.message);
  const resolved = (data ?? []) as Record<string, unknown>[];
  return lines.map((l, i) => {
    const r = resolved[i] ?? {};
    const product = r.product as Record<string, unknown> | null;
    const flags = [...l.flags];
    if (!product) flags.push("unresolved");
    // A maker we know from our product is no longer missing.
    const noMaker = flags.indexOf("no_maker");
    if (noMaker >= 0 && (product?.maker || r.maker_name)) flags.splice(noMaker, 1);
    return {
      ...l,
      flags,
      product,
      product_id: product?.id ?? null,
      matched_by: r.matched_by ?? null,
      maker_resolved: r.maker_name ?? null,
    };
  });
}

// Turn one reviewed line into a plan-line row, in the company's own words;
// the database books it under our JAN when it resolves (0105).
function toLineRow(l: Record<string, unknown>): Record<string, unknown> {
  const productId = Number(l.product_id);
  const jan = normalizeJan(l.jan_code ?? l.raw_jan_code);
  return {
    jan_code: isJan(jan) ? jan : "",
    raw_jan_code: str(l.raw_jan_code),
    product_id: Number.isFinite(productId) && productId > 0 ? productId : null,
    maker: str(l.maker),
    product_code: str(l.product_code) ?? "",
    product_name: str(l.product_name) ?? str(l.product_code) ?? "",
    raw_name_code: str(l.raw_name_code),
    review_flags: Array.isArray(l.flags) && (l.flags as unknown[]).length ? l.flags : null,
    spec: str(l.spec),
    planned_quantity: toInt(l.planned_quantity) ?? 0,
    unit_price: toInt(l.unit_price),
    amount: toInt(l.amount),
    tax_rate: toNum(l.tax_rate),
    order_date: str(l.order_date),
  };
}

/** Decide which warehouse this import belongs to, and refuse rather than guess.
 * See the §37 note in the file header for the four cases. */
async function resolveWarehouse(
  supabase: Client,
  requested: number | null,
): Promise<{ warehouseId: number | null } | { error: Response }> {
  if (requested !== null) {
    if (!(await clientCanAccessWarehouse(supabase, requested))) {
      return { error: json({ message: notInScopeMessage(requested) }, 403) };
    }
    return { warehouseId: requested };
  }
  const scope = await accessibleWarehouseIds(supabase);
  if (scope === null) return { warehouseId: null };
  if (scope.length === 0) {
    return { error: json({ message: "no warehouse is assigned to your account" }, 403) };
  }
  if (scope.length === 1) return { warehouseId: scope[0] };
  return {
    error: json({
      message: "warehouse_id is required when you have access to more than one",
      warehouse_ids: scope,
    }, 422),
  };
}

/** What was confirmed on commit, learned for next time. Best effort: a
 * failure to learn never undoes a saved plan. */
async function learn(
  supabase: Client, partnerId: number, rows: Record<string, unknown>[],
  columns: { header?: string | null; field?: string | null }[],
) {
  const learnable = rows.filter((r) => r.product_id).map((r) => ({
    product_id: r.product_id,
    jan_code: r.raw_jan_code ?? null,
    maker: r.source_maker ?? r.maker,
    product_name: r.source_product_name ?? r.product_name,
    product_code: r.source_product_code ?? r.product_code,
  }));
  let learned: unknown = null;
  if (learnable.length) {
    const { data } = await supabase.rpc("learn_notation_lines", {
      p_partner_id: partnerId, p_lines: learnable, p_source: "import", p_confirmed: true,
    });
    learned = data;
  }
  const map = columns
    .filter((c) => str(c.header) && FIELDS.includes(c.field as Field))
    .map((c) => ({ header: c.header, field: c.field }));
  if (map.length) {
    await supabase.rpc("learn_column_aliases", { p_partner_id: partnerId, p_map: map });
  }
  return learned;
}

async function commit(supabase: Client, input: {
  deliveryNumber: string;
  supplier: string | null;
  supplierCode: string | null;
  registrationNumber: string | null;
  customerCode: string | null;
  docNumber: string | null;
  deliveryDate: string | null;
  orderDate: string | null;
  warehouseId: number | null;
  lines: Record<string, unknown>[];
  columns: { header?: string | null; field?: string | null }[];
  source: string;
  target: string;
}): Promise<Response> {
  const permission = input.target === "shipment" ? "pack.complete" : "receiving.confirm";
  if (!(await clientPermitted(supabase, permission))) {
    return json({ message: notPermittedMessage(permission) }, 403);
  }
  const resolved = await resolveWarehouse(supabase, input.warehouseId);
  if ("error" in resolved) return resolved.error;
  const { warehouseId } = resolved;

  // A line is saved when it carries a JAN or has been tied to our product.
  const all = input.lines.map(toLineRow);
  const lines = all.filter((l) => isJan(l.jan_code as string) || l.product_id);
  const skipped = all.length - lines.length;
  if (lines.length === 0) return json({ message: "No JAN rows found." }, 422);
  const totalQty = lines.reduce((s, l) => s + (l.planned_quantity as number), 0);

  const { id: supplierId, unidentified } = await resolveSupplier(
    input.supplier, input.supplierCode, input.registrationNumber,
  );
  const { data: ref } = await admin.rpc("assign_reference", { p_supplier_id: supplierId });
  const referenceNo = (ref as string) ?? null;

  if (input.target === "shipment") {
    const { data: plan, error: e1 } = await admin
      .from("shipment_plans")
      .insert({
        warehouse_id: warehouseId,
        shipment_number: input.deliveryNumber,
        party_id: supplierId,
        customer_name: input.supplier,
        customer_code: input.customerCode,
        registration_number: input.registrationNumber,
        reference_no: referenceNo,
        doc_number: input.docNumber,
        order_date: input.orderDate,
        ship_date: input.deliveryDate,
        needs_review: unidentified,
        status: "open",
      })
      .select("id")
      .single();
    if (e1) return json({ message: e1.message }, 400);

    const withId = lines.map((l) => ({
      shipment_plan_id: plan.id,
      jan_code: l.jan_code,
      product_id: l.product_id,
      maker: l.maker,
      product_code: l.product_code,
      product_name: l.product_name,
      spec: l.spec,
      quantity: l.planned_quantity,
      unit_price: l.unit_price,
      amount: l.amount,
      tax_rate: l.tax_rate,
      order_date: l.order_date,
    }));
    const { data: saved, error: e2 } = await admin.from("shipment_lines").insert(withId).select();
    if (e2) return json({ message: e2.message }, 400);
    const learned = await learn(supabase, supplierId,
      (saved ?? []).map((r: Record<string, unknown>) => ({ ...r, raw_jan_code: r.source_jan_code })),
      input.columns);

    return json({ data: {
      source: input.source, plan_id: plan.id, target: "shipment",
      delivery_number: input.deliveryNumber, reference_no: referenceNo,
      needs_review: unidentified, line_count: lines.length, total_quantity: totalQty,
      skipped, learned,
    } });
  }

  const { data: plan, error: e1 } = await admin
    .from("delivery_plans")
    .insert({
      warehouse_id: warehouseId,
      delivery_number: input.deliveryNumber,
      supplier_name: input.supplier,
      supplier_code: input.supplierCode,
      supplier_id: supplierId,
      registration_number: input.registrationNumber,
      customer_code: input.customerCode,
      doc_number: input.docNumber,
      reference_no: referenceNo,
      order_date: input.orderDate ?? input.deliveryDate,
      delivery_date: input.deliveryDate,
      doc_type: "plan",
      needs_review: unidentified || lines.some((l) => !l.product_id && !isJan(l.jan_code as string)),
      status: "open",
    })
    .select("id")
    .single();
  if (e1) return json({ message: e1.message }, 400);

  const withId = lines.map((l) => ({ ...l, delivery_plan_id: plan.id }));
  const { data: saved, error: e2 } = await admin.from("delivery_plan_lines").insert(withId).select();
  if (e2) return json({ message: e2.message }, 400);
  const learned = await learn(supabase, supplierId, saved ?? [], input.columns);

  return json({ data: {
    source: input.source, plan_id: plan.id, target: "plan",
    delivery_number: input.deliveryNumber,
    reference_no: referenceNo, needs_review: unidentified,
    line_count: lines.length, total_quantity: totalQty, skipped, learned,
  } });
}

function parseOverrides(raw: unknown): Record<number, Field> {
  const out: Record<number, Field> = {};
  const s = str(raw);
  if (!s) return out;
  try {
    const obj = JSON.parse(s) as Record<string, string>;
    for (const [k, v] of Object.entries(obj)) {
      if (FIELDS.includes(v as Field) && Number.isFinite(Number(k))) out[Number(k)] = v as Field;
    }
  } catch (_) { /* ignore a malformed override */ }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);

  try {
    const supabase = callerClient(req, supabaseUrl);
    const ctype = req.headers.get("content-type") ?? "";

    // COMMIT: the reviewed/edited header + lines come back as JSON.
    if (ctype.includes("application/json")) {
      const b = await req.json();
      // Training (0106): what a checked sample taught, learned — nothing booked.
      if (str(b.mode) === "learn") {
        const { data: allowed } = await supabase.rpc("notation_training_allowed");
        if (allowed !== true) return json({ message: notPermittedMessage("product.manage") }, 403);
        const partnerId = Number(b.partner_id);
        if (!Number.isFinite(partnerId) || partnerId <= 0) {
          return json({ message: "partner_id is required" }, 400);
        }
        const learned = await learn(supabase, partnerId,
          (Array.isArray(b.lines) ? b.lines : []) as Record<string, unknown>[],
          Array.isArray(b.columns) ? b.columns : []);
        const trainingId = Number(b.training_id);
        if (Number.isFinite(trainingId) && trainingId > 0) {
          await supabase.rpc("finish_notation_training", {
            p_id: trainingId, p_partner_id: partnerId, p_learned: learned ?? {},
          });
        }
        return json({ data: { learned, training_id: Number.isFinite(trainingId) ? trainingId : null } });
      }
      const deliveryNumber = String(b.delivery_number ?? "").trim();
      if (!deliveryNumber) return json({ message: "delivery_number is required" }, 400);
      const lines = Array.isArray(b.lines) ? b.lines : [];
      const wh = Number(b.warehouse_id);
      return await commit(supabase, {
        deliveryNumber,
        supplier: str(b.supplier),
        supplierCode: str(b.supplier_code),
        registrationNumber: normalizeRegNo(b.registration_number),
        customerCode: str(b.customer_code),
        docNumber: str(b.doc_number),
        deliveryDate: str(b.delivery_date),
        orderDate: str(b.order_date),
        warehouseId: Number.isFinite(wh) && wh > 0 ? wh : null,
        lines,
        columns: Array.isArray(b.columns) ? b.columns : [],
        source: str(b.source) ?? "review",
        target: str(b.target) === "shipment" ? "shipment" : "plan",
      });
    }

    // PREVIEW / one-shot: a file is uploaded and parsed here.
    const form = await req.formData();
    const file = form.get("file");
    const deliveryNumber = String(form.get("delivery_number") ?? "").trim();
    const supplier = str(form.get("supplier"));
    const supplierCode = str(form.get("supplier_code"));
    const deliveryDate = str(form.get("delivery_date"));
    const target = str(form.get("target")) === "shipment" ? "shipment" : "plan";
    const formWh = Number(form.get("warehouse_id"));
    const warehouseId = Number.isFinite(formWh) && formWh > 0 ? formWh : null;
    const training = str(form.get("mode")) === "training";
    const dryRun = training || String(form.get("dry_run") ?? "") === "1";
    const formPartner = Number(form.get("partner_id"));
    const overrides = parseOverrides(form.get("column_overrides"));
    if (!(file instanceof File)) return json({ message: "file is required" }, 400);

    const name = file.name.toLowerCase();
    const bytes = new Uint8Array(await file.arrayBuffer());
    let lines: ReadLine[];
    let columns: Column[];
    let header: Header = {
      supplier_name: null, registration_number: null,
      customer_code: null, doc_number: null, doc_date: null,
    };
    let source: string;
    let verified = true;

    if (training) {
      const { data: allowed } = await supabase.rpc("notation_training_allowed");
      if (allowed !== true) return json({ message: notPermittedMessage("product.manage") }, 403);
    }
    let partnerId = Number.isFinite(formPartner) && formPartner > 0
      ? formPartner
      : await findPartner(supplier, supplierCode, null);
    if (/\.(xlsx|xlsm|xls|csv)$/.test(name)) {
      const { data: aliasData } = await supabase.rpc("column_alias_map", { p_partner_id: partnerId });
      ({ columns, lines } = await readSpreadsheet(bytes, (aliasData ?? []) as AliasRow[], overrides));
      source = name.endsWith(".csv") ? "csv" : "xlsx";
    } else {
      const mime = file.type || (name.endsWith(".pdf") ? "application/pdf" : "image/jpeg");
      ({ header, columns, lines, verified } = await readDocument(bytes, mime));
      header.registration_number = normalizeRegNo(header.registration_number);
      source = "gemini";
      partnerId ??= await findPartner(header.supplier_name, null, header.registration_number);
    }

    const merged = aggregate(lines);
    if (merged.length === 0) return json({ message: "No JAN rows found." }, 422);
    const withProducts = await resolveLines(supabase, partnerId, merged);
    const totalQty = merged.reduce((s, l) => s + (l.planned_quantity || 0), 0);
    const orderDate = merged.find((l) => l.order_date)?.order_date ?? null;

    const mergedHeader: Header = {
      supplier_name: supplier ?? header.supplier_name,
      registration_number: header.registration_number,
      customer_code: header.customer_code,
      doc_number: header.doc_number ?? (deliveryNumber || null),
      doc_date: header.doc_date ?? deliveryDate,
    };

    // Training (0106): the read is kept, with what went wrong, for review.
    let trainingId: number | null = null;
    if (training) {
      const { data: tid, error: te } = await supabase.rpc("record_notation_training", {
        p_partner_id: partnerId, p_file_name: file.name, p_source: source,
        p_verified: verified, p_columns: columns, p_lines: withProducts,
      });
      if (te) return json({ message: te.message }, 400);
      trainingId = tid as number;
    }

    if (dryRun) {
      return json({ data: {
        source, dry_run: true, verified, training_id: trainingId,
        header: mergedHeader,
        supplier_code: supplierCode,
        partner_id: partnerId,
        delivery_number: deliveryNumber || header.doc_number || "",
        order_date: orderDate,
        columns,
        line_count: merged.length, total_quantity: totalQty,
        lines: withProducts,
      } });
    }

    const num = deliveryNumber || mergedHeader.doc_number;
    if (!num) return json({ message: "delivery_number is required" }, 400);
    return await commit(supabase, {
      deliveryNumber: num,
      supplier: mergedHeader.supplier_name,
      supplierCode,
      registrationNumber: mergedHeader.registration_number,
      customerCode: mergedHeader.customer_code,
      docNumber: mergedHeader.doc_number,
      deliveryDate,
      orderDate,
      warehouseId,
      lines: withProducts,
      columns,
      source,
      target,
    });
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
