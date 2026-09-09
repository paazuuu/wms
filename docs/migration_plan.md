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

> Status: **0010–0018 applied.** 0019 onward is still planned.

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

### 0017 — Cycle count + adjustment (Step 10) ✅
- `stock_adjustments`: reason-coded corrections (DAMAGE/LOSS/FOUND/CORRECTION/
  RETURN/OTHER). The movement carries the arithmetic, this table carries *why*.
- `stock_counts` / `stock_count_lines`: a session freezes the current balance
  into its lines, so a later receipt cannot rewrite what the counter measured
  against. `variance` is a generated column.
- Blind counting (spec §40): while the session is open, `stock_count_detail`
  withholds the system quantity and the variance, so the counter cannot anchor
  on them. Both appear once the count is completed. `stock_count_lines` has RLS
  on with **no** read policy, so the masking cannot be bypassed by reading the
  table directly — the RPC is the only way in.
- `complete_stock_count` posts one COUNT movement per non-zero variance and
  leaves uncounted lines alone: not counting something is not the same as
  counting it as zero.
- Everything posts through `apply_stock_movement`, so before + quantity = after
  still holds and each correction lands in the audit log.
- Edge function `stock-ops` (adjustments + count sessions), service role only.
- Works with or without locations, since both are per-warehouse.
- Flutter client `features/stock_ops`: an adjustment screen (direction toggle +
  magnitude + reason chips — a single signed field invites a missing minus, and
  a missing minus doubles stock) and the count list/detail pair. The detail
  screen honours `hide_system`: while a blind session is open it prints
  「確定まで非表示」 instead of a number, and the confirm dialog spells out how
  many uncounted lines will be left alone.
- The home menu's 在庫調整 and 棚卸 now open these Supabase screens. The older
  `features/stock_adjustment` and `features/stock_count` modules stay in the
  tree unreferenced: they are InventorOS clients and belong to the Connector
  work (0022+), not to this step.
- A write needs one warehouse. `writeWarehouseIdProvider` resolves the active
  one, falls back to the sole warehouse when there is exactly one, and returns
  null otherwise — the UI then asks rather than guessing a building.

### 0018 — Picking (Step 7) ✅ · Packing/Shipping (Steps 8–9) unchanged
- `pick_lists`/`pick_tasks`: opening a list snapshots the shipment plan's lines
  into tasks; recording a pick never round-trips through the order, so a short
  or over pick is its own status (`SHORT`/`OVER`, a generated `variance`
  column) rather than being corrected to plan (spec §10).
- Completing a list refuses while any task is untouched — not picking a line
  is not the same as picking it as zero (spec §40) — then moves the shipment
  plan to `packing`, which is exactly the status the existing carton-splitting
  UI already understands. A plan that skips picking entirely (the pre-existing
  flow) still ships fine; picking is additive, not a new gate.
- `bin_id` on a task is accepted only where the warehouse actually uses
  locations (0016) and the bin belongs to it — picking works with or without
  locations, same as the rest of the ledger.
- `ship_plan`/`cancel_shipment` are rewritten to prefer a completed pick
  list's picked quantities over the order lines, and `cancel_shipment` now
  reverses the ledger's own net (`shipped_net`, reading `stock_movements`)
  instead of recomputing from the order lines — so a plan whose lines changed
  after shipping still reverses the exact amount that actually left.
- `stock_availability`: on-hand minus everything reserved by an *open* pick
  list, so a picker's promise reflects what has not already been claimed.
- Edge function `picking` (lists, tasks, availability), service role only.
  `stock_ops`-style grant discipline: every mutating RPC is revoked from
  PUBLIC/anon/authenticated and granted only to service_role (Postgres grants
  EXECUTE to PUBLIC by default, so this has to be explicit every time).
- Flutter client `features/picking_ops`: a pick-list index (start one by
  choosing an open shipment) and a detail screen — each task shows
  planned/picked/variance, tapping one opens quantity + (when the warehouse
  uses locations) a bin dropdown, and the sticky complete action explains a
  pending-task refusal instead of letting the tap silently fail. The home
  menu's ピッキング now opens this instead of the old sales-order checklist
  (`features/picking`, which had no backend of its own — it just filtered
  sales orders client-side with nothing persisted). That module stays in the
  tree unreferenced, same treatment as 0017's stock_adjustment/stock_count.
- Packing and shipping themselves are untouched: cartons, JAN print, 送り状
  and the sender profile still work exactly as before. Packing UI is Step 8
  and shipping-detail polish is Step 9; both are already served by the
  existing shipment screens, so nothing new was required there for this pass.

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
