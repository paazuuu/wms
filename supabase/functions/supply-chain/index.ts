// Supply chain profit & risk (0107). POST JSON { action, ... }:
//
//   dashboard   { warehouse_id? }                    current state: totals,
//               products, bottlenecks, risks (not stored unless save: true)
//   run         { warehouse_id?, params, name?, scenario_id?, product_ids? }
//               current vs scenario, with the delta and what drove it;
//               kept as a snapshot (kind scenario)
//   compare     { warehouse_id?, scenarios: [{ name, params }] }  ≤ 5, kept
//   product     { product_id, warehouse_id?, params?, rates?: [0.65, …] }
//               every supplier × route for one product, and 掛率 sweeps
//   disruption  { warehouse_id?, disruptions: [...], name? }  kept
//   purchase_check { warehouse_id?, lines: [{ product_id, partner_id,
//               unit_price, quantity }] }  before a purchase order (§30)
//
// Everything is read on the caller's client (sc_model checks
// supply_chain.view and warehouse scope); the engine is pure
// (_shared/supply_chain_engine.ts). Nothing here changes stock or orders.
import { callerClient } from "../_shared/require_permission.ts";
import {
  compare,
  compareMany,
  type Model,
  productOptions,
  purchaseCheck,
  runScenario,
  type ScenarioParams,
} from "../_shared/supply_chain_engine.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

// deno-lint-ignore no-explicit-any
type Client = any;

function idOrNull(v: unknown): number | null {
  const x = Number(v);
  return Number.isFinite(x) && x > 0 ? x : null;
}

function params(v: unknown): ScenarioParams {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as ScenarioParams) : {};
}

async function loadModel(client: Client, warehouseId: number | null, productIds: number[] | null): Promise<Model> {
  const { data, error } = await client.rpc("sc_model", {
    p_warehouse_id: warehouseId,
    p_product_ids: productIds && productIds.length ? productIds : null,
  });
  if (error) throw new HttpError(error.message, error.message.startsWith("not permitted") ? 403 : 400);
  const model = data as Model;
  const { data: stats } = await client.rpc("sc_supplier_stats", { p_partner_id: null });
  model.supplier_stats = Array.isArray(stats) ? stats : [];
  return model;
}

async function record(
  client: Client, kind: string, warehouseId: number | null, name: string | null,
  scenarioId: number | null, p: unknown, summary: Record<string, unknown>, result: unknown,
): Promise<number | null> {
  const { data, error } = await client.rpc("sc_record_result", {
    p_kind: kind, p_scenario_id: scenarioId, p_name: name, p_warehouse_id: warehouseId,
    p_params: p ?? {}, p_summary: summary, p_result: result,
  });
  if (error) {
    console.error("sc_record_result", error.message);
    return null;
  }
  return data as number;
}

class HttpError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);
  try {
    const client = callerClient(req, supabaseUrl);
    const { data: user } = await client.auth.getUser();
    if (!user?.user) return json({ message: "not signed in" }, 401);

    const b = await req.json().catch(() => ({}));
    const action = String(b.action ?? "");
    const warehouseId = idOrNull(b.warehouse_id);
    const productIds: number[] | null = Array.isArray(b.product_ids)
      ? b.product_ids.map(Number).filter((x: number) => Number.isFinite(x))
      : null;

    switch (action) {
      case "dashboard": {
        const model = await loadModel(client, warehouseId, productIds);
        const run = runScenario(model, { name: "現在", apply_risk_events: false });
        let resultId: number | null = null;
        if (b.save === true) {
          resultId = await record(client, "baseline", warehouseId, "現在（スナップショット）", null, {},
            { ...run.summary }, run);
        }
        return json({ data: { ...run, settings: model.settings, result_id: resultId, as_of: model.as_of } });
      }

      case "run": {
        const p = params(b.params);
        const model = await loadModel(client, warehouseId, productIds ?? p.product_ids ?? null);
        const c = compare(model, { ...p, name: b.name ?? p.name ?? "シナリオ" }, params(b.baseline));
        const resultId = await record(client, "scenario", warehouseId, b.name ?? p.name ?? null,
          idOrNull(b.scenario_id), p,
          { ...c.scenario.summary, baseline_profit: c.baseline.summary.profit, delta: c.delta },
          c);
        return json({ data: { ...c, result_id: resultId } });
      }

      case "compare": {
        const list = (Array.isArray(b.scenarios) ? b.scenarios : []).slice(0, 5)
          .map((s: { name?: string; params?: unknown }, i: number) => ({ ...params(s?.params), name: s?.name ?? `#${i + 1}` }));
        if (!list.length) return json({ message: "scenarios are required" }, 400);
        const model = await loadModel(client, warehouseId, productIds);
        const out = compareMany(model, list);
        const best = out.scenarios.reduce((a, c) => (c.summary.profit > a.summary.profit ? c : a), out.scenarios[0]);
        const resultId = await record(client, "compare", warehouseId, b.name ?? list.map((x: ScenarioParams) => x.name).join(" / "),
          null, { scenarios: list }, { ...best.summary, baseline_profit: out.baseline.summary.profit }, out);
        return json({ data: { ...out, result_id: resultId } });
      }

      case "product": {
        const pid = idOrNull(b.product_id);
        if (!pid) return json({ message: "product_id is required" }, 400);
        const rates = (Array.isArray(b.rates) ? b.rates : []).map(Number)
          .filter((x: number) => Number.isFinite(x) && x > 0 && x <= 2);
        const model = await loadModel(client, warehouseId, [pid]);
        const out = productOptions(model, pid, params(b.params), rates);
        let resultId: number | null = null;
        if (b.save === true && out.product) {
          resultId = await record(client, "product", warehouseId, out.product.name, null, b.params ?? {},
            { revenue: out.product.revenue, landed_cost: out.product.landed_total, profit: out.product.profit_total, margin: out.product.margin },
            out);
        }
        return json({ data: { ...out, settings: model.settings, result_id: resultId } });
      }

      case "disruption": {
        const disruptions = Array.isArray(b.disruptions) ? b.disruptions : [];
        if (!disruptions.length) return json({ message: "disruptions are required" }, 400);
        const model = await loadModel(client, warehouseId, productIds);
        const p: ScenarioParams = { ...params(b.params), disruptions };
        const c = compare(model, { ...p, name: b.name ?? "障害" });
        const impact = c.scenario.disruptions.reduce((s, d) => s + d.impact, 0);
        const resultId = await record(client, "disruption", warehouseId, b.name ?? null, null, p,
          { ...c.scenario.summary, profit: c.scenario.summary.profit + impact, baseline_profit: c.baseline.summary.profit, disruption_impact: impact },
          c);
        return json({ data: { ...c, disruption_impact: impact, result_id: resultId } });
      }

      case "purchase_check": {
        const lines = (Array.isArray(b.lines) ? b.lines : [])
          .map((l: Record<string, unknown>) => ({
            product_id: idOrNull(l.product_id), partner_id: idOrNull(l.partner_id),
            unit_price: l.unit_price == null || l.unit_price === "" ? null : Number(l.unit_price),
            quantity: l.quantity == null ? null : Number(l.quantity),
          }))
          .filter((l: { product_id: number | null; partner_id: number | null }) => l.product_id && l.partner_id);
        if (!lines.length) return json({ data: { lines: [], warn: false } });
        const model = await loadModel(client, warehouseId, lines.map((l: { product_id: number }) => l.product_id));
        const out = purchaseCheck(model, lines);
        const warn = out.some((l) => l.warn.some((w) => w !== "new_supplier"));
        if (warn) {
          await record(client, "purchase_check", warehouseId, "発注前チェック", null, { lines },
            { margin: out[0]?.margin_after ?? null }, out);
        }
        return json({ data: { lines: out, warn, settings: model.settings } });
      }

      default:
        return json({ message: `unknown action ${action}` }, 400);
    }
  } catch (e) {
    if (e instanceof HttpError) return json({ message: e.message }, e.status);
    return json({ message: String(e instanceof Error ? e.message : e) }, 500);
  }
});
