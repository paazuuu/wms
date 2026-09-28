// Supply chain profit & risk engine (spec §11, §18–20, §24, rule 8).
//
// Pure functions over a model read from `sc_model` (0107): no I/O, no clock
// except `model.as_of`, so every number can be tested. The edge function
// `supply-chain` loads the model, calls `runScenario` / `compare` / `compareMany` /
// `productOptions` / `purchaseCheck`, and stores the snapshot.
//
// Landed cost per unit, for one product bought from one supplier and moved
// along one route into one warehouse:
//
//   purchase (at the base FX rate)            仕入
//   + fx_impact (the scenario's FX move)       為替影響
//   + international_freight                    国際送料（船・航空）
//   + insurance                                保険
//   + customs_duty                             関税（＋その他輸入税）
//   + import_tax (only if not recoverable)     輸入消費税等（控除不可分）
//   + customs_fee                              通関費
//   + port_fee                                 港湾・空港・中継費
//   + domestic_freight                         国内送料
//   + warehouse                                倉庫費（保管・倉庫の荷役）
//   + receiving + inspection + packing         入荷・検品・梱包
//   + labor                                    人件費（ピッキング・出荷他）
//   + overhead + other                         共通経費・その他
//   = landed
//
//   profit = sales_price − landed − sales_related
//
// Per-shipment amounts (a leg's base cost, a broker's fee) are spread over the
// lot: the order lot, else the MOQ or `default_lot_months` of demand,
// whichever is larger. Nothing is hard-coded: every rate, fee and FX rate
// comes from the model.

// ------------------------------------------------------------------ types

export type Mode = "sea" | "air" | "truck" | "rail" | "courier" | "internal";
export type RiskLevel = "low" | "medium" | "high" | "critical";

export interface Settings {
  base_currency: string;
  margin_warn: number;
  margin_drop_warn: number;
  load_warn: number;
  load_exceeded: number;
  default_lot_months: number;
}

export interface Node {
  id: number;
  code?: string;
  name: string;
  kind: string;
  partner_id?: number | null;
  warehouse_id?: number | null;
  country_code?: string | null;
  capacity_units_month?: number | null;
  capacity_kg_month?: number | null;
  dwell_days?: number | null;
  handling_cost_per_unit?: number | null;
  handling_cost_per_shipment?: number | null;
  risk_level?: RiskLevel | null;
}

export interface Edge {
  id?: number;
  seq: number;
  from_node_id: number;
  to_node_id: number;
  transport_mode: Mode;
  leg_scope?: "international" | "domestic" | null;
  currency?: string | null;
  distance_km?: number | null;
  lead_time_days?: number | null;
  base_cost?: number | null;
  cost_per_kg?: number | null;
  cost_per_unit?: number | null;
  fuel_surcharge_rate?: number | null;
  insurance_rate?: number | null;
  capacity_kg_month?: number | null;
  capacity_units_month?: number | null;
  customs_clearance?: boolean | null;
  customs_cost?: number | null;
  tariff_rate?: number | null;
  handling_cost?: number | null;
  handling_cost_per_unit?: number | null;
  risk_level?: RiskLevel | null;
}

export interface Route {
  id: number;
  code?: string;
  name: string;
  origin_node_id: number;
  destination_node_id: number;
  edges: Edge[];
}

export interface SupplyTerm {
  id?: number;
  partner_id: number;
  product_id: number;
  supplier_sku?: string | null;
  list_price?: number | null;
  discount_rate?: number | null;
  unit_price?: number | null;
  currency?: string | null;
  moq?: number | null;
  order_lot?: number | null;
  lead_time_days?: number | null;
  payment_terms?: string | null;
  default_route_id?: number | null;
  is_primary?: boolean | null;
  /** A hypothetical supplier added in a scenario (§6). */
  partner_name?: string | null;
  country_code?: string | null;
  hypothetical?: boolean;
}

export interface Profile {
  sales_price?: number | null;
  annual_volume?: number | null;
  unit_weight_kg?: number | null;
  units_per_carton?: number | null;
  units_per_line?: number | null;
  units_per_order?: number | null;
  storage_days?: number | null;
  hs_code?: string | null;
  origin_country?: string | null;
  destination_country?: string | null;
}

export interface ProductRow {
  id: number;
  jan_code?: string | null;
  name: string;
  sku?: string | null;
  maker?: string | null;
  price?: number | null;
  profile?: Profile | null;
  on_hand?: number | null;
  shipped_12m?: number | null;
  sold_price_avg?: number | null;
}

export type CostCategory =
  | "storage" | "receiving" | "inspection" | "packing" | "picking" | "shipping"
  | "labor" | "overhead" | "domestic_freight" | "sales_related" | "other";

export interface CostRule {
  id?: number;
  name: string;
  category: CostCategory;
  basis:
    | "per_unit" | "per_unit_month" | "per_carton" | "per_line" | "per_order"
    | "per_hour" | "percent_of_revenue" | "percent_of_purchase" | "fixed_monthly";
  amount: number;
  units_per_basis?: number | null;
  currency?: string | null;
  warehouse_id?: number | null;
  product_id?: number | null;
  partner_id?: number | null;
  expensed?: boolean | null;
}

export interface TariffRule {
  id?: number;
  product_id?: number | null;
  hs_code_prefix?: string | null;
  origin_country?: string | null;
  destination_country?: string | null;
  tariff_rate: number;
  import_tax_rate?: number | null;
  import_tax_recoverable?: boolean | null;
  other_rate?: number | null;
  valuation?: "CIF" | "FOB" | null;
}

export interface RiskEvent {
  id?: number;
  title: string;
  kind: string;
  severity: RiskLevel;
  node_id?: number | null;
  route_id?: number | null;
  partner_id?: number | null;
  transport_mode?: Mode | null;
  starts_on?: string | null;
  ends_on?: string | null;
  price_multiplier?: number | null;
  cost_multiplier?: number | null;
  capacity_multiplier?: number | null;
  delay_days?: number | null;
}

export interface SupplierStat {
  partner_id: number;
  late_rate?: number | null;
  defect_rate?: number | null;
  avg_lead_time_days?: number | null;
}

export interface Model {
  as_of?: string;
  warehouse_id?: number | null;
  settings?: Partial<Settings> | null;
  fx?: Record<string, number>;
  nodes?: Node[];
  routes?: Route[];
  partners?: { id: number; name: string; code?: string | null; country_code?: string | null }[];
  supplier_products?: SupplyTerm[];
  products?: ProductRow[];
  cost_rules?: CostRule[];
  tariff_rules?: TariffRule[];
  risk_events?: RiskEvent[];
  supplier_stats?: SupplierStat[];
}

/** What a scenario changes (spec §23, extended). Everything is optional; an
 * empty object is "現在条件". */
export interface ScenarioParams {
  name?: string;
  product_ids?: number[];
  /** Units per order, for comparing at a given quantity (§5). */
  lot_quantity?: number;
  supplier_price_multiplier?: number;
  supplier_price_multipliers?: Record<string, number>;
  /** 掛率 by partner id, or by "partner:product". */
  discount_rate_overrides?: Record<string, number>;
  /** 仕入単価 by "partner:product" — a purchase being priced (§30). */
  unit_price_overrides?: Record<string, number>;
  freight_multiplier?: number;
  freight_multipliers?: Partial<Record<Mode, number>>;
  insurance_multiplier?: number;
  tariff_multiplier?: number;
  tariff_rate_override?: number;
  customs_cost_multiplier?: number;
  warehouse_cost_multiplier?: number;
  labor_cost_multiplier?: number;
  overhead_multiplier?: number;
  fx_multiplier?: number;
  fx_overrides?: Record<string, number>;
  sales_price_multiplier?: number;
  sales_price_overrides?: Record<string, number>;
  volume_multiplier?: number;
  volume_overrides?: Record<string, number>;
  /** current / cheapest / fastest, or a transport mode to prefer. */
  route_mode?: "current" | "cheapest" | "fastest" | Mode;
  route_overrides?: Record<string, number>;
  /** Only these suppliers (partner ids). Unset: all. */
  supplier_enabled?: number[];
  supplier_choice?: "current" | "cheapest" | "fastest";
  /** Share of volume per partner id, where a product has that supplier. */
  supplier_split?: Record<string, number>;
  added_suppliers?: SupplyTerm[];
  disruptions?: Disruption[];
  /** Turn the registered risk events into disruptions. */
  apply_risk_events?: boolean;
}

export interface Disruption {
  kind: "stop" | "price" | "cost" | "capacity" | "delay";
  node_id?: number | null;
  route_id?: number | null;
  partner_id?: number | null;
  mode?: Mode | null;
  /** Temporary: how long. Unset on a stop: the target is gone for the period. */
  days?: number | null;
  multiplier?: number | null;
  delay_days?: number | null;
  label?: string | null;
}

export const COST_LINES = [
  "purchase", "fx_impact", "international_freight", "insurance", "customs_duty",
  "import_tax", "customs_fee", "port_fee", "domestic_freight", "warehouse",
  "receiving", "inspection", "packing", "labor", "overhead", "other",
] as const;
export type CostLine = typeof COST_LINES[number];

export type Breakdown = Record<CostLine, number> & {
  landed: number;
  sales_related: number;
  /** Shown, not counted: recoverable import tax, non-expensed rules. */
  recoverable: number;
};

export interface OptionResult {
  key: string;
  product_id: number;
  partner_id: number;
  partner_name: string;
  hypothetical: boolean;
  route_id: number | null;
  route_name: string | null;
  mode: Mode | null;
  modes: Mode[];
  lead_time_days: number;
  lot: number;
  currency: string;
  unit_price_foreign: number;
  discount_rate: number | null;
  moq: number | null;
  unit: Breakdown;
  sales_price: number;
  profit_per_unit: number;
  margin: number | null;
  available: boolean;
  blocked_by: string[];
  notes: string[];
  node_ids: number[];
}

export interface ChosenOption extends OptionResult {
  share: number;
}

export interface ProductResult {
  product_id: number;
  name: string;
  jan_code: string | null;
  sku: string | null;
  maker: string | null;
  volume: number;
  on_hand: number;
  sales_price: number;
  unit: Breakdown;
  profit_per_unit: number;
  margin: number | null;
  lead_time_days: number;
  revenue: number;
  landed_total: number;
  sales_related_total: number;
  profit_total: number;
  chosen: ChosenOption[];
  options: OptionResult[];
  single_source: boolean;
  notes: string[];
}

export interface Summary {
  revenue: number;
  units: number;
  purchase: number;
  fx_impact: number;
  logistics: number;
  customs: number;
  warehouse: number;
  labor: number;
  other: number;
  landed_cost: number;
  sales_related: number;
  total_cost: number;
  profit: number;
  margin: number | null;
  lead_time_days: number | null;
  lines: Record<CostLine, number>;
  recoverable: number;
}

export interface Load {
  kind: "node" | "edge";
  id: number;
  name: string;
  node_kind?: string;
  mode?: Mode;
  route_id?: number;
  units_month: number;
  kg_month: number;
  capacity_units_month: number | null;
  capacity_kg_month: number | null;
  load: number | null;
  status: "ok" | "busy" | "exceeded" | "no_capacity" | "stopped";
  has_alternative: boolean;
  products: number[];
}

export interface RiskItem {
  kind: "supplier" | "node" | "route";
  id: number;
  name: string;
  score: number;
  level: RiskLevel;
  reasons: string[];
}

export interface DisruptionImpact {
  label: string;
  disruption: Disruption;
  affected_products: {
    product_id: number;
    name: string;
    affected_units: number;
    rerouted_units: number;
    lost_units: number;
    alternative: string | null;
    extra_cost_per_unit: number;
    lead_time_change: number | null;
    coverage_days: number | null;
    extra_cost: number;
    lost_profit: number;
    impact: number;
  }[];
  extra_cost: number;
  lost_profit: number;
  lost_units: number;
  impact: number;
}

export interface RunResult {
  name: string;
  summary: Summary;
  products: ProductResult[];
  bottlenecks: Load[];
  risks: RiskItem[];
  disruptions: DisruptionImpact[];
  warnings: string[];
}

// ------------------------------------------------------------------ helpers

const n = (v: unknown, d = 0): number => {
  const x = typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" ? Number(v) : NaN;
  return Number.isFinite(x) ? x : d;
};
const opt = (v: unknown): number | null => {
  const x = n(v, NaN);
  return Number.isFinite(x) ? x : null;
};
const up = (s: unknown) => (typeof s === "string" && s.trim() ? s.trim().toUpperCase() : null);
export const round = (v: number, d = 2) => {
  const f = 10 ** d;
  return Math.round((v + Number.EPSILON) * f) / f;
};

export function settingsOf(model: Model): Settings {
  const s = model.settings ?? {};
  return {
    base_currency: up(s.base_currency) ?? "JPY",
    margin_warn: n(s.margin_warn, 0.15),
    margin_drop_warn: n(s.margin_drop_warn, 0.05),
    load_warn: n(s.load_warn, 0.8),
    load_exceeded: n(s.load_exceeded, 1),
    default_lot_months: n(s.default_lot_months, 1),
  };
}

function emptyBreakdown(): Breakdown {
  const b = { landed: 0, sales_related: 0, recoverable: 0 } as Breakdown;
  for (const k of COST_LINES) b[k] = 0;
  return b;
}

function sumLanded(b: Breakdown) {
  b.landed = COST_LINES.reduce((s, k) => s + b[k], 0);
}

// Per-unit amounts keep 4 decimals so totals over thousands of units add up
// to the yen; screens round for display.
const U = 4;

function roundBreakdown(b: Breakdown): Breakdown {
  const out = emptyBreakdown();
  for (const k of COST_LINES) out[k] = round(b[k], U);
  out.landed = round(b.landed, U);
  out.sales_related = round(b.sales_related, U);
  out.recoverable = round(b.recoverable, U);
  return out;
}

/** The ¥ value of `amount` in `currency`, or null when the rate is missing. */
function fxRate(model: Model, currency: string | null | undefined, base: string): number | null {
  const c = up(currency) ?? base;
  if (c === base) return 1;
  const r = opt(model.fx?.[c]);
  return r && r > 0 ? r : null;
}

const LEVEL_POINTS: Record<RiskLevel, number> = { low: 5, medium: 25, high: 50, critical: 75 };
const SEVERITY_POINTS: Record<RiskLevel, number> = { low: 10, medium: 20, high: 35, critical: 50 };
export function levelOf(score: number): RiskLevel {
  if (score >= 75) return "critical";
  if (score >= 50) return "high";
  if (score >= 25) return "medium";
  return "low";
}

function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(b) - Date.parse(a)) / 86_400_000);
}

/** The registered risk events as disruptions (a stop that ends becomes a
 * temporary one; one without an end stops the target for the period). */
export function eventsAsDisruptions(model: Model): Disruption[] {
  const today = model.as_of ?? new Date().toISOString().slice(0, 10);
  const out: Disruption[] = [];
  for (const e of model.risk_events ?? []) {
    const target = {
      node_id: e.node_id ?? null, route_id: e.route_id ?? null,
      partner_id: e.partner_id ?? null, mode: e.transport_mode ?? null, label: e.title,
    };
    const from = e.starts_on && e.starts_on > today ? e.starts_on : today;
    const days = e.ends_on ? Math.max(0, daysBetween(from, e.ends_on) + 1) : null;
    if (e.kind.endsWith("_stop")) out.push({ kind: "stop", days, ...target });
    else if (e.kind.endsWith("_delay")) out.push({ kind: "delay", delay_days: n(e.delay_days, 7), ...target });
    if (e.price_multiplier) out.push({ kind: "price", multiplier: e.price_multiplier, ...target });
    if (e.cost_multiplier) out.push({ kind: "cost", multiplier: e.cost_multiplier, ...target });
    if (e.capacity_multiplier != null) out.push({ kind: "capacity", multiplier: e.capacity_multiplier, ...target });
  }
  return out;
}

// ------------------------------------------------------------------ the context

interface Ctx {
  model: Model;
  s: Settings;
  p: ScenarioParams;
  nodes: Map<number, Node>;
  routes: Route[];
  partnerName: Map<number, string>;
  partnerCountry: Map<number, string | null>;
  disruptions: Disruption[];
  /** Monthly units into each warehouse id (for fixed monthly costs). */
  warehouseVolume: Map<number, number>;
}

function makeCtx(model: Model, p: ScenarioParams): Ctx {
  const nodes = new Map((model.nodes ?? []).map((x) => [x.id, x]));
  const partnerName = new Map<number, string>();
  const partnerCountry = new Map<number, string | null>();
  for (const x of model.partners ?? []) {
    partnerName.set(x.id, x.name);
    partnerCountry.set(x.id, up(x.country_code));
  }
  for (const t of p.added_suppliers ?? []) {
    if (t.partner_name) partnerName.set(t.partner_id, t.partner_name);
    if (t.country_code) partnerCountry.set(t.partner_id, up(t.country_code));
  }
  const disruptions = [...(p.disruptions ?? []), ...(p.apply_risk_events ? eventsAsDisruptions(model) : [])];
  const ctx: Ctx = {
    model, s: settingsOf(model), p, nodes, routes: model.routes ?? [], partnerName, partnerCountry,
    disruptions, warehouseVolume: new Map(),
  };
  return ctx;
}

function warehouseNodeIds(ctx: Ctx): Set<number> {
  const wh = ctx.model.warehouse_id;
  return new Set([...ctx.nodes.values()]
    .filter((x) => x.kind === "warehouse" && (wh == null || x.warehouse_id === wh))
    .map((x) => x.id));
}

function supplierNodeId(ctx: Ctx, partnerId: number): number | null {
  for (const x of ctx.nodes.values()) if (x.kind === "supplier" && x.partner_id === partnerId) return x.id;
  return null;
}

function routeNodes(r: Route): number[] {
  const ids = [r.origin_node_id];
  for (const e of [...r.edges].sort((a, b) => a.seq - b.seq)) ids.push(e.to_node_id);
  return ids;
}

function routeModes(r: Route): Mode[] {
  return [...new Set(r.edges.map((e) => e.transport_mode))];
}

function isInternational(ctx: Ctx, e: Edge): boolean {
  if (e.leg_scope) return e.leg_scope === "international";
  if (e.transport_mode === "sea" || e.transport_mode === "air") return true;
  const a = up(ctx.nodes.get(e.from_node_id)?.country_code);
  const b = up(ctx.nodes.get(e.to_node_id)?.country_code);
  return a != null && b != null && a !== b;
}

function primaryMode(ctx: Ctx, r: Route): Mode | null {
  const intl = r.edges.find((e) => isInternational(ctx, e));
  return intl?.transport_mode ?? r.edges[0]?.transport_mode ?? null;
}

/** Does a disruption hit this supplier / route? */
function hits(d: Disruption, partnerId: number, route: Route | null): boolean {
  if (d.partner_id != null && d.partner_id !== partnerId) return false;
  if (d.route_id != null && d.route_id !== route?.id) return false;
  if (d.node_id != null && !(route && routeNodes(route).includes(d.node_id))) return false;
  if (d.mode != null && !(route && routeModes(route).includes(d.mode))) return false;
  return d.partner_id != null || d.route_id != null || d.node_id != null || d.mode != null;
}

function edgeHit(d: Disruption, e: Edge, route: Route): boolean {
  if (d.route_id != null && d.route_id !== route.id) return false;
  if (d.mode != null && d.mode !== e.transport_mode) return false;
  if (d.node_id != null && d.node_id !== e.from_node_id && d.node_id !== e.to_node_id) return false;
  return d.route_id != null || d.mode != null || d.node_id != null;
}

function tariffFor(ctx: Ctx, product: ProductRow, origin: string | null, dest: string | null): TariffRule | null {
  const hs = (product.profile?.hs_code ?? "").replace(/\D/g, "");
  let best: TariffRule | null = null;
  let bestScore = -1;
  for (const r of ctx.model.tariff_rules ?? []) {
    if (r.product_id != null && r.product_id !== product.id) continue;
    const prefix = (r.hs_code_prefix ?? "").replace(/\D/g, "");
    if (prefix && !hs.startsWith(prefix)) continue;
    if (r.origin_country && up(r.origin_country) !== origin) continue;
    if (r.destination_country && up(r.destination_country) !== dest) continue;
    const score = (r.product_id != null ? 1000 : 0) + prefix.length * 10 +
      (r.origin_country ? 2 : 0) + (r.destination_country ? 1 : 0);
    if (score > bestScore) {
      best = r;
      bestScore = score;
    }
  }
  return best;
}

function annualVolume(ctx: Ctx, pr: ProductRow): number {
  const o = opt(ctx.p.volume_overrides?.[String(pr.id)]);
  const base = o ?? opt(pr.profile?.annual_volume) ?? n(pr.shipped_12m);
  return Math.max(0, base * n(ctx.p.volume_multiplier, 1));
}

function salesPrice(ctx: Ctx, pr: ProductRow): number {
  const o = opt(ctx.p.sales_price_overrides?.[String(pr.id)]);
  const base = o ?? opt(pr.profile?.sales_price) ?? opt(pr.price) ?? opt(pr.sold_price_avg) ?? 0;
  return base * (o != null ? 1 : n(ctx.p.sales_price_multiplier, 1));
}

// ------------------------------------------------------------------ one option

export function costOption(ctx: Ctx, pr: ProductRow, term: SupplyTerm, route: Route | null): OptionResult {
  const s = ctx.s;
  const p = ctx.p;
  const base = s.base_currency;
  const notes: string[] = [];
  const blocked: string[] = [];
  const b = emptyBreakdown();
  const volume = annualVolume(ctx, pr);
  const monthly = volume / 12;
  const weight = n(pr.profile?.unit_weight_kg);
  if (!pr.profile?.unit_weight_kg && route) notes.push("no_weight");

  // The lot the per-shipment amounts are spread over.
  let lot = opt(p.lot_quantity) ?? opt(term.order_lot) ??
    Math.max(n(term.moq), Math.ceil(monthly * s.default_lot_months));
  if (!lot || lot < 1) {
    lot = 1;
    notes.push("no_volume");
  }

  // Purchase.
  const key = `${term.partner_id}:${pr.id}`;
  const rateOverride = opt(p.discount_rate_overrides?.[key]) ?? opt(p.discount_rate_overrides?.[String(term.partner_id)]);
  const discount = rateOverride ?? opt(term.discount_rate);
  let foreign = opt(p.unit_price_overrides?.[key]) ??
    (rateOverride != null && term.list_price != null
      ? n(term.list_price) * rateOverride
      : opt(term.unit_price) ?? (term.list_price != null ? n(term.list_price) * (discount ?? 1) : null));
  if (foreign == null) {
    foreign = 0;
    notes.push("no_price");
  }
  foreign *= n(p.supplier_price_multiplier, 1) * n(p.supplier_price_multipliers?.[String(term.partner_id)], 1);
  for (const d of ctx.disruptions) {
    if (d.kind === "price" && d.partner_id === term.partner_id && d.days == null) foreign *= n(d.multiplier, 1);
  }
  const currency = up(term.currency) ?? base;
  const fxBase = fxRate(ctx.model, currency, base);
  if (fxBase == null) notes.push(`no_fx:${currency}`);
  const rate0 = fxBase ?? 1;
  const rate1 = currency === base
    ? 1
    : opt(p.fx_overrides?.[currency]) ?? rate0 * n(p.fx_multiplier, 1);
  b.purchase = foreign * rate0;
  b.fx_impact = foreign * (rate1 - rate0);
  const goodsValue = b.purchase + b.fx_impact;

  // Freight, insurance, customs, handling along the route.
  let lead = n(term.lead_time_days);
  const origin = up(pr.profile?.origin_country) ?? ctx.partnerCountry.get(term.partner_id) ?? null;
  let destCountry = up(pr.profile?.destination_country);
  let destWarehouse: number | null = ctx.model.warehouse_id ?? null;
  const modes: Mode[] = [];
  if (route) {
    const dest = ctx.nodes.get(route.destination_node_id);
    destWarehouse = dest?.warehouse_id ?? destWarehouse;
    destCountry ??= up(dest?.country_code);
    for (const e of [...route.edges].sort((a, c) => a.seq - c.seq)) {
      modes.push(e.transport_mode);
      const intl = isInternational(ctx, e);
      const eRate = fxRate(ctx.model, e.currency, base);
      if (eRate == null) notes.push(`no_fx:${up(e.currency)}`);
      const r = eRate ?? 1;
      let mult = n(p.freight_multiplier, 1) * n(p.freight_multipliers?.[e.transport_mode], 1);
      for (const d of ctx.disruptions) {
        if (d.kind === "cost" && d.days == null && edgeHit(d, e, route)) mult *= n(d.multiplier, 1);
      }
      const freight = (n(e.base_cost) / lot + n(e.cost_per_kg) * weight + n(e.cost_per_unit)) *
        (1 + n(e.fuel_surcharge_rate)) * mult * r;
      if (intl) b.international_freight += freight;
      else b.domestic_freight += freight;
      b.insurance += goodsValue * n(e.insurance_rate) * n(p.insurance_multiplier, 1);
      b.port_fee += (n(e.handling_cost) / lot + n(e.handling_cost_per_unit)) * r;
      lead += n(e.lead_time_days);
      for (const d of ctx.disruptions) {
        if (d.kind === "delay" && d.days == null && edgeHit(d, e, route)) lead += n(d.delay_days);
      }

      if (e.customs_clearance) {
        const rule = tariffFor(ctx, pr, origin, destCountry ?? up(ctx.nodes.get(e.to_node_id)?.country_code));
        const valuation = rule?.valuation ?? "CIF";
        const customsValue = valuation === "FOB"
          ? goodsValue
          : goodsValue + b.international_freight + b.insurance;
        const tariffRate = opt(p.tariff_rate_override) ?? opt(e.tariff_rate) ?? n(rule?.tariff_rate);
        if (!rule && e.tariff_rate == null && p.tariff_rate_override == null) notes.push("no_tariff_rule");
        const duty = customsValue * tariffRate * n(p.tariff_multiplier, 1);
        const other = customsValue * n(rule?.other_rate);
        b.customs_duty += duty + other;
        const tax = (customsValue + duty + other) * n(rule?.import_tax_rate);
        if (rule?.import_tax_recoverable === false) b.import_tax += tax;
        else b.recoverable += tax;
        b.customs_fee += n(e.customs_cost) / lot * n(p.customs_cost_multiplier, 1) * r;
      }

      // Handling where the goods pass through (not the supplier; the
      // destination warehouse's own handling counts as warehouse cost).
      const to = ctx.nodes.get(e.to_node_id);
      if (to) {
        const handling = n(to.handling_cost_per_unit) + n(to.handling_cost_per_shipment) / lot;
        if (to.kind === "warehouse" || to.kind === "dc") b.warehouse += handling * n(p.warehouse_cost_multiplier, 1);
        else b.port_fee += handling;
        lead += n(to.dwell_days);
      }
    }
  } else {
    notes.push("no_route");
  }

  // Warehouse, labour and the rest, from the cost rules.
  const price = salesPrice(ctx, pr);
  for (const rule of ctx.model.cost_rules ?? []) {
    if (rule.warehouse_id != null && rule.warehouse_id !== destWarehouse) continue;
    if (rule.product_id != null && rule.product_id !== pr.id) continue;
    if (rule.partner_id != null && rule.partner_id !== term.partner_id) continue;
    const rr = fxRate(ctx.model, rule.currency, base) ?? 1;
    const per = (u: number | null | undefined) => Math.max(n(rule.units_per_basis, n(u, 1)), 1e-9);
    let v = 0;
    switch (rule.basis) {
      case "per_unit": v = rule.amount * rr; break;
      case "per_unit_month": v = rule.amount * rr * n(pr.profile?.storage_days, 30) / 30; break;
      case "per_carton": v = rule.amount * rr / per(pr.profile?.units_per_carton); break;
      case "per_line": v = rule.amount * rr / per(pr.profile?.units_per_line); break;
      case "per_order": v = rule.amount * rr / per(pr.profile?.units_per_order); break;
      case "per_hour": v = rule.amount * rr / per(1); break;
      case "percent_of_revenue": v = rule.amount * price; break;
      case "percent_of_purchase": v = rule.amount * goodsValue; break;
      case "fixed_monthly": {
        const vol = opt(rule.units_per_basis) ??
          (destWarehouse != null ? ctx.warehouseVolume.get(destWarehouse) : [...ctx.warehouseVolume.values()].reduce((a, c) => a + c, 0));
        if (vol && vol > 0) v = rule.amount * rr / vol;
        else notes.push("fixed_cost_unallocated");
        break;
      }
    }
    const cat = rule.category;
    if (cat === "storage") v *= n(p.warehouse_cost_multiplier, 1);
    else if (["receiving", "inspection", "packing", "picking", "shipping", "labor"].includes(cat)) v *= n(p.labor_cost_multiplier, 1);
    else if (cat === "overhead" || cat === "other") v *= n(p.overhead_multiplier, 1);
    else if (cat === "domestic_freight") v *= n(p.freight_multiplier, 1);
    for (const d of ctx.disruptions) {
      // A cost spike at the warehouse node raises what it costs there.
      if (d.kind === "cost" && d.days == null && d.node_id != null && route &&
          ctx.nodes.get(d.node_id)?.warehouse_id === destWarehouse &&
          ["storage", "receiving", "inspection", "packing", "picking", "shipping", "labor", "overhead"].includes(cat)) {
        v *= n(d.multiplier, 1);
      }
    }
    if (rule.expensed === false) {
      b.recoverable += v;
      continue;
    }
    switch (cat) {
      case "storage": b.warehouse += v; break;
      case "receiving": b.receiving += v; break;
      case "inspection": b.inspection += v; break;
      case "packing": b.packing += v; break;
      case "picking": case "shipping": case "labor": b.labor += v; break;
      case "domestic_freight": b.domestic_freight += v; break;
      case "sales_related": b.sales_related += v; break;
      case "overhead": b.overhead += v; break;
      default: b.other += v;
    }
  }
  sumLanded(b);

  // Is it usable at all under this scenario?
  const enabled = p.supplier_enabled;
  if (enabled && !enabled.includes(term.partner_id) && !term.hypothetical) blocked.push("supplier_disabled");
  for (const d of ctx.disruptions) {
    if (d.kind === "stop" && d.days == null && hits(d, term.partner_id, route)) {
      blocked.push(d.label ?? "stopped");
    }
  }

  const profit = price - b.landed - b.sales_related;
  return {
    key: `${term.partner_id}:${route?.id ?? 0}`,
    product_id: pr.id,
    partner_id: term.partner_id,
    partner_name: ctx.partnerName.get(term.partner_id) ?? term.partner_name ?? `#${term.partner_id}`,
    hypothetical: term.hypothetical === true,
    route_id: route?.id ?? null,
    route_name: route?.name ?? null,
    mode: route ? primaryMode(ctx, route) : null,
    modes: [...new Set(modes)],
    lead_time_days: round(lead, 1),
    lot,
    currency,
    unit_price_foreign: round(foreign, 4),
    discount_rate: discount,
    moq: opt(term.moq),
    unit: roundBreakdown(b),
    sales_price: round(price, U),
    profit_per_unit: round(profit, U),
    margin: price > 0 ? round(profit / price, 4) : null,
    available: blocked.length === 0,
    blocked_by: blocked,
    notes: [...new Set(notes)],
    node_ids: route ? routeNodes(route) : [],
  };
}

/** Every route this supplier could use into the warehouse(s) in scope. */
function candidateRoutes(ctx: Ctx, partnerId: number): Route[] {
  const src = supplierNodeId(ctx, partnerId);
  if (src == null) return [];
  const dests = warehouseNodeIds(ctx);
  return ctx.routes.filter((r) => r.origin_node_id === src && dests.has(r.destination_node_id));
}

function termsFor(ctx: Ctx, productId: number): SupplyTerm[] {
  const base = (ctx.model.supplier_products ?? []).filter((t) => t.product_id === productId);
  const added = (ctx.p.added_suppliers ?? [])
    .filter((t) => t.product_id === productId)
    .map((t) => ({ ...t, hypothetical: true }));
  // A scenario's added terms replace a real one for the same supplier.
  const addedPartners = new Set(added.map((t) => t.partner_id));
  return [...base.filter((t) => !addedPartners.has(t.partner_id)), ...added];
}

export function optionsFor(ctx: Ctx, pr: ProductRow): OptionResult[] {
  const out: OptionResult[] = [];
  for (const term of termsFor(ctx, pr.id)) {
    const routes = candidateRoutes(ctx, term.partner_id);
    if (routes.length === 0) out.push(costOption(ctx, pr, term, null));
    for (const r of routes) out.push(costOption(ctx, pr, term, r));
  }
  return out;
}

function pickRoute(ctx: Ctx, opts: OptionResult[], term: SupplyTerm | undefined, productId: number): OptionResult | null {
  const usable = opts.filter((o) => o.available);
  if (usable.length === 0) return null;
  const forced = opt(ctx.p.route_overrides?.[String(productId)]);
  if (forced != null) {
    const f = usable.find((o) => o.route_id === forced);
    if (f) return f;
  }
  const mode = ctx.p.route_mode ?? "current";
  const cheapest = () => usable.reduce((a, c) => (c.unit.landed < a.unit.landed ? c : a));
  const fastest = () => usable.reduce((a, c) => (c.lead_time_days < a.lead_time_days || (c.lead_time_days === a.lead_time_days && c.unit.landed < a.unit.landed) ? c : a));
  if (mode === "cheapest") return cheapest();
  if (mode === "fastest") return fastest();
  if (mode === "current") {
    return usable.find((o) => term?.default_route_id != null && o.route_id === term.default_route_id) ?? cheapest();
  }
  const byMode = usable.filter((o) => o.mode === mode || o.modes.includes(mode));
  if (byMode.length) return byMode.reduce((a, c) => (c.unit.landed < a.unit.landed ? c : a));
  return cheapest();
}

/** Which supplier(s) and route(s) supply this product under the scenario. */
function choose(ctx: Ctx, pr: ProductRow, options: OptionResult[]): { chosen: ChosenOption[]; notes: string[] } {
  const notes: string[] = [];
  const terms = termsFor(ctx, pr.id);
  const byPartner = new Map<number, OptionResult[]>();
  for (const o of options) {
    if (!byPartner.has(o.partner_id)) byPartner.set(o.partner_id, []);
    byPartner.get(o.partner_id)!.push(o);
  }
  const best = new Map<number, OptionResult>();
  for (const [pid, opts] of byPartner) {
    const pick = pickRoute(ctx, opts, terms.find((t) => t.partner_id === pid), pr.id);
    if (pick) best.set(pid, pick);
  }
  if (best.size === 0) {
    notes.push(options.length ? "no_available_supplier" : "no_supplier");
    return { chosen: [], notes };
  }

  const split = ctx.p.supplier_split;
  if (split && Object.keys(split).length) {
    const parts = [...best.values()].filter((o) => n(split[String(o.partner_id)]) > 0);
    const total = parts.reduce((s, o) => s + n(split[String(o.partner_id)]), 0);
    if (parts.length && total > 0) {
      return { chosen: parts.map((o) => ({ ...o, share: n(split[String(o.partner_id)]) / total })), notes };
    }
    notes.push("split_not_applicable");
  }

  const all = [...best.values()];
  const choice = ctx.p.supplier_choice ?? "current";
  let pick: OptionResult | undefined;
  if (choice === "cheapest") pick = all.reduce((a, c) => (c.profit_per_unit > a.profit_per_unit ? c : a));
  else if (choice === "fastest") pick = all.reduce((a, c) => (c.lead_time_days < a.lead_time_days ? c : a));
  else {
    const primary = terms.find((t) => t.is_primary && !t.hypothetical) ?? terms.find((t) => !t.hypothetical);
    pick = primary ? best.get(primary.partner_id) : undefined;
    // An added supplier is part of the plan: it takes the product when it
    // leaves more profit than the current one.
    const added = all.filter((o) => o.hypothetical);
    if (added.length) {
      const bestAdded = added.reduce((a, c) => (c.profit_per_unit > a.profit_per_unit ? c : a));
      if (!pick || bestAdded.profit_per_unit > pick.profit_per_unit) pick = bestAdded;
    }
    if (!pick) {
      pick = all.reduce((a, c) => (c.profit_per_unit > a.profit_per_unit ? c : a));
      notes.push("current_unavailable");
    }
  }
  return { chosen: [{ ...pick!, share: 1 }], notes };
}

function weighted(chosen: ChosenOption[]): Breakdown {
  const b = emptyBreakdown();
  for (const c of chosen) {
    for (const k of COST_LINES) b[k] += c.unit[k] * c.share;
    b.sales_related += c.unit.sales_related * c.share;
    b.recoverable += c.unit.recoverable * c.share;
  }
  sumLanded(b);
  return b;
}

// ------------------------------------------------------------------ a run

function productsInScope(model: Model, p: ScenarioParams): ProductRow[] {
  const ids = p.product_ids?.length ? new Set(p.product_ids) : null;
  return (model.products ?? []).filter((x) => !ids || ids.has(x.id));
}

export function runScenario(model: Model, params: ScenarioParams = {}): RunResult {
  const ctx = makeCtx(model, params);
  const products = productsInScope(model, params);
  const warnings: string[] = [];

  // Monthly volume into each warehouse, for spreading fixed costs: the
  // destination of each product's first usable route, else the warehouse
  // in scope.
  for (const pr of products) {
    const monthly = annualVolume(ctx, pr) / 12;
    const t = termsFor(ctx, pr.id)[0];
    const r = t ? candidateRoutes(ctx, t.partner_id)[0] : undefined;
    const wh = (r ? ctx.nodes.get(r.destination_node_id)?.warehouse_id : null) ?? model.warehouse_id ?? null;
    if (wh != null) ctx.warehouseVolume.set(wh, (ctx.warehouseVolume.get(wh) ?? 0) + monthly);
  }

  const results: ProductResult[] = [];
  for (const pr of products) {
    const options = optionsFor(ctx, pr);
    const { chosen, notes } = choose(ctx, pr, options);
    const volume = annualVolume(ctx, pr);
    const price = salesPrice(ctx, pr);
    const unit = weighted(chosen);
    const profit = price - unit.landed - unit.sales_related;
    const lead = chosen.reduce((s, c) => s + c.lead_time_days * c.share, 0);
    const partners = new Set(options.filter((o) => o.available).map((o) => o.partner_id));
    results.push({
      product_id: pr.id,
      name: pr.name,
      jan_code: pr.jan_code ?? null,
      sku: pr.sku ?? null,
      maker: pr.maker ?? null,
      volume: round(volume, 2),
      on_hand: n(pr.on_hand),
      sales_price: round(price, U),
      unit: roundBreakdown(unit),
      profit_per_unit: round(profit, U),
      margin: price > 0 ? round(profit / price, 4) : null,
      lead_time_days: round(lead, 1),
      revenue: round(chosen.length ? price * volume : 0),
      landed_total: round(unit.landed * volume),
      sales_related_total: round(unit.sales_related * volume),
      profit_total: round(chosen.length ? profit * volume : 0),
      chosen,
      options,
      single_source: partners.size <= 1,
      notes: [...notes, ...new Set(chosen.flatMap((c) => c.notes))],
    });
    if (!chosen.length) warnings.push(`no_supply:${pr.id}`);
  }

  const summary = summarize(results);
  const bottlenecks = computeLoads(ctx, results);
  const risks = computeRisks(ctx, results, bottlenecks);
  const disruptions = computeDisruptions(ctx, products, results);
  return { name: params.name ?? "", summary, products: results, bottlenecks, risks, disruptions, warnings };
}

export function summarize(results: ProductResult[]): Summary {
  const lines = {} as Record<CostLine, number>;
  for (const k of COST_LINES) lines[k] = 0;
  let revenue = 0, units = 0, salesRelated = 0, recoverable = 0, leadWeighted = 0;
  for (const r of results) {
    if (!r.chosen.length) continue;
    revenue += r.revenue;
    units += r.volume;
    salesRelated += r.sales_related_total;
    recoverable += r.unit.recoverable * r.volume;
    leadWeighted += r.lead_time_days * r.volume;
    for (const k of COST_LINES) lines[k] += r.unit[k] * r.volume;
  }
  for (const k of COST_LINES) lines[k] = round(lines[k]);
  const landed = COST_LINES.reduce((s, k) => s + lines[k], 0);
  const total = landed + salesRelated;
  const profit = revenue - total;
  return {
    revenue: round(revenue),
    units: round(units),
    purchase: lines.purchase,
    fx_impact: lines.fx_impact,
    logistics: round(lines.international_freight + lines.insurance + lines.port_fee + lines.domestic_freight),
    customs: round(lines.customs_duty + lines.import_tax + lines.customs_fee),
    warehouse: lines.warehouse,
    labor: round(lines.receiving + lines.inspection + lines.packing + lines.labor),
    other: round(lines.overhead + lines.other),
    landed_cost: round(landed),
    sales_related: round(salesRelated),
    total_cost: round(total),
    profit: round(profit),
    margin: revenue > 0 ? round(profit / revenue, 4) : null,
    lead_time_days: units > 0 ? round(leadWeighted / units, 1) : null,
    lines,
    recoverable: round(recoverable),
  };
}

// ------------------------------------------------------------------ bottlenecks

export function computeLoads(ctx: Ctx, results: ProductResult[]): Load[] {
  const s = ctx.s;
  type Acc = Omit<Load, "load" | "status" | "has_alternative"> & { noAlt: boolean };
  const acc = new Map<string, Acc>();
  const routeById = new Map(ctx.routes.map((r) => [r.id, r]));
  const weightOf = new Map((ctx.model.products ?? []).map((x) => [x.id, n(x.profile?.unit_weight_kg)]));

  for (const r of results) {
    for (const c of r.chosen) {
      const route = c.route_id != null ? routeById.get(c.route_id) : undefined;
      if (!route) continue;
      const units = r.volume * c.share / 12;
      const kg = units * (weightOf.get(r.product_id) ?? 0);
      // Could this product avoid the node / leg?
      const alts = r.options.filter((o) => o.key !== c.key && o.available);
      const touch = (k: string, init: () => Acc, avoid: (o: OptionResult) => boolean) => {
        const a = acc.get(k) ?? init();
        a.units_month += units;
        a.kg_month += kg;
        if (!a.products.includes(r.product_id)) a.products.push(r.product_id);
        if (!alts.some(avoid)) a.noAlt = true;
        acc.set(k, a);
      };
      for (const nid of routeNodes(route)) {
        const node = ctx.nodes.get(nid);
        if (!node) continue;
        touch(`n${nid}`, () => ({
          kind: "node", id: nid, name: node.name, node_kind: node.kind, units_month: 0, kg_month: 0,
          capacity_units_month: opt(node.capacity_units_month), capacity_kg_month: opt(node.capacity_kg_month),
          products: [], noAlt: false,
        }), (o) => !o.node_ids.includes(nid) && node.kind !== "warehouse");
      }
      for (const e of route.edges) {
        touch(`e${route.id}:${e.seq}`, () => ({
          kind: "edge", id: e.id ?? route.id * 1000 + e.seq,
          name: `${ctx.nodes.get(e.from_node_id)?.name ?? e.from_node_id} → ${ctx.nodes.get(e.to_node_id)?.name ?? e.to_node_id}`,
          mode: e.transport_mode, route_id: route.id, units_month: 0, kg_month: 0,
          capacity_units_month: opt(e.capacity_units_month), capacity_kg_month: opt(e.capacity_kg_month),
          products: [], noAlt: false,
        }), (o) => o.route_id !== route.id);
      }
    }
  }

  const out: Load[] = [];
  for (const a of acc.values()) {
    let capU = a.capacity_units_month;
    let capKg = a.capacity_kg_month;
    let stopped = false;
    for (const d of ctx.disruptions) {
      const hitNode = a.kind === "node" && d.node_id === a.id;
      const hitEdge = a.kind === "edge" && ((d.route_id != null && d.route_id === a.route_id && d.node_id == null && d.mode == null) || (d.mode != null && d.mode === a.mode && d.route_id == null && d.node_id == null));
      if (!hitNode && !hitEdge) continue;
      if (d.kind === "capacity") {
        const m = n(d.multiplier, 1);
        if (capU != null) capU *= m;
        if (capKg != null) capKg *= m;
      }
      if (d.kind === "stop") stopped = true;
    }
    const loads = [
      capU != null && capU > 0 ? a.units_month / capU : capU === 0 && a.units_month > 0 ? Infinity : null,
      capKg != null && capKg > 0 ? a.kg_month / capKg : capKg === 0 && a.kg_month > 0 ? Infinity : null,
    ].filter((x): x is number => x != null);
    const load = loads.length ? Math.max(...loads) : null;
    const status: Load["status"] = stopped
      ? "stopped"
      : load == null
      ? "no_capacity"
      : load >= s.load_exceeded
      ? "exceeded"
      : load >= s.load_warn
      ? "busy"
      : "ok";
    out.push({
      kind: a.kind, id: a.id, name: a.name, node_kind: a.node_kind, mode: a.mode, route_id: a.route_id,
      units_month: round(a.units_month, 1), kg_month: round(a.kg_month, 1),
      capacity_units_month: capU != null ? round(capU, 1) : null,
      capacity_kg_month: capKg != null ? round(capKg, 1) : null,
      load: load == null ? null : Number.isFinite(load) ? round(load, 4) : 99,
      status, has_alternative: !a.noAlt, products: a.products,
    });
  }
  const rank = { stopped: 0, exceeded: 1, busy: 2, ok: 3, no_capacity: 4 };
  return out.sort((x, y) => rank[x.status] - rank[y.status] || n(y.load) - n(x.load) || y.units_month - x.units_month);
}

// ------------------------------------------------------------------ risk

export function computeRisks(ctx: Ctx, results: ProductResult[], loads: Load[]): RiskItem[] {
  const items: RiskItem[] = [];
  const events = ctx.model.risk_events ?? [];
  const stats = new Map((ctx.model.supplier_stats ?? []).map((x) => [x.partner_id, x]));
  const usedRoutes = new Set<number>();
  const usedPartners = new Map<number, number>(); // partner -> sole-sourced products
  for (const r of results) {
    for (const c of r.chosen) {
      if (c.route_id != null) usedRoutes.add(c.route_id);
      if (!usedPartners.has(c.partner_id)) usedPartners.set(c.partner_id, 0);
      if (r.single_source) usedPartners.set(c.partner_id, usedPartners.get(c.partner_id)! + 1);
    }
  }
  for (const t of ctx.model.supplier_products ?? []) {
    if (!usedPartners.has(t.partner_id)) usedPartners.set(t.partner_id, 0);
  }

  const push = (kind: RiskItem["kind"], id: number, name: string, parts: [number, string][]) => {
    const score = Math.min(100, parts.reduce((s, [p]) => s + p, 0));
    items.push({ kind, id, name, score: round(score, 0), level: levelOf(score), reasons: parts.filter(([p]) => p > 0).map(([, r]) => r) });
  };

  for (const [pid, sole] of usedPartners) {
    const parts: [number, string][] = [];
    const node = [...ctx.nodes.values()].find((x) => x.kind === "supplier" && x.partner_id === pid);
    if (node?.risk_level) parts.push([LEVEL_POINTS[node.risk_level], `level:${node.risk_level}`]);
    if (sole > 0) parts.push([Math.min(35, 15 + sole * 4), `sole_source:${sole}`]);
    for (const e of events) if (e.partner_id === pid) parts.push([SEVERITY_POINTS[e.severity], `event:${e.kind}`]);
    const st = stats.get(pid);
    if (st?.late_rate && st.late_rate > 0.05) parts.push([Math.min(25, Math.round(st.late_rate * 100)), `late_rate:${round(st.late_rate * 100, 1)}`]);
    if (st?.defect_rate && st.defect_rate > 0.01) parts.push([Math.min(20, Math.round(st.defect_rate * 400)), `defect_rate:${round(st.defect_rate * 100, 2)}`]);
    push("supplier", pid, ctx.partnerName.get(pid) ?? `#${pid}`, parts);
  }

  const loadByNode = new Map(loads.filter((l) => l.kind === "node").map((l) => [l.id, l]));
  for (const node of ctx.nodes.values()) {
    if (node.kind === "supplier") continue;
    const l = loadByNode.get(node.id);
    if (!l && node.kind !== "warehouse") continue;
    const parts: [number, string][] = [];
    if (node.risk_level) parts.push([LEVEL_POINTS[node.risk_level], `level:${node.risk_level}`]);
    if (l?.status === "exceeded") parts.push([30, "load_exceeded"]);
    else if (l?.status === "busy") parts.push([15, "load_busy"]);
    if (l && !l.has_alternative && node.kind !== "warehouse") parts.push([15, "no_alternative"]);
    for (const e of events) if (e.node_id === node.id) parts.push([SEVERITY_POINTS[e.severity], `event:${e.kind}`]);
    push("node", node.id, node.name, parts);
  }

  for (const r of ctx.routes) {
    if (!usedRoutes.has(r.id)) continue;
    const parts: [number, string][] = [];
    const worst = r.edges.reduce<RiskLevel>((w, e) => (LEVEL_POINTS[e.risk_level ?? "low"] > LEVEL_POINTS[w] ? e.risk_level ?? "low" : w), "low");
    parts.push([LEVEL_POINTS[worst], `level:${worst}`]);
    const lead = r.edges.reduce((s, e) => s + n(e.lead_time_days), 0);
    if (lead > 30) parts.push([10, `long_lead:${round(lead, 0)}`]);
    if (r.edges.some((e) => isInternational(ctx, e))) parts.push([5, "cross_border"]);
    const edgeLoads = loads.filter((l) => l.kind === "edge" && l.route_id === r.id);
    if (edgeLoads.some((l) => l.status === "exceeded")) parts.push([30, "load_exceeded"]);
    else if (edgeLoads.some((l) => l.status === "busy")) parts.push([15, "load_busy"]);
    for (const e of events) {
      if (e.route_id === r.id || (e.transport_mode && routeModes(r).includes(e.transport_mode))) {
        parts.push([SEVERITY_POINTS[e.severity], `event:${e.kind}`]);
      }
    }
    push("route", r.id, r.name, parts);
  }
  return items.sort((a, b) => b.score - a.score);
}

// ------------------------------------------------------------------ disruption (§19)

function describe(ctx: Ctx, d: Disruption): string {
  if (d.label) return d.label;
  const target = d.node_id != null
    ? ctx.nodes.get(d.node_id)?.name
    : d.route_id != null
    ? ctx.routes.find((r) => r.id === d.route_id)?.name
    : d.partner_id != null
    ? ctx.partnerName.get(d.partner_id)
    : d.mode;
  return `${target ?? "?"} ${d.kind}${d.days ? ` ${d.days}d` : ""}`;
}

export function computeDisruptions(ctx: Ctx, products: ProductRow[], results: ProductResult[]): DisruptionImpact[] {
  const out: DisruptionImpact[] = [];
  const routeById = new Map(ctx.routes.map((r) => [r.id, r]));
  const byId = new Map(products.map((x) => [x.id, x]));
  for (const d of ctx.disruptions) {
    const temporaryStop = d.kind === "stop" && n(d.days) > 0;
    const delay = d.kind === "delay" && n(d.delay_days) > 0;
    if (!temporaryStop && !delay) continue;
    const impact: DisruptionImpact = {
      label: describe(ctx, d), disruption: d, affected_products: [],
      extra_cost: 0, lost_profit: 0, lost_units: 0, impact: 0,
    };
    for (const r of results) {
      const pr = byId.get(r.product_id);
      if (!pr) continue;
      const daily = r.volume / 365;
      const coverage = daily > 0 ? r.on_hand / daily : null;
      for (const c of r.chosen) {
        const route = c.route_id != null ? routeById.get(c.route_id) ?? null : null;
        if (!hits(d, c.partner_id, route)) continue;
        const shareDaily = daily * c.share;
        let alternative: OptionResult | null = null;
        let lost = 0, extraPerUnit = 0, leadChange: number | null = null, affected = 0;
        if (temporaryStop) {
          const days = n(d.days);
          affected = shareDaily * days;
          const alts = r.options.filter((o) => o.available && o.key !== c.key &&
            !hits(d, o.partner_id, o.route_id != null ? routeById.get(o.route_id) ?? null : null));
          if (alts.length) {
            alternative = alts.reduce((a, x) => (x.unit.landed < a.unit.landed ? x : a));
            extraPerUnit = alternative.unit.landed - c.unit.landed;
            leadChange = round(alternative.lead_time_days - c.lead_time_days, 1);
            // Until the alternative's goods arrive, only stock covers demand.
            const gap = Math.min(days, alternative.lead_time_days) - (coverage ?? 0);
            lost = shareDaily * Math.max(0, gap);
          } else {
            lost = shareDaily * Math.max(0, days - (coverage ?? 0));
          }
        } else {
          affected = shareDaily * n(d.delay_days);
          leadChange = n(d.delay_days);
          lost = shareDaily * Math.max(0, n(d.delay_days) - (coverage ?? 0));
        }
        lost = Math.min(lost, affected);
        const rerouted = temporaryStop && alternative ? Math.max(0, affected - lost) : 0;
        const extraCost = rerouted * extraPerUnit;
        const lostProfit = lost * Math.max(0, c.profit_per_unit);
        impact.affected_products.push({
          product_id: r.product_id, name: r.name,
          affected_units: round(affected, 1), rerouted_units: round(rerouted, 1), lost_units: round(lost, 1),
          alternative: alternative ? `${alternative.partner_name}${alternative.route_name ? ` / ${alternative.route_name}` : ""}` : null,
          extra_cost_per_unit: round(extraPerUnit, U), lead_time_change: leadChange,
          coverage_days: coverage == null ? null : round(coverage, 1),
          extra_cost: round(extraCost), lost_profit: round(lostProfit), impact: round(-extraCost - lostProfit),
        });
        impact.extra_cost += extraCost;
        impact.lost_profit += lostProfit;
        impact.lost_units += lost;
      }
    }
    impact.extra_cost = round(impact.extra_cost);
    impact.lost_profit = round(impact.lost_profit);
    impact.lost_units = round(impact.lost_units, 1);
    impact.impact = round(-impact.extra_cost - impact.lost_profit);
    out.push(impact);
  }
  return out;
}

// ------------------------------------------------------------------ comparisons

export interface Driver {
  line: CostLine | "revenue" | "sales_related";
  delta: number;
}

/** Which lines moved the profit, largest first (the "原因" of §30). */
export function drivers(a: Summary, b: Summary): Driver[] {
  const out: Driver[] = [];
  const rev = round(b.revenue - a.revenue);
  if (Math.abs(rev) >= 0.5) out.push({ line: "revenue", delta: rev });
  for (const k of COST_LINES) {
    const d = round(b.lines[k] - a.lines[k]);
    if (Math.abs(d) >= 0.5) out.push({ line: k, delta: d });
  }
  const sr = round(b.sales_related - a.sales_related);
  if (Math.abs(sr) >= 0.5) out.push({ line: "sales_related", delta: sr });
  return out.sort((x, y) => Math.abs(y.delta) - Math.abs(x.delta));
}

export interface Comparison {
  baseline: RunResult;
  scenario: RunResult;
  delta: { revenue: number; landed_cost: number; profit: number; margin: number | null; lead_time_days: number | null };
  drivers: Driver[];
}

export function compare(model: Model, scenario: ScenarioParams, baseline: ScenarioParams = {}): Comparison {
  const scope = scenario.product_ids ?? baseline.product_ids;
  const a = runScenario(model, { ...baseline, product_ids: scope });
  const b = runScenario(model, { ...scenario, product_ids: scope });
  return {
    baseline: a,
    scenario: b,
    delta: {
      revenue: round(b.summary.revenue - a.summary.revenue),
      landed_cost: round(b.summary.landed_cost - a.summary.landed_cost),
      profit: round(b.summary.profit - a.summary.profit),
      margin: a.summary.margin != null && b.summary.margin != null ? round(b.summary.margin - a.summary.margin, 4) : null,
      lead_time_days: a.summary.lead_time_days != null && b.summary.lead_time_days != null
        ? round(b.summary.lead_time_days - a.summary.lead_time_days, 1) : null,
    },
    drivers: drivers(a.summary, b.summary),
  };
}

/** Up to five scenarios side by side against the current state (§16). */
export function compareMany(model: Model, scenarios: ScenarioParams[]) {
  const base = runScenario(model, {});
  return {
    baseline: slim(base),
    scenarios: scenarios.slice(0, 5).map((s) => {
      const r = runScenario(model, s);
      return { ...slim(r), delta_profit: round(r.summary.profit - base.summary.profit), drivers: drivers(base.summary, r.summary).slice(0, 5) };
    }),
  };
}

function slim(r: RunResult) {
  return {
    name: r.name,
    summary: r.summary,
    risks_high: r.risks.filter((x) => x.level === "high" || x.level === "critical").length,
    bottlenecks_exceeded: r.bottlenecks.filter((x) => x.status === "exceeded" || x.status === "stopped").length,
    disruption_impact: round(r.disruptions.reduce((s, d) => s + d.impact, 0)),
  };
}

/** Every supplier × route for one product, and optionally the same at other
 * 掛率 (§5, §7, §27). */
export function productOptions(model: Model, productId: number, params: ScenarioParams = {}, rates: number[] = []) {
  const run = runScenario(model, { ...params, product_ids: [productId] });
  const product = run.products[0] ?? null;
  const sweeps = rates.slice(0, 8).map((rate) => {
    const overrides: Record<string, number> = {};
    for (const t of model.supplier_products ?? []) if (t.product_id === productId) overrides[String(t.partner_id)] = rate;
    const r = runScenario(model, { ...params, product_ids: [productId], discount_rate_overrides: { ...params.discount_rate_overrides, ...overrides } });
    return { rate, options: r.products[0]?.options ?? [], chosen: r.products[0]?.chosen ?? [] };
  });
  return { product, sweeps, risks: run.risks, bottlenecks: run.bottlenecks };
}

export interface PurchaseLine {
  product_id: number;
  partner_id: number;
  unit_price?: number | null;
  quantity?: number | null;
}

/** Before a purchase order is placed (§29–30): each line's landed cost and
 * profit at this price from this supplier, against the current state. */
export function purchaseCheck(model: Model, lines: PurchaseLine[]) {
  const s = settingsOf(model);
  return lines.map((l) => {
    const known = (model.supplier_products ?? []).some((t) => t.product_id === l.product_id && t.partner_id === l.partner_id);
    const scenario: ScenarioParams = {
      product_ids: [l.product_id],
      supplier_split: { [String(l.partner_id)]: 1 },
      lot_quantity: l.quantity ?? undefined,
      unit_price_overrides: l.unit_price != null ? { [`${l.partner_id}:${l.product_id}`]: l.unit_price } : undefined,
      added_suppliers: known ? undefined : [{ partner_id: l.partner_id, product_id: l.product_id, unit_price: l.unit_price ?? null }],
    };
    const c = compare(model, scenario, { product_ids: [l.product_id] });
    const before = c.baseline.products[0];
    const after = c.scenario.products[0];
    const mb = before?.margin ?? null;
    const ma = after?.margin ?? null;
    const warn: string[] = [];
    if (ma != null && ma < s.margin_warn) warn.push("margin_low");
    if (mb != null && ma != null && mb - ma >= s.margin_drop_warn) warn.push("margin_drop");
    if (after && after.profit_per_unit < 0) warn.push("loss");
    if (!known) warn.push("new_supplier");
    return {
      product_id: l.product_id,
      partner_id: l.partner_id,
      quantity: l.quantity ?? null,
      unit_price: l.unit_price ?? null,
      name: after?.name ?? before?.name ?? `#${l.product_id}`,
      sales_price: after?.sales_price ?? null,
      landed_before: before?.unit.landed ?? null,
      landed_after: after?.unit.landed ?? null,
      profit_before: before?.profit_per_unit ?? null,
      profit_after: after?.profit_per_unit ?? null,
      margin_before: mb,
      margin_after: ma,
      unit_after: after?.unit ?? null,
      chosen_after: after?.chosen ?? [],
      warn,
      drivers: productDrivers(before, after),
    };
  });
}

function productDrivers(a: ProductResult | undefined, b: ProductResult | undefined): Driver[] {
  if (!a || !b) return [];
  const out: Driver[] = [];
  for (const k of COST_LINES) {
    const d = round(b.unit[k] - a.unit[k]);
    if (Math.abs(d) >= 0.01) out.push({ line: k, delta: d });
  }
  return out.sort((x, y) => Math.abs(y.delta) - Math.abs(x.delta));
}
