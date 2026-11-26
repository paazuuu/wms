// 登録番号の確認 (0229): invoices' 登録番号 checked against 国税庁の適格請求書
// 発行事業者公表システム Web-API, for whoever is signed in.
//
//   POST /invoice-check  {numbers: string[], refresh?: boolean}
//     → {configured, results: [{number, status, name, address, kind,
//        registration_date, disposal_date, expire_date, checked_at, cached}],
//        bad: string[]}
//
// An answer is kept a week (invoice_registrations) and given from there; a
// refresh asks again. Without the アプリケーションID (integration_keys
// 'nta_invoice', set in 自社情報) only what is kept is given.
import { adminClient, callerClient } from "../_shared/require_permission.ts";
import { normalizeRegNo, ntaRequestUrl, readNtaAnswer } from "../_shared/invoice_registration.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const WEEK_MS = 7 * 86_400_000;
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "not found" }, 404);
  const caller = callerClient(req, supabaseUrl);
  const { data: userData } = await caller.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ message: "not permitted: sign in required" }, 401);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ message: "bad request" }, 400);
  }
  const given = Array.isArray(body.numbers) ? body.numbers.slice(0, 50) : [];
  const numbers = [...new Set(given.map(normalizeRegNo).filter((n): n is string => n !== null))];
  const bad = given.filter((n) => normalizeRegNo(n) === null).map(String);
  const refresh = body.refresh === true;
  const admin = adminClient(supabaseUrl);

  const { data: kept } = numbers.length === 0
    ? { data: [] }
    : await admin.from("invoice_registrations").select("*").in("number", numbers);
  const keptBy = new Map<string, Record<string, unknown>>(
    ((kept ?? []) as Record<string, unknown>[]).map((r) => [String(r.number), r]),
  );
  const fresh = (r: Record<string, unknown> | undefined) =>
    r !== undefined && Date.now() - new Date(String(r.checked_at)).getTime() < WEEK_MS;
  const toAsk = numbers.filter((n) => refresh || !fresh(keptBy.get(n)));

  const { data: key } = await admin.from("integration_keys").select("secret").eq("service", "nta_invoice").maybeSingle();
  const appId = typeof key?.secret === "string" && key.secret.trim() ? key.secret.trim() : null;
  let failure: string | null = null;
  if (appId && toAsk.length > 0) {
    for (let i = 0; i < toAsk.length; i += 10) {
      const chunk = toAsk.slice(i, i + 10);
      try {
        const r = await fetch(ntaRequestUrl(appId, chunk), { headers: { Accept: "application/json" } });
        if (!r.ok) {
          failure = `nta_http_${r.status}`;
          console.error("invoice-check", r.status, (await r.text()).slice(0, 300));
          break;
        }
        const answers = readNtaAnswer(await r.json(), chunk);
        const now = new Date().toISOString();
        const rows = answers.map((a) => ({ ...a, checked_at: now, checked_by: user.id }));
        const { error } = await admin.from("invoice_registrations").upsert(rows, { onConflict: "number" });
        if (error) console.error("invoice-check keep", error.message);
        for (const row of rows) keptBy.set(row.number, row);
      } catch (e) {
        failure = "nta_unreachable";
        console.error("invoice-check", String(e));
        break;
      }
    }
  }
  const results = numbers.filter((n) => keptBy.has(n)).map((n) => {
    const r = keptBy.get(n)!;
    const { raw: _raw, checked_by: _by, ...shown } = r;
    return { ...shown, cached: !toAsk.includes(n) || !appId };
  });
  return json({ configured: appId !== null, failure, results, bad });
});
