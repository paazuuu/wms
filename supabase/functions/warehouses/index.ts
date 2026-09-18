// Warehouse / tenancy API for the WMS client (spec §4, §6, §49).
// Routes (function is mounted at /functions/v1/warehouses):
//   GET    /warehouses            overview: every warehouse + headline figures + totals
//   GET    /warehouses/:id/bins   bins of one warehouse
//   POST   /warehouses            create {code, name, ...} (+ optional default bins)
//   PATCH  /warehouses/:id        update {name?, description?, address?, phone?,
//                                         timezone?, status?}
//
// Two clients, and which one a statement uses is the whole security story
// (UI spec §37):
//
//   READS (overview, bins)   -> the caller's client, so 0052's policies on
//                               `warehouses` and `bins` scope them. On the
//                               service role they did not: it holds
//                               `rolbypassrls` and presents a null
//                               auth.uid(), which makes
//                               `can_access_warehouse()` answer "every
//                               warehouse", so a warehouse-1 operator saw
//                               every warehouse's headline figures and could
//                               enumerate any warehouse's bins.
//   WRITES (create, update)  -> the service role, because there are no
//                               INSERT/UPDATE policies for `authenticated`
//                               on `warehouses`. So they carry an explicit
//                               scope check instead: PATCH refuses a
//                               warehouse outside the caller's scope. POST
//                               creates a warehouse that does not exist yet,
//                               so there is nothing to scope it against —
//                               `warehouse.manage` is the whole gate there.
//
// verify_jwt=true only proves the caller is signed in, so every mutation
// re-checks has_permission() itself using the caller's own JWT (see
// ../_shared/require_permission.ts).
import {
  adminClient,
  callerClient,
  clientCanAccessWarehouse,
  clientPermitted,
  notInScopeMessage,
  notPermittedMessage,
} from "../_shared/require_permission.ts";

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

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
// Writes only. Named `admin` so no read accidentally reaches for it: every
// read in this function must go through the per-request caller client.
const admin = adminClient(supabaseUrl);

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

// On the caller's client, so warehouse_overview()'s own scope fallback binds
// on a real auth.uid() and the result lists only the caller's warehouses.
// deno-lint-ignore no-explicit-any
async function overview(supabase: any): Promise<Response> {
  const { data, error } = await supabase.rpc("warehouse_overview");
  if (error) return json({ message: error.message }, 400);
  return json({ data });
}

/**
 * Append an audit entry (spec §33). Best-effort: an audit failure must never
 * fail the operation the operator just completed, but it is logged server-side.
 */
async function audit(
  eventType: string,
  entityId: number,
  warehouseId: number | null,
  details: Record<string, unknown>,
): Promise<void> {
  // Deliberately the admin client: the audit trail must record what happened
  // even when the caller could not have written the row themselves.
  const { error } = await admin.rpc("log_audit", {
    p_event_type: eventType,
    p_entity_type: "warehouse",
    p_entity_id: String(entityId),
    p_warehouse_id: warehouseId,
    p_details: details,
  });
  if (error) console.error("audit failed", eventType, entityId, error.message);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // One caller-scoped client per request. Reads and scope checks use it;
    // only the two writes reach for `admin`.
    const supabase = callerClient(req, supabaseUrl);
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const i = parts.indexOf("warehouses");
    const rest = i >= 0 ? parts.slice(i + 1) : [];

    // GET /warehouses
    if (req.method === "GET" && rest.length === 0) {
      return await overview(supabase);
    }

    // GET /warehouses/:id/bins
    if (req.method === "GET" && rest.length === 2 && rest[1] === "bins") {
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad warehouse id" }, 400);
      // 0052's "read bins" policy does the scoping; a warehouse outside the
      // caller's scope simply yields no rows rather than an error.
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
      if (!(await clientPermitted(supabase, "warehouse.manage"))) {
        return json({ message: notPermittedMessage("warehouse.manage") }, 403);
      }
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

      const { data: created, error } = await admin
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
          // Locations are opt-in: absent means a plain per-warehouse balance.
          uses_locations: body.uses_locations === true,
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

      // Starter bins only on an explicit opt-in, and only for a warehouse that
      // actually manages stock by location. Never a default (spec §7, §49).
      if (body.uses_locations === true && body.create_default_bins === true) {
        const receiving = str(body.receiving_bin)?.toUpperCase() ?? "STAGE-01";
        const shipping = str(body.shipping_bin)?.toUpperCase() ?? "SHIP-01";
        const rows = defaultBins(receiving, shipping).map((b) => ({
          warehouse_id: created.id,
          code: b.code,
          bin_type: b.bin_type,
        }));
        const { error: bErr } = await admin.from("bins").insert(rows);
        // Bin seeding is best-effort: the warehouse itself is already created,
        // and bins can be added later from the warehouse screen.
        if (bErr) {
          await audit("warehouse.created", created.id, created.id, {
            code, name, bins_seeded: false,
          });
          return json({ data: created, warning: bErr.message }, 201);
        }
        await audit("warehouse.created", created.id, created.id, {
          code, name, bins_seeded: rows.map((r) => r.code),
        });
        return json({ data: created }, 201);
      }

      await audit("warehouse.created", created.id, created.id, {
        code, name, bins_seeded: false,
      });
      return json({ data: created }, 201);
    }

    // PATCH /warehouses/:id
    if (req.method === "PATCH" && rest.length === 1) {
      if (!(await clientPermitted(supabase, "warehouse.manage"))) {
        return json({ message: notPermittedMessage("warehouse.manage") }, 403);
      }
      const id = Number(rest[0]);
      if (!Number.isFinite(id)) return json({ message: "bad warehouse id" }, 400);
      // The update runs as service role (no UPDATE policy for
      // `authenticated`), so the scope check has to be explicit — otherwise
      // `warehouse.manage` scoped to one warehouse would rename any of them.
      if (!(await clientCanAccessWarehouse(supabase, id))) {
        return json({ message: notInScopeMessage(id) }, 403);
      }
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
      if ("uses_locations" in body) {
        patch.uses_locations = body.uses_locations === true;
      }

      const { data, error } = await admin
        .from("warehouses")
        .update(patch)
        .eq("id", id)
        .select("*")
        .maybeSingle();
      if (error) return json({ message: error.message }, 400);
      if (!data) return json({ message: "warehouse not found" }, 404);
      // Record which fields changed, not the whole row.
      const changed = Object.keys(patch).filter((k) => k !== "updated_at");
      await audit("warehouse.updated", id, id, { changed, values: patch });
      return json({ data });
    }

    return json({ message: "not found" }, 404);
  } catch (e) {
    return json({ message: `${e}` }, 500);
  }
});
