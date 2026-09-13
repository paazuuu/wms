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

> Status: **0010–0033 applied.** Step 13 (seed/demo) deliberately skipped —
> see below.

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

### 0019 — Inter-warehouse transfer (Step 11) ✅
- `transfer_orders`/`transfer_order_lines`, following the spec's state
  machine verbatim: DRAFT → PENDING_APPROVAL → APPROVED → PICKING →
  IN_TRANSIT → RECEIVING → COMPLETED, with REJECTED off PENDING_APPROVAL and
  CANCELLED off anything before stock has actually left (DRAFT/
  PENDING_APPROVAL/APPROVED/PICKING).
- Picking a line and receiving one both use the nullable-quantity +
  generated-variance shape already established by pick_tasks (0018),
  inspection items (0015) and count lines (0017): a short pick or a transit
  loss is its own recorded number, never silently corrected to plan
  (spec §10). `receive_variance` catches transit loss specifically.
- Stock moves exactly twice: `TRANSFER_OUT` at the source when picking
  completes, `TRANSFER_IN` at the destination when receiving completes —
  both movement types were already anticipated in `stock_movements`' check
  constraint back in 0013.
- Self-approval is refused once both requester and approver are known
  (spec §16 "自己承認禁止"): `requested_by`/`approved_by` are captured from
  `auth.uid()` inside the RPCs, never taken as a parameter. Inactive today —
  same transitional gate as 0012's `has_permission`, since the app still has
  no sign-in — and starts enforcing the moment auth ships.
- Edge function `transfers`, service role only, same grant discipline as
  every ledger-touching function before it (PUBLIC's default EXECUTE grant
  revoked, service_role only).
- Verified live via an aborted transaction: created a throwaway second
  warehouse and a transfer, refused a same-warehouse transfer and an
  out-of-order pick, ran it through a **short pick** (30 requested → 27
  picked) and a **transit loss** (27 shipped → 25 received) to COMPLETED,
  confirmed the source/destination stock levels matched exactly, then let
  the deliberate exception roll all of it back — nothing persisted.
- Flutter client `features/transfers`: a list (create by choosing source +
  destination + line items) and a detail screen that drives the state
  machine one step at a time, with the primary action changing per status
  and a cancel/reject action alongside it while applicable. Completing
  picking or receiving explains a not-all-lines-touched refusal instead of
  letting the tap fail silently, matching 0018's pick-list detail screen.
  Home menu gets a new 倉庫間移動 entry (`field_operations` group).

### 0020 — Audit trail surfacing (Step 12) ✅
- The stock ledger already answered "why did this JAN's quantity change"
  (`stock_ledger`, since 0013/0014 — callable with `jan_code=null` for a
  whole warehouse). What was missing was "who did what" beyond stock:
  approvals, rejections, cancellations, count/inspection completions — all
  already written to `audit_log` by `log_audit` since 0012, nothing ever
  read it back.
- `audit_log` has RLS restricted to `authenticated` only (0012), which the
  still-login-free app never satisfies as `anon` — direct REST reads return
  nothing. `audit_log_query` and `audit_event_types` are SECURITY DEFINER
  RPCs that read through that gate deliberately, the same pattern
  `stock_count_lines`' masking already established: RLS stays closed, the
  RPC is the only way in. Granted broadly (anon/authenticated/service_role),
  same visibility posture as `stock_ledger` — this is a read surface, not a
  mutation.
- Edge function `audit-log`: the query plus a distinct-event-types endpoint,
  so a filter chip row never offers a choice nothing has actually logged.
- CSV export (the other half of the "stock alerts + CSV" workstream picked
  at the start of this pass, not yet delivered): `core/export/csv_export.dart`
  builds an RFC 4180 CSV (quotes only where needed, doubles embedded quotes,
  UTF-8 BOM so Excel on Windows doesn't mis-guess Japanese text) and hands it
  to `file_picker`'s `saveFile` — already a dependency for plan import, so no
  new native permissions. Wired into three places: the new Audit Log screen,
  the per-JAN Stock Ledger screen, and the dashboard's low-stock watch card.
- Flutter client `features/audit`: a list with event-type filter chips and a
  CSV export action. New 監査ログ entry on the home menu (`management` group).

### Step 13 (seed / demo) — deliberately skipped
- Populating "Demo Trading Co." (神戸/大阪 warehouses, demo users, POs/SOs,
  inspections, a sample transfer) means writing fictitious company/product/
  order records into this **live** Supabase project — the one holding the
  operator's real delivery plans and stock. Asked explicitly; the answer was
  to skip it rather than mix demo rows into production data. If a real demo
  is wanted later, it belongs in a separate project (or branch), not here —
  the migrations up to this point apply cleanly to a fresh project with no
  seed step required.

### 0021 — Dashboard task counts (Step 14, partial) ✅
- §23's admin dashboard sketch lists six "today" counts — 入荷予定・検品待ち・
  棚入れ待ち・ピッキング・梱包待ち・出荷待ち — but `dashboard_metrics` had
  never been extended as each flow landed, so inspection/picking/transfer/
  count activity was invisible on the dashboard even though the backends
  existed. Added the missing counts as more keys on the same jsonb response
  (`pending_inspection_count`, `open_picking_count`, `packing_wait_count`,
  `shipping_wait_count`, `open_count_count`, `open_transfer_count`) — no
  signature change, so none of the overload-ambiguity risk 0011/0016 hit.
- Flutter: `TodayTasksRow` — the §24 mobile task-first strip
  ("📥入荷12 📦棚入れ8 🛒ピッキング23…") — now sits above the KPI section on
  the dashboard, each tile a live count that opens its feature. Shown even at
  zero, so "nothing pending" is a visible state rather than an absent one.
- The rest of Step 14 (a management-surface pass: global search, filterable
  tables with a detail drawer, activity timelines) is unstarted — this pass
  only closed the "dashboard doesn't know about half the app" gap.

### 0022 — Global search (Step 14, continued) ✅
- §23's "Global search over items/bins/POs/SOs/customers" — of those, only
  items (stock_levels), inbound plans (delivery_plans, this app's stand-in
  for a PO) and outbound plans (shipment_plans, its SO stand-in) actually
  live in Supabase; suppliers/customers/PO/SO themselves are still
  InventorOS records (a future Connector) and aren't searchable from here.
  Picking and transfer are included too, since both now have their own
  numbers worth finding directly.
- `global_search(p_query, p_warehouse_id, p_limit)`: one UNION ALL across
  stock/delivery/shipment/pick_list/transfer, each capped at `p_limit`
  independently so one category can't crowd out the others. Read-only,
  called directly over PostgREST like `dashboard_metrics`/`stock_ledger` —
  no edge function needed for a read anon is already granted.
- Verified live (read-only call, real data): searching "0901" correctly
  found the matching delivery plan.
- Flutter: `features/search` — a full-screen search reachable from a new
  icon in the top bar, kept deliberately separate from the top bar's
  existing scan box (that field is tuned for one fast job, JAN → Product
  Lookup, and mixing in general search would slow it down). Each result
  opens the real detail screen for its kind (ledger / reconciliation /
  shipment / pick list / transfer detail) rather than a generic viewer.

### 0023 — Per-document activity timeline (Step 14, continued) ✅
- §40: "state machines... are surfaced so an operator sees where a job is."
  `audit_log_query` (0020) could filter by entity_type/event_type but had no
  entity_id filter, so nothing could show "everything that happened to
  *this* transfer" on the transfer's own screen — only the company-wide
  Audit Log list existed.
- `audit_log_for_entity(p_entity_type, p_entity_id, p_limit)`: a separate
  function rather than adding a parameter to the already-shipped
  `audit_log_query` — that RPC is called from the Audit Log screen and
  adding an unrelated filter to it wasn't worth the signature risk for a
  different use case. Read-only, called directly over PostgREST.
- Verified live (aborted transaction): logged three entries across two
  entity ids, confirmed the filtered read returned only the two that
  actually belonged to the entity asked for.
- Flutter: `EntityAuditTimeline`, a compact "what happened to this record"
  card — embedded at the bottom of Transfer Detail and Pick List Detail's
  line list. Renders nothing while loading or on a record with no history,
  so it never displaces the screen's primary content.
- Caught during testing, not in the review: the timeline's connector line
  used `Expanded` inside a `Column` with no bounded height, which crashes
  on real layout (`RenderFlex children have non-zero flex but incoming
  height constraints are unbounded`) — wrapping the row in `IntrinsicHeight`
  fixed it. The widget test that exercises real data is what caught this;
  `flutter analyze` had nothing to say about it.

### 0024 — Real sign-in: Supabase Auth replaces InventorOS login ✅
- The login screen actually pointed at a dead InventorOS (Laravel Sanctum)
  backend the whole time — a separate identity system that never populated
  `auth.uid()`, so every RBAC/self-approval check built since 0010 (`has_permission`,
  `assign_user_role`, etc.) stayed in its "transitional gate" (`auth.uid() is
  null` → allow everything) no matter who was "logged in" in the app. Confirmed
  with the user that login had never really worked, and that Supabase Auth
  should replace it outright rather than run alongside it.
- `bootstrap_first_admin()`: SECURITY DEFINER RPC, solves the chicken-and-egg
  problem of "the first user needs a role but assigning roles requires an
  existing admin" — it assigns `system_admin` to `auth.uid()` exactly once
  (`if not exists (select 1 from public.user_roles)`), a no-op for every sign-in
  after the first. `assign_user_role` / `revoke_user_role` (both gated on
  `user.manage`) and `my_roles()` (the caller's own roles) round out the surface
  an admin needs to manage teammates after their first sign-in. Grants verified
  live via `has_function_privilege`: `anon` denied on all four, `authenticated`
  allowed.
- No self-service sign-up (asked explicitly — small internal team, the admin
  creates each account by hand in the Supabase dashboard).
- Flutter: `SupabaseSessionStorage` (secure-storage-backed access/refresh/expiry),
  `SupabaseAuthInterceptor` + `SupabaseTokenRefresher` attached to every
  Supabase-facing Dio client (`deliveryDioProvider`, `restDioProvider`, the new
  `authDioProvider`) — one shared refresher so a near-expiry token is refreshed
  once, not once per client racing the same (rotatable) refresh token.
  `AuthRepository`/`AuthUser` rewritten against GoTrue (`id` is now the real
  `uuid` string `auth.uid()` resolves to, not an InventorOS integer). Removed
  the `kDebugMode` "skip login" shortcut on the login screen now that signing
  in actually works.
- Caught during implementation, not in review: the real keychain/keystore
  plugin has no test-harness backend, so any screen test that reached a
  Supabase Dio client through the new interceptor would hang forever on the
  session read. Fixed by extracting `SecureKeyValueStore` (an interface
  `SupabaseSessionStorage` depends on instead of `FlutterSecureStorage`
  directly) and giving the test harness's `pumpApp`/`pumpAppWith` a default
  in-memory fake — also added a bounded timeout around every real read/write/
  clear so a genuinely unreachable keyring degrades to "signed out" instead of
  hanging a real device.
- Not yet built: an in-app screen for `assign_user_role`/`revoke_user_role` —
  an admin manages teammates' roles via the RPCs directly (e.g. through the
  Supabase dashboard's SQL editor) until that lands.

### 0025 — Admin: list users with their roles (Step 3, completing 0024) ✅
- 0024 gave an admin `assign_user_role`/`revoke_user_role` but nothing to see
  *who* to assign roles to: `app_users` and `user_roles` both carry a single
  RLS policy ("read own row only"), so even an admin querying them directly
  saw just themselves. `list_app_users()`: SECURITY DEFINER, same
  `user.manage` gate as the writes, returns every user who has ever signed
  in (has an `app_users` row) with their current roles as a nested jsonb
  array. Grants verified live: `anon` denied, `authenticated` allowed.
- Flutter: `features/admin` — `UserManagementScreen`, reachable from the
  Management group. Lists users, an "add role" bottom sheet excludes roles
  already held, removing a role asks for confirmation first. No client-side
  admin check gates the screen itself — consistent with how every other
  feature in this app works (the server's `has_permission` call is the real
  boundary; a non-admin just sees the RPC's own permission error here,
  the same way an unpermitted action anywhere else in the app surfaces).
- 6 widget tests (roster render, no-roles state, empty state, permission-
  denied state, add role, remove role). Caught while writing the "remove
  role" test, not in review: Material 3's default `InputChip` delete
  affordance renders `Icons.clear`, not the pre-M3 `Icons.cancel` — found by
  dumping the screen's actual `Icon` widgets rather than guessing.

### 0026/0027 — AI result store + provider abstraction (Steps 15–16) ✅
- docs/ai_architecture.md §1: AI results never reach WMS data directly — they
  land in a separate store with a confidence and a PENDING_REVIEW state until
  a human acts. Before this, the OCR edge function called Gemini and handed
  the result straight to the client with no record kept of what was asked,
  what came back, or whether it was ever reviewed.
- `ai_analysis` table (id, company/warehouse/delivery_plan/inspection scoping,
  provider, model, task_type, input_hash, output_json, confidence, status
  `PENDING_REVIEW|CONFIRMED|REJECTED`, reviewed_by/at). `product_id`/
  `attachment_id` are plain nullable columns, not FKs — neither table exists
  yet; shaped to fit them later rather than redesigning then. RLS: readable
  only to `ai.review` holders; every write goes through a function, never a
  client insert.
- `find_ai_analysis_reuse`/`record_ai_analysis` (service_role-only — called
  by the OCR edge function, which holds that key server-side) give idempotent
  reuse: the same delivery-note photo resubmitted (a retry, a second crop)
  skips a second Gemini call. `confirm_ai_analysis`/`reject_ai_analysis`
  (`ai.review`-gated) round out the store even though no screen calls them
  yet — spec §31's candidate-review UI is separate, larger future work.
  0027 fixed `record_ai_analysis` to default `company_id` to the single
  seeded company when the caller (today: always) has no company context.
- Verified live (aborted transaction): a fresh hash misses reuse, records a
  row, then the same hash hits reuse and returns the recorded output —
  confirming the idempotency path end-to-end.
- `supabase/functions/ocr-delivery-note`: refactored behind an `AIProvider`
  interface (spec §27) — `GeminiProvider` is the only implementation
  (`qwen` stays a reserved, not-yet-implemented slot, as before); the
  handler no longer talks to Gemini's REST shape directly. Every call now
  hashes the image, checks for reuse, and records the result — the response
  shape is unchanged (`{ data: { provider, lines } }` plus two new additive
  fields, `analysis_id`/`reused`, that the existing Flutter parser already
  ignores), so no mobile client change was needed and today's header/line
  extraction behavior is preserved exactly, per this step's own scope note.

### 0028 — Connector/adapter skeleton (Step 17) ✅
- architecture_target.md §4: external systems (Shopify, carriers, freee,
  InventorOS…) belong behind adapters, never embedded in core logic. Asked
  for explicitly as a **skeleton only** — no adapter talks to an external
  system yet.
- `connectors` (registry: code, name, kind, config, enabled) and
  `connector_runs` (per-sync history: direction, status, summary, error) —
  the same registry-plus-run-log shape `ai_analysis` already established for
  AI calls. RLS: readable only to a new `connector.manage` permission (22nd
  permission, company_admin/system_admin only — same restriction as
  `user.manage`). `list_connectors()`/`set_connector_enabled()` are the only
  writes; both gated and audit-logged.
- Seeded one row: `inventoros` (kind `wms`), registered and disabled, config
  noting it isn't currently reachable and has no adapter — literally the
  position architecture_target.md describes for it ("can later become one
  Connector among others, not the core"), not a working sync.
- Verified live: grants (`anon` denied, `authenticated` allowed),
  `list_connectors()` returns the seeded row with `last_run: null`.
- Flutter: `features/connectors` — a read-only-plus-toggle list screen
  (Management group). Each card states plainly that no adapter is
  implemented yet, so enabling a connector here is understood as registering
  intent, never mistaken for triggering a sync.
- Also removed while investigating this: `features/picking` (application +
  presentation), a fully orphaned InventorOS-era duplicate of `picking_ops`
  with zero references anywhere in the app — dead code, not part of this
  step's scope but found and cleaned up alongside it.

### Post-0028 — InventorOS removed entirely (no new migration; client-only)
- Investigating Step 17 surfaced that InventorOS was never actually
  reachable in this deployment (`apiBaseUrl` defaults to unreachable
  `http://localhost/api/v1`) and nobody runs it — confirmed with the user,
  who decided not to stand it up and to remove the dependency rather than
  leave broken menu entries in the app.
- Deleted entirely: 11 InventorOS-routed feature folders (inspection,
  locations, products, purchase_orders, receiving, reports, sales_orders,
  stock_adjustment, stock_count, suppliers, tracking, warehouses,
  work_orders — `stock_adjustment`/`stock_count` were already fully
  orphaned duplicates of the Supabase `stock_ops` screens, unreachable from
  any menu) and their tests, plus the offline-mutation-queue subsystem
  (`core/offline/*`) — it existed solely to retry the old InventorOS
  inspection screen's mutations and had no other consumer.
- Preserved: `barcode_scan_screen.dart` (a plain camera-scanner widget with
  no backend coupling, still used by the home screen's camera-scan button)
  moved to `core/scan/`.
- Fixed two call sites the deletions broke that weren't reachable only
  through the feature menu: the home screen's top-bar scan box routed any
  scanned JAN straight to the deleted product-lookup screen — repointed to
  `StockLedgerScreen` (Supabase, already exists) since this app has no
  product-master table to look up against. The dashboard's "ready to scan"
  hero card opened the same deleted screen — repointed to
  `GlobalSearchScreen`.
- Removed now-unused dependencies (`drift`, `drift_flutter`, `sqlite3`,
  `sqlite3_flutter_libs`, `path_provider`, `path`, `connectivity_plus`,
  `build_runner`, `drift_dev`, `mocktail`) and 241 orphaned localization
  keys (computed by diffing every `l10n.*` key actually referenced in code
  against every key defined in the ARB files, not by guessing which ones
  belonged to the deleted screens).
- `flutter analyze`: clean. `flutter test`: 134/134 passing (down from 226 —
  the removed screens' own tests went with them).

### 0029 — Per-user warehouse scope management (spec §22) ✅
- `can_access_warehouse()` (0012) has checked `user_warehouses` since real
  sign-in went live, but nothing ever wrote to that table — no admin could
  actually restrict a non-admin user to specific warehouses.
- `assign_user_warehouse`/`revoke_user_warehouse`, same `user.manage` gate
  and audit logging as `assign_user_role`/`revoke_user_role`. `list_app_users`
  extended (additively — a new jsonb key, not a signature change) to include
  each user's `warehouse_ids`.
- Verified live (aborted transaction): assigned a warehouse to a fresh test
  user, confirmed `list_app_users()` returned it in `warehouse_ids`.
- Flutter: `UserManagementScreen` gained a warehouse-access section per user
  card (add via picker, remove via chip + confirm), reusing the same
  `warehouseOverviewProvider` the top-bar picker already uses. 4 new widget
  tests.
- `flutter analyze`: clean. `flutter test`: 179/179 passing.

### 0030 — AI human-review screen (spec §31, completing 0026) ✅
- `confirm_ai_analysis`/`reject_ai_analysis` (0026) let an `ai.review` holder
  act on one result, but nothing let them see which results were waiting —
  same gap pattern as 0025/0029 for users, this time for AI results.
- `list_ai_analysis(p_status, p_limit)`: `ai.review`-gated, defaults to
  `PENDING_REVIEW`, newest first.
- Verified live (aborted transaction): recorded an analysis, listed it as
  pending, confirmed it, and confirmed the status flipped to CONFIRMED.
- Flutter: `features/ai_review` — a list screen showing each result's
  provider/model/extracted lines with confirm/reject actions (reject prompts
  for an optional reason). A flat confirm/reject per result, not spec §5's
  per-field `[確定][要確認][NG]` UI — that needs candidate-level structure
  nothing produces yet, since OCR is still the only task type. 4 new widget
  tests.
- `flutter analyze`: clean. `flutter test`: 183/183 passing.

### 0031 — Image/attachment storage (spec §32) ✅
- Nothing in this app had ever stored a file: `storage.buckets` was empty in
  the live project, and the OCR flow only ever sends image bytes transiently
  to an edge function. First real attachment capability.
- A private `inspection-attachments` Storage bucket; a polymorphic
  `attachments` table (`entity_type`/`entity_id`, not an FK — matches
  `domain_model.md`'s own "attachments (→ any)" reference, so other entities
  can attach files later without a redesign) with RLS (read gated on
  `inspection.view`, no insert/update/delete policy — every write goes
  through `record_attachment`); `record_attachment(p_entity_type, p_entity_id,
  p_storage_path, p_content_type)`, gated on `inspection.confirm`, audit-logs
  `attachment.uploaded`; two `storage.objects` RLS policies (insert gated on
  `inspection.confirm`, select on `inspection.view`) scoped to the bucket.
- Verified live: `has_function_privilege` confirmed `anon`/`public` refused,
  `authenticated` allowed; an aborted transaction called `record_attachment`,
  confirmed the row's `entity_type`/`entity_id`/`storage_path`/`content_type`/
  `company_id`, then rolled back (0 leftover rows).
- Flutter: `features/qc` gained an `Attachment` domain model, an
  `AttachmentRepository` (upload bytes straight to Storage via a new
  `storageDioProvider`, then `record_attachment` via `restDioProvider`; list
  via a PostgREST filter; a signed URL per file since the bucket is private).
  `InspectionDetailScreen` gained a photo strip: add via camera or gallery
  while the inspection is open, thumbnails render off a time-limited signed
  URL. 3 new repository tests (`FakeHttpClientAdapter`-based, covering list/
  upload/signedUrl) plus a `FakeAttachmentRepository` added to the shared
  harness so no unrelated screen test reaches a real Storage/PostgREST call.
- `flutter analyze`: clean. `flutter test`: 186/186 passing.

### 0032 — Product master (spec §19, checklist item 5) ✅
- No `products` table had ever existed: every JAN is a bare text column
  repeated across `stock_levels`/`stock_movements`/`bin_stock`/
  `inspection_items`, each with its own denormalized `product_name`.
  Deliberately narrow master data (name, category, price — the JAN itself is
  the barcode already used everywhere) keyed by `jan_code`, not a new
  `product_id` foreign key threaded through the existing stock tables — a
  much larger, riskier migration for a want that's really "look up and price
  a JAN".
- `products` (RLS: read on `product.view`, no direct insert/update/delete —
  writes only via the RPCs below); two new permissions, `product.view`
  (mirrors `inventory.view`'s role set) and `product.manage` (mirrors
  `inventory.adjust`'s); `list_products(p_search, p_status)`,
  `create_product`, `update_product`, `set_product_status` (soft
  activate/deactivate, matching "inactivate, never hard-delete").
- Verified live: grants (`anon`/`public` refused, `authenticated` allowed)
  for all four RPCs; an aborted transaction created a product, listed it by
  search, updated it, deactivated it, and confirmed a duplicate `jan_code`
  is rejected — then rolled back (0 leftover rows).
- Flutter: `features/product` — `Product` domain model, `ProductRepository`,
  a `ProductListScreen` (search, show/hide inactive, add/edit via a bottom
  sheet, tap the status pill to activate/deactivate) added to the home menu.
  4 screen tests + 3 repository tests (`FakeHttpClientAdapter`-based) plus a
  `FakeProductRepository` added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 193/193 passing.

### 0033 — Purchase orders (checklist item 6) ✅
- "Purchase orders" were removed with InventorOS and never rebuilt.
  `delivery_plans` is a related but distinct concept — an already-shipped
  delivery used for QC reconciliation; a purchase order is the earlier-stage
  document, what was ordered before it ships. Deliberately self-contained:
  draft → submit → approve/reject → cancel/complete, never moves stock,
  not wired into delivery_plans/reconciliation — "complete" is a bookkeeping
  close, not a receiving event.
- `purchase_orders`/`purchase_order_lines` (RLS: read on `purchase_order.view`,
  no direct writes); three new permissions (`purchase_order.view`/`.manage`/
  `.approve`); `create_purchase_order` (order + lines in one call, like
  `create_transfer_order`), `submit_purchase_order`, `approve_purchase_order`
  (self-approval refused once both requester and approver are known — same
  guard as `approve_transfer_order`), `reject_purchase_order`,
  `cancel_purchase_order`, `complete_purchase_order`, `purchase_order_detail`,
  `purchase_order_index`. Grants go directly to `authenticated` with
  `has_permission()` checks inside — the pattern every RPC since 0024 uses,
  not 0019's now-superseded service_role-only grants.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 8
  RPCs; two aborted transactions — one drove a full create → list → detail →
  submit → (re-submit refused) → approve → complete lifecycle, the other
  covered reject and cancel-from-draft — both rolled back (0 leftover rows).
- Flutter: `features/purchasing` — `PurchaseOrder`/`PurchaseOrderLine` domain
  models, `PurchaseOrderRepository`, a list screen (create via a bottom sheet
  with dynamic lines, mirroring `TransferListScreen`'s shape) and a detail
  screen driving the state machine one step at a time, added to the home
  menu. 4 screen tests + 3 repository tests plus a `FakePurchaseOrderRepository`
  added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 200/200 passing.

## Rollout discipline

- One concern per migration; each reversible in intent (inactivate, not destroy).
- After each: `flutter analyze` clean, `flutter test` green, and a DB smoke check
  via the Supabase RPC. Commit per step with a clear message.
