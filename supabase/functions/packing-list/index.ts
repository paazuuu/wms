// packing-list (0192): what each column of a packing list means, when the
// device's own words do not tell — the AI reads the headings and a few rows
// (Japanese, Chinese, English …) and names each column. Nothing is kept but
// the call's record (ai_calls).
//
// POST { headers: string[], samples: string[][] }
//   → { data: { columns: [{ index, field }] } }
// field: carton_no, carton_count, description, maker, item_code, jan,
// quantity, size, length, width, height, carton_weight, net_weight, note,
// ignore.

const FIELDS = [
  "carton_no", "carton_count", "description", "maker", "item_code", "jan", "quantity", "size",
  "length", "width", "height", "carton_weight", "net_weight", "note", "ignore",
];
const DEFAULT_MODEL = "gemini-3.1-flash-lite";

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
      body: JSON.stringify({ function_name: "packing-list", task: "packing_columns", ...row }),
    });
  } catch (_) { /* the record is not worth failing for */ }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "POST only" }, 405);
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "");
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
  const headers = (Array.isArray(b.headers) ? b.headers : []).slice(0, 60).map((h) => String(h ?? "").slice(0, 120));
  if (!headers.some((h) => h.trim() !== "")) return json({ message: "headers are required" }, 400);
  const samples = (Array.isArray(b.samples) ? b.samples : []).slice(0, 8)
    .filter((r): r is unknown[] => Array.isArray(r))
    .map((r) => r.slice(0, 60).map((c) => (c === null || c === undefined ? "" : String(c).slice(0, 120))));

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
    return json({ data: { columns: [] }, message: "no AI key" });
  }

  const prompt =
    "これは出荷のパッキングリスト(箱ごとの中身の表)の見出し行とデータ例です。見出しは日本語・中国語・英語など様々です。" +
    "各列が何を表すか、次のどれかで答えてください: carton_no=箱番号(C/No.), carton_count=同じ箱の数(箱量・箱数), " +
    "description=品名, maker=メーカー・ブランド, item_code=品番・型番, jan=JAN/EANバーコード, quantity=数量(1箱の中の個数), " +
    "size=箱のサイズ(縦×横×高さが1つのセル), length=縦・長さ, width=横・幅, height=高さ, carton_weight=箱の総重量(G.W.), " +
    "net_weight=正味重量・按数量分重量(N.W.), note=備考, ignore=どれでもない・集計欄。" +
    "見出しだけでなく値も見て判断すること(13桁の数字はjan、36*32*30のような値はsize)。\n" +
    JSON.stringify({ headers, samples });
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
              columns: {
                type: "array",
                items: {
                  type: "object",
                  properties: { index: { type: "integer" }, field: { type: "string", enum: FIELDS } },
                  required: ["index", "field"],
                },
              },
            },
            required: ["columns"],
          },
        },
      }),
    });
    if (res.status !== 503 && res.status !== 429) break;
    await new Promise((r) => setTimeout(r, 700 * (i + 1)));
  }
  if (!res || !res.ok) {
    const body = res ? await res.text() : "";
    await log({ key_id: keyId, ok: false, model, http_status: res?.status ?? null, error_kind: "http", error: body.slice(0, 500), attempts,
      latency_ms: Date.now() - started });
    return json({ data: { columns: [] }, message: `AI error ${res?.status ?? "?"}` });
  }
  const body = await res.json();
  const usage = body?.usageMetadata ?? {};
  let columns: { index: number; field: string }[] = [];
  try {
    const parsed = JSON.parse(body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}");
    columns = (Array.isArray(parsed.columns) ? parsed.columns : [])
      .filter((c: { index: unknown; field: unknown }) =>
        Number.isInteger(c.index) && (c.index as number) >= 0 && (c.index as number) < headers.length &&
        FIELDS.includes(String(c.field)))
      .map((c: { index: number; field: string }) => ({ index: c.index, field: c.field }));
  } catch (_) {
    columns = [];
  }
  await log({ key_id: keyId, ok: true, model, http_status: res.status, attempts, latency_ms: Date.now() - started,
    input_tokens: usage.promptTokenCount ?? null, output_tokens: usage.candidatesTokenCount ?? null });
  return json({ data: { columns } });
});
