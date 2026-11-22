// Cards erased for good (0228).
//
//   POST /card-erase  {kind: "partner" | "overseas_site", id}
//
// partner: the system administrator's (partner_erase_check). A card still
// named by work records (納品・発注・受注・出荷・ロット・請求書) does not go:
// 409 with what uses it. The 未確認 placeholder never goes.
// overseas_site: the system administrator's and the 管理者 tier's
// (overseas_site_erase_check); its counts, shipments, notes and files go too.
// Either way the erasing is written on the audit log.
import { adminClient, callerClient } from "../_shared/require_permission.ts";
import { erasePartner, eraseOverseasSite } from "../_shared/card_erase.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "not found" }, 404);
  const caller = callerClient(req, supabaseUrl);
  const { data: userData } = await caller.auth.getUser();
  if (!userData?.user) return json({ message: "not permitted: sign in required" }, 401);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ message: "bad request" }, 400);
  }
  const id = Number(body.id);
  if (!Number.isSafeInteger(id) || id <= 0) return json({ message: "bad request" }, 400);
  const kind = body.kind;
  if (kind !== "partner" && kind !== "overseas_site") return json({ message: "bad request" }, 400);

  const { data: check, error: checkError } = await caller.rpc(
    kind === "partner" ? "partner_erase_check" : "overseas_site_erase_check",
    { p_id: id },
  );
  if (checkError) {
    const permitted = !/not permitted/.test(checkError.message);
    return json({ message: checkError.message }, permitted ? 400 : 403);
  }
  const c = check as Record<string, unknown>;
  try {
    if (kind === "partner") {
      if (c.placeholder === true) return json({ message: "partner_placeholder" }, 409);
      const blockers = (c.blockers ?? {}) as Record<string, number>;
      if (Object.keys(blockers).length > 0) return json({ message: "partner_in_use", blockers }, 409);
      await erasePartner(adminClient(supabaseUrl), id);
      await caller.rpc("card_erased_note", {
        p_kind: kind, p_id: id, p_name: c.name, p_detail: { detached: c.detached, erased: c.erased },
      });
      return json({ erased: true, detached: c.detached ?? {}, with: c.erased ?? {} });
    }
    const r = await eraseOverseasSite(adminClient(supabaseUrl), c);
    await caller.rpc("card_erased_note", {
      p_kind: kind, p_id: id, p_name: c.name,
      p_detail: { imports: (c.import_ids as unknown[] ?? []).length, shipments: (c.shipment_ids as unknown[] ?? []).length, files: r.files },
    });
    return json({ erased: true, files: r.files });
  } catch (e) {
    console.error("card-erase failed", String(e));
    return json({ message: String(e) }, 500);
  }
});
