// Upload-a-file plan importer for the WMS back office.
// POST /import-plan  (multipart/form-data)
//   file / delivery_number / supplier? / supplier_code? / delivery_date? / dry_run?
//
// Converts each source to one canonical shape, resolves the supplier (company),
// assigns a per-company reference number, and stores order dates for traceability.
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
function dateStr(v: unknown): string | null {
  if (v === null || v === undefined || v === "") return null;
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  return String(v).trim();
}

type Rec = {
  jan: string;
  qty: number;
  product_code: string;
  product_name: string;
  unit: number | null;
  amount: number | null;
  order_date: string | null;
};

const QTY_KEYS = ["発注数量", "数量", "発注数", "数"];
const MAKER_KEYS = ["メーカー", "maker", "ﾒｰｶｰ"];
const PNUM_KEYS = ["品番", "項目", "商品コード", "品名"];
const UNIT_KEYS = ["単価", "定価"];
const AMOUNT_KEYS = ["金額", "調達合計金額"];
const DATE_KEYS = ["注文日", "発注日", "日付", "作成日", "納品日"];

function parseXlsx(bytes: Uint8Array): Rec[] {
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
  const unitCol = findCol(UNIT_KEYS);
  const amountCol = findCol(AMOUNT_KEYS);
  const dateCol = findCol(DATE_KEYS);
  const cell = (r: unknown[], c: number) => (c >= 0 && c < r.length ? r[c] : null);

  const out: Rec[] = [];
  for (const r of rows) {
    const jan = normalizeJan(cell(r, janCol));
    if (!isJan(jan)) continue;
    const maker = cell(r, makerCol) ?? "";
    const pnum = cell(r, pnumCol) ?? "";
    out.push({
      jan,
      qty: toInt(cell(r, qtyCol)) ?? 0,
      product_code: String(pnum),
      product_name: `${maker} ${pnum}`.trim(),
      unit: toInt(cell(r, unitCol)),
      amount: toInt(cell(r, amountCol)),
      order_date: dateStr(cell(r, dateCol)),
    });
  }
  return out;
}

const PROMPT =
  "この画像/PDFは日本の物流の納品書または注文明細です。明細表を抽出し、各行を " +
  "{jan_code, product_name, quantity} のJSONで返してください。jan_code は商品の" +
  "バーコード数字（13桁または8桁）で半角数字のみ・ハイフンや空白なし。住所・電話・" +
  "登録番号(Tで始まる番号)・合計金額はJANとして扱わない。数量が読めない行は quantity を省略。";
const SCHEMA = {
  type: "object",
  properties: {
    lines: {
      type: "array",
      items: {
        type: "object",
        properties: {
          jan_code: { type: "string" },
          product_name: { type: "string" },
          quantity: { type: "integer" },
        },
        required: ["jan_code"],
      },
    },
  },
  required: ["lines"],
};

async function parseWithGemini(bytes: Uint8Array, mime: string): Promise<Rec[]> {
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
  let parsed: { lines?: unknown[] } = {};
  try { parsed = JSON.parse(text); } catch (_) { parsed = {}; }
  const lines = Array.isArray(parsed.lines) ? parsed.lines : [];
  const out: Rec[] = [];
  for (const ln of lines as Record<string, unknown>[]) {
    const jan = normalizeJan(ln.jan_code);
    if (!isJan(jan)) continue;
    out.push({
      jan, qty: toInt(ln.quantity) ?? 0, product_code: "",
      product_name: String(ln.product_name ?? ""), unit: null, amount: null,
      order_date: null,
    });
  }
  return out;
}

function aggregate(records: Rec[]) {
  const map = new Map<string, Record<string, unknown>>();
  for (const r of records) {
    let m = map.get(r.jan);
    if (!m) {
      m = {
        jan_code: r.jan, product_code: r.product_code,
        product_name: r.product_name, planned_quantity: 0,
        unit_price: r.unit, amount: 0, order_date: r.order_date,
      };
      map.set(r.jan, m);
    }
    m.planned_quantity = (m.planned_quantity as number) + (r.qty || 0);
    if (r.amount) m.amount = (m.amount as number) + r.amount;
  }
  return [...map.values()];
}

// Find or create the supplier (company); returns its id or null.
async function resolveSupplier(name: string | null, code: string | null) {
  if (!name && !code) return null;
  if (code) {
    const { data } = await supabase.from("delivery_suppliers")
      .select("id").eq("code", code).maybeSingle();
    if (data) return data.id as number;
  }
  if (name) {
    const { data } = await supabase.from("delivery_suppliers")
      .select("id").eq("name", name).maybeSingle();
    if (data) return data.id as number;
  }
  const { data, error } = await supabase.from("delivery_suppliers")
    .insert({ name: name ?? code, code: code }).select("id").single();
  if (error) throw new Error(error.message);
  return data.id as number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);

  try {
    const form = await req.formData();
    const file = form.get("file");
    const deliveryNumber = String(form.get("delivery_number") ?? "").trim();
    const supplier = (form.get("supplier") as string) || null;
    const supplierCode = (form.get("supplier_code") as string) || null;
    const deliveryDate = (form.get("delivery_date") as string) || null;
    const dryRun = String(form.get("dry_run") ?? "") === "1";
    if (!(file instanceof File)) return json({ message: "file is required" }, 400);
    if (!deliveryNumber) return json({ message: "delivery_number is required" }, 400);

    const name = file.name.toLowerCase();
    const bytes = new Uint8Array(await file.arrayBuffer());
    let records: Rec[];
    let source: string;
    if (name.endsWith(".xlsx") || name.endsWith(".xlsm")) {
      records = parseXlsx(bytes);
      source = "xlsx";
    } else {
      const mime = file.type || (name.endsWith(".pdf") ? "application/pdf" : "image/jpeg");
      records = await parseWithGemini(bytes, mime);
      source = "gemini";
    }

    const lines = aggregate(records);
    const totalQty = lines.reduce((s, l) => s + (l.planned_quantity as number), 0);
    if (lines.length === 0) return json({ message: "No JAN rows found." }, 422);
    const orderDate = (lines.find((l) => l.order_date)?.order_date as string) ?? null;

    if (dryRun) {
      return json({ data: { source, dry_run: true, line_count: lines.length,
        total_quantity: totalQty, order_date: orderDate, sample: lines.slice(0, 5) } });
    }

    const supplierId = await resolveSupplier(supplier, supplierCode);
    let referenceNo: string | null = null;
    if (supplierId) {
      const { data: ref } = await supabase.rpc("assign_reference", { p_supplier_id: supplierId });
      referenceNo = (ref as string) ?? null;
    }

    const { data: plan, error: e1 } = await supabase
      .from("delivery_plans")
      .insert({
        delivery_number: deliveryNumber,
        supplier_name: supplier,
        supplier_id: supplierId,
        reference_no: referenceNo,
        order_date: orderDate ?? deliveryDate,
        delivery_date: deliveryDate,
        doc_type: "plan",
        status: "open",
      })
      .select("id")
      .single();
    if (e1) return json({ message: e1.message }, 400);

    const withId = lines.map((l) => ({ ...l, delivery_plan_id: plan.id }));
    const { error: e2 } = await supabase.from("delivery_plan_lines").insert(withId);
    if (e2) return json({ message: e2.message }, 400);

    return json({ data: { source, plan_id: plan.id, delivery_number: deliveryNumber,
      reference_no: referenceNo, line_count: lines.length, total_quantity: totalQty } });
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
