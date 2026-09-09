# Migration Plan

_Additive, non-breaking, migration-first (spec §36, §47). Existing migrations
`0001`–`0009` stay; new work continues the sequence. No `DROP DATABASE`, no
unplanned table re-creation. Every stock change becomes a movement + snapshot
update inside a transaction._

## 0. Compatibility rules

- Extend existing tables with nullable columns / new tables; never break the
  delivery / shipment / stock flows in use.
- Backfill the current single implicit warehouse as a seeded **default company +
  default warehouse**; attach existing `stock_levels`, `delivery_plans`,
  `shipment_plans` to it via nullable `warehouse_id` defaulted to that warehouse.
- Ship each migration with a matching RPC/edge-function change and Flutter repo
  change behind the existing `ApiResult` pattern; keep the test suite green.

## Step-by-step (aligned to spec §46)

> Status: **0010–0016 applied.** 0017 onward is still planned.

### 0010 — Tenancy & warehouse (Steps 1) ✅
- `companies`, `warehouses`, `zones`, `bins` (+ bin_type enum/check).
- Seed default company + default warehouse (is_default = true).
- Add nullable `warehouse_id` to `stock_levels`, `delivery_plans`,
  `shipment_plans`; backfill to the default warehouse; keep old queries working.

### 0011 — Warehouse picker/context support (Step 2) ✅
- Views/RPCs to list warehouses with per-warehouse KPI rollups (extends
  `dashboard_metrics` to accept a `warehouse_id`, defaulting to all/default).

### 0012 — Identity, roles, scope (Step 3) ✅ (guards transitional — see permission_model.md)
- Adopt Supabase Auth. `app_users` (link to auth.uid), `roles`, `user_roles`,
  `user_warehouses`. RLS policies keyed on company/warehouse membership.
- SECURITY DEFINER RPCs re-check role + scope; record actor id everywhere.
- `audit_log` table introduced here (used by all later steps).

### 0013/0014 — Inventory ledger (precondition for ops) ✅
- `stock_movements` ledger (signed delta + before/after + reference + actor).
- `stock_levels` kept as the snapshot but **re-keyed to (warehouse_id, jan_code)**
  — the old jan_code-only key made per-warehouse stock impossible. Renaming it to
  `inventory` was dropped as churn: the table already is the snapshot, and not
  touching a table the whole app reads and writes kept the blast radius small.
  A bin-level balance table arrives with put-away, when it is actually needed.
- `apply_stock_movement` is the single place stock moves: locks the row, computes
  the effective delta, appends the movement, updates the snapshot.
- reconcile/cancel/ship/cancel_shipment rewritten to go through it, each also
  writing an `audit_log` entry.
- `stock_ledger()` answers "why did stock change" (spec §18).
- Hardening: mutating routines revoked from PUBLIC/anon/authenticated (Postgres
  grants EXECUTE to PUBLIC by default, so anon could previously call
  `reconcile_delivery_plan` and fabricate stock) and granted to service_role.

### 0015 — Receiving + inspection (Steps 4–5) ✅
- `inspections` / `inspection_items` hanging off a receipt, with
  PASS/FAIL/PARTIAL/HOLD and a **stored** discrepancy (generated column, never
  corrected away — spec §10) and a pass/fail split per line so 47 pass / 3 fail
  is expressible (§38 Scenario B).
- start_inspection (idempotent) / save_inspection_item / complete_inspection
  (refuses to close while lines are unchecked) / inspection_detail.
- `inspections` edge function + Flutter list & detail screens; the home menu's
  検品 entry now points here instead of the dead InventorOS screen.
- Renaming `delivery_plans`→`purchase_orders` and `delivery_reconciliations`→
  `receipts` was deliberately NOT done: the existing names already carry the
  same meaning, and renaming live tables the whole app reads would be churn
  with no behavioural gain. Generalisation can happen if a second inbound
  document type ever appears.

### 0016 — Locations & put-away, opt-in (Step 6) ✅
- `warehouses.uses_locations` (**default false**) is the switch. The operator
  does not use shelf locations, so nothing is created by default and the system
  behaves exactly as before; the capability is designed in for when they adopt
  it. Spec §7 (don't force the hierarchy) and §49 (auto-creation is a toggle).
- The four bins 0010 seeded were removed for warehouses that have not opted in,
  guarded on the ledger so a bin that was ever used is never dropped.
- `bin_stock` per-bin balances + `apply_bin_movement` (the bin analogue of
  apply_stock_movement) + `putaway()`, which refuses when locations are off,
  when bins span warehouses, or when the source does not hold enough.
- `stock_movements.balance_scope` says whether a row's before/after describe the
  warehouse or a bin balance; a put-away redistributes stock, so the warehouse
  total is untouched. `stock_ledger` gained a scope filter defaulting to
  WAREHOUSE, so existing callers see exactly what they saw before.
- Wizard: locations off by default, bin seeding only offered once it is on.

### 0017 — Picking / packing / shipping (Steps 7–9)
- `pick_lists`/`pick_tasks`, allocation, pack sessions, shipping completion.
- Extend current shipment model with allocate/pick/pack states; keep cartons + JAN
  print + 送り状 + sender profile intact.

### 0018 — Cycle count + adjustment (Step 10)
- Count sessions, variance, approval → ADJUST movements; blind-count option.

### 0019 — Inter-warehouse transfer (Step 11)
- `transfer_orders` + state machine; TRANSFER_OUT/IN movements; no self-approval.

### 0020 — Stock ledger views / audit surfacing (Step 12)
- Ledger read views ("why did stock change"), audit query RPCs.

### 0021 — Seed / demo (Step 13)
- Demo company (Demo Trading Co.), 神戸/大阪 warehouses, zones A/B/C, bins
  (A-01-01…, QC-01, STAGE-01, SHIP-01), demo users per role, 20–50 products,
  5 POs, 10–20 SOs, inspections (PASS/FAIL/PARTIAL), a 神戸→大阪 transfer, so the
  app is populated on first run (fixes "looks empty"). Demo scenarios A–D (§38).

### 0022+ — AI + connectors (Steps 15–17)
- `ai_analysis` + provider abstraction; re-point Gemini OCR through it.
- Connector/adapter tables for external systems; InventorOS becomes one connector.

## Rollout discipline

- One concern per migration; each reversible in intent (inactivate, not destroy).
- After each: `flutter analyze` clean, `flutter test` green, and a DB smoke check
  via the Supabase RPC. Commit per step with a clear message.
