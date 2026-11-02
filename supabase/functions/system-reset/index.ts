// システムの初期化 (0175): the environment emptied of what was done in it.
// The system administrator's only (system.reset), after typing 「初期化」.
//
//   POST /system-reset  {confirm: "初期化", products?, suppliers?, lookups?, logs?}
//
// The database is emptied first, in one go, as the caller (system_reset
// checks the permission and writes the audit line under their name); then
// the files those rows pointed to: the stock files and their evidence, the
// transfer proofs, and the products' pictures when the products went. A
// file that cannot be removed is said, not hidden — the data is already
// gone either way.
// The pictures found on the web per JAN (jan_photos, product-images/jan/,
// 0179) are what was looked up: they stay unless lookups is chosen.
import { adminClient, callerClient, clientPermitted, notPermittedMessage } from "../_shared/require_permission.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

/** Every file in [bucket], however deep. */
// deno-lint-ignore no-explicit-any
export async function listAll(admin: any, bucket: string, prefix = ""): Promise<string[]> {
  const out: string[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000, offset });
    if (error) throw new Error(`${bucket}: ${error.message}`);
    const items = (data ?? []) as { name: string; id: string | null }[];
    for (const it of items) {
      const path = prefix ? `${prefix}/${it.name}` : it.name;
      // A folder has no id; a file has one.
      if (it.id === null) out.push(...await listAll(admin, bucket, path));
      else out.push(path);
    }
    if (items.length < 1000) break;
  }
  return out;
}

async function emptyBucket(
  // deno-lint-ignore no-explicit-any
  admin: any,
  bucket: string,
  prefix = "",
  keep: (path: string) => boolean = () => false,
): Promise<{ removed: number; failed: number }> {
  const paths = (await listAll(admin, bucket, prefix)).filter((p) => !keep(p));
  let removed = 0, failed = 0;
  for (let i = 0; i < paths.length; i += 100) {
    const chunk = paths.slice(i, i + 100);
    const { error } = await admin.storage.from(bucket).remove(chunk);
    if (error) failed += chunk.length;
    else removed += chunk.length;
  }
  return { removed, failed };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "not found" }, 404);
  const caller = callerClient(req, supabaseUrl);
  if (!(await clientPermitted(caller, "system.reset"))) {
    return json({ message: notPermittedMessage("system.reset") }, 403);
  }
  const b = await req.json().catch(() => ({}));
  const options = {
    products: b.products !== false,
    suppliers: b.suppliers === true,
    lookups: b.lookups === true,
    logs: b.logs !== false,
  };
  const { data, error } = await caller.rpc("system_reset", { p_confirm: String(b.confirm ?? ""), p_options: options });
  if (error) return json({ message: error.message }, 400);

  const admin = adminClient(supabaseUrl);
  const files: Record<string, { removed: number; failed: number } | { error: string }> = {};
  const empty = async (name: string, bucket: string, prefix = "", keep?: (p: string) => boolean) => {
    try {
      files[name] = await emptyBucket(admin, bucket, prefix, keep);
    } catch (e) {
      files[name] = { error: String((e as Error)?.message ?? e) };
    }
  };
  for (const bucket of ["import-documents", "master-import-files", "payment-proofs"]) await empty(bucket, bucket);
  if (options.products) await empty("product-images", "product-images", "", (p) => p.startsWith("jan/"));
  if (options.lookups) {
    await empty("jan-photos", "product-images", "jan");
    const { error: e } = await admin.from("jan_photos").delete().neq("jan", "");
    if (e) files["jan-photos-rows"] = { error: e.message };
  }
  return json({ data: { ...(data as Record<string, unknown>), files } });
});
