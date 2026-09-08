// Warehouse / tenancy API for the WMS client (spec §4, §6, §49).
// Routes (function is mounted at /functions/v1/warehouses):
//   GET    /warehouses            overview: every warehouse + headline figures + totals
//   GET    /warehouses/:id/bins   bins of one warehouse
//   POST   /warehouses            create {code, name, ...} (+ optional default bins)
//   PATCH  /warehouses/:id        update {name?, description?, address?, phone?,
//                                         timezone?, status?}
//
// Uses the service role internally; verify_jwt=true (the app's anon key
// qualifies). The tables themselves stay read-only to the client, so every
// warehouse mutation lands here. Per-user role/warehouse-scope checks arrive
// with Step 3 (migration 0012) — the TODOs below mark exactly where.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
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

function str(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" ? null : s;
}

/** Bin codes seeded for a new warehouse when the wizard asks for them. */
function defaultBins(receiving: string, shipping: string) {
  return [
    { code: receiving, bin_type: "STAGING" },
    { code: "QC-01", bin_type: "QC_HOLD" },
    { code: shipping, bin_type: "SHIPPING" },
    { code: "A-01-01", bin_type: "PICKABLE" },
  ];
}

async function overview(): Promise<Response> {
  const { data, error } = await supabase.rpc("warehouse_overview");
  if (error) return json({ message: error.message }, 400);
  return json({ data });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("warehouses");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    // GET /warehouses
    if (req.method === "GET" && rest.length === 0) {
      return await overview();
    }

    // GET /warehouses/:id/bins
    if (req.method === "GET" && rest.length === 2 && rest[1] === "bins") {
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad warehouse id" }, 400);
      const { data, error } = await supabase
        .from("bins")
        .select("*")
        .eq("warehouse_id", id)
        .order("code");
      if (error) return json({ message: error.message }, 400);
      return json({ data });
    }

    // POST /warehouses
    if (req.method === "POST" && rest.length === 0) {
      // TODO(Step 3): require warehouse.manage permission for the caller.
      const body = await req.json().catch(() => ({}));
      const code = str(body.code)?.toUpperCase() ?? null;
      const name = str(body.name);
      if (!code) return json({ message: "code is required" }, 422);
      if (!name) return json({ message: "name is required" }, 422);

      // Single-tenant for now: attach to the default (first) company.
      // TODO(Step 3): resolve the company from the authenticated user.
      const { data: company, error: cErr } = await supabase
        .from("companies")
        .select("id")
        .order("id")
        .limit(1)
        .maybeSingle();
      if (cErr) return json({ message: cErr.message }, 400);
      if (!company) return json({ message: "no company configured" }, 409);

      const { data: created, error } = await supabase
        .from("warehouses")
        .insert({
          company_id: company.id,
          code,
          name,
          description: str(body.description),
          address: str(body.address),
          phone: str(body.phone),
          timezone: str(body.timezone) ?? "Asia/Tokyo",
          status: body.is_active === false ? "inactive" : "active",
        })
        .select("*")
        .single();
      if (error) {
        // 23505 = unique violation on (company_id, code)
        const status = error.code === "23505" ? 409 : 400;
        const message = error.code === "23505"
          ? `warehouse code ${code} already exists`
          : error.message;
        return json({ message }, status);
      }

      // Optional starter bins so the staged flows have somewhere to land.
      if (body.create_default_bins !== false) {
        const receiving = str(body.receiving_bin)?.toUpperCase() ?? "STAGE-01";
        const shipping = str(body.shipping_bin)?.toUpperCase() ?? "SHIP-01";
        const rows = defaultBins(receiving, shipping).map((b) => ({
          warehouse_id: created.id,
          code: b.code,
          bin_type: b.bin_type,
        }));
        const { error: bErr } = await supabase.from("bins").insert(rows);
        // Bin seeding is best-effort: the warehouse itself is already created,
        // and bins can be added later from the warehouse screen.
        if (bErr) return json({ data: created, warning: bErr.message }, 201);
      }

      return json({ data: created }, 201);
    }

    // PATCH /warehouses/:id
    if (req.method === "PATCH" && rest.length === 1) {
      // TODO(Step 3): require warehouse.manage permission + warehouse scope.
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad warehouse id" }, 400);
      const body = await req.json().catch(() => ({}));

      const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
      if ("name" in body) {
        const name = str(body.name);
        if (!name) return json({ message: "name cannot be empty" }, 422);
        patch.name = name;
      }
      if ("description" in body) patch.description = str(body.description);
      if ("address" in body) patch.address = str(body.address);
      if ("phone" in body) patch.phone = str(body.phone);
      if ("timezone" in body) patch.timezone = str(body.timezone) ?? "Asia/Tokyo";
      if ("is_active" in body) {
        patch.status = body.is_active === false ? "inactive" : "active";
      }

      const { data, error } = await supabase
        .from("warehouses")
        .update(patch)
        .eq("id", id)
        .select("*")
        .maybeSingle();
      if (error) return json({ message: error.message }, 400);
      if (!data) return json({ message: "warehouse not found" }, 404);
      return json({ data });
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
