// price-currency (0197): in which currency each sales price of a shipping list
// is written. The list is usually in 円, but the person who made it may have
// written some (or all) prices in 人民元 — about 1/20 of the 円 figure — so
// each row is judged from its product, its price and what we bought it for
// (in 円). Nothing is kept but the call's record (ai_calls).
//
// POST { rows: [{ i, name?, maker?, code?, price_ex?, price_tax?, purchase_jpy? }], hint? }
//   → { data: { rows: [{ i, currency: "JPY"|"CNY"|"USD", confident: boolean }] } }

const DEFAULT_MODEL = "gemini-3.1-flash-lite";
const CURRENCIES = ["JPY", "CNY", "USD"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const url = Deno.env.get("SUPABASE_URL") ?? "";
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

async function rpc(name: string, args: unknown, token: string): Promise<unknown> {
  const r = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: token === service ? service : anon, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(args ?? {}),
  });
  if (!r.ok) throw new Error(`${name}: ${r.status} ${await r.text()}`);
  return await r.json();
}

async function log(row: Record<string, unknown>) {
  try {
    await fetch(`${url}/rest/v1/ai_calls`, {
      method: "POST",
      headers: { apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ function_name: "price-currency", task: "price_currency", ...row }),
    });
  } catch (_) { /* the record is not worth failing for */ }
}

function num(v: unknown): number | null {
  const n = typeof v === "number" ? v : Number(String(v ?? "").replace(/,/g, ""));
  return Number.isFinite(n) ? n : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "POST only" }, 405);
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ message: "sign in required" }, 401);
  const who = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: `Bearer ${token}` } });
  if (!who.ok) return json({ message: "sign in required" }, 401);
  try {
    if ((await rpc("can_view_outbound", {}, token)) !== true) return json({ message: "not permitted: ship.complete required" }, 403);
  } catch (e) {
    return json({ message: String(e) }, 500);
  }

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch (_) {
    return json({ message: "a JSON body is required" }, 400);
  }
  const rows = (Array.isArray(b.rows) ? b.rows : []).slice(0, 150).map((r: Record<string, unknown>) => ({
    i: Number(r.i),
    name: String(r.name ?? "").slice(0, 80),
    maker: String(r.maker ?? "").slice(0, 40),
    code: String(r.code ?? "").slice(0, 40),
    price_ex: num(r.price_ex),
    price_tax: num(r.price_tax),
    purchase_jpy: num(r.purchase_jpy),
  })).filter((r) => Number.isInteger(r.i) && (r.price_ex !== null || r.price_tax !== null));
  if (rows.length === 0) return json({ data: { rows: [] } });
  const hint = String(b.hint ?? "").slice(0, 200);

  let key: string | null = Deno.env.get("GEMINI_API_KEY") ?? null;
  let keyId: number | null = null;
  let model = Deno.env.get("GEMINI_MODEL") ?? DEFAULT_MODEL;
  try {
    const k = await rpc("ai_active_key", { p_id: null }, service) as { key_id?: number; key?: string; model?: string | null } | null;
    if (k?.key) {
      key = k.key;
      keyId = k.key_id ?? null;
      if (k.model) model = k.model;
    }
  } catch (_) { /* the server's own key is used */ }
  if (!key) {
    await log({ ok: false, model, error_kind: "no_key", error: "no API key is chosen or set", attempts: 0 });
    return json({ data: { rows: [] }, message: "no AI key" });
  }

  const prompt =
    "日本の倉庫から出荷する文房具などの出荷明細の販売単価です。通常は日本円（JPY）ですが、作成者が一部または全部を人民元（CNY、1元は約20円）で書いていることがあります。" +
    "各行について、単価がどの通貨で書かれているか判断してください。判断材料: purchase_jpy は当社の仕入れ値（円）。販売単価が仕入れ値（円）の数分の1以下なら人民元の可能性が高い。" +
    "仕入れ値がない行は、商品の種類と一般的な日本の価格から判断（例: ボールペン1本が5.5なら元、55なら円）。確信が低い場合は confident=false。" +
    (hint ? `見出し・備考: ${hint}\n` : "\n") +
    JSON.stringify(rows);
  const started = Date.now();
  let res: Response | null = null;
  let attempts = 0;
  for (let i = 0; i < 3; i++) {
    attempts++;
    res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0,
          responseSchema: {
            type: "object",
            properties: {
              rows: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    i: { type: "integer" },
                    currency: { type: "string", enum: CURRENCIES },
                    confident: { type: "boolean" },
                  },
                  required: ["i", "currency", "confident"],
                },
              },
            },
            required: ["rows"],
          },
        },
      }),
    });
    if (res.status !== 503 && res.status !== 429) break;
    await new Promise((r) => setTimeout(r, 700 * (i + 1)));
  }
  if (!res || !res.ok) {
    const text = res ? await res.text() : "";
    await log({ key_id: keyId, ok: false, model, http_status: res?.status ?? null, error_kind: "http", error: text.slice(0, 500), attempts,
      latency_ms: Date.now() - started });
    return json({ data: { rows: [] }, message: `AI error ${res?.status ?? "?"}` });
  }
  const body = await res.json();
  const usage = body?.usageMetadata ?? {};
  const asked = new Set(rows.map((r) => r.i));
  let out: { i: number; currency: string; confident: boolean }[] = [];
  try {
    const parsed = JSON.parse(body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}");
    out = (Array.isArray(parsed.rows) ? parsed.rows : [])
      .filter((r: { i: unknown; currency: unknown }) => Number.isInteger(r.i) && asked.has(r.i as number) && CURRENCIES.includes(String(r.currency)))
      .map((r: { i: number; currency: string; confident: unknown }) => ({ i: r.i, currency: r.currency, confident: r.confident === true }));
  } catch (_) {
    out = [];
  }
  await log({ key_id: keyId, ok: true, model, http_status: res.status, attempts, latency_ms: Date.now() - started,
    input_tokens: usage.promptTokenCount ?? null, output_tokens: usage.candidatesTokenCount ?? null });
  return json({ data: { rows: out } });
});
