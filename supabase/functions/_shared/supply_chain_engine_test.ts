import { assert, assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";
import {
  compare,
  compareMany,
  type Model,
  productOptions,
  purchaseCheck,
  runScenario,
} from "./supply_chain_engine.ts";

// One product, two suppliers in China, sea and air into one Japanese warehouse.
function model(): Model {
  return {
    as_of: "2026-09-28",
    warehouse_id: 1,
    settings: { base_currency: "JPY", margin_warn: 0.15, margin_drop_warn: 0.02, load_warn: 0.8, load_exceeded: 1, default_lot_months: 1 },
    fx: { JPY: 1, CNY: 20 },
    partners: [
      { id: 1, name: "Supplier A", country_code: "CN" },
      { id: 2, name: "Supplier B", country_code: "CN" },
    ],
    nodes: [
      { id: 10, name: "Supplier A", kind: "supplier", partner_id: 1, country_code: "CN" },
      { id: 11, name: "Supplier B", kind: "supplier", partner_id: 2, country_code: "CN" },
      { id: 20, name: "上海港", kind: "port", country_code: "CN" },
      { id: 21, name: "大阪港", kind: "port", country_code: "JP", capacity_units_month: 800 },
      { id: 22, name: "上海空港", kind: "airport", country_code: "CN" },
      { id: 23, name: "関西空港", kind: "airport", country_code: "JP" },
      { id: 30, name: "大阪倉庫", kind: "warehouse", warehouse_id: 1, country_code: "JP" },
    ],
    routes: [
      {
        id: 100, name: "A 船便", origin_node_id: 10, destination_node_id: 30, edges: [
          { seq: 1, from_node_id: 10, to_node_id: 20, transport_mode: "truck", cost_per_unit: 5, lead_time_days: 2 },
          { seq: 2, from_node_id: 20, to_node_id: 21, transport_mode: "sea", base_cost: 12000, cost_per_kg: 20, insurance_rate: 0.003, lead_time_days: 7, customs_clearance: true, customs_cost: 10000 },
          { seq: 3, from_node_id: 21, to_node_id: 30, transport_mode: "truck", cost_per_unit: 10, lead_time_days: 1 },
        ],
      },
      {
        id: 101, name: "A 航空便", origin_node_id: 10, destination_node_id: 30, edges: [
          { seq: 1, from_node_id: 10, to_node_id: 22, transport_mode: "truck", cost_per_unit: 5, lead_time_days: 1 },
          { seq: 2, from_node_id: 22, to_node_id: 23, transport_mode: "air", cost_per_kg: 500, insurance_rate: 0.002, lead_time_days: 2, customs_clearance: true, customs_cost: 10000 },
          { seq: 3, from_node_id: 23, to_node_id: 30, transport_mode: "truck", cost_per_unit: 15, lead_time_days: 1 },
        ],
      },
      {
        id: 102, name: "B 船便", origin_node_id: 11, destination_node_id: 30, edges: [
          { seq: 1, from_node_id: 11, to_node_id: 20, transport_mode: "truck", cost_per_unit: 8, lead_time_days: 3 },
          { seq: 2, from_node_id: 20, to_node_id: 21, transport_mode: "sea", base_cost: 12000, cost_per_kg: 20, insurance_rate: 0.003, lead_time_days: 7, customs_clearance: true, customs_cost: 10000 },
          { seq: 3, from_node_id: 21, to_node_id: 30, transport_mode: "truck", cost_per_unit: 10, lead_time_days: 1 },
        ],
      },
    ],
    supplier_products: [
      { partner_id: 1, product_id: 1, list_price: 1000, discount_rate: 0.7, lead_time_days: 14, default_route_id: 100, is_primary: true },
      { partner_id: 2, product_id: 1, unit_price: 650, lead_time_days: 21, default_route_id: 102 },
    ],
    products: [
      {
        id: 1, name: "ABC-001", price: 1800, on_hand: 0,
        profile: { annual_volume: 12000, unit_weight_kg: 0.5, hs_code: "3926.90", origin_country: "CN", storage_days: 30, units_per_carton: 20 },
      },
    ],
    tariff_rules: [
      { hs_code_prefix: "39", origin_country: "CN", destination_country: "JP", tariff_rate: 0.05, import_tax_rate: 0.1, import_tax_recoverable: true },
    ],
    cost_rules: [
      { name: "保管", category: "storage", basis: "per_unit_month", amount: 15 },
      { name: "検品", category: "inspection", basis: "per_hour", amount: 1500, units_per_basis: 60 },
      { name: "梱包", category: "packing", basis: "per_carton", amount: 120 },
      { name: "販売手数料", category: "sales_related", basis: "percent_of_revenue", amount: 0.05 },
    ],
    risk_events: [],
  };
}

Deno.test("landed cost adds every step from the supplier to the shelf", () => {
  const r = runScenario(model());
  const p = r.products[0];
  const c = p.chosen[0];
  assertEquals(c.partner_name, "Supplier A");
  assertEquals(c.route_id, 100);
  assertEquals(c.lot, 1000); // a month of demand
  const u = c.unit;
  assertEquals(u.purchase, 700); // 1000 × 70%
  assertEquals(u.international_freight, 22); // 12000/1000 + 20 × 0.5kg
  assertEquals(u.domestic_freight, 15); // 5 + 10
  assertAlmostEquals(u.insurance, 2.1, 0.001);
  assertAlmostEquals(u.customs_duty, 36.205, 0.0001); // 5% of CIF 724.1
  assertEquals(u.customs_fee, 10);
  assertEquals(u.import_tax, 0); // recoverable: shown, not counted
  assertAlmostEquals(u.recoverable, 76.0305, 0.0001);
  assertEquals(u.warehouse, 15);
  assertEquals(u.inspection, 25);
  assertEquals(u.packing, 6);
  assertAlmostEquals(u.landed, 831.305, 0.0001);
  assertEquals(u.sales_related, 90);
  assertAlmostEquals(p.profit_per_unit, 878.695, 0.0001);
  assertAlmostEquals(p.margin!, 0.4882, 0.0001);
  assertEquals(c.lead_time_days, 14 + 2 + 7 + 1);
  assertAlmostEquals(r.summary.profit, 878.695 * 12000, 1);
  assertEquals(r.summary.revenue, 1800 * 12000);
});

Deno.test("a lower 掛率 lowers purchase and the duty on it", () => {
  const c = compare(model(), { discount_rate_overrides: { "1": 0.65 } });
  const u = c.scenario.products[0].unit;
  assertEquals(u.purchase, 650);
  assert(c.delta.profit > 0);
  assertEquals(c.drivers[0].line, "purchase");
  assertEquals(c.drivers[0].delta, -50 * 12000);
  // Duty follows the CIF value down too.
  assert(c.drivers.some((d) => d.line === "customs_duty" && d.delta < 0));
});

Deno.test("comparing suppliers by what is left, not the cheapest price", () => {
  const o = productOptions(model(), 1);
  const opts = o.product!.options;
  // A by sea and by air, B by sea.
  assertEquals(opts.length, 3);
  const bSea = opts.find((x) => x.partner_id === 2)!;
  const aSea = opts.find((x) => x.route_id === 100)!;
  assert(bSea.unit.purchase < aSea.unit.purchase);
  const cheapest = runScenario(model(), { supplier_choice: "cheapest" });
  assertEquals(cheapest.products[0].chosen[0].partner_id, 2);
  // A 掛率 sweep answers "65% / 70% / 75%" in one go (§7).
  const sweep = productOptions(model(), 1, {}, [0.65, 0.75]);
  const a65 = sweep.sweeps[0].options.find((x) => x.route_id === 100)!;
  const a75 = sweep.sweeps[1].options.find((x) => x.route_id === 100)!;
  assertEquals(a65.unit.purchase, 650);
  assertEquals(a75.unit.purchase, 750);
});

Deno.test("air is faster and dearer than sea", () => {
  const c = compare(model(), { route_mode: "air" });
  const air = c.scenario.products[0].chosen[0];
  const sea = c.baseline.products[0].chosen[0];
  assertEquals(air.mode, "air");
  assertEquals(air.unit.international_freight, 250); // 500/kg × 0.5kg
  assert(air.lead_time_days < sea.lead_time_days);
  assert(c.delta.profit < 0);
});

Deno.test("price, freight and warehouse changes together make one scenario (§20)", () => {
  const c = compare(model(), {
    supplier_price_multipliers: { "1": 1.1 },
    freight_multipliers: { sea: 1.2 },
    warehouse_cost_multiplier: 1.05,
  });
  const u = c.scenario.products[0].unit;
  assertEquals(u.purchase, 770);
  assertAlmostEquals(u.international_freight, 26.4, 0.001);
  assertAlmostEquals(u.warehouse, 15.75, 0.001);
  assert(c.delta.profit < 0);
  const lines = c.drivers.map((d) => d.line);
  assert(lines.includes("purchase") && lines.includes("international_freight") && lines.includes("warehouse"));
});

Deno.test("foreign currency: the FX move is its own line", () => {
  const m = model();
  m.supplier_products![0] = { ...m.supplier_products![0], list_price: 50, discount_rate: 0.7, currency: "CNY" };
  const c = compare(m, { fx_multiplier: 1.05 });
  const base = c.baseline.products[0].unit;
  const scen = c.scenario.products[0].unit;
  assertEquals(base.purchase, 700); // 35 CNY × 20
  assertEquals(base.fx_impact, 0);
  assertEquals(scen.purchase, 700);
  assertAlmostEquals(scen.fx_impact, 35, 0.001); // 35 × (21 − 20)
  assertEquals(c.drivers[0].line, "fx_impact");
});

Deno.test("an added supplier takes the product when it leaves more (§6)", () => {
  const c = compare(model(), {
    added_suppliers: [{ partner_id: 9, partner_name: "Supplier C", product_id: 1, unit_price: 500, lead_time_days: 7 }],
  });
  const chosen = c.scenario.products[0].chosen[0];
  assertEquals(chosen.partner_name, "Supplier C");
  assert(chosen.hypothetical);
  assert(chosen.notes.includes("no_route")); // no route registered for it yet
  assert(c.delta.profit > 0);
});

Deno.test("a split sources part of the volume from each supplier", () => {
  const r = runScenario(model(), { supplier_split: { "1": 3, "2": 1 } });
  const chosen = r.products[0].chosen;
  assertEquals(chosen.length, 2);
  assertAlmostEquals(chosen.find((c) => c.partner_id === 1)!.share, 0.75, 1e-9);
  assert(!r.products[0].single_source);
});

Deno.test("Osaka port over capacity is a bottleneck (§18)", () => {
  const r = runScenario(model());
  const osaka = r.bottlenecks.find((b) => b.kind === "node" && b.id === 21)!;
  assertEquals(osaka.units_month, 1000);
  assertEquals(osaka.load, 1.25);
  assertEquals(osaka.status, "exceeded");
  assert(osaka.has_alternative); // the air route avoids it
  const risk = r.risks.find((x) => x.kind === "node" && x.id === 21)!;
  assert(risk.reasons.includes("load_exceeded"));
});

Deno.test("Osaka port closed for 14 days: rerouted by air, with the cost (§19)", () => {
  const m = model();
  m.products![0].on_hand = 0;
  const r = runScenario(m, { disruptions: [{ kind: "stop", node_id: 21, days: 14 }] });
  const d = r.disruptions[0];
  const a = d.affected_products[0];
  assertAlmostEquals(a.affected_units, 12000 / 365 * 14, 0.1);
  assert(a.alternative!.includes("航空便"));
  assert(a.extra_cost_per_unit > 0);
  // No stock: the days until air freight lands are lost sales.
  assert(a.lost_units > 0);
  assert(d.impact < 0);
  // With plenty of stock nothing is lost, only the dearer freight.
  m.products![0].on_hand = 5000;
  const r2 = runScenario(m, { disruptions: [{ kind: "stop", node_id: 21, days: 14 }] });
  assertEquals(r2.disruptions[0].affected_products[0].lost_units, 0);
});

Deno.test("a stopped supplier moves the product to the other one", () => {
  const r = runScenario(model(), { disruptions: [{ kind: "stop", partner_id: 1 }] });
  assertEquals(r.products[0].chosen[0].partner_id, 2);
  assert(r.products[0].notes.includes("current_unavailable"));
});

Deno.test("disabled suppliers are not used", () => {
  const r = runScenario(model(), { supplier_enabled: [2] });
  assertEquals(r.products[0].chosen[0].partner_id, 2);
});

Deno.test("a pricier purchase is warned about before it is placed (§30)", () => {
  const [line] = purchaseCheck(model(), [{ product_id: 1, partner_id: 1, unit_price: 900, quantity: 1000 }]);
  assert(line.margin_after! < line.margin_before!);
  assert(line.warn.includes("margin_drop"));
  assertEquals(line.drivers[0].line, "purchase");
  const [same] = purchaseCheck(model(), [{ product_id: 1, partner_id: 1, unit_price: 700, quantity: 1000 }]);
  assertEquals(same.warn, []);
});

Deno.test("fixed monthly costs are spread over the warehouse's volume", () => {
  const m = model();
  m.cost_rules!.push({ name: "倉庫固定費", category: "overhead", basis: "fixed_monthly", amount: 300000, warehouse_id: 1 });
  const r = runScenario(m);
  assertEquals(r.products[0].unit.overhead, 300); // 300,000 / 1,000 units a month
});

Deno.test("five scenarios at most, each against the current state (§16)", () => {
  const out = compareMany(model(), [
    { name: "B", supplier_choice: "cheapest" },
    { name: "航空", route_mode: "air" },
    { name: "1" }, { name: "2" }, { name: "3" }, { name: "6" },
  ]);
  assertEquals(out.scenarios.length, 5);
  assert(out.scenarios[0].delta_profit > 0);
  assert(out.scenarios[1].delta_profit < 0);
});

Deno.test("registered risk events can be applied as disruptions", () => {
  const m = model();
  m.risk_events = [{ title: "A値上げ", kind: "supplier_price", severity: "medium", partner_id: 1, price_multiplier: 1.2 }];
  const r = runScenario(m, { apply_risk_events: true });
  assertEquals(r.products[0].unit.purchase, 840);
  const supplier = r.risks.find((x) => x.kind === "supplier" && x.id === 1)!;
  assert(supplier.reasons.includes("event:supplier_price"));
});
