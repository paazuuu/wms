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
  type AttributeDef,
  type Column,
  type Field,
  FIELDS,
  type Header,
  type OwnCompany,
  checkJan,
  companiesInFileName,
  companyKey,
  CODE_MATCHES,
  normalizeJan,
  normalizeText,
  aiPing,
  readDocument,
  readingQuality,
  readIssuer,
  readPdfText,
  type ReadingHints,
  readSpreadsheet,
  setAiFunction,
  type Totals,
  type ReadAttribute,
  type ReadLine,
  splitAttr,
  str,
  toInt,
  toNum,
} from "../_shared/document_reader.ts";
import { EVIDENCE_PURPOSES, keepEvidence, noteEvidence } from "../_shared/evidence.ts";

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
setAiFunction("import-plan");

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

/** Our own company (0131) as the reader needs it: every name it goes by,
 * and its 登録番号. Null while none is set beyond the placeholder. */
async function ownCompany(): Promise<OwnCompany | null> {
  const { data } = await admin.from("companies")
    .select("name, name_kana, name_en, aliases, registration_number").order("id").limit(1).maybeSingle();
  if (!data) return null;
  const names = [data.name, data.name_kana, data.name_en, ...((data.aliases as string[] | null) ?? [])]
    .map((n) => str(n))
    .filter((n): n is string => n !== null && n !== "自社");
  // Not set yet: the company our earlier documents were addressed to, when
  // at least two of them agree (0132).
  if (names.length === 0) {
    const { data: seen } = await admin.from("import_documents")
      .select("addressee").not("addressee", "is", null).order("uploaded_at", { ascending: false }).limit(200);
    const count = new Map<string, { name: string; n: number }>();
    for (const r of (seen ?? []) as { addressee: string }[]) {
      const k = companyKey(r.addressee);
      if (k.length < 2) continue;
      const c = count.get(k) ?? { name: r.addressee, n: 0 };
      c.n++;
      count.set(k, c);
    }
    const top = [...count.values()].sort((a, b) => b.n - a.n)[0];
    if (top && top.n >= 2) names.push(top.name);
  }
  if (names.length === 0 && !data.registration_number) return null;
  return { names, registration_number: str(data.registration_number) };
}

/** The supplier among the companies a document names (0132), in this order:
 *   1. a company it (or its file name) names that we already know;
 *   2. the company we know by its 登録番号 — under the name we keep for it;
 *   3. the likeliest issuer in its text, then in its file name;
 *   4. for a PDF or picture whose issuer is a logo, what the AI reads off
 *      the page.
 * Our own company is never among them. */
async function pickSupplier(
  header: Header, fileName: string, own: OwnCompany | null, page: { bytes: Uint8Array; mime: string } | null,
): Promise<{ name: string | null; partnerId: number | null }> {
  const names = [...new Set([
    header.supplier_name, ...(header.supplier_candidates ?? []), ...companiesInFileName(fileName, own),
  ].filter((n): n is string => !!n))];
  header.supplier_candidates = names;
  for (const n of names) {
    const id = await findPartner(n, null, null);
    if (id !== null) return { name: n, partnerId: id };
  }
  if (header.registration_number) {
    const id = await findPartner(null, null, header.registration_number);
    if (id !== null) return { name: await partnerName(id), partnerId: id };
  }
  if (names.length) return { name: names[0], partnerId: null };
  if (page) {
    const read = await readIssuer(page.bytes, page.mime, own);
    if (read) {
      header.addressee ??= read.addressee;
      header.registration_number ??= normalizeRegNo(read.registration_number);
      if (read.supplier_name) {
        header.supplier_candidates = [read.supplier_name];
        const id = await findPartner(read.supplier_name, null, header.registration_number);
        return { name: id !== null ? await partnerName(id) ?? read.supplier_name : read.supplier_name, partnerId: id };
      }
    }
  }
  return { name: null, partnerId: null };
}

async function partnerName(id: number): Promise<string | null> {
  const { data } = await admin.from("delivery_suppliers").select("name").eq("id", id).maybeSingle();
  return str(data?.name);
}

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
      map.set(key, {
        ...l, flags: [...l.flags], alternatives: { ...l.alternatives }, attributes: [...(l.attributes ?? [])],
      });
      continue;
    }
    m.planned_quantity += l.planned_quantity || 0;
    if (l.amount) m.amount = (m.amount ?? 0) + l.amount;
    for (const f of l.flags) if (!m.flags.includes(f)) m.flags.push(f);
    for (const a of l.attributes ?? []) {
      if (!m.attributes.some((x) => x.key === a.key)) m.attributes.push(a);
    }
    m.spec ??= l.spec;
    m.tax_rate ??= l.tax_rate;
  }
  return [...map.values()];
}

/** Our product for each line, through the dialect dictionary (0105). */
async function resolveLines(
  supabase: Client, partnerId: number | null, lines: ReadLine[],
): Promise<Record<string, unknown>[]> {
  // A JAN that lost its digits is not used to find anything (0113).
  const lost = (l: ReadLine) => l.flags.includes("jan_exponent");
  const { data, error } = await supabase.rpc("resolve_notation_lines", {
    p_partner_id: partnerId,
    p_lines: lines.map((l) => ({
      jan_code: lost(l) ? null : (l.raw_jan_code ?? l.jan_code), maker: l.maker,
      product_name: l.product_name, product_code: l.product_code,
    })),
  });
  if (error) throw new Error(error.message);
  const resolved = (data ?? []) as Record<string, unknown>[];
  // What the 品番 alone points to, to check the JAN against (0113).
  const { data: byCodeData } = await supabase.rpc("resolve_notation_lines", {
    p_partner_id: partnerId,
    p_lines: lines.map((l) => ({ jan_code: null, maker: l.maker, product_name: null, product_code: l.product_code })),
  });
  const byCode = (byCodeData ?? []) as Record<string, unknown>[];
  return lines.map((l, i) => {
    const r = resolved[i] ?? {};
    let product = r.product as Record<string, unknown> | null;
    let matchedBy = (r.matched_by ?? null) as string | null;
    let janCode = l.jan_code;
    const flags = [...l.flags];
    const alternatives = { ...l.alternatives };
    const c = byCode[i] ?? {};
    const codeProduct = CODE_MATCHES.has(String(c.matched_by ?? "")) ? c.product as Record<string, unknown> | null : null;
    const check = checkJan(l, product, matchedBy, codeProduct);
    if (check.flag) flags.push(check.flag);
    if (check.alternative) alternatives.code_product = check.alternative;
    if (check.restored) {
      product = check.restored;
      matchedBy = "jan_restored";
      janCode = String(check.restored.jan_code ?? "");
      const at = flags.indexOf("jan_exponent");
      if (at >= 0) flags.splice(at, 1);
    } else if (check.drop) {
      product = null;
      matchedBy = null;
    }
    if (!product) flags.push("unresolved");
    // A maker we know from our product is no longer missing.
    const noMaker = flags.indexOf("no_maker");
    if (noMaker >= 0 && (product?.maker || r.maker_name)) flags.splice(noMaker, 1);
    return {
      ...l,
      jan_code: janCode,
      flags,
      alternatives,
      product,
      product_id: product?.id ?? null,
      matched_by: matchedBy,
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
    unit_price: toNum(l.unit_price),
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

type ColumnLike = {
  header?: string | null;
  field?: string | null;
  attribute?: string | null;
  parts?: string[] | null;
  separator?: string | null;
};

/** A line's attributes as the company wrote them (0110): the attribute
 * columns, plus its 入数 and — when the file had a 規格 column — its 規格,
 * each under the company's own heading. */
function attributesToLearn(r: Record<string, unknown>, columns: ColumnLike[]): ReadAttribute[] {
  const out: ReadAttribute[] = [];
  for (const a of (Array.isArray(r.attributes) ? r.attributes : []) as Partial<ReadAttribute>[]) {
    const key = str(a?.key), value = str(a?.value);
    if (key && value && !out.some((x) => x.key === key)) out.push({ key, name: str(a?.name) ?? "", value });
  }
  const headerOf = (f: string) => str(columns.find((c) => c.field === f)?.header);
  const caseQty = toInt(r.case_quantity);
  if (caseQty && !out.some((x) => x.key === "case_quantity")) {
    out.push({ key: "case_quantity", name: headerOf("case_quantity") ?? "入数", value: String(caseQty) });
  }
  const spec = str(r.spec);
  const specHeader = headerOf("spec");
  if (spec && specHeader && !out.some((x) => x.key === "spec")) {
    out.push({ key: "spec", name: specHeader, value: spec });
  }
  return out;
}

/** What was confirmed on commit, learned for next time. Best effort: a
 * failure to learn never undoes a saved plan. */
async function learn(
  supabase: Client, partnerId: number, rows: Record<string, unknown>[],
  columns: ColumnLike[],
) {
  const learnable = rows.filter((r) => r.product_id).map((r) => ({
    product_id: r.product_id,
    jan_code: r.raw_jan_code ?? null,
    maker: r.source_maker ?? r.maker,
    product_name: r.source_product_name ?? r.product_name,
    product_code: r.source_product_code ?? r.product_code,
    // The company's own code for the item, its 単位 and 定価 (0111).
    supplier_code: r.supplier_code ?? null,
    unit: r.unit ?? null,
    list_price: r.list_price ?? null,
    // The company's code for its own supplier of the item (0112).
    upstream_code: r.upstream_code ?? null,
    attributes: attributesToLearn(r, columns),
  }));
  let learned: unknown = null;
  if (learnable.length) {
    const { data } = await supabase.rpc("learn_notation_lines", {
      p_partner_id: partnerId, p_lines: learnable, p_source: "import", p_confirmed: true,
    });
    learned = data;
  }
  const map = columns
    .filter((c) => str(c.header) && FIELDS.includes(c.field as Field) && (c.field !== "attr" || str(c.attribute)))
    .map((c) => ({
      header: c.header, field: c.field, attribute: c.field === "attr" ? c.attribute : null,
      // How a combined cell splits (0114).
      parts: c.field === "multi" ? c.parts ?? null : null,
      separator: c.field === "multi" ? c.separator ?? null : null,
    }));
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
  columns: ColumnLike[];
  source: string;
  target: string;
  documentId: number | null;
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
  const keep = all.map((l, i) => ({ l, i })).filter(({ l }) => isJan(l.jan_code as string) || l.product_id);
  const lines = keep.map(({ l }) => l);
  // What each kept line said about the product's attributes, for learning
  // once the lines are saved (same order).
  const attrsByLine = keep.map(({ i }) => attributesToLearn(input.lines[i], input.columns));
  const extraByLine = keep.map(({ i }) => ({
    supplier_code: str(input.lines[i].supplier_code),
    unit: str(input.lines[i].unit),
    list_price: toNum(input.lines[i].list_price),
    upstream_code: str(input.lines[i].upstream_code),
  }));
  const withAttrs = (saved: Record<string, unknown>[]) =>
    saved.map((r, i) => ({ ...r, ...(extraByLine[i] ?? {}), attributes: attrsByLine[i] ?? [] }));
  const skipped = all.length - lines.length;
  if (lines.length === 0) return json({ message: "No JAN rows found." }, 422);
  const totalQty = lines.reduce((s, l) => s + (l.planned_quantity as number), 0);

  const { id: supplierId, unidentified } = await resolveSupplier(
    input.supplier, input.supplierCode, input.registrationNumber,
  );
  // Its code for us (得意先コード), read off the document, is kept on the
  // company the first time (0112); ours for it is the company's own code.
  const customerCode = input.customerCode ??
    input.lines.map((l) => str(l.customer_code)).find((c) => c) ?? null;
  if (customerCode && !unidentified) {
    await admin.from("delivery_suppliers").update({ their_code_for_us: customerCode })
      .eq("id", supplierId).is("their_code_for_us", null);
  }
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
      withAttrs((saved ?? []).map((r: Record<string, unknown>) => ({ ...r, raw_jan_code: r.source_jan_code }))),
      input.columns);
    await noteEvidence(admin, input.documentId, {
      shipment_plan_id: plan.id, committed_at: new Date().toISOString(), supplier_id: supplierId,
      warehouse_id: warehouseId, doc_number: input.docNumber ?? input.deliveryNumber, line_count: lines.length,
    });

    return json({ data: {
      source: input.source, plan_id: plan.id, target: "shipment",
      delivery_number: input.deliveryNumber, reference_no: referenceNo,
      needs_review: unidentified, line_count: lines.length, total_quantity: totalQty,
      skipped, learned, document_id: input.documentId,
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
  const learned = await learn(supabase, supplierId, withAttrs(saved ?? []), input.columns);
  await noteEvidence(admin, input.documentId, {
    delivery_plan_id: plan.id, committed_at: new Date().toISOString(), supplier_id: supplierId,
    warehouse_id: warehouseId, doc_number: input.docNumber ?? input.deliveryNumber, line_count: lines.length,
  });

  return json({ data: {
    source: input.source, plan_id: plan.id, target: "plan",
    delivery_number: input.deliveryNumber,
    reference_no: referenceNo, needs_review: unidentified,
    line_count: lines.length, total_quantity: totalQty, skipped, learned,
    document_id: input.documentId,
  } });
}

function parseOverrides(raw: unknown): Record<number, string> {
  const out: Record<number, string> = {};
  const s = str(raw);
  if (!s) return out;
  try {
    const obj = JSON.parse(s) as Record<string, string>;
    for (const [k, v] of Object.entries(obj)) {
      // A field, or "attr:<attribute>" for one of our product attributes.
      if (typeof v === "string" && splitAttr(v) && Number.isFinite(Number(k))) out[Number(k)] = v;
    }
  } catch (_) { /* ignore a malformed override */ }
  return out;
}

function parseHeaders(raw: unknown): Record<number, string> {
  const out: Record<number, string> = {};
  const s = str(raw);
  if (!s) return out;
  try {
    for (const [k, v] of Object.entries(JSON.parse(s) as Record<string, unknown>)) {
      const h = str(v);
      if (h && Number.isFinite(Number(k))) out[Number(k)] = h;
    }
  } catch (_) { /* ignore malformed headings */ }
  return out;
}

/** The AI's columns with what we know of their headings put over them. */
function withHints(
  columns: Column[], hints: ReadingHints, overrides: Record<number, string>, headers: Record<number, string>,
): Column[] {
  const out = columns.map((c) => ({ ...c }));
  const corrected = new Set(Object.keys(overrides).map((k) => normalizeText(headers[Number(k)] ?? "")));
  for (const h of hints.columns ?? []) {
    const key = normalizeText(h.header);
    const source: Column["source"] = corrected.has(key) ? "override" : "partner";
    const set = { field: h.field, parts: h.parts ?? null, separator: h.separator ?? null, source, conflict: false };
    const at = out.findIndex((c) => normalizeText(c.header) === key);
    if (at >= 0) out[at] = { ...out[at], ...set };
    else out.push({ index: out.length, header: h.header, attribute: null, ...set });
  }
  return out;
}

/** What the AI is told of this company's documents: its own headings as
 * learned, the columns corrected on this reading, and its 書式メモ (0114). */
async function readingHints(
  partnerId: number | null, aliases: AliasRow[], overrides: Record<number, string>, headers: Record<number, string>,
): Promise<ReadingHints> {
  const columns: NonNullable<ReadingHints["columns"]> = [];
  for (const [k, v] of Object.entries(overrides)) {
    const o = splitAttr(v);
    const header = headers[Number(k)];
    if (o && header) columns.push({ header, field: o.field, parts: o.parts ?? null, separator: o.separator ?? null });
  }
  for (const a of aliases) {
    if (!a.partner || !a.header || columns.some((c) => normalizeText(c.header) === a.header_key)) continue;
    columns.push({
      header: a.header, field: a.field,
      parts: a.field === "multi" ? (a.parts ?? []) as Field[] : null, separator: a.separator ?? null,
    });
  }
  let notes: string | null = null;
  if (partnerId) {
    const { data } = await admin.from("delivery_suppliers").select("reading_notes").eq("id", partnerId).maybeSingle();
    notes = str(data?.reading_notes);
  }
  return { columns, notes };
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
      // 接続テスト (0133): is the AI answering, with this key, right now?
      if (str(b.mode) === "ai_ping") {
        if (!(await clientPermitted(supabase, "ai.review")) && !(await clientPermitted(supabase, "user.manage"))) {
          return json({ message: notPermittedMessage("ai.review") }, 403);
        }
        return json({ data: await aiPing() });
      }
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
        documentId: Number.isFinite(Number(b.document_id)) && Number(b.document_id) > 0 ? Number(b.document_id) : null,
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
    // The headings the corrected columns had on the last reading (0114), so a
    // PDF read by the AI can be told what they mean.
    const overrideHeaders = parseHeaders(form.get("column_headers"));
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
    let totals: Totals | null = null;

    if (training) {
      const { data: allowed } = await supabase.rpc("notation_training_allowed");
      if (allowed !== true) return json({ message: notPermittedMessage("product.manage") }, 403);
    }
    // The file is kept as evidence before it is read, so even one that
    // cannot be read is on record (0132).
    const askedPurpose = str(form.get("purpose"));
    const purpose = askedPurpose && EVIDENCE_PURPOSES.has(askedPurpose)
      ? askedPurpose
      : training ? "training" : target === "shipment" ? "shipment" : "plan";
    const documentId = await keepEvidence(admin, supabase, file, bytes, purpose, warehouseId);
    let partnerId = Number.isFinite(formPartner) && formPartner > 0
      ? formPartner
      : await findPartner(supplier, supplierCode, null);
    // The headings we know (this company's first), and our product
    // attributes (0110), so attribute columns land on the right attribute.
    const { data: aliasData } = await supabase.rpc("column_alias_map", { p_partner_id: partnerId });
    const aliases = (aliasData ?? []) as AliasRow[];
    const { data: attrData } = await supabase.rpc("list_product_attributes");
    const attributes = ((attrData ?? []) as { key: string; name: string; status?: string }[])
      .filter((a) => a.status !== "inactive")
      .map((a): AttributeDef => ({ key: a.key, name: a.name }));
    // Our own company (0131): kept out of the supplier, so the other company
    // on the document is taken as the supplier.
    const own = await ownCompany();
    // Of the companies the document names, the one we already know wins
    // (0132); the header then says it.
    const settleSupplier = async (page: { bytes: Uint8Array; mime: string } | null = null): Promise<number | null> => {
      const pick = await pickSupplier(header, file.name, own, page);
      header.supplier_name = pick.name;
      return pick.partnerId;
    };
    const mime = file.type || (name.endsWith(".pdf") ? "application/pdf" : "image/jpeg");
    // A PDF that carries its text is read where the words stand, exactly;
    // a scan or photo is read by the AI (0114).
    const asText = mime === "application/pdf"
      ? await readPdfText(bytes, aliases, overrides, true, attributes, own)
      : null;
    if (/\.(xlsx|xlsm|xls|csv)$/.test(name)) {
      ({ header, columns, lines, totals } = await readSpreadsheet(bytes, aliases, overrides, true, attributes, own));
      header.registration_number = normalizeRegNo(header.registration_number);
      source = name.endsWith(".csv") ? "csv" : "xlsx";
      partnerId ??= await settleSupplier();
    } else if (asText) {
      ({ header, columns, lines, totals } = asText);
      header.registration_number = normalizeRegNo(header.registration_number);
      source = "pdf_text";
      partnerId ??= await settleSupplier({ bytes, mime });
    } else {
      const hints = await readingHints(partnerId, aliases, overrides, overrideHeaders);
      ({ header, columns, lines, verified, totals } = await readDocument(bytes, mime, aliases, hints, own));
      // What the AI was told stands for the columns too, so a correction made
      // on this reading is what gets learned (0114).
      columns = withHints(columns, hints, overrides, overrideHeaders);
      header.registration_number = normalizeRegNo(header.registration_number);
      source = "gemini";
      partnerId ??= await settleSupplier();
    }

    // A company chosen on the form, or found earlier, under the name we keep.
    if (partnerId && !header.supplier_name && !supplier) header.supplier_name = await partnerName(partnerId);
    const merged = aggregate(lines);
    await noteEvidence(admin, documentId, {
      source, supplier_id: partnerId, supplier_name: supplier ?? header.supplier_name,
      registration_number: header.registration_number, doc_number: header.doc_number ?? (deliveryNumber || null),
      doc_date: header.doc_date ?? deliveryDate, line_count: merged.length, addressee: header.addressee ?? null,
      // How the reading went, for AIの稼働状況 (0133).
      quality: readingQuality(lines, source, verified, totals),
    });
    if (merged.length === 0) return json({ message: "No JAN rows found.", document_id: documentId }, 422);
    const withProducts = await resolveLines(supabase, partnerId, merged);
    const totalQty = merged.reduce((s, l) => s + (l.planned_quantity || 0), 0);
    const orderDate = merged.find((l) => l.order_date)?.order_date ?? null;

    const mergedHeader: Header = {
      supplier_name: supplier ?? header.supplier_name,
      registration_number: header.registration_number,
      // A sheet may repeat its code for us (得意先コード) on every line (0112).
      customer_code: header.customer_code ?? merged.map((l) => l.customer_code).find((c) => c) ?? null,
      doc_number: header.doc_number ?? (deliveryNumber || null),
      doc_date: header.doc_date ?? deliveryDate,
      addressee: header.addressee ?? null,
      supplier_candidates: header.supplier_candidates ?? [],
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
        source, dry_run: true, verified, training_id: trainingId, document_id: documentId,
        header: mergedHeader,
        supplier_code: supplierCode,
        partner_id: partnerId,
        delivery_number: deliveryNumber || header.doc_number || "",
        order_date: orderDate,
        columns,
        line_count: merged.length, total_quantity: totalQty,
        // The lines against the document's own totals (0114).
        totals,
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
      documentId,
    });
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
