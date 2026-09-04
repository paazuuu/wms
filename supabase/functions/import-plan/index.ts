// Upload-a-file plan importer for the WMS back office.
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
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as XLSX from "npm:xlsx@0.18.5";
import { encodeBase64 } from "jsr:@std/encoding/base64";

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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const UNKNOWN_CODE = "UNKNOWN";

function normalizeJan(value: unknown): string {
  if (value === null || value === undefined) return "";
  let s = "";
  for (const ch of String(value)) {
    const c = ch.codePointAt(0)!;
    if (c >= 0xff10 && c <= 0xff19) s += String.fromCharCode(c - 0xff10 + 0x30);
    else if (c === 0xff0e) s += ".";
    else s += ch;
  }
  const dot = s.indexOf(".");
  if (dot >= 0) s = s.slice(0, dot);
  let digits = s.replace(/\D/g, "");
  if (digits.length === 12) digits = "0" + digits;
  return digits;
}
const isJan = (d: string) => d.length === 13 || d.length === 8;
function toInt(v: unknown): number | null {
  const n = Number(String(v ?? "").replace(/[^\d.-]/g, ""));
  return Number.isFinite(n) ? Math.round(n) : null;
}
function toNum(v: unknown): number | null {
  const n = Number(String(v ?? "").replace(/[^\d.-]/g, ""));
  return Number.isFinite(n) && String(v ?? "").trim() !== "" ? n : null;
}
function dateStr(v: unknown): string | null {
  if (v === null || v === undefined || v === "") return null;
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).trim();
}
function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}
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
  return out; // keep whatever was read so it can still be shown/edited
}

type Header = {
  supplier_name: string | null;
  registration_number: string | null;
  customer_code: string | null;
  doc_number: string | null;
  doc_date: string | null;
};
const emptyHeader = (): Header => ({
  supplier_name: null, registration_number: null,
  customer_code: null, doc_number: null, doc_date: null,
});

type Rec = {
  jan: string;
  qty: number;
  product_code: string;
  product_name: string;
  spec: string | null;
  unit: number | null;
  amount: number | null;
  tax_rate: number | null;
  order_date: string | null;
};

const QTY_KEYS = ["発注数量", "数量", "発注数", "数"];
const MAKER_KEYS = ["メーカー", "maker", "ﾒｰｶｰ"];
const PNUM_KEYS = ["品番", "項目", "商品コード", "品名"];
const SPEC_KEYS = ["規格", "仕様"];
const UNIT_KEYS = ["単価", "定価"];
const AMOUNT_KEYS = ["金額", "調達合計金額"];
const TAX_KEYS = ["税率", "消費税率"];
const DATE_KEYS = ["注文日", "発注日", "日付", "作成日", "納品日"];

function parseXlsx(bytes: Uint8Array): { records: Rec[]; header: Header } {
  const wb = XLSX.read(bytes, { type: "array", cellDates: true });
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, {
    header: 1, raw: true, defval: null,
  }) as unknown[][];
  const ncol = rows.reduce((m, r) => Math.max(m, r.length), 0);

  let janCol = -1, best = 0;
  for (let c = 0; c < ncol; c++) {
    let cnt = 0;
    for (const r of rows) if (isJan(normalizeJan(r[c]))) cnt++;
    if (cnt > best) { best = cnt; janCol = c; }
  }
  if (janCol < 0 || best === 0) throw new Error("Could not find a JAN column.");

  const findCell = (keys: string[]): [number, number] => {
    for (let ri = 0; ri < rows.length; ri++) {
      const r = rows[ri];
      for (let c = 0; c < r.length; c++) {
        const v = r[c];
        if (typeof v === "string" && keys.some((k) => v.includes(k))) return [ri, c];
      }
    }
    return [-1, -1];
  };
  const [headerRow, qtyCol] = findCell(QTY_KEYS);
  const findCol = (keys: string[]): number => {
    if (headerRow >= 0) {
      const r = rows[headerRow];
      for (let c = 0; c < r.length; c++) {
        const v = r[c];
        if (typeof v === "string" && keys.some((k) => v.includes(k))) return c;
      }
    }
    return findCell(keys)[1];
  };
  const makerCol = findCol(MAKER_KEYS);
  const pnumCol = findCol(PNUM_KEYS);
  const specCol = findCol(SPEC_KEYS);
  const unitCol = findCol(UNIT_KEYS);
  const amountCol = findCol(AMOUNT_KEYS);
  const taxCol = findCol(TAX_KEYS);
  const dateCol = findCol(DATE_KEYS);
  const cell = (r: unknown[], c: number) => (c >= 0 && c < r.length ? r[c] : null);

  const out: Rec[] = [];
  for (const r of rows) {
    const jan = normalizeJan(cell(r, janCol));
    if (!isJan(jan)) continue;
    const maker = cell(r, makerCol) ?? "";
    const pnum = cell(r, pnumCol) ?? "";
    const spec = cell(r, specCol);
    out.push({
      jan,
      qty: toInt(cell(r, qtyCol)) ?? 0,
      product_code: String(pnum),
      product_name: `${maker} ${pnum}`.trim(),
      spec: spec == null ? null : String(spec).trim() || null,
      unit: toInt(cell(r, unitCol)),
      amount: toInt(cell(r, amountCol)),
      tax_rate: toNum(cell(r, taxCol)),
      order_date: dateStr(cell(r, dateCol)),
    });
  }
  // Excel plans carry no printed note header; leave it for the operator to fill.
  return { records: out, header: emptyHeader() };
}

const PROMPT =
  "この画像/PDFは日本の物流の納品書または注文明細です。次の2つを返してください。\n" +
  "1) header: 書類の相手先(仕入先/発行元)の情報。" +
  "{supplier_name: 会社名, registration_number: インボイス登録番号(Tで始まる13桁), " +
  "customer_code: お客様コード/得意先コード, doc_number: 伝票番号/納品書番号, " +
  "doc_date: 日付(YYYY-MM-DD)}。読めない項目は省略。\n" +
  "2) lines: 明細表。各行を {jan_code, product_name, spec, quantity, unit_price, " +
  "amount, tax_rate}。jan_code は商品のバーコード数字(13桁または8桁)で半角数字のみ・" +
  "ハイフンや空白なし。spec は規格/仕様、unit_price は単価、amount は金額、" +
  "tax_rate は税率(%)の数値。読めない項目は省略。住所・電話・登録番号・合計金額は" +
  "JANとして扱わない。数量が読めない行は quantity を省略。";
const SCHEMA = {
  type: "object",
  properties: {
    header: {
      type: "object",
      properties: {
        supplier_name: { type: "string" },
        registration_number: { type: "string" },
        customer_code: { type: "string" },
        doc_number: { type: "string" },
        doc_date: { type: "string" },
      },
    },
    lines: {
      type: "array",
      items: {
        type: "object",
        properties: {
          jan_code: { type: "string" },
          product_name: { type: "string" },
          spec: { type: "string" },
          quantity: { type: "integer" },
          unit_price: { type: "number" },
          amount: { type: "number" },
          tax_rate: { type: "number" },
        },
        required: ["jan_code"],
      },
    },
  },
  required: ["lines"],
};

async function parseWithGemini(
  bytes: Uint8Array,
  mime: string,
): Promise<{ records: Rec[]; header: Header }> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set on the server.");
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash";
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const payload = {
    contents: [{
      role: "user",
      parts: [
        { text: PROMPT },
        { inline_data: { mime_type: mime, data: encodeBase64(bytes) } },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: SCHEMA,
      temperature: 0,
    },
  };
  let res: Response | null = null;
  for (let attempt = 0; attempt < 4; attempt++) {
    res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: JSON.stringify(payload),
    });
    if (res.status !== 503 && res.status !== 429) break;
    if (attempt < 3) await new Promise((r) => setTimeout(r, 700 * (attempt + 1)));
  }
  if (!res || !res.ok) {
    throw new Error(`Gemini error ${res ? res.status : "?"}: ${res ? await res.text() : ""}`);
  }
  const body = await res.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: { lines?: unknown[]; header?: Record<string, unknown> } = {};
  try { parsed = JSON.parse(text); } catch (_) { parsed = {}; }

  const h = parsed.header ?? {};
  const header: Header = {
    supplier_name: str(h.supplier_name),
    registration_number: normalizeRegNo(h.registration_number),
    customer_code: str(h.customer_code),
    doc_number: str(h.doc_number),
    doc_date: str(h.doc_date),
  };

  const lines = Array.isArray(parsed.lines) ? parsed.lines : [];
  const out: Rec[] = [];
  for (const ln of lines as Record<string, unknown>[]) {
    const jan = normalizeJan(ln.jan_code);
    if (!isJan(jan)) continue;
    out.push({
      jan, qty: toInt(ln.quantity) ?? 0, product_code: "",
      product_name: String(ln.product_name ?? ""),
      spec: ln.spec == null ? null : String(ln.spec).trim() || null,
      unit: toInt(ln.unit_price), amount: toInt(ln.amount),
      tax_rate: toNum(ln.tax_rate), order_date: null,
    });
  }
  return { records: out, header };
}

function aggregate(records: Rec[]) {
  const map = new Map<string, Record<string, unknown>>();
  for (const r of records) {
    let m = map.get(r.jan);
    if (!m) {
      m = {
        jan_code: r.jan, product_code: r.product_code,
        product_name: r.product_name, spec: r.spec, planned_quantity: 0,
        unit_price: r.unit, amount: 0, tax_rate: r.tax_rate,
        order_date: r.order_date,
      };
      map.set(r.jan, m);
    }
    m.planned_quantity = (m.planned_quantity as number) + (r.qty || 0);
    if (r.amount) m.amount = (m.amount as number) + r.amount;
    if (m.spec == null && r.spec != null) m.spec = r.spec;
    if (m.tax_rate == null && r.tax_rate != null) m.tax_rate = r.tax_rate;
  }
  return [...map.values()];
}

// Find or create the supplier (company). Matches by 登録番号, then code, then
// name. When nothing identifies the company, routes to the shared UNKNOWN
// bucket so the delivery still gets a distinct, traceable reference series.
async function resolveSupplier(
  name: string | null,
  code: string | null,
  regNo: string | null,
): Promise<{ id: number; unidentified: boolean }> {
  if (regNo) {
    const { data } = await supabase.from("delivery_suppliers")
      .select("id").eq("registration_number", regNo).maybeSingle();
    if (data) return { id: data.id as number, unidentified: false };
  }
  if (code && code !== UNKNOWN_CODE) {
    const { data } = await supabase.from("delivery_suppliers")
      .select("id").eq("code", code).maybeSingle();
    if (data) return { id: data.id as number, unidentified: false };
  }
  if (name) {
    const { data } = await supabase.from("delivery_suppliers")
      .select("id").eq("name", name).maybeSingle();
    if (data) return { id: data.id as number, unidentified: false };
  }
  if (name || code || regNo) {
    const { data, error } = await supabase.from("delivery_suppliers")
      .insert({ name: name ?? code ?? regNo, code, registration_number: regNo })
      .select("id").single();
    if (error) throw new Error(error.message);
    return { id: data.id as number, unidentified: false };
  }
  // Nothing identifies this company → the UNKNOWN bucket.
  const { data } = await supabase.from("delivery_suppliers")
    .select("id").eq("code", UNKNOWN_CODE).maybeSingle();
  if (data) return { id: data.id as number, unidentified: true };
  const { data: created, error } = await supabase.from("delivery_suppliers")
    .insert({ code: UNKNOWN_CODE, name: "未確認（要手動確認）" })
    .select("id").single();
  if (error) throw new Error(error.message);
  return { id: created.id as number, unidentified: true };
}

// Turn one aggregated line back into a plan-line row.
function toLineRow(l: Record<string, unknown>): Record<string, unknown> {
  return {
    jan_code: normalizeJan(l.jan_code),
    product_code: str(l.product_code) ?? "",
    product_name: str(l.product_name) ?? "",
    spec: str(l.spec),
    planned_quantity: toInt(l.planned_quantity) ?? 0,
    unit_price: toInt(l.unit_price),
    amount: toInt(l.amount),
    tax_rate: toNum(l.tax_rate),
    order_date: str(l.order_date),
  };
}

// Save a plan + its lines. Shared by the multipart one-shot and the JSON commit.
async function commit(input: {
  deliveryNumber: string;
  supplier: string | null;
  supplierCode: string | null;
  registrationNumber: string | null;
  customerCode: string | null;
  docNumber: string | null;
  deliveryDate: string | null;
  orderDate: string | null;
  lines: Record<string, unknown>[];
  source: string;
}): Promise<Response> {
  const lines = input.lines.map(toLineRow).filter((l) => isJan(l.jan_code as string));
  if (lines.length === 0) return json({ message: "No JAN rows found." }, 422);
  const totalQty = lines.reduce((s, l) => s + (l.planned_quantity as number), 0);

  const { id: supplierId, unidentified } = await resolveSupplier(
    input.supplier, input.supplierCode, input.registrationNumber,
  );
  const { data: ref } = await supabase.rpc("assign_reference", { p_supplier_id: supplierId });
  const referenceNo = (ref as string) ?? null;

  const { data: plan, error: e1 } = await supabase
    .from("delivery_plans")
    .insert({
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
      needs_review: unidentified,
      status: "open",
    })
    .select("id")
    .single();
  if (e1) return json({ message: e1.message }, 400);

  const withId = lines.map((l) => ({ ...l, delivery_plan_id: plan.id }));
  const { error: e2 } = await supabase.from("delivery_plan_lines").insert(withId);
  if (e2) return json({ message: e2.message }, 400);

  return json({ data: {
    source: input.source, plan_id: plan.id, delivery_number: input.deliveryNumber,
    reference_no: referenceNo, needs_review: unidentified,
    line_count: lines.length, total_quantity: totalQty,
  } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);

  try {
    const ctype = req.headers.get("content-type") ?? "";

    // COMMIT: the reviewed/edited header + lines come back as JSON.
    if (ctype.includes("application/json")) {
      const b = await req.json();
      const deliveryNumber = String(b.delivery_number ?? "").trim();
      if (!deliveryNumber) return json({ message: "delivery_number is required" }, 400);
      const lines = Array.isArray(b.lines) ? b.lines : [];
      return await commit({
        deliveryNumber,
        supplier: str(b.supplier),
        supplierCode: str(b.supplier_code),
        registrationNumber: normalizeRegNo(b.registration_number),
        customerCode: str(b.customer_code),
        docNumber: str(b.doc_number),
        deliveryDate: str(b.delivery_date),
        orderDate: str(b.order_date),
        lines,
        source: str(b.source) ?? "review",
      });
    }

    // PREVIEW / one-shot: a file is uploaded and parsed here.
    const form = await req.formData();
    const file = form.get("file");
    const deliveryNumber = String(form.get("delivery_number") ?? "").trim();
    const supplier = str(form.get("supplier"));
    const supplierCode = str(form.get("supplier_code"));
    const deliveryDate = str(form.get("delivery_date"));
    const dryRun = String(form.get("dry_run") ?? "") === "1";
    if (!(file instanceof File)) return json({ message: "file is required" }, 400);

    const name = file.name.toLowerCase();
    const bytes = new Uint8Array(await file.arrayBuffer());
    let records: Rec[];
    let header: Header;
    let source: string;
    if (name.endsWith(".xlsx") || name.endsWith(".xlsm")) {
      ({ records, header } = parseXlsx(bytes));
      source = "xlsx";
    } else {
      const mime = file.type || (name.endsWith(".pdf") ? "application/pdf" : "image/jpeg");
      ({ records, header } = await parseWithGemini(bytes, mime));
      source = "gemini";
    }

    const lines = aggregate(records);
    const totalQty = lines.reduce((s, l) => s + (l.planned_quantity as number), 0);
    if (lines.length === 0) return json({ message: "No JAN rows found." }, 422);
    const orderDate = (lines.find((l) => l.order_date)?.order_date as string) ?? null;

    // Operator-supplied form fields win over what was auto-read.
    const mergedHeader: Header = {
      supplier_name: supplier ?? header.supplier_name,
      registration_number: header.registration_number,
      customer_code: header.customer_code,
      doc_number: header.doc_number ?? (deliveryNumber || null),
      doc_date: header.doc_date ?? deliveryDate,
    };

    if (dryRun) {
      return json({ data: {
        source, dry_run: true,
        header: mergedHeader,
        supplier_code: supplierCode,
        delivery_number: deliveryNumber || header.doc_number || "",
        order_date: orderDate,
        line_count: lines.length, total_quantity: totalQty,
        lines,
      } });
    }

    // One-shot save (no review): needs a delivery number now.
    const num = deliveryNumber || mergedHeader.doc_number;
    if (!num) return json({ message: "delivery_number is required" }, 400);
    return await commit({
      deliveryNumber: num,
      supplier: mergedHeader.supplier_name,
      supplierCode,
      registrationNumber: mergedHeader.registration_number,
      customerCode: mergedHeader.customer_code,
      docNumber: mergedHeader.doc_number,
      deliveryDate,
      orderDate,
      lines,
      source,
    });
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
