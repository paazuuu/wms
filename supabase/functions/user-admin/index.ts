// user-admin (0194): an ADMIN adds users from the app, or gives one a new
// password — no Supabase dashboard, no mail. The account is made with the
// service role (email confirmed) and a temporary password that is returned
// once, for the ADMIN to hand over; admin_provision_user then gives it its
// roles and warehouses.
//
// POST { action: "create", users: [{ email, name?, tier: "user"|"manager"|"admin" }] }
//   → { data: { results: [{ email, tier, status: "created"|"existing"|"error", password?, error? }] } }
// POST { action: "reset_password", user_id }
//   → { data: { password } }

const url = Deno.env.get("SUPABASE_URL") ?? "";
const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

// The roles each kind of user gets (0193's tiers).
const TIER_ROLES: Record<string, string[]> = {
  user: ["receiving", "inspector", "putaway_operator", "picker", "packer", "shipper"],
  manager: ["warehouse_manager"],
  admin: ["system_admin"],
};

const adminHeaders = { apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "application/json" };

/// 12 characters, no look-alikes (0/O, 1/l/I), at least a letter and a digit.
function tempPassword(): string {
  const letters = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
  const digits = "23456789";
  const all = letters + digits;
  for (;;) {
    const bytes = new Uint8Array(12);
    crypto.getRandomValues(bytes);
    const p = Array.from(bytes, (b) => all[b % all.length]).join("");
    if (/[a-zA-Z]/.test(p) && /[0-9]/.test(p)) return p;
  }
}

async function rpc(name: string, args: unknown, token: string): Promise<unknown> {
  const r = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: token === service ? service : anon, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(args ?? {}),
  });
  if (!r.ok) throw new Error(`${name}: ${r.status} ${await r.text()}`);
  return await r.json();
}

async function findUserId(email: string): Promise<string | null> {
  for (let page = 1; page <= 20; page++) {
    const r = await fetch(`${url}/auth/v1/admin/users?page=${page}&per_page=200`, { headers: adminHeaders });
    if (!r.ok) return null;
    const body = await r.json();
    const users = (body?.users ?? []) as { id: string; email?: string }[];
    const hit = users.find((u) => (u.email ?? "").toLowerCase() === email);
    if (hit) return hit.id;
    if (users.length < 200) return null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "POST only" }, 405);
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ message: "sign in required" }, 401);
  const who = await fetch(`${url}/auth/v1/user`, { headers: { apikey: anon, Authorization: `Bearer ${token}` } });
  if (!who.ok) return json({ message: "sign in required" }, 401);
  try {
    if ((await rpc("is_app_admin", {}, token)) !== true) return json({ message: "not permitted: ADMIN only" }, 403);
  } catch (e) {
    return json({ message: String(e) }, 500);
  }

  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch (_) {
    return json({ message: "a JSON body is required" }, 400);
  }

  if (b.action === "reset_password") {
    const id = String(b.user_id ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(id)) return json({ message: "user_id required" }, 400);
    const password = tempPassword();
    const r = await fetch(`${url}/auth/v1/admin/users/${id}`, {
      method: "PUT",
      headers: adminHeaders,
      body: JSON.stringify({ password }),
    });
    if (!r.ok) return json({ message: `reset failed: ${r.status} ${(await r.text()).slice(0, 200)}` }, 502);
    try {
      await rpc("log_audit", { p_event_type: "user.password_reset", p_entity_type: "app_user", p_entity_id: id }, service);
    } catch (_) { /* the record is not worth failing for */ }
    return json({ data: { password } });
  }

  if (b.action !== "create") return json({ message: "unknown action" }, 400);
  const list = (Array.isArray(b.users) ? b.users : []).slice(0, 100) as Record<string, unknown>[];
  const results: Record<string, unknown>[] = [];
  for (const u of list) {
    const email = String(u.email ?? "").trim().toLowerCase();
    const tier = String(u.tier ?? "user");
    const name = String(u.name ?? "").trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      results.push({ email, tier, status: "error", error: "invalid_email" });
      continue;
    }
    if (!TIER_ROLES[tier]) {
      results.push({ email, tier, status: "error", error: "invalid_tier" });
      continue;
    }
    let id: string | null = null;
    let password: string | null = tempPassword();
    let status = "created";
    const r = await fetch(`${url}/auth/v1/admin/users`, {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({ email, password, email_confirm: true, user_metadata: name ? { name } : {} }),
    });
    if (r.ok) {
      id = (await r.json())?.id ?? null;
    } else {
      const text = await r.text();
      if (r.status === 422 || /already|exists|registered/i.test(text)) {
        // Already has an account: its password stays; it gets the roles.
        id = await findUserId(email);
        password = null;
        status = "existing";
      } else {
        results.push({ email, tier, status: "error", error: `${r.status} ${text.slice(0, 200)}` });
        continue;
      }
    }
    if (!id) {
      results.push({ email, tier, status: "error", error: "user not found" });
      continue;
    }
    try {
      await rpc("admin_provision_user", {
        p_user_id: id, p_email: email, p_name: name || null, p_roles: TIER_ROLES[tier], p_warehouse_ids: null,
      }, service);
    } catch (e) {
      results.push({ email, tier, status: "error", user_id: id, error: String(e).slice(0, 200) });
      continue;
    }
    results.push({ email, tier, status, user_id: id, ...(password ? { password } : {}) });
  }
  return json({ data: { results } });
});
