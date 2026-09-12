# Architecture — Current State

_Phase 0 investigation output. Snapshot of `paazuuu/wms` as it exists today,
before the spec-driven evolution (`WMS_改善統合仕様書_Claude_Code.md`)._

> **Historical snapshot — no longer the current state.** Everything below
> describing InventorOS-routed screens (inspection, receiving, picking,
> products, purchase_orders, sales_orders, suppliers, locations, warehouses,
> work_orders, reports, stock_adjustment, stock_count, tracking, and the
> InventorOS Sanctum login) was removed from the app: that backend was never
> actually reachable, and the decision was made not to stand it up. See
> `migration_plan.md`'s status line for what the app is today — Supabase only,
> real Supabase Auth sign-in, no InventorOS dependency anywhere.

## 1. High-level shape

The system is a **hybrid of two independent backends** behind one Flutter app:

```
Flutter app (mobile / web)
   ├── InventorOS API      (Laravel, EXTERNAL, apiBaseUrl = http://localhost/api/v1)
   │     products, categories, locations, orders, purchase-orders,
   │     stock-adjustments, stock-audits, suppliers, warehouses,
   │     work-orders, reports, barcode lookup, inspection*, attachments*
   │     multi-tenant via organization_id; auth via Sanctum + permissions
   │
   └── Supabase             (Postgres + Edge Functions, project vjunicsfobglmncjucbb)
         delivery reconciliation, outbound shipment, stock_levels,
         suppliers (delivery_suppliers), dashboard metrics
         auth: anon key (login-free); logic guarded server-side in functions/RPCs
```

The two backends do **not** share data. The delivery/shipment/stock features
(the ones actively used and demoed) live entirely in Supabase; everything else
on the home menu targets the InventorOS API.

## 2. Repository layout

- `mobile/` — Flutter app (Riverpod, gen_l10n ja/en/zh, Dio, drift offline queue).
- `supabase/migrations/` — `0001`–`0009` SQL migrations (delivery, reconcile RPC,
  traceability/suppliers/stock, header auto-read, split delivery, cancel,
  shipments, dashboard_metrics).
- `supabase/functions/` — `delivery-plans`, `import-plan`, `ocr-delivery-note`,
  `shipments` (Deno edge functions).
- `backend/` — empty in this repo. InventorOS (github.com/Inventoros/Inventoros,
  Laravel 13/PHP 8.2/MySQL, MIT) is an **external** app the mobile client calls;
  earlier sessions cloned it here transiently and added an inspection +
  polymorphic attachments domain (see `findings.md`, `progress.md`).
- `docs/` — `delivery-reconciliation.md` (+ these Phase 0 docs).
- Root planning docs: `findings.md`, `progress.md`, `task_plan.md`,
  `WMS_開発仕様書_Phase1-3.md`, `WMS_改善統合仕様書_Claude_Code.md` (the new spec).

## 3. Flutter feature modules (`mobile/lib/features/`)

| Module | Screens | Backend | Working today? |
|---|---|---|---|
| delivery | plan list, import, reconciliation, receipt history, stock list | Supabase | ✅ |
| shipment | list, detail, carton edit, sender settings | Supabase | ✅ |
| home | dashboard overview (+live KPI section), coming-soon shell | Supabase (metrics) | ✅ |
| inspection | list, detail, barcode scan | InventorOS | only if InventorOS runs |
| receiving | list, detail | InventorOS | only if InventorOS runs |
| picking | list, pick list | InventorOS | only if InventorOS runs |
| products | lookup, detail | InventorOS | only if InventorOS runs |
| purchase_orders | list, view | InventorOS | only if InventorOS runs |
| sales_orders | list, detail | InventorOS | only if InventorOS runs |
| suppliers | list, detail | InventorOS | only if InventorOS runs |
| locations | list, detail | InventorOS | only if InventorOS runs |
| warehouses | list, detail | InventorOS | only if InventorOS runs |
| work_orders | list, view | InventorOS | only if InventorOS runs |
| reports | list, result | InventorOS | only if InventorOS runs |
| stock_adjustment | search, form | InventorOS | only if InventorOS runs |
| stock_count | list, audit view | InventorOS | only if InventorOS runs |
| tracking | search, detail (lots/serials) | InventorOS | only if InventorOS runs |
| auth | login | InventorOS (Sanctum) | InventorOS only |

`feature_catalog.dart` marks all 16 menu entries `ready`; the comment says each
maps to a live InventorOS endpoint. In practice, with no InventorOS backend
reachable, only delivery/shipment/stock/dashboard light up — which is why the
app "feels empty."

## 4. Supabase data model (public schema)

- `delivery_plans` / `delivery_plan_lines` — expected inbound (納品予定) + lines
  with `planned_quantity`, `received_quantity`, header auto-read fields.
- `delivery_reconciliations` / `reconciliation_lines` — receipt events + counted
  lines; `reconcile_delivery_plan` RPC accumulates split deliveries.
- `delivery_suppliers` — supplier master for the delivery flow.
- `stock_levels` — **snapshot only**: `(jan_code, on_hand, product_name, updated_at)`.
  No movement ledger; quantity is mutated in place by the reconcile/ship RPCs.
- `shipment_plans` / `shipment_lines` / `shipment_cartons` / `shipment_carton_items`
  — outbound (出庫) with carton subdivision; `ship_plan` / `cancel_shipment` RPCs.
- `dashboard_metrics(p_days, p_low_threshold)` RPC — aggregated home KPIs.
- RLS is enabled on all tables; edge functions use the service role, the app
  reads stock via PostgREST with the anon key.

## 5. Cross-cutting current capabilities

- **i18n**: gen_l10n, ja (template) / en / zh; keys resolved by id.
- **Theming**: `AppTheme.light()/dark()`, `ThemeMode.system` (dark mode works).
- **Scanning**: `HardwareScanner` (keyboard-wedge) + camera (`mobile_scanner`) +
  manual `ScanField`. On-device OCR (ML Kit) guarded off web via conditional import.
- **Offline**: drift-backed `OfflineSyncService` (queue + flush on connectivity).
- **OCR**: Gemini via `import-plan` / `ocr-delivery-note` edge functions
  (header + line extraction), used ad hoc — no AI-result table.
- **Text scaling** option + **widget tests** (169 passing) for key screens.

## 6. What is NOT present today (gaps vs spec)

- No **company/tenant** concept in Supabase (InventorOS has `organization_id`).
- No **multi-warehouse** in the Supabase model or the Flutter shell; no top-level
  warehouse picker / add-warehouse; stock is one implicit warehouse.
- No **zones/bins/bin-types** (STAGING/QC_HOLD/PICKABLE/…).
- No **stock_movements / stock ledger**; stock is a mutable snapshot.
- No **roles/permissions/warehouse-scope** on the Supabase path (anon, login-free).
- No **audit log** table.
- No **AI-result store** separate from WMS data; no provider abstraction.
- Inbound/outbound are single-step (reconcile / ship) rather than the spec's
  staged flows (receiving→inspection→put-away, allocate→pick→pack→ship).
- No **inter-warehouse transfer**.

See `architecture_target.md` for where these go and `migration_plan.md` for how.
