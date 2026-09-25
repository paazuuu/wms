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

> Status: **0010–0042 applied.** Step 13 (seed/demo) deliberately skipped —
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

### 0034 — Sales orders (checklist item 7) ✅
- The outbound counterpart to 0033. `shipment_plans` is a related but
  distinct concept — an already-committed shipment feeding picking/packing/
  shipping; a sales order is the earlier-stage document, what a customer
  ordered before fulfillment starts. Same self-contained shape as purchase
  orders: draft → submit → approve/reject → cancel/complete, never moves
  stock, not wired into shipment_plans/picking.
- `sales_orders`/`sales_order_lines` (RLS: read on `sales_order.view`, no
  direct writes); three new permissions (`sales_order.view`/`.manage`/
  `.approve`); `create_sales_order`, `submit_sales_order`,
  `approve_sales_order` (self-approval refused, same guard as
  `approve_purchase_order`), `reject_sales_order`, `cancel_sales_order`,
  `complete_sales_order`, `sales_order_detail`, `sales_order_index`.
  `customer_id` reuses `delivery_suppliers` rather than a new table —
  `shipment_plans.party_id` already references it as a generic trading-
  partner master for the outbound side.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 8
  RPCs; an aborted transaction drove a full create → list → detail → submit
  → (re-submit refused) → approve → complete lifecycle plus a second
  order's reject path and a cancel-after-complete refusal — rolled back
  (0 leftover rows in both tables).
- Flutter: `features/sales` — mirrors `features/purchasing`'s shape exactly
  (`SalesOrder`/`SalesOrderLine` domain models, `SalesOrderRepository`, a
  list screen with a create bottom sheet, a detail screen driving the state
  machine), added to the home menu. 4 screen tests + 3 repository tests
  plus a `FakeSalesOrderRepository` added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 207/207 passing.

### 0035 — Supplier/customer CRM (checklist item 8) ✅
- "Full supplier management" and "customer management" were two separate
  checklist gaps, but this project already has one table serving both
  roles: `delivery_suppliers` is referenced by `delivery_plans.supplier_id`
  (inbound) *and* `shipment_plans.party_id` (outbound) — a generic trading-
  partner reference in practice. domain_model.md §2 already called for
  reconciling it into a general supplier master while keeping delivery
  references working — this does exactly that, additively (new columns
  only), instead of a second `customers` table forking the two FKs apart.
- Added columns: `kind` (supplier/customer/both — a company can be either),
  `contact_name`, `phone`, `email`, `address`, `payment_terms`, `notes`,
  `status`, `updated_at`. Two new permissions (`partner.view`/`.manage`);
  `list_trading_partners` (filters by kind — `both` matches either filter —
  search, status), `create_trading_partner`, `update_trading_partner`,
  `set_trading_partner_status`. The pre-existing `using (true)` read policy
  (0003) is untouched — delivery-note import and shipment lookups keep
  reading unconditionally; the new CRUD surface gates itself inside the
  RPCs instead.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 4
  RPCs; an aborted transaction created a partner, confirmed `kind='both'`
  matches both a supplier-scoped and a customer-scoped list, updated it to
  `kind='customer'` and confirmed a supplier-scoped list no longer finds it,
  then deactivated it — rolled back (0 leftover rows).
- Flutter: `features/partners` — `TradingPartner`/`PartnerKind` domain
  model, `TradingPartnerRepository`, a `TradingPartnerListScreen` (search,
  kind filter chips, add/edit via a form sheet, tap the status pill to
  activate/deactivate) added to the home menu. 3 repository tests + 8
  screen tests plus a `FakeTradingPartnerRepository` added to the shared
  harness.
- `flutter analyze`: clean. `flutter test`: 215/215 passing.

### 0036 — Work orders / kitting / assembly (checklist item 9) ✅
- Unlike purchase/sales orders (0033/0034), which are deliberately external
  documents that never move stock, a work order IS a stock-moving
  operation — the internal counterpart: consume a set of component JANs,
  produce one output JAN, inside one warehouse. Scoped to assembly/kitting
  only (many components → one output); disassembly would reuse this same
  shape and is a natural follow-up.
- Extended `stock_movements`' movement_type check constraint with
  `WORK_ORDER_CONSUME`/`WORK_ORDER_PRODUCE` (additive, same pattern 0019
  used for `TRANSFER_IN`/`TRANSFER_OUT`). `work_orders`/
  `work_order_components` (RLS: read on `work_order.view`, no direct
  writes); two new permissions (`work_order.view`/`.manage`);
  `create_work_order` (order + components in one call), `start_work_order`,
  `cancel_work_order`, `complete_work_order` (the only step that moves
  stock — posts through the existing `apply_stock_movement` for every
  component and the output, same function every other ledger-writing RPC
  already uses), `work_order_detail`, `work_order_index`.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 6
  RPCs; an aborted transaction seeded known stock levels, created →
  started → completed a work order, and confirmed the exact before/after
  on-hand quantities (component −20, output +5) plus the corresponding
  `WORK_ORDER_CONSUME`/`WORK_ORDER_PRODUCE` ledger rows, then confirmed
  starting an already-completed order is refused — rolled back (0 leftover
  rows across orders, components, stock levels and movements).
- Flutter: `features/work_orders` — mirrors `features/purchasing`'s shape
  (`WorkOrder`/`WorkOrderComponent` domain models, `WorkOrderRepository`, a
  list screen with a create bottom sheet, a detail screen driving the
  state machine), added to the home menu. 3 repository tests + 4 screen
  tests plus a `FakeWorkOrderRepository` added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 222/222 passing.

### 0037 — Custom/saved report builder (checklist item 10, final item) ✅
- `report.view` has existed since 0012 (one of the original 22 permissions,
  already granted to company_admin/system_admin/warehouse_manager/viewer)
  but nothing ever implemented it — the actual gap the checklist called
  out, not a missing permission.
- `report_definitions` (RLS: read on `report.view`, no direct writes); one
  new permission (`report.manage`); `run_report(p_source, p_filters,
  p_limit)` — a fixed set of six safe, server-defined sources
  (`stock_movements`, `purchase_orders`, `sales_orders`, `work_orders`,
  `audit_log`, `products`), never arbitrary user SQL, each with a small
  structured filter set read defensively from the jsonb (missing/wrong-
  typed keys are just treated as unset); `save_report_definition`,
  `list_report_definitions`, `delete_report_definition` for the
  "custom/saved" half of the ask.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 4
  RPCs; an aborted transaction seeded one real stock movement and
  confirmed `run_report` finds it with a matching filter and returns an
  empty array (not an error) for a non-matching one, confirmed all six
  sources run without error, confirmed an unknown source is rejected, and
  ran the full saved-definition CRUD cycle — rolled back (0 leftover rows).
- Flutter: `features/reports` — `ReportSource`/`ReportResult`/
  `ReportDefinition` domain models, `ReportRepository`, a
  `ReportBuilderScreen` (source picker, a generic filter panel, a generic
  results `DataTable`, save/load/delete for saved definitions) added to
  the home menu. 3 repository tests + 3 screen tests plus a
  `FakeReportRepository` added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 228/228 passing.

This closes the user's 10-item completion-pass plan (product master →
purchase orders → sales orders → supplier/customer CRM → work orders →
report builder, following image/attachment storage). Remaining gaps are
documented in `feature_checklist.md` §3 and were explicitly deprioritized
earlier in the pass (2FA/webhooks/GraphQL, further AI modules, real
connector adapters) or are new, smaller items surfaced along the way
(returns/RMA, additional report sources).

### 0038 — Put-away queue & confirmation (UI spec §13) ✅
- The gap `feature_checklist.md` had flagged since 0016: locations and a
  `putaway()` RPC existed, but nothing told an operator *what* still needed
  shelving. 0016's `putaway()` is bin→bin, `service_role`-only and does no
  permission check, so it cannot serve the real receiving→shelf flow; 0038
  adds alongside it rather than rewriting it (spec §53 forbids rewriting an
  applied migration).
- `putaway.confirm` has existed since 0012 (one of the original 22
  permissions) with nothing implementing it — the same dormant-permission
  pattern as `report.view` in 0037.
- `putaway_confirmations` (an idempotency ledger, unique on
  `idempotency_key` where not null); `putaway_queue(p_warehouse_id)` —
  **derived**, not a work table: per JAN it is `stock_levels.on_hand` minus
  the sum of that JAN's `bin_stock`, so anything that raises warehouse stock
  (receiving, an adjustment, a transfer-in) appears automatically and
  nothing can drift out of sync. Returns `'[]'` when the warehouse does not
  use locations. `bin_by_code(p_warehouse_id, p_code)` resolves a scanned
  shelf label (case/whitespace-insensitive, returns null for an unknown
  code, includes what the bin currently holds). `confirm_putaway(...)` is
  `putaway.confirm`-gated, replays a known idempotency key instead of
  double-posting, refuses more than is pending, and moves stock only via
  `apply_bin_movement(..., 'PUTAWAY', ...)` — BIN-scoped, so the warehouse
  total is never touched, only *where* the stock sits (§48).
- `dashboard_metrics` gained `putaway_pending_count` / `putaway_pending_units`.
- Verified live: grants (`anon` refused, `authenticated` allowed) for all 3
  RPCs; an 8-part aborted transaction confirmed the queue shows the pending
  quantity with a suggested bin, `bin_by_code` resolves `'  pa-test-a '` and
  returns null for an unknown code, a partial confirm gives the right
  `pending_after`/`bin_on_hand` with the warehouse total unchanged, a
  repeated idempotency key sets `replayed: true` without double-posting,
  over-put-away is refused, finishing the remainder clears the queue entry,
  and the dashboard counters track the queue — rolled back (0 leftover rows).
- Flutter: `features/putaway` — `PutawayTask`/`BinLocation`/`BinStockLine`/
  `PutawayResult` domain models, `PutawayRepository`, a `PutawayQueueScreen`
  (pending quantity big and monospaced, suggested bin, and two distinct
  empty states so "locations are off" never reads as "all done") and a
  `PutawayConfirmSheet` (scan the shelf → see what is already on it →
  confirm how many go in, with the idempotency key generated once per
  resolved bin so a double tap replays). Added to the home menu right after
  受入/検品 and to the today's-tasks strip as 棚入れ待ち. 7 repository tests +
  7 screen tests plus a `FakePutawayRepository` added to the shared harness.
- `flutter analyze`: clean. `flutter test`: 242/242 passing.

### 0039 — Packing: auto carton split + shipping logistics (UI spec §17–§21) ✅
- `pack.complete` has existed since 0012 (warehouse_manager, packer) with
  nothing implementing it — the third dormant permission activated in this
  pass, after `report.view` (0037) and `putaway.confirm` (0038).
- `shipment_plans` gained `weight_kg` / `carrier` / `tracking_number` for
  §21's shipping block; `set_shipment_logistics(...)` writes them and a null
  clears a field, so a mistyped tracking number can be taken back out.
- `autopack_shipment(p_plan_id, p_units_per_carton)` is §18's 箱数自動計算:
  it fills cartons sequentially (a box takes what fits of the current line,
  the next line continues in the same box), moves the order to `packing`,
  and refuses to merge into cartons that already exist — silently re-packing
  a half-packed shipment is the sort of quiet data change §48 warns about.
- Neither RPC moves stock: cartons record *how* the picked quantity is boxed,
  and `ship_plan` (0008/0014) stays the only thing that deducts it.
- Verified live: grants (`anon` refused after an explicit revoke — Supabase's
  default privileges grant execute to `anon` on every new function and
  "revoke from public" does not remove that, so the revoke has to name
  `anon`); an aborted transaction confirmed the spec's own example (237 @ 24
  → 10 boxes, 24 in the first, 21 in the last), status moving to `packing`,
  a mixed-SKU order boxing as [A6][A4+B2][B3], and refusals for a re-pack,
  a zero box size and a negative weight — rolled back, 0 leftover rows.
- Flutter: `LabelTemplate` (§20's `{{variable}}` substitution, framework-free
  and unit-tested) + the 標準箱ラベル; `ShipmentPrinter.cartonLabelHtml` /
  `allCartonLabelsHtml` render §17's per-carton label with the box's own QR
  (`SHP:<no>|BOX:n/total`, so a dock scan works with no network) and a JAN
  barcode; an autopack dialog that shows the resulting box count *before*
  creating anything; a 配送情報 card + edit sheet for weight/carrier/tracking.
  10 label tests + 4 screen tests.
- `flutter analyze`: clean. `flutter test`: 278/278 passing.

### Edge-function changes (no migration)

Two list endpoints gained an optional `warehouse_id` query parameter so the
current-warehouse context reaches Receiving and Shipping (UI spec §4):
`delivery-plans` (now v4) and `shipments` (now v2), both redeployed with
`verify_jwt` unchanged. The parameter is optional and ignored when absent, so
the "all warehouses" scope and any older client keep the previous behaviour.

Verified: the deploys returned ACTIVE with bumped versions, and the predicate
each handler now applies was checked against live data (no filter → 2 plans,
`warehouse_id=1` → 2, an unknown warehouse → 0). An HTTP round-trip against
the function could not be made from this environment — the network policy
denies the project host — so that part is verified by the deployed source and
the SQL predicate, not by calling the endpoint.

### 0040 — Audit trail: resolve the actor's name (UI spec §29) ✅
- `audit_log.actor_user_id` has been a bare uuid since 0012; both read RPCs
  (`audit_log_query` 0020, `audit_log_for_entity` 0023) selected it but
  nothing ever resolved it, so every screen's "who" was really a uuid.
  `app_users` (0012) already mirrors `auth.users`' name/email for exactly
  this — `create or replace` on both functions adds a left join, returning
  `actor_name`/`actor_email` alongside the existing `actor_user_id`. A null
  actor (bootstrap, a cron-driven job) stays null.
- Signatures unchanged, so the existing `anon`/`authenticated`/`service_role`
  grants (this app is still login-free, per 0020's own note) needed no
  change — re-stated in the migration for clarity, not because anything
  actually changed.
- Verified live: grants confirmed unchanged; an aborted transaction seeded
  an `app_users` row and two `audit_log` rows (one with that actor, one with
  none), called both RPCs, and confirmed the actor's row resolves to its
  name while the actor-less row's `actor_name` stays null — rolled back,
  0 leftover rows in either table.
- Flutter: `AuditEntry` gained `actorName`/`actorEmail`/`actorDisplay` (name,
  then email, then null — never a fabricated one for a genuinely actor-less
  entry). `AuditEventLabels` maps all 55 `log_audit(...)` event codes in the
  schema to a human phrase per language, with an unrecognised code falling
  back to a humanized version of the raw string rather than disappearing or
  crashing — a regression test asserts every currently-known code resolves
  to a real phrase, not the fallback. `EntityAuditTimeline` and
  `AuditLogScreen` (headline, filter chips, CSV export) all switched from
  the raw code/uuid to the humanized label/resolved name; the raw code stays
  as a small monospace caption on the full Audit Log screen for anyone
  cross-referencing it against something else.
- `flutter analyze`: clean. `flutter test`: 291 → 300 passing.

### 0041 — Notifications: the one missing dashboard metric (UI spec §30) ✅
- §30's alert row (🔴検品NG／🟠入荷待ち／🟡棚入れ待ち／🔵ピック待ち, click-through
  to the relevant work) needed only one new number: `failed_inspection_count`
  (inspections with `status = 'FAIL'`). The other three already existed —
  `outstanding_plan_count`, `putaway_pending_count`, `open_picking_count` —
  so this migration is `create or replace function dashboard_metrics(...)`
  with one new CTE and one new key in the returned jsonb, otherwise a
  byte-for-byte copy of the live definition (fetched from the database
  before editing, not reconstructed from memory, to guarantee nothing else
  moved).
- Kept separate from `pending_inspection_count` on purpose: FAIL is a
  problem to act on, PENDING is a queue to work through, and folding a
  failure into an ordinary backlog number would hide it.
- Signature unchanged, so the existing grants needed no change — confirmed
  identical before and after (`anon`/`authenticated`/`service_role`, all
  true).
- Verified live: an aborted transaction called `dashboard_metrics` before
  and after inserting one FAIL inspection with no delivery plan / inspector
  (both nullable) — `failed_inspection_count` went 0 → 1 and
  `pending_inspection_count` was unaffected by it. Rolled back, 0 leftover
  rows.
- Flutter: `DashboardMetrics.failedInspectionCount`; `dashboardNotifications()`
  builds §30's list from the metrics already on hand, filtering out any row
  with nothing to report rather than repeating [TodayTasksRow]'s full count
  strip a second time — an all-clear state is shown as an explicit "nothing
  needs attention" line. `DashboardNotificationsPanel` renders it between
  the today's-tasks strip and the KPI section, sharing the same permission-
  filtered `entryById` lookup as every other dashboard shortcut, so a
  notification cannot open a screen its own menu entry would have hidden
  (§37). Titled 通知 rather than reusing the mockup's own "今日の作業" label,
  which the existing task-count strip already carries.
- `flutter analyze`: clean. `flutter test`: 300 → 308 passing.

### Client-only change: permission-aware menu (UI spec §37, no migration)

No schema change — `my_access()` (roles + permissions + warehouse_ids, one
round trip) has existed since 0012 and was already granted to
`anon`/`authenticated`; the client simply never called it, using the
roles-only `my_roles()` in login/`currentUser` instead. Switched the client
to `my_access()`, added `permissions` to `AuthUser`, and gated every
`FeatureEntry` in the catalog on the permission(s) that unlock it (any-of, so
a view/manage pair on the same screen both work). The sidebar, dashboard
feature grid, and the today's-tasks/outstanding shortcuts now hide anything
the signed-in user holds nothing for, and a whole group hides when every
entry in it does — previously every screen was listed for every signed-in
user regardless of role, discoverable as a restriction only via a server
refusal or an RLS-emptied screen.

Verified: `my_access()` still returns the expected shape and grants are
unchanged (checked live — no session context in a SQL-editor call correctly
comes back `authenticated: false` with empty arrays, matching an
unauthenticated caller). A test (`feature_entry_test.dart`) asserts every
catalog entry declares a non-empty `requiredAnyOf`, so a newly added feature
that forgets to gate itself fails the suite rather than silently shipping
unrestricted. This is a UI convenience only: every RPC and RLS policy still
re-checks `has_permission()` itself, unchanged.

Deliberately not done in this pass: surfacing per-warehouse scope
(`user_warehouses`) the same way — RLS already enforces it on every table,
but the warehouse picker still lists every warehouse the company has rather
than just the ones this user is scoped to. No real user has a restricted
`user_warehouses` row yet to make the gap visible, and fixing it properly
means changing the picker's own list query, not gating a menu entry — noted
in `feature_checklist.md` instead of built speculatively.

`flutter analyze`: clean. `flutter test`: 278 → 291 passing.

### Client-only change: confirm dangerous operations (UI spec §36, no migration)

No schema change. Audited every `showDialog` call in the app against the
spec's own list of 8 operations that must ask before acting, plus its other
side ("don't overuse confirmation dialogs" — every non-destructive dialog,
picker, and form sheet was left exactly as it was). 6 of the 8 already had a
real confirmation (出荷確定, 棚卸確定, Transfer完了, POキャンセル, SOキャンセル, and
implicitly the shared `_confirm` helpers behind them); 倉庫削除 doesn't exist
as a feature anywhere in the app, so there's nothing to gate. Two real gaps:

- 在庫調整 (`StockAdjustmentScreen._newAdjustment`) applied the adjustment
  form's draft straight to the ledger on submit. Added a confirm dialog
  between the form and the write, showing the JAN and signed delta and
  stating the change can't be undone.
- 商品無効化 (`ProductListScreen._toggleStatus`) flipped `status` on a single
  tap of the status pill either direction. Added a confirm dialog, but only
  when going active → inactive; reactivating stays a single tap since it
  isn't destructive — matching the spec's "don't overuse" side rather than
  gating both directions symmetrically.

Existing tests for both screens updated to tap through the new dialog; added
a cancel-path test for each (confirming nothing is written when the dialog
is dismissed) and a no-dialog-on-reactivate test for products.

`flutter analyze`: clean. `flutter test`: 308 → 311 passing.

### Client-only change: no more raw RPC text on screen (UI spec §34, no migration)

No schema change. While auditing §33/§34 (empty/loading/error consistency)
found that every screen already routes async loads through the shared
`LoadingView`/`ErrorStateView`, one real gap turned up in what those screens
render: every `has_permission()` guard across the RPC layer raises the exact
same shape, `raise exception 'not permitted: <code> required'`, and that raw
Postgres text was reaching `ErrorStateView` verbatim — exactly the "悪い:
`PostgrestException`" example the spec itself calls out. Not a theoretical
gap either: most `FeatureEntry`s gate their menu on a "view OR manage" pair
(§37), so a view-only user regularly opens a screen whose write action needs
the stronger permission, and the RPC's own check is the first place that
becomes visible — confirmed by an existing test
(`user_management_screen_test.dart`) that had baked in the raw
`not permitted: user.manage required` text as its expected output.

Added `humanizeApiErrorMessage()` (`core/api/api_error_text.dart`): matches
that one consistent RPC error shape and swaps in a localized "この操作を行う
権限がありません。", passing anything else through unchanged rather than
guessing at a translation for messages it doesn't recognise. Wired into
`ErrorStateView` itself (one file) rather than each of the ~30 screens that
use it, so every one of them picked up the fix at once. The test with the
stale expectation was corrected to assert the friendly text instead.

Deliberately not done in this pass: the write-side equivalent, where a
failed action's message reaches a SnackBar via each screen's own local
`_snack(f.message, ...)` — there's no shared helper behind those calls the
way `ErrorStateView` is shared for reads, so covering it means ~20
individual screen edits rather than one. Noted in `feature_checklist.md`
rather than done partially.

`flutter analyze`: clean. `flutter test`: 311 → 317 passing.

### Client-only change: Form UX (UI spec §35, no migration)

No schema change. Audited the spec's 5 Form UX bullets. Two were already
true everywhere (required fields first; nothing complex enough to warrant a
collapsible "advanced" section) and one is a real but non-mechanical gap
left open (post-save transition to the next task — see
`feature_checklist.md` for why it needs a workflow-by-workflow decision
rather than one shared fix). Two were real, fixable gaps:

- Barcode input before manual keying: the product form and stock adjustment
  form both had a plain numeric `TextField` for JAN, unlike every other
  barcode-driven screen in the app. Added a scan icon that pushes the shared
  `BarcodeScanScreen` and fills the field with the result, matching the
  existing `ScanField` + camera-button pattern used elsewhere — hidden on
  the product form once editing (the JAN is fixed after creation).
- Large-number UI for quantity entry: the transfer pick/receive dialog and
  the stock count line dialog both rendered their one number in ordinary
  body text. Both now use `textTheme.displaySmall`, centered — a number
  pad's display, not a line of text. The stock adjustment form's quantity
  field was left alone on purpose: it's one field among several there, not
  a single-purpose dialog, so enlarging it would look inconsistent with the
  rest of that form.

Existing tests for both forms updated/added to assert the scan button's
presence (and its absence once a product's JAN is fixed); no behavioral
test needed for the font-size change itself.

`flutter analyze`: clean. `flutter test`: 317 → 320 passing.

### Edge function fix: enforce permissions in `stock-ops` (UI spec §22/§23, no schema migration)

While auditing §22 (Transfer state visibility — already fine, same
`StatusPill`-per-status pattern used everywhere else in the app) and §23
(stock count), found a real, live security gap while checking §23's
"承認権限を分離する" (separate the approval permission): the `stock-ops` edge
function backing every stock-count and stock-adjustment mutation ran
entirely as service role with no permission check at all — three
`// TODO(auth): require ... for the caller.` comments were left in the code
where the checks should have been. Concretely, before this fix, any
signed-in user — regardless of role or permissions — could start, record,
complete (posting real variance adjustments to the ledger), or cancel any
company's cycle count, and could post arbitrary stock adjustments.

This is architecturally different from the client-only fixes elsewhere in
this file: `stock-ops` predates the app's has_permission()-in-every-RPC
convention and is one of the handful of edge functions (not a PostgREST
RPC) still running purely on the service-role client, which has no user
JWT context at all (`auth.uid()` is null there). Fixed by having the edge
function build a second, per-request client carrying the caller's own
`Authorization` header, calling `has_permission()` under that identity:
`count.perform` now gates start/record/cancel, `count.approve` gates
complete (the one action that actually moves stock), and `inventory.adjust`
gates the adjustment endpoint.

One subtlety caught before deploying: `has_permission()` itself resolves to
`true` when `auth.uid()` is null — by design, for SECURITY DEFINER calls
made from trusted server-side code with no user at all, not for "nobody
sent a valid token." Calling it naively from the edge function would have
reproduced the exact bug being fixed (a missing/garbage Authorization
header would silently pass). The fix calls `client.auth.getUser()` first to
confirm a genuine signed-in user before trusting `has_permission()`'s
answer at all.

Deployed as `stock-ops` v3. Not independently verified via a live HTTP call
— this session's network proxy doesn't reach `*.supabase.co` directly — so
correctness rests on code review (`auth.getUser()` is supabase-js's
documented pattern for this) and on confirming the Flutter client already
attaches a real bearer token to every `stock-ops` request today
(`dio_client.dart`'s interceptor), so no legitimate call breaks.

The resulting `not permitted: <code> required` message is the same shape
already handled by §34's `humanizeApiErrorMessage()`; wired it into the
stock-ops screens' three `_snack(f.message, ...)` call sites (previously
raw), since this fix is what makes that error newly reachable from them.

`flutter analyze`: clean. `flutter test`: 320 → 322 passing.

### Edge function fix: real OCR confidence, not a hardcoded null (UI spec §31, no schema migration)

No schema migration — `ai_analysis.confidence` (numeric) has existed since
0026. Auditing §31 (AI UI) against the spec's mockup — 納品書番号/商品/数量/
信頼度 with [確認して登録]/[修正]/[却下] — and against `ai_architecture.md`'s
own design notes turned up one real, two-layer gap and confirmed several
things already correctly built:

- Already correct: AI never writes WMS data directly. `PlanImportScreen`
  (the actual point an OCR read becomes a committed delivery plan) presents
  every header field as an editable, pre-filled `TextField` before
  `commitPlan()` runs; `AiReviewListScreen`'s confirm/reject only touch the
  `ai_analysis` row's own status, exactly as its header comment already
  documented. The flat confirm/reject (vs. the mockup's per-field
  `[確定][要確認][NG]`) is a deliberate, already-documented scope cut in
  `ai_architecture.md` §8, not something to build now — per-field
  candidate structure doesn't exist yet since OCR is the only task type.
- Real gap: 信頼度 was never shown in `AiReviewListScreen`, and separately,
  `ocr-delivery-note` hardcoded `p_confidence: null` on every recorded
  analysis — Gemini was never asked for a confidence score, so even
  rendering the (already-parsed, already-in-the-domain-model) field would
  have shown nothing for every row that exists. Fixed both ends: extended
  `OCR_SCHEMA` and the prompt to ask Gemini for a 0–1 self-assessment of
  its own read quality alongside the lines, parsed defensively (clamped to
  [0,1], null if the model omits it or returns something non-numeric —
  never fabricated), and threaded through to `record_ai_analysis`'s
  existing `p_confidence` parameter (unchanged signature). Deployed as
  `ocr-delivery-note` v8. `AiReviewListScreen` now renders "信頼度 NN%" per
  result when present, in the error colour under 60%.

Left open at the time, later closed (see 0042 below): `PlanImportScreen`'s
line-item preview was read-only with no documented reason, and 納品書番号 on
the review screen didn't exist. The spec's own "future" list (product-photo
ID, damage detection, auto-registration, put-away suggestions, inventory
analysis) stays unbuilt, matching `ai_architecture.md`'s own "still open"
section — not attempted here either.

`flutter analyze`: clean. `flutter test`: 322 → 324 passing.

### 0042 — `list_ai_analysis` joins delivery_plans (UI spec §31, closing both deferred gaps)

Went back for the two gaps deliberately left open above, at the user's
request ("見送った項目を何とか解決して").

**納品書番号 on the review screen.** Root cause: `ai_analysis.delivery_plan_id`
existed since 0026 but nothing had ever populated it for an
`ocr-delivery-note` call — not a schema gap, a wiring gap. Its only real
caller, `ReconciliationScreen._runOcr`, already had `_plan.id` in scope the
whole time. Threaded it through the whole path: `DeliveryNoteScanner.scan()`
gained an optional `deliveryPlanId` parameter (all four implementations —
remote, fallback, ML Kit native, ML Kit web stub — updated to match, only
the remote one actually uses it), `RemoteDeliveryNoteScanner` sends it as
`plan_id` in the multipart form (a field name the edge function's own doc
comment had anticipated since it was first written), and
`ocr-delivery-note` reads it and passes it to `record_ai_analysis` — a
`create or replace` of the same function, no signature change, deployed as
v9. `list_ai_analysis` (this migration) left-joins `delivery_plans` on that
id and adds `delivery_plan_id`/`delivery_number` to the returned jsonb —
fetched the live definition first, changed only the join and two new keys,
verified live in an aborted transaction (inserted a linked plan +
analysis row, confirmed the joined `delivery_number` came back, rolled
back, 0 leftover rows), confirmed `anon`/`authenticated`/`service_role`
grants unchanged. `AiAnalysisEntry` gained `deliveryNumber`;
`AiReviewListScreen` shows it at the top of the card when present, nothing
when the call was standalone (before any plan existed, say).

**Line items in `PlanImportScreen` were read-only.** Fixed by lifting
`ImportPreview.lines` into mutable state (`_lines`) the moment a read
succeeds, making `_LinesPreview` interactive (tap a row to edit JAN/product/
quantity in a dialog — reusing §35's scan-button and large-number-quantity
patterns — plus a delete icon per row and an "add line" button), and
sending `_lines` instead of the original preview on commit. Also added the
two operations the user's own follow-up explicitly permitted ("分解と結合表記
も可能です"): 分割 (split) halves a line's quantity into a second row with
the same JAN, letting the operator fine-tune either half afterward through
the same edit dialog rather than prompting for an exact split amount up
front; 結合 (merge, surfaced as "同じJANをまとめる") sums every group of
duplicate JANs into one row, shown only when a duplicate actually exists.
`FilePicker`'s platform channel can't be driven from a widget test, so
`PlanImportScreen` gained an injectable `pickFile` parameter — the same
seam `BarcodeScanScreen` already uses for its camera — enabling the first
test file this screen has ever had.

`flutter analyze`: clean. `flutter test`: 324 → 334 passing.

### Edge function audit: the same missing-permission-check gap, across every other edge function (no schema migration)

The `stock-ops` fix earlier in this document was one instance of a
systemic pattern, not an isolated bug: any edge function that predates the
app's has_permission()-in-every-RPC convention runs purely on the
service-role client and could have a mutation with no real permission
check. Audited every function under `supabase/functions` for the same gap
and found it, in two shapes, in seven more:

- `inspections` — POST start, PATCH item, POST complete: zero checks, no
  TODO even acknowledging the gap. Any signed-in user could confirm a QC
  pass/fail on any delivery.
- `picking` — start/record/complete/cancel: one TODO referenced
  `picking.perform`, a permission code that **does not exist** in the live
  `permissions` table; the other three endpoints had zero checks.
- `transfers` — the full 8-endpoint lifecycle (create through
  complete-receiving) had TODOs referencing `transfer.request`, which
  likewise does not exist. Any signed-in user could create, approve/reject,
  pick, or receive any inter-warehouse transfer.
- `delivery-plans` — POST reconcile, POST receipt-cancel: zero checks. Any
  signed-in user could post a receiving reconciliation (which adjusts
  stock) or void one.
- `shipments` — POST ship, POST cancel, and all three carton endpoints:
  zero checks. Any signed-in user could confirm/cancel a shipment
  (deducting/restoring stock) or edit its cartons.
- `warehouses` — POST create, PATCH update: TODOs referencing
  `warehouse.manage` left unimplemented.
- `import-plan` — the shared `commit()` helper behind both the multipart
  one-shot save and the reviewed-JSON commit path: zero checks. Any
  signed-in user could register an inbound delivery or outbound shipment
  plan.

Every TODO-referenced permission code was checked against the live
`permissions` table before use rather than trusted verbatim — that's how
the two nonexistent codes above (`picking.perform`, `transfer.request`)
were caught before they could be baked into a fix that still wouldn't work.

Fixed all seven the same way as `stock-ops`, this time factored into a
shared `supabase/functions/_shared/require_permission.ts` (`callerPermitted()`
builds the per-request client, calls `auth.getUser()` to confirm a genuine
signed-in user, then trusts `has_permission()` under that identity — the
same null-`auth.uid()` footgun from the stock-ops fix applies here too, so
every one of these follows the same "confirm the user first" rule).
Supabase's `deploy_edge_function` bundles each function independently, so
the shared file's content had to be included in every deploy call, not
committed once and assumed shared.

Permission mapping: `inspection.confirm` (inspections); `pick.confirm`
(picking); `transfer.create`/`transfer.approve`/`transfer.receive`
(transfers — `create` covers the whole source/requesting-side lifecycle,
`approve` gates the approve/reject decision, `receive` covers the
destination side); `receiving.confirm` (delivery-plans, and import-plan's
delivery-plan target); `ship.complete`/`pack.complete` (shipments —
`complete` gates ship/cancel, `pack` gates the carton edits leading up to
it; `pack.complete` also gates import-plan's shipment target);
`warehouse.manage` (warehouses). Deployed as `inspections` v2, `picking`
v2, `transfers` v2, `delivery-plans` v5, `shipments` v3, `warehouses` v4,
`import-plan` v6.

Same verification limitation as `stock-ops`: not exercised over a live
HTTP call (this session's network proxy doesn't reach `*.supabase.co`
directly), so correctness rests on code review plus `flutter analyze`/
`flutter test` passing against the client side.

`humanizeApiErrorMessage()` wired into every screen whose action is newly
gated by one of these checks and whose SnackBar previously showed
`f.message` raw: `InspectionDetailScreen`, `PickListDetailScreen`,
`PickListIndexScreen`, `TransferDetailScreen`, `TransferListScreen`,
`ReconciliationScreen`, `ReceiptHistoryScreen`, `ShipmentDetailScreen`,
`CartonEditScreen`, `AddWarehouseScreen`, `PlanImportScreen`. Added one
permission-denied widget test per newly-fixed function, exercising a
representative mutation, following the same `failWith`-on-a-fake-repository
pattern the stock-ops tests already used — extended `test/support/harness.dart`
with a `failWith` field on `FakeInspectionRepository`, `FakePickingRepository`,
`FakeTransferRepository`, `FakeDeliveryRepository`, `FakeShipmentRepository`,
and `FakeWarehouseRepository`.

Found and deliberately not fixed in this round: `audit_log_query`,
`audit_log_for_entity`, and `audit_event_types` (the RPCs behind the
`audit-log` edge function, itself a thin read-only proxy) have no
`has_permission('audit.view')` check in their SQL bodies at all — any
signed-in user can read the full audit trail regardless of that
permission. That's a read-side information-disclosure gap, architecturally
different from everything above (it needs a migration fixing the RPCs, not
an edge-function-level fix), and is flagged here for follow-up rather than
folded into this round.

`flutter analyze`: clean. `flutter test`: 334 → 342 passing.

### Client-only change: §34's write-side SnackBar, the deferred half (no migration)

The original §34 fix above deliberately left one thing undone: a failed
*write* still showed its raw RPC message in a SnackBar, since each screen
builds its own SnackBar locally rather than through a shared widget the way
`ErrorStateView` centralizes reads. That gap became load-bearing the moment
the edge-function audit above turned on real permission checks across seven
more functions — every one of those screens could now surface a genuine
`not permitted: ... required` error where none was reachable before.

Closed it in two passes: the 11 screens whose write action gained a new
permission check in the edge-function audit (done as part of that same
commit), then a final pass across the 13 remaining screens with a write
action anywhere in the app that still showed `f.message` raw — purchase
orders, sales orders, work orders, the report builder, put-away confirm,
the product master, trading partners, user management, AI review, and the
connector registry. Two call shapes needed the fix: the common
`_snack(f.message, ...)` SnackBar, and a `setState(() => _error =
f.message)` inline error rendered via `Text` in a handful of form sheets
(`putaway_confirm_sheet.dart`, and the product/trading-partner add/edit
sheets) — both now go through `humanizeApiErrorMessage()` first. Combined
with the 3 `stock-ops` screens from the earlier fix, that's 27 files total,
every write-side failure path in the app.

Added one permission-denied widget test per call shape rather than per
file — `purchase_order_list_screen_test.dart` for the SnackBar shape,
`product_list_screen_test.dart` for the inline-`_error` shape — since the
wiring is identical everywhere and the humanizer's own logic already has
dedicated unit tests (`api_error_text_test.dart`). `FakePurchaseOrderRepository`
gained a `failWith` field to support it, matching the pattern already used
by the fakes from the edge-function audit.

`flutter analyze`: clean. `flutter test`: 342 → 344 passing.

### 0043 — Enforce audit.view on the audit-log read RPCs (closing the audit-function follow-up)

The edge-function audit above deliberately left one thing open:
`audit_log_query`, `audit_log_for_entity`, and `audit_event_types` (the
RPCs behind the `audit-log` edge function, itself a thin read-only proxy)
had no `has_permission('audit.view')` check in their bodies at all — a
read-side gap, architecturally different from the write-side gaps fixed
there, since these are plain `SECURITY DEFINER` RPCs rather than an edge
function, so the fix belongs in a migration, not `_shared/require_permission.ts`.

Checking the live grants turned up something worse than "any signed-in
user": all three were also granted to `anon`. RLS never runs for these
calls — `SECURITY DEFINER` executes as the function owner, bypassing
`audit_log`'s own `audit.view`-gated policy from 0012 entirely — so an
unauthenticated caller with nothing but the anon key could read the full
audit trail (actor names, emails, every event) today.

Fixed both problems together. Converted all three from `language sql` to
`language plpgsql` (needed for `raise exception`) and added `if not
public.has_permission('audit.view') then raise exception 'not permitted:
audit.view required'; end if;` at the top of each, matching the exact
idiom `list_ai_analysis` (0030) already established for this shape of
check. Then `revoke all ... from public, anon` and re-granted to
`authenticated, service_role` only, matching the grant shape every other
read RPC in this app already uses.

The `anon` revoke isn't redundant with the permission check — it's the
part that actually closes the anon hole. `has_permission()` treats a null
`auth.uid()` as "allow", by design, for trusted server-side calls with no
user context at all (the same rule documented in
`supabase/functions/_shared/require_permission.ts`); an anon-key call also
has a null `auth.uid()`, for the opposite reason (no user ever
authenticated). Adding the check alone would have let anon straight
through unchanged. Revoking the grant is what actually stops it, and
matches how the anon role can't reach `audit_log_query` at all now
regardless of what the function body does.

Verified live end to end: `has_function_privilege` confirms `anon` can no
longer execute any of the three while `authenticated`/`service_role`
still can, and `pg_get_functiondef` confirms the live function bodies
carry the new check. No client change needed — `ErrorStateView` already
routes every read failure through `humanizeApiErrorMessage()` (the §34
fix), which already recognizes this exact `not permitted: ... required`
shape, and the "Audit" menu entry already gates on `audit.view` (§37's
existing menu-permission wiring), so a user without the permission now
sees a menu that was already hidden from them plus, if they somehow
reached the screen directly, the same friendly permission-denied message
every other screen shows.

No client code changed, so no test count change.

### 0044 — Per-user warehouse scope, batch 1: actually enforce it (UI spec §37)

The §37 checklist item asked for one thing ("the warehouse picker still
lists every warehouse the company has, not just the ones this user is
scoped to") on the stated basis that the scope was already "enforced
server-side by RLS on every table." Checking that premise against the live
database rather than the note found it false, and the correction is the
whole point of this migration: **`can_access_warehouse()` (0012) had never
been called from anywhere.** Zero RLS policies reference `user_warehouses`
or `can_access_warehouse` (`pg_policies`), and zero RPCs or edge functions
did either (`pg_get_functiondef` across all 26 functions taking a
`p_warehouse_id`). The table, the helper, the assign/revoke RPCs (0029) and
the admin UI to drive them all existed; nothing consumed them. A user
restricted to one warehouse was not restricted at all.

Two things make this not fixable the obvious ways:

- **RLS is the wrong layer here.** Every one of these tables is read and
  written through `SECURITY DEFINER` RPCs, which run as the function owner
  and bypass RLS entirely — the same structural gap as the audit-log RPCs in
  0043. A policy on `stock_levels` would not fire for `adjust_stock`.
- **A bolt-on guard would not have worked.** Most of these RPCs treat
  `p_warehouse_id IS NULL` as "every warehouse," a deliberate
  all-warehouses view, so `if not can_access_warehouse(p_warehouse_id)`
  leaves a restricted caller free to just omit the filter and get
  everything. Read paths have to fall back to the caller's scoped set.

Added `accessible_warehouse_ids()`: the caller's warehouse ids, or `null`
meaning unrestricted (system_admin/company_admin, or a trusted server-side
caller with no user context — the same null-`auth.uid()` convention
`has_permission()` uses). A non-null array, possibly empty, is a real
restriction. Read paths fall back to this instead of to everything.

Batch 1 targets the choke points rather than all 26 call sites, because
there are only two: **every** warehouse-level stock quantity change in the
app funnels through `apply_stock_movement`, and every bin-level one through
`apply_bin_movement`. One check in each reaches adjustments, counts,
transfers, shipments, receiving and work orders together, because
`SECURITY DEFINER` does not reset `auth.uid()` across nested calls — the
original caller's identity is still what gets checked at the bottom of the
stack. `apply_bin_movement` derives the warehouse from the bin itself rather
than a parameter, so it cannot be bypassed by misdeclaring which warehouse a
bin is in. Added explicit checks to the two entry points that route through
neither (`confirm_putaway`, which only moves stock between unbinned and
binned within one warehouse, and `start_stock_count`), and rewrote
`warehouse_overview()` to filter its list and totals to the caller's scope —
that last one is the RPC the picker reads, so it is what turns the original
ask into a real restriction instead of a client-side cosmetic filter.

Error message is `not permitted: warehouse.scope required`, deliberately
shaped to match the `not permitted: <code> required` pattern every
`has_permission()` guard raises, so §34's existing
`humanizeApiErrorMessage()` already turns it into the friendly
permission-denied text with no client change. `warehouse.scope` is not a
row in `permissions` — it is not an assignable permission, just the same
error shape so the client buckets it correctly.

Grants deliberately untouched (`create or replace function` preserves
them): verified live that `apply_stock_movement`, `apply_bin_movement` and
`start_stock_count` remain service_role-only internal helpers,
`confirm_putaway`/`warehouse_overview` remain authenticated+service_role,
and the new `accessible_warehouse_ids()` is authenticated+service_role, not
anon.

Timing matters here and it is good: `app_users` is **empty** — nobody has
ever signed in — so switching deny-by-default on cannot lock out a live
user. The first sign-in is safe by construction, since
`bootstrap_first_admin()` (0024) makes user #1 `system_admin` and admins
resolve to unrestricted. From user #2 on, a role alone stops being enough:
a non-admin with no `user_warehouses` rows now resolves to zero warehouses
(empty picker; writes refused). That is precisely the semantics
`can_access_warehouse()` was always written to have — it just never ran —
so admins now have to assign warehouses as well as a role, which the
user-management screen already supports.

Still open, deliberately and explicitly rather than quietly: the read-side
list/index RPCs (`pick_list_index`, the three `*_order_index`,
`work_order_index`, `dashboard_metrics`, `global_search`, `stock_ledger`,
`stock_availability`, `bin_by_code`, `bin_stock_overview`, `putaway_queue`,
`default_staging_bin`, `warehouse_uses_locations`), the `create_*_order`
entry points, and the edge functions' own `warehouse_id` filters. Those
leak reads across warehouses rather than permitting writes, which is why
they sort after batch 1. Also noticed and not changed: `warehouse_overview()`
is granted to `anon` (so an anon-key caller reads it unrestricted, since a
null `auth.uid()` resolves to unrestricted) — the same class of stale grant
0043 fixed, but revoking it could break a pre-login screen, so it wants a
look at the sign-in flow rather than a silent revoke.

Verified by aborted transaction before applying, then live afterwards
(function bodies carry the checks; grants unchanged). `flutter analyze`:
clean. `flutter test`: 344 passing, unchanged — no client code changed.

### Client-only change: §35's post-save hand-off, the deferred judgment call (no migration)

The §35 pass left one item open on purpose, and the reason it was left open
turned out to contain the fix. The objection on file was that deciding "the
next task" per save is a workflow-by-workflow judgment, and that
auto-navigating away can be unwanted — an operator may want to re-read what
they just recorded (a short pick, a QC finding) before moving on.

Resolved by not auto-navigating at all: the success SnackBar these screens
already showed now carries a `SnackBarAction` for the next step. The next
task is one tap away, the screen the operator just finished on stays where
it is, and it collapses into one shared pattern instead of three bespoke
navigation decisions. `_snack` on each of the three screens gained an
optional `action` parameter; nothing else about them changed.

The three hand-offs are the ones where the physical work actually continues:

- 検品確定 → 棚入れ (`PutawayQueueScreen`). Goods that just passed QC are
  precisely what put-away draws from.
- ピッキング完了 → 梱包 (`ShipmentDetailScreen`), for *that* pick list's own
  shipment rather than the shipping list — `PickList.shipmentPlanId` is
  already in scope, so the operator lands on the right record.
- 照合完了 → 検品 (`ReceiptHistoryScreen`), since QC is per receipt and that
  screen is where a pass is started. This one captures its `Navigator`
  before the screen pops, because its own context is gone by the time the
  action can be tapped, and is offered on a partial save too — a partial
  reconciliation posts a receipt just the same.

Deliberately given no next step: the purchase/sales/work-order approval
screens, whose state machines are bookkeeping closes that move no stock and
start no physical task (their own header comments say as much), so a
hand-off there would be invented rather than observed. 棚入れ確定 also stays
as it is — it already pops back to the queue, which is where the operator
wants to be when more is waiting.

Three l10n keys added across ja/en/zh (`nextStepPutaway`,
`nextStepPacking`, `nextStepInspection`). Two widget tests assert both
halves of the design: the action is offered, *and* the screen did not
navigate away by itself.

`flutter analyze`: clean. `flutter test`: 344 → 345 passing.

### 0045 / 0046 — Per-user warehouse scope, batches 2 and 3 (UI spec §37)

0044 covered the stock-moving core and the picker's own feed. These finish
the surface it flagged as open.

**0045, the list/index reads.** `pick_list_index`, `purchase_order_index`,
`sales_order_index`, `work_order_index`, `transfer_order_index` and
`putaway_queue`. These leaked *reads* rather than permitting writes — a
user restricted to one warehouse could still list every other warehouse's
picks, orders and transfers.

The fix lives in the WHERE clause, not in a guard, for the reason 0044
documented: all of these treat `p_warehouse_id IS NULL` as "every
warehouse", so validating only an explicitly passed id would leave a
restricted caller free to omit the filter and get everything. The no-filter
case now falls back to `accessible_warehouse_ids()` instead of to
everything; unrestricted callers still get null from that helper and so see
all warehouses exactly as before.

Reads filter rather than raise — an out-of-scope warehouse simply yields
nothing. That keeps every "all warehouses" call working unchanged, and
since 0044 narrowed the picker itself the case can only arise from a
crafted request, where returning nothing beats confirming the record
exists. `transfer_order_index` matches on *either* end of the transfer, so
a user scoped to just the destination still sees what is arriving —
mirroring how 0044 gates the two halves of the lifecycle separately.
`putaway_queue` is the exception that raises: its warehouse is a required
argument, so there is no all-warehouses fallback to repair, and an
out-of-scope request should not be mistaken for "nothing to put away".

**0046, the order-creation writes.** `create_purchase_order`,
`create_sales_order`, `create_work_order`. Each already checked that the
warehouse *exists*; the added `can_access_warehouse()` check asks whether
this caller may use it, placed directly after the existing
`has_permission()` guard so the two authorization questions — may you do
this kind of thing, and may you do it here — read together. None of these
moves stock (completing a work order does, and that already routes through
0044's `apply_stock_movement`), which is why they sorted after the core.

Verified live: all nine functions carry the check, and each still returns
correctly against the current data (`pick_list_index`,
`transfer_order_index`, the three `*_index` order RPCs and
`warehouse_overview` all execute and return the expected shape). Grants
untouched throughout — `create or replace function` preserves them.
No client code changed, so no test count change.

Still open after this, and smaller than what is now covered: the remaining
read helpers that take a required warehouse (`dashboard_metrics`,
`global_search`, `stock_ledger`, `stock_availability`, `bin_by_code`,
`bin_stock_overview`, `default_staging_bin`, `warehouse_uses_locations`)
and the edge functions' own `warehouse_id` query filters. Also still open:
the pre-existing `anon` grant on `warehouse_overview()`, which wants a look
at the sign-in flow rather than a silent revoke.

_(Both of those are now closed — the `anon` grants by 0048/0050, and the
read helpers by 0051's permission checks plus 0052's table-layer scope.
The edge functions' own `warehouse_id` query filters remain open, and are
now the last piece of §37.)_

### 0047 — Inspection / transfer / shipment report sources (UI spec §46 item 10)

`run_report(p_source, p_filters, p_limit)` offered six sources. The custom
report builder could reach stock movements, the three order kinds, the audit
log and the product master, but nothing about the middle of the warehouse
day: what was inspected, what moved between warehouses, what shipped. This
migration replaces the function, adding three sources and — separately —
the warehouse-scope fallback 0044-0046 had not yet reached.

**The three sources.**

- `inspections` rolls up `passed_quantity`, `failed_quantity` and
  `failed_lines` from `inspection_items` per inspection, joining
  `delivery_plans` for the delivery number and `app_users` for the
  inspector. A failed-line count is what makes the report answer "which
  suppliers keep sending bad stock", which a per-item dump does not.
- `transfers` reports both ends of the move (from/to warehouse names), the
  three lifecycle timestamps (`approved_at`, `shipped_at`, `received_at`)
  and the `requested_quantity` / `received_quantity` sums, so a shortfall
  in transit is visible as a difference between two columns.
- `shipments` reports line and carton counts alongside §21's `weight_kg`,
  `carrier` and `tracking_number`.

Each aggregate is computed in a subquery and then joined, not summed across
a multi-table join — a rolled-back data test confirmed the numbers
(transfers: 2 lines, requested 15, received 13; shipments: qty 7, carrier
ヤマト) specifically to rule out JOIN-induced row inflation.

**The scope fallback.** `run_report` is `security definer`, so RLS never
fires for it, and it had no `accessible_warehouse_ids()` fallback. A scoped
operator could report across every warehouse. Each source now declares
`v_scope bigint[] := public.accessible_warehouse_ids()` and filters on
`v_scope is null or <warehouse> = any(v_scope)`; `transfers` matches
*either* end, consistent with 0045's `transfer_order_index`.

Two judgment calls, both deliberate:

- `products` stays unscoped. It is company-wide master data with no
  warehouse column; scoping it would mean inventing a rule ("products that
  have stock in your warehouses") that no other screen applies.
- `audit_log` rows with a null `warehouse_id` are *excluded* for scoped
  callers. Company-level events (a role change, a partner edit) have no
  warehouse, so there is no way to decide whether a warehouse-scoped
  operator should see them; excluding is the safe reading, and an admin
  (null scope) still sees everything.

**Filter shape.** The warehouse filter lives inside `p_filters` as
`{"warehouse_id": N}` rather than becoming a fourth positional
`p_warehouse_id` argument. This was raised and decided explicitly: a
top-level argument reads as *the* scope of the report, but for `transfers`
it means "either end" and for `products` it means nothing at all, so it
belongs with the other per-source filters where its meaning is source-
dependent. Keeping the signature at three arguments also avoids a
breaking change for the saved `report_definitions` rows.

Client side: `ReportSource` gained the three wire values and
`report_builder_screen.dart` their labels, with l10n in ja/en/zh. Two tests
added — the dropdown offers all three and renders inspection rows, and
every `ReportSource.wire` round-trips through `parse` (a guard against
adding an enum case and forgetting the `parse` branch, which would silently
fall back to stock movements).

### 0048-0052 — The anon/permission/scope sweep

Five migrations from one thread: setting out to narrow §37's warehouse
scope, an audit of `pg_proc` and `pg_policies` turned up something larger
underneath it.

**0048 — revoke public/anon execute on 15 business-data RPCs.** The anon
key is embedded in the shipped app, so it is public by construction.
Anyone holding it could read the complete stock ledger, every on-hand and
reserved quantity, the dashboard KPIs, the search index, every bin's
contents, and any pick list / transfer / inspection / stock-count detail,
across every warehouse, without signing in.

A permission check would not have closed it, which is why the fix is a
revoke. `has_permission()` returns true when `auth.uid()` is null — the
deliberate branch that lets the service-role edge functions work without a
user — and an anon request has a null uid too. Worse,
`accessible_warehouse_ids()` returns null for a null uid, and null means
"every warehouse", so the entire §37 enforcement of 0044-0047 was a no-op
for an anon caller; it only ever bound signed-in users. Revoking is what
made that work load-bearing.

Revoking from `anon` alone would have done nothing: the live ACLs read
`{=X/postgres, ..., anon=X/postgres, ...}`, and that leading empty grantee
is a grant to PUBLIC — Postgres's default for a new function. Two
independent paths, so every statement revokes from `public, anon`.

**0049 — drop anon from 22 permissive table read policies.** 0048 was
necessary and not sufficient: PostgREST exposes tables directly, and
`GET /rest/v1/stock_movements` with the anon key returned the whole ledger
regardless of what the RPC layer allowed. Also reachable unauthenticated
were `roles`, `permissions` and `role_permissions` — a readable map of the
authorization model. RLS was enabled throughout (the `rls_auto_enable`
event trigger does its job); the policies were simply scaffolding that was
never tightened.

**0050 — the last four anon grants**, including `has_permission` itself,
which answered `true` to an unauthenticated probe for any permission code.
`my_access` / `my_roles` are deliberately left, both verified to return
nothing for a null uid; they are the sign-in bootstrap and sign-in is the
one flow never yet exercised live.

**0051 — the missing permission checks on 14 read RPCs.** Implemented as a
rename-plus-wrapper rather than by re-creating each body, so the diff shows
only the guard: `alter function ... rename` keeps the OID, making the body
provably byte-identical. That matters most for `dashboard_metrics`, ~200
lines of aggregate SQL where a mistyped `sum()` would be silent. The
`_impl` functions are stripped to `{postgres=X}` and are unreachable
through the API.

Two things the dry run caught. First, `create function` grants EXECUTE to
PUBLIC by default, so the initial attempt came back `anon: true` on all
fourteen wrappers — it would have re-opened the hole 0048 had just closed.
Second, checking callers changed the permission mapping: eight of the
fourteen are reached only from edge functions on the service-role client,
where the guard cannot lock anyone out, while the three client-called ones
sit behind controls every role has (dashboard, search button, scan box)
and so take `warehouse.view`, held by all 11 roles.

**0052 — warehouse-scope the table read policies.** The `USING (true)`
that 0049 left behind. RLS is the right instrument here, unlike 0044-0047:
these are direct reads by `authenticated`, so policies do fire. Reuses
`can_access_warehouse()` rather than inventing a second predicate. Five
tables stay unscoped for want of a warehouse dimension — `companies`, the
three authorization-model tables, and `delivery_suppliers`.

Verified with a three-way rolled-back control on two warehouses and a
picker assigned to one: unchanged policies 2/2/2/2, scoped policies 1/1/1/1,
system_admin 2/2/2/2 (warehouses / stock_levels / bins / bin_stock). The
admin case carries no `user_warehouses` row, so it also exercises the
unrestricted branch.

Two corrections to the record came out of this work. The project's own
checklist had claimed per-warehouse scope was "enforced server-side by RLS
on every table already"; it was not, and `can_access_warehouse()` had never
been called from anywhere until 0044. And the production database is not
empty as an earlier status said — `products`, `stock_movements` and
`stock_levels` are, but 2 delivery plans and 69 delivery plan lines were
already stored.

Still open at that point, and framed as the last piece of §37: the edge
functions' own `warehouse_id` query filters. Finishing them turned up two
mistakes in the paragraphs above — see 0053-0055 below.

### 0053-0055 — Finishing §37, and two corrections to the record

**Correction 1: the mutation RPCs check nothing, and are not client-callable.**
The 0048-0052 write-up said edge functions should run RPC writes on the caller's
client so "the RPC's own has_permission() and can_access_warehouse() bind on a
real uid." Both halves were wrong, measured against `pg_proc` on the live
database:

- `ship_plan`, `cancel_shipment`, `adjust_stock`, `record_pick`, the pick-list /
  inspection / stock-count / transfer families, `reconcile_delivery_plan`,
  `cancel_reconciliation` and `log_audit` contain **no** `has_permission()` and
  **no** `can_access_warehouse()` call at all, and
- every one of them is granted to `service_role` only. `authenticated` has no
  EXECUTE, so calling one on the caller's client fails outright with "permission
  denied for function".

The second point meant the change actually shipped a regression: picking,
stock-ops, transfers, inspections and delivery-plans writes were failing in
production until this was fixed. The first means there is **no warehouse check
anywhere on a write path** unless the edge function performs one — RLS cannot
help, because the RPC is SECURITY DEFINER and runs as its owner.

The corrected rule now lives in `_shared/require_permission.ts` and is followed
by all nine functions:

```
reads            -> caller's client, so 0052/0053's policies scope them
permission check -> caller's client (has_permission needs a real uid)
scope check      -> caller's client, EXPLICIT, at the call site, before the write
writes           -> service role, RPC and direct alike
```

`callerCanSee(client, table, id)` is the usual gate: one lookup on the caller's
client answers both "does this row exist" and "is it in my warehouses", because
the policy already reaches through a child row to its parent's warehouse. It
answers 404 rather than 403, so it cannot be used to probe for rows in another
warehouse.

**Correction 2: only 3 of the 14 read wrappers scope themselves.** 0044-0047
scoped the *index* functions (`pick_list_index`, `transfer_order_index`,
`warehouse_overview`). The eleven detail/search wrappers — `pick_list_detail`,
`transfer_order_detail`, `inspection_detail`, `stock_count_detail`,
`stock_ledger`, `stock_availability`, `dashboard_metrics`, `bin_stock_overview`,
`global_search`, `default_staging_bin`, `warehouse_uses_locations` — are
SECURITY DEFINER with no scope predicate, so they return whatever id they are
given. The edge functions now gate each one; they remain reachable directly over
PostgREST by any signed-in user, which is the next tranche of work.

**0053** — a scoped SELECT policy for `stock_count_lines`, which had none. It
did not matter while reads ran as service role; it did the moment they moved to
the caller's client.

**0054** — the three write policies 0052 missed, because 0052 only touched
SELECT. `delivery_plans` UPDATE and the `delivery_reconciliations` /
`reconciliation_lines` INSERTs were `true` for `authenticated`: any signed-in
user could edit any warehouse's delivery plans and post receipts against them,
straight over PostgREST with no edge function involved. Nothing in the app
depended on that — the real paths go through SECURITY DEFINER RPCs, which these
policies never governed.

**0055** — `audit_log_query` and `audit_event_types` had no warehouse predicate
at all. Being SECURITY DEFINER, `audit_log`'s own policy never applied to them
either, so anyone holding `audit.view` read every warehouse's trail, including
actor names, emails and each operation's `details` payload. Scoped in the body,
where a list can be filtered row by row. `can_access_warehouse(a.warehouse_id)`
is exactly the rule wanted because of its branch order: an admin
short-circuits to true before the null check, so admins keep seeing entries with
no warehouse (global events such as a role change) while a scoped operator does
not.

**Edge functions.** All nine now follow the rule above. Beyond the client split:
`shipments` had run every read as service role (a warehouse-1 packer could list
and open any warehouse's shipments) and took a carton id on PUT/DELETE with no
check that it belonged to the plan in the URL; `warehouses` ran overview and
bins unscoped and let anyone with `warehouse.manage` rename a warehouse outside
their scope; `import-plan` never set `warehouse_id` at all, so
`fill_default_warehouse()` filed every import into the default warehouse — a
plain bug as much as a scope hole, since a Kobe operator's delivery note landed
in Osaka's receiving list. It now resolves the warehouse from the caller's scope,
or refuses with a 422 when the caller has access to several and named none.

`supabase/checks/verify_security.sql` asserts all seven invariants read-only; all
seven pass against the live database.

### 0057 — Phase A steps 1-2: product identity and barcode aliases

The InvenTree-maturation spec's §3 and §37-8 are the same instruction from two
directions: JAN must stop being the product's key. Today it effectively is.
`products` has an `id`, but **nothing references it** — `stock_levels`,
`bin_stock`, `stock_movements`, `pick_tasks`, `shipment_carton_items` and
`work_order_components` all key on `jan_code` text, and so do the RPC
signatures (`p_jan_code`) and the Flutter model, whose own doc comment says so.

This migration changes none of that. It is deliberately additive (§2, §38):
it builds the identity and the alias table the later steps need, and every
existing column, RPC signature and client call behaves exactly as before.
Repointing the stock tables at `product_id` is a later step and needs this
mapping to exist first.

- **`products.sku`** — the internal code §3 asks for. Unique per company *only
  where assigned*, via a partial index: a product with no code yet is not in
  conflict with every other product that also has none.
- **`products.tracking_mode`** — §4's UNTRACKED / LOT / SERIAL /
  LOT_AND_SERIAL / EXPIRY. Defaults to UNTRACKED, so nothing changes until
  steps 4-6 give lots and serials somewhere to live.
- **`product_barcodes`** — many codes per product: JAN, EAN/UPC, an internal
  SKU, a case code, a QR, a logistics label. `quantity_per_scan` is §21's
  "scan one case, get twelve".
- **`normalize_barcode()`** — one definition of two scans being the same code,
  mirroring `normalizeJan` in the import-plan function: full-width digits
  folded, separators dropped, alphanumerics upper-cased (CODE128 and internal
  SKUs are not digits), and a 12-digit UPC-A padded to the EAN-13 form of the
  same article.
- **`resolve_barcode()`** — §26's resolver. Returns a tagged object
  (`{kind: 'product' | 'unknown', ...}`) rather than a product row, so steps
  4-9 can add `lot`, `serial`, `location` and `carton` kinds without any caller
  changing the shape it expects. An unregistered code is a normal answer, not
  an error: the operator scanned something and the screen needs to say "not
  registered".

Two design points worth keeping:

**Barcode uniqueness is per company, enforced structurally rather than by a
trigger.** `product_barcodes` carries `company_id` and reaches its product
through a composite foreign key to `products (company_id, id)`, so the child
cannot disagree with the parent about which company it belongs to, and
`unique (company_id, barcode)` then means exactly what it says. There is one
company today; this costs nothing now and is not a migration later.

**The primary barcode is a trigger, not a line in `create_product`.** Every
product gets its JAN as a primary alias whatever created it — the RPC, a future
importer, a seed script. The trigger deliberately *fails* the product insert
when two JANs normalize to the same code (`4901-234-567890` and
`４９０１２３４５６７８９０` are the same barcode), because a code that resolves
to two products is worse than a refused product, and the operator can see why.

`list_products` gains `sku`, `tracking_mode` and a `barcodes` array, and its
search now matches sku and any registered alias. Additive to the JSON only —
every existing key keeps its name, and the Dart model ignores keys it does not
know, so the client keeps working untouched. Existing signatures were left
alone; the new data is written through new entry points
(`add_product_barcode`, `remove_product_barcode`, `set_product_identity`).

Verified against the live database with a self-rolling-back test block: the
normalizer on five input forms; the trigger producing exactly one primary; the
same product resolving from `4901234567890` and from
`４９０１－２３４－５６７８９０`; an unregistered code answering `unknown`; a CASE
alias resolving to the same product with `quantity_per_scan` 12; a duplicate
barcode refused; removing the primary refused; `tracking_mode` normalised from
lowercase and a nonsense value refused; `list_products` carrying the new keys
and finding the product by sku; and the barcodes cascading away with the
product. Afterwards: 0 products, 0 barcodes, 0 audit rows — the block rolled
itself back.

verify_security.sql gains **check 9** — no table with RLS off or with RLS on
but no policy. Supabase grants `anon` and `authenticated` full table privileges
by default, so RLS is the only thing in front of every table; one table created
without it is open to anyone holding the anon key. Phase A adds tables steadily,
which is exactly when that slips. All nine invariants pass.

Still keyed on `jan_code`, unchanged by this migration and next in line:
`stock_levels`, `bin_stock`, `stock_movements`, `pick_tasks`,
`shipment_carton_items`, `work_order_components`.

### 0058 — Phase A step 3: `product_id` alongside `jan_code` (併走)

0057 built the identity; nothing used it. This puts the column that will
eventually replace `jan_code` as the join key on all **sixteen** tables that
carry one — `stock_levels`, `bin_stock`, `stock_movements`,
`stock_adjustments`, `pick_tasks`, `inspection_items`, `reconciliation_lines`,
`stock_count_lines`, `transfer_order_lines`, `shipment_lines`,
`shipment_carton_items`, `delivery_plan_lines`, `purchase_order_lines`,
`sales_order_lines`, `work_order_components`, `putaway_confirmations`.

This is the run-in-parallel step, **not** the switch-over. `jan_code` keeps its
name, its type, its place in two primary keys (`stock_levels (warehouse_id,
jan_code)`, `bin_stock (bin_id, jan_code)`) and every RPC signature. Nothing
reads `product_id` yet. It was the cheapest possible moment to do this:
`delivery_plan_lines` holds 69 rows and the other fifteen tables are empty.

**Nullable, and nothing is auto-created.** `products` is empty and today's
write paths do not need a product to exist — `adjust_stock(p_jan_code,
p_product_name)` will make a stock level for a JAN nobody registered, carrying a
free-text name. That is the "stock CRUD" shape §3/§11 move away from, but it is
how the app works now, so NOT NULL would break every one of those paths. What
the migration deliberately does *not* do is invent a product when a scan
presents an unknown JAN: that is how a product table fills with
"4901234567890 / (unnamed)", and §30's rule — scans and AI produce candidates,
humans confirm domain data — applies to a barcode as much as to OCR.

Instead the gap is made visible and closable:

- `product_for_jan(text)` resolves through `product_barcodes` **first**, so an
  EAN, a case code or an internal SKU resolves as readily as the JAN. That is
  0057 paying off.
- `fill_product_id()` — a BEFORE INSERT/UPDATE trigger on all sixteen tables,
  filling the column from `jan_code` only when the caller supplied nothing, so a
  future caller that knows the product is never second-guessed by a text lookup.
- `link_products_by_jan()` — re-resolves rows that have no product yet. Safe to
  re-run; it can only link, never unlink.
- **A products INSERT fires it for that product's own codes.** This is what
  makes "register the master data later" a real answer rather than a permanent
  gap: receive stock today under a bare JAN, register the product next week, and
  the movements, plan lines and counts link themselves.
- `unlinked_jan_codes()` — the worklist: codes in use that no product accounts
  for, with the row counts and which tables they appear in.
- `product_id_coverage()` — per-table linked/unlinked, and `ready_to_switch`,
  which is the criterion for when reads may start moving over.

`on delete restrict` on every foreign key, not `cascade` or `set null`: §37-4
says history is not balanced by deleting it, and quietly detaching a movement
from its product is a softer version of the same thing.

The sixteen tables are handled by one loop over an explicit list rather than
sixty-four hand-written statements — a loop cannot apply the treatment to
fifteen tables and silently skip the sixteenth — and the loop refuses to touch a
table whose `jan_code` it cannot find.

Verified against **real production rows** with a self-rolling-back block:
16 columns / 16 FKs / 16 triggers / 16 indexes created; stock written for an
unregistered JAN left `product_id` null with `products` still empty (nothing
invented); `unlinked_jan_codes()` listed that code first at 2 rows, correctly
aggregating the new stock row with the delivery plan line that already existed;
coverage read 70 rows / 0 linked / not ready; then registering
`4901427333022` ("くれ竹 LP-F-010S", a real line from the seeded delivery plan)
**linked both the stock row and the pre-existing plan line by itself**; a write
quoting a CASE alias resolved to the same product; and deleting a product with
history was refused by the foreign key. Rolled back to 69 plan lines with 0
linked.

Two housekeeping items came out of it. verify_security.sql gains **check 10** —
no trigger function is executable by a client role. Postgres refuses a direct
call to one, so such a grant is inert, but inert in a way a reviewer has to stop
and rule out, and `create function` hands out the PUBLIC grant every time. The
migration makes the whole set uniform, including `fill_default_warehouse` from
0050, which still carried it. All ten invariants pass.

### 0059 — units of measure (Phase A step 4, §21)

0057 gave `product_barcodes` a `quantity_per_scan`, which is §21's whole feature
in miniature: scan the case once, get twelve pieces. What it could not say was
what the twelve were twelve *of*, nor let an operator define a pack size without
inventing a barcode for it. 0059 adds the vocabulary and the conversions, and
then makes the conversions authoritative so the two numbers cannot drift.

The split is §21's, and it matters:

- `uoms` — the vocabulary. Global, because 箱 means the same word everywhere.
  Sixteen rows seeded for a Japanese warehouse: PCS 個, SET, PACK, BOX 箱,
  CASE ケース, BAG 袋, ROLL 巻, SHEET 枚, DOZEN, PALLET, plus KG/G, L/ML, M/CM.
  Names in Japanese, because this is the text an operator reads on a picking
  screen; `code` is the stable key.
- `product_uoms` — the conversions. **Per product**, because a box of pens and a
  box of copier paper are not the same number of pieces, and a global
  "1 BOX = 12" would be wrong for almost everything.

`products.base_uom_id` is NOT NULL and says which unit `on_hand` counts. It is
backfilled to PCS and a BEFORE INSERT trigger defaults new products the same
way — every quantity already in this database is a count of pieces, so declaring
PCS states what was already true rather than changing anything. The base unit
also gets an explicit factor-1 row in `product_uoms` (an AFTER INSERT trigger),
so `product_uoms` answers every conversion question on its own and no caller has
to special-case the base.

**§5, in one trigger.** `quantity_per_scan` and a `product_uoms` factor are the
same number said two ways, which is exactly the double-count §5 warns about. So
when a barcode names a unit, `derive_barcode_quantity()` takes the multiplier
*from* the conversion and ignores what the caller passed; correcting "a case is
144, not 120" therefore fixes every case barcode at once instead of leaving
stale multipliers behind. A barcode with no unit keeps its own number, which is
how a plain JAN (one scan, one piece) still works.

What this deliberately does **not** do:

- **Widen the ledger.** `stock_levels.on_hand`, `stock_movements.quantity` and
  every line quantity are `integer`. `conversion_factor` is numeric so master
  data can express a 500 g bag as 0.5, but a barcode whose scan would produce a
  fractional quantity is *refused* rather than rounded somewhere downstream.
  Going numeric end-to-end is its own migration with its own risks (rounding,
  the existing arithmetic, the report SQL) and does not belong in the change
  that introduces the vocabulary.
- **Enforce matching `uom_type`.** It looks like an invariant and is not: a
  product based in KG legitimately comes in a BAG (a COUNT unit) of 5. The
  factor carries the meaning and is type-agnostic by design.
- **Create units on demand.** `set_product_uom` rejects a code that is not in
  `uoms`. A typo would otherwise become a new unit, and a vocabulary nobody
  curates stops meaning anything.

`set_product_base_uom` refuses once the product has any `stock_movements`: that
is §37-15 directly — a past transaction must not change meaning because master
data changed. `remove_product_uom` refuses the base unit, and refuses a unit a
barcode still uses. `add_product_barcode` was **dropped and recreated** with a
7th parameter `p_uom_code` rather than gaining a defaulted one, because an added
default is a second overload PostgREST would have to guess at; nothing calls it
yet, so there was no call to break.

Reads gain it additively: `list_products` carries `base_uom`, `uoms` and a `uom`
per barcode; `resolve_barcode` carries `uom` and `base_uom`, so a scanning
screen gets "one scan = 24 個" without a second round trip. `to_base_quantity()`
is the function every later step will use, and returns NULL rather than a
silently wrong number when the product has no conversion for the unit.

Verified with a self-rolling-back block, **26 checks, all OK**: the 16 units
seed and `list_uoms()` returns them; a new product gets PCS and its factor-1 row
from the two triggers; `set_product_uom(BOX,12)` then a barcode registered with
`p_uom_code => 'BOX'` and `p_quantity_per_scan => 1` stores **12**, derived, not
passed; re-setting BOX to 24 re-derives that barcode to **24**; `to_base` reads
48 for 2 BOX, 7 for a null unit and NULL for an undefined one; a fractional
factor on a unit a barcode uses is refused with the integer-ledger message and
leaves the factor at 24; the base factor is locked at 1; removing the base or an
in-use unit is refused; a barcode naming a unit with no conversion is refused, as
is an unknown unit code; the base unit can be changed while there is no history
and is refused the moment a `stock_movements` row exists; both reads carry the
new keys; the plain JAN barcode keeps `quantity_per_scan` 1 with a null unit; and
none of the eight functions is anon-executable. All ten security invariants pass,
including check 9 against the two new tables.

### 0060 — Lot / Serial / Expiry (Phase A steps 4-6, §4)

Three free-text columns on `inspection_items` — `lot`, `serial`, `expiry` — are
where this data goes today. They are written once at inspection and never read
again, because there is nothing to read them *from*: no row says "this lot
expires on the 31st", so no screen can warn about it and no picker can be told
to take the older one first.

The three spec steps are one migration because they are one shape: expiry lives
on the lot, and a serial points at the lot it came in. Splitting them would mean
a `lots` table with no date column and a `serial_numbers` table with nothing to
point at.

- `lots` — product, lot code, manufacture/expiry dates, supplier, received_at.
  Codes are uppercased and trimmed but keep their separators: "A-2024/05" is
  what an operator reads back off a carton, and unlike a barcode no standard
  says the punctuation is noise.
- `serial_numbers` — product, serial, optional lot, status (IN_STOCK / SHIPPED /
  RETURNED / SCRAPPED / HOLD).

**0057's `tracking_mode` stops being decoration.** It is the whole point of this
migration, and triggers — not the RPCs — enforce it, so a future caller (a
receiving flow, an import, another trigger) cannot get it wrong by forgetting to
ask:

| mode | means |
| --- | --- |
| `UNTRACKED` | no lots, no serials. The default, and every existing product. |
| `LOT` | lots allowed, expiry optional. |
| `EXPIRY` | lots allowed and **every lot must carry an expiry date** — the food/medical case, where the date is the thing being tracked. |
| `SERIAL` | serials allowed, lots are not. |
| `LOT_AND_SERIAL` | both, and **every serial must name its lot**, or the mode claims to track two things while recording one. |

And the §37-15 half, in the other direction: the mode cannot be changed into one
that contradicts data already recorded under it. Dropping to `UNTRACKED` with
lots on file would not delete them — it would leave them unreachable and make
every past inspection that cited one mean something else. Tightening is refused
just as firmly when the existing rows would not satisfy the stricter mode (lots
with no date before switching to `EXPIRY`; serials with no lot before switching
to `LOT_AND_SERIAL`), because the row triggers only ever see rows being written.

**A table nothing writes to is worse than no table: it looks like a feature.**
So the existing inspection path feeds these. `inspection_items` gains `lot_id`
and `serial_id` behind *composite* FKs — `(product_id, lot_id) → lots
(product_id, id)` — so a line cannot cite a lot belonging to a different
product, and MATCH SIMPLE leaves rows whose `product_id` is still null (0058)
alone. A trigger then resolves the ids from the text columns the inspection
screen is already filling in: the same 併走 pattern as 0058, for the same
reason — the new column becomes correct on live data before any screen changes.
An UNTRACKED product keeps its text and gets no lot, because a lot the product
does not track is a row nothing will ever look up.

This is not §30 being bent. §30 says a scan or an AI produces a *candidate* and
a human confirms domain data — which is why 0058 refuses to invent a product
from an unknown JAN. A lot is not master data somebody curates; it is an
observation of what physically arrived, typed by the inspector holding the box.
Recording it *is* the confirmation.

Two deliberate calls worth stating:

- **A serial is unique company-wide, not per product.** Two manufacturers can
  legitimately stamp the same serial on different goods, so this refuses
  something the world allows. But a serial that resolves to two rows is useless
  at a scan gun, and resolving a bare serial is the entire reason for recording
  it; a genuine collision is fixed by prefixing one, which is a cheaper problem
  than an ambiguous scan.
- **`expiring_lots()` is not warehouse-scoped.** A lot belongs to a product, not
  to a building, and `lots` carries no warehouse — the same reason
  `list_products` is not scoped. It becomes a per-warehouse number in step 8,
  when stock rows start carrying `lot_id` and the question turns from "which
  lots expire" into "how many of them are in bin A-01".

`resolve_barcode` now answers for a serial too, after the barcode tables have
had their say (a serial that looks like a product barcode still resolves as the
product). §26 wants one resolver: a serial label and a product barcode are the
same physical gesture at the same scan gun, and making the operator pick the
right screen first is exactly what gets skipped on the floor. `inspection_detail`
gains `lot_id` / `lot_code` / `lot_expiry_date` / `serial_id` / `serial_status`
by the same asserted `pg_get_functiondef` transform 0056 used, so a drifted body
fails the migration instead of being silently missed.

Writes go through `register_lot` / `register_serial` / `set_serial_status`
(`inventory.adjust` or `product.manage` — a lot is recorded by whoever receives
the stock, not only by whoever curates the product master). The internal
`upsert_lot` / `upsert_serial` are granted to **nothing**: only SECURITY DEFINER
callers reach them, which keeps the tracking-mode rules the single gate rather
than something a direct PostgREST insert can walk around. Neither table has a
write policy for the same reason.

Verified with a self-rolling-back block, **32 checks, all OK**: every mode
accepts what it should and refuses what it should (11 distinct refusals, each
matched on its own message); a lot code normalizes to `A-2024/05`; re-registering
it is the same row and a later receipt cannot erase the expiry it already knew;
an EXPIRY product with no printed code gets `EXP-20261001` derived from the date;
a serial cannot be claimed by a second product; a lot with serials against it
cannot be deleted; an inspection line quoting a bare JAN resolved its product
(0058), then its lot, and the lot learned the expiry from the same line; an
UNTRACKED line kept its text and got no lot; a typed serial became a
`serial_numbers` row; all five new keys appear in `inspection_detail`;
`expiring_lots(4000)` returned the three dated lots soonest-first and
`expiring_lots(0)` none; `resolve_barcode` answered `kind=serial` with the
product, its lot and its base unit, while a product barcode still won; and none
of the writes is reachable by a client role. All ten security invariants pass.

### 0061 — Stock Status and the Stock Unit (Phase A steps 7-8, §5)

`on_hand = 100` is too weak a sentence. It cannot say that twenty of those
hundred are quarantined, or that the oldest lot expires on Friday, and so it
cannot answer the only question an outbound flow asks: how many can ship today.
§5 wants `available ≠ on_hand`, and attaches the rule that decides the whole
design — 二重計上しないよう、実装上の正規ソースを決める, pick the canonical
source so nothing is counted twice.

**Which source is canonical.** `stock_movements` is the ledger and stays the
record of what happened (§37-4). Two projections of it already exist:
`stock_levels` (warehouse × JAN), written by `apply_stock_movement`, and
`bin_stock` (bin × JAN), written by `apply_bin_movement`. They are *not* two
copies of one number: a WAREHOUSE-scope movement changes what the warehouse
holds, while a BIN-scope movement (put-away) only moves stock inside it and
leaves the total alone. `balance_scope` is what keeps them apart, and — verified
against `pg_proc` — no function writes both for one event.

`stock_units` joins as a **third projection of the same ledger, never as a
second writer**. One trigger, on WAREHOUSE-scope movements only, keeps it in
step, so for every warehouse:

```
sum(stock_units.quantity) == stock_levels.on_hand
```

That equality is the safety property, and `stock_reconciliation()` checks it on
demand. Everything else is arranged so it cannot quietly stop holding.

Three deliberate exclusions, each one a double-count avoided:

- **Bins stay out.** `stock_units.bin_id` exists and is always null. Bin
  granularity would mean modelling put-away as a transfer between parcels, and a
  put-away that outran its receipt would either drive a parcel negative or break
  the equality. Bins are step 9's subject; `bin_stock` remains the bin-level
  answer until then.
- **RESERVED and ALLOCATED are not statuses**, though §5 lists them beside the
  others. A reserved unit is still physically on hand and still in its own
  condition; making RESERVED a bucket would move the quantity out of OK and count
  the reservation twice — once as a missing unit, once as a claim. They become
  rows in their own table in step 12, and `stock_available()` subtracts them
  there, which is why the subtraction belongs in that one function rather than in
  each caller.
- **Every status counts toward on-hand**, so there is no `counts_on_hand`
  column — only `counts_available`. Scrapping is not a status change but a stock
  movement that reduces the total and leaves a ledger entry, per §37-4. This is
  what makes a status change always conserve the warehouse total, and therefore
  what keeps the equality true without a second ledger.

Seven statuses: OK 良品 (the only available one), QC_PENDING 検品待ち, HOLD 保留,
QUARANTINE 隔離, DAMAGED 破損, EXPIRED 期限切れ, BLOCKED 出荷停止.

`apply_stock_unit_delta()` takes the signed effect from the balance the movement
recorded (`quantity_after - quantity_before`) rather than from `quantity` plus a
sign convention per `movement_type`. On the way out it draws from the most
available, soonest-expiring parcel first — an outbound should consume usable
stock closest to its date and only reach into held or damaged stock when there
is nothing else, which in practice means the parcels and the ledger have
drifted. It returns that shortfall rather than going negative, and
`stock_reconciliation()` is where it surfaces.

`backfill_stock_units()` brings the parcels to what `stock_levels` says for
every row that has a product, and reports how many it skipped for want of one.
It computes the difference and applies only that, so it is safe to re-run — it
is the function to run after `link_products_by_jan()` links a JAN that had stock
before its product existed.

Verified with two self-rolling-back blocks against the live schema, **27 checks,
all OK**: a real receipt through `apply_stock_movement` projected to one OK
parcel of 100 with `stock_levels` agreeing and reconciliation empty; quarantining
20 left on_hand at 100 and dropped available to 80, still reconciled; moving
more than a status holds, and an unknown status, were both refused; shipping 50
took it all from the available parcel and left the quarantine at 20; shipping 40
more drew 10 out of quarantine only once nothing else remained, emptied parcels
were removed, and reconciliation stayed clean throughout; a put-away filled
`bin_stock` to 30 without touching the 40 on hand (the no-double-count rule,
proven rather than asserted); a receipt for an unlinked JAN created no parcel and
was reported as `unlinked jan_code` with its quantity; registering that product
late, linking the history and running the backfill adjusted exactly one row,
reconciled, and adjusted nothing on a second run; the breakdown returned the
per-status parcels with their lots; releasing the quarantine restored
availability; and none of the new functions is reachable by a client role. All
ten security invariants pass, including check 9 against both new tables.

### 0062 — the location tree (Phase A step 9, §7 §8)

The current shape is exactly two levels deep — Warehouse → Zone → Bin — so a
warehouse actually laid out as Zone → Aisle → Rack → Shelf → Bin has to flatten
three of those levels into a bin code and trust everyone to read it the same
way. §7 asks for a general tree; §8 adds the half that makes it useful, a
location *type*, so "can this shelf hold ordinary stock?" is a column instead of
a convention, and RECEIVING / QC / SHIPPING / TRANSIT / DAMAGED become real
places stock can sit rather than states invented per screen.

**`bins` is not touched.** It is what `bin_stock` keys on and what every put-away
RPC references, so rewriting those onto a new table would be a large change to
working code for no gain today. Instead the responsibilities are split and
written down: `locations` is canonical for **structure**, `bins` stays canonical
for **bin-level quantity**. Every zone and every bin gets a location row, kept in
step by triggers, with a back-pointer (`zone_id` / `bin_id`) so the two can
always be lined up; a rack or a virtual RECEIVING area simply has neither. The
sync is one-way on purpose — bins and zones are what the running system writes,
so they lead and the tree follows. When Phase B moves put-away onto locations,
that migration flips the direction and says so.

`location_types` is a table, not a check constraint, because §8's point is that a
type's *behaviour* is data: eleven types each carrying the defaults a new
location of that type starts with (`default_pickable`, `default_receivable`,
`default_shipping`, `default_quarantine`, `default_virtual`). `create_location`
takes the flags nullable and falls back to the type's defaults, so "a RECEIVING
area" is one argument rather than five, while a particular shelf can still be
marked unpickable without inventing a type for it.

Three things the constraints alone could not do:

- **A cycle.** The composite FK `(warehouse_id, parent_id) → (warehouse_id, id)`
  keeps a parent in the same warehouse and a check stops a row being its own
  parent, but A → B → A satisfies both. Walking up on every `parent_id` write is
  the only way to know, and the 32-level limit doubles as a guard against a tree
  nested absurdly.
- **A code collision.** A code is unique within a warehouse so that scanning one,
  or naming a parent by it, has exactly one answer — which makes a zone and a bin
  both called "A" possible in principle. This sync must never be the reason a
  warehouse edit fails, so `location_code_for()` disambiguates (`A#17`) instead
  of raising. In a sensibly named warehouse it never fires.
- **Nesting the JSON.** `location_subtree()` recurses rather than using a
  recursive CTE: a CTE walks *down* a tree easily but has to be turned inside out
  to build JSON *up* from the leaves, and the inside-out version is exactly the
  query that silently loses grandchildren — which is what the first draft of this
  did, and what the test caught.

`resolve_barcode` now also answers for a location, after products and serials,
because a location barcode is the rarer scan and an overlap should favour the
goods. Unlike those two it is **warehouse-scoped**: a product is master data any
operator may look up, but a location belongs to a building, and which buildings
this operator may see is the §37 rule every other warehouse read follows.

It does not move quantity. `stock_units.bin_id` stays null (0061) and `bin_stock`
stays the bin-level answer — a tree is what makes put-away suggestion, pick paths
and zone-level counting possible later, but pretending the quantity moved with it
would be the double count §5 warns about.

Verified with self-rolling-back blocks, **26 checks, all OK** (three assertions
in the first run were wrong about the test's own expectations — booleans render
as `t`/`f`, and roots come back sorted by code so `Z1` is the third, not the
first — and were re-run correctly rather than left as failures): the eleven types
seed and list; a zone becomes a location and a bin becomes its child; renaming
the bin moves its location instead of leaving a stale one; deleting the bin
cascades the location away; a four-level tree builds through `create_location`
and comes back nested to full depth with the leaf's type, flags and normalized
barcode intact; flags default from the type and yield to a caller who names one;
an unknown type, a missing parent, a duplicate code and a cycle are each refused
with their own message; deactivating a rack hides its whole branch until
`include_inactive` asks for it; a shelf resolves by barcode and an aisle by code
through the one resolver, while nonsense still comes back `unknown`; a bin whose
code collides with a zone's is disambiguated rather than rejected; and neither
`location_subtree` nor `location_code_for` is reachable by a client role. All ten
security invariants pass.

### 0063 — warehouse products (Phase A step 10, §22 §31)

§22's example is the whole feature: the same product lives at A-01 in Osaka, B-03
in Kobe and C-10 in Tokyo, and "where does this go" has three different right
answers. There was nowhere to put any of them, so a put-away decision had to come
from memory every time, and a reorder point could not exist at all — it would
have had to mean the same number in every building.

`warehouse_products` is that split: `products` keeps what is true of the goods
everywhere, this keeps what is true of them *here* — default location, min/max,
reorder point, pick priority, put-away rule, preferred supplier, lead time. A row
is optional, and no row means no special settings: seeding one per product ×
warehouse would fill the table with nulls and make "has anyone thought about this
product here?" unanswerable.

**The default target points at `locations`, not `bins`** — 0062 made the tree
canonical for structure, and this also lets the target be a rack or a zone rather
than only a leaf bin, which is what "put this in aisle 3, anywhere" needs. The
read hands back `default_bin_id` from `locations.bin_id` beside it, so the
put-away RPCs that still work in bins need no translation layer. The composite FK
keeps a warehouse from naming another warehouse's location, and its `ON DELETE
SET NULL` carries a **column list** — without one, Postgres would null every
referencing column when a location is deleted, and `warehouse_id` is half the
primary key, so the delete would fail instead of clearing the setting.

**§31 is where step 7 pays for itself.** A reorder point compared against
`on_hand` is the wrong comparison: quarantined or damaged stock is on hand and
cannot cover an order. `replenishment_suggestions()` compares against
`stock_available()` (0061), so a warehouse holding 100 units of which 90 are
blocked correctly reads as needing to reorder — which the test proves directly.
Without step 7 this read would have been confidently wrong. It suggests ordering
up to `max_stock` rather than to the reorder point, because ordering exactly to
the line puts the product straight back on the list. The suggestion is a read,
not a row: computed from current numbers each time, so it cannot go stale and
nothing has to decide when to invalidate it.

`set_warehouse_product` takes a location *code*, because the person setting this
up is reading the rack label. Null means "leave this field alone" for every
field, so one flag can be changed without restating the row — and an empty string
is how a location is cleared, which a null cannot express.

Verified with a self-rolling-back block, **20 checks, all OK**: no row reads as
null rather than an invented default; a full set round-trips with the location,
its bin, the levels, the rule, the supplier and the live stock numbers; a
one-field call leaves the rest alone and an empty string clears the location; an
unknown location, an unknown rule and `max < min` are each refused; with no stock
the product is suggested with shortfall 60 and an order of 200; at 100 on hand it
drops off the list; **quarantining 90 of those 100 brings it back with on_hand
100, available 10, shortfall 50 and a suggested 190**; an inactive row is not
listed; deleting the location clears the setting instead of failing the delete;
the list form and `clear_warehouse_product` behave, the second clear returning
false; and nothing is anon-executable. All ten security invariants pass.

### 0064 — reservations and allocations (Phase A steps 11-12, §5 §6)

§6's flow — Sales Order → Reservation → Allocation → Pick → Pack → Ship — with
the line that decides the design: **Allocationしただけでは在庫を減らさない.**

That is why these are rows and not a status. 0061 already refused to make RESERVED
a stock status, because a reserved unit is still physically on hand and still in
its own condition; moving the quantity into a RESERVED bucket would count the
promise twice, once as a missing unit and once as a claim. So the promise lives
beside the stock instead of inside it, and this is where 0061's own comment —
"step 12 subtracts reservations here, so there is one definition of available" —
comes true.

Two levels, because they answer different questions:

- `stock_reservations` — the promise. 30 of this product, in this warehouse, for
  this order. Says nothing about which 30.
- `stock_allocations` — the plan. These particular parcels will supply it, this
  lot, in this condition. Says nothing about anything having moved.

A reservation with no allocation is a perfectly good state (the promise is made,
the picker has not been told which shelf). An allocation without a reservation is
not, which is why it hangs off one.

`stock_available()` is **redefined, not wrapped**, so there stays exactly one
definition and every existing caller — `warehouse_product_settings`,
`replenishment_suggestions`, `move_stock_status` — gets the complete answer
untouched:

```
available = on-hand in a usable condition  -  reserved
```

It is deliberately **not floored at zero**: a negative means more has been
promised than can ship, which is worth seeing rather than rounding away, and
callers asking "is there enough for N" compare against N and are unaffected.

Four rules the code makes explicit:

- **Neither one moves stock.** No ledger entry, no change to `stock_units`. The
  quantity moves when a pick and a ship say so, which is the only place §37-4's
  record of what happened can come from — the test asserts that the movement
  count does not change.
- **An allocation never blocks a stock movement.** If a shipment consumes stock
  someone else had allocated, the shipment wins: it is what physically happened.
  The allocation becomes over-committed, and `over_allocated_stock()` is the read
  that says so. Same reason `stock_allocations` cascades when a parcel is deleted:
  an allocation is a plan against a parcel, and the promise outlives the plan.
- **Nothing can be promised twice.** A `BEFORE` trigger checks three things no
  constraint can see — that the parcel is the reservation's own product and
  warehouse, that a parcel is not allocated beyond what it holds, and that a
  reservation is not over-supplied. Being a `BEFORE` trigger, it fires before
  conflict resolution, so `ON CONFLICT DO NOTHING` is not an escape hatch.
- **Expiry is honoured by the read, not by a job.** A reservation past its
  `expires_at` stops counting immediately, because `stock_reserved()` looks at the
  clock. `expire_stale_reservations()` tidies the status afterwards and nothing
  depends on it having run — a correctness property that needs a cron to hold is
  not a correctness property.

`allocate_stock()` fills soonest-expiry-first, then from the parcel with least
left so a part-used lot is finished before another is opened, and **reports a
shortfall rather than raising on it**: "I could only find 20 of the 30" is an
answer a picking screen can act on, and rolling the 20 back would help nobody.
`stock_position()` returns the four numbers §5 asks to keep apart — on_hand,
reserved, available, allocated — plus the per-status breakdown.

Verified with self-rolling-back blocks, **30 checks, all OK** (two assertions in
the first run were the test's own mistakes — expecting `ON CONFLICT` to bypass a
BEFORE trigger, and reading a status in the same `format()` call that changed it,
where argument evaluation order is undefined — and were re-run correctly):
reserving 30 of 100 left on_hand at 100, available at 70 and the ledger untouched;
reserving 80 was refused against *available*, not on-hand; quarantining 50 on top
took available to 20; auto-allocation named one parcel for all 30 and still moved
nothing; a second order took the remaining 70 and a direct over-allocating insert
was refused even with `ON CONFLICT DO NOTHING`, while `allocate_stock` itself
returned `allocated 0, short 10` instead of tripping it; releasing freed the
quantity, kept the row as RELEASED and dropped its allocations, and a second
release was refused; a lapsed reservation held nothing while still reading ACTIVE,
and `expire_stale_reservations()` then tidied exactly one row and nothing on a
second run; partial fulfilment left 20 held and the rest closed it as FULFILLED;
shipping 80 out from under a 40-unit allocation left `over_allocated_stock()`
reporting quantity 20 / allocated 40 / over 20 with available at −20;
`stock_position` agreed on all four numbers; and deleting the parcel took the
plan while the promise stayed ACTIVE. All ten security invariants pass.

**Phase A is complete.** All twelve items of §36's Inventory Core list are in
place: product internal id and barcodes (0057), UOM (0059), lot / serial / expiry
(0060), stock status and the stock unit (0061), the location tree (0062),
warehouse products (0063), and available / reserved / reservation / allocation
(0064) — with `product_id` running alongside `jan_code` (0058) as the bridge
between the old shape and the new one.

### 0065 — a SKU can be cleared

0057 wrote `set_product_identity` with `coalesce(v_sku, sku)` so that passing one
field left the other alone. The cost was that a SKU could be set and never
removed: null meant "leave it", and there was no way to say "make it empty".
0063 had already settled the convention — null leaves a field alone, an empty
string clears it — so this brings the older function into line with it, and with
the client, which now offers a SKU field an operator can empty. A field that
silently refuses to clear reads as a bug, and is one.

The fix is to separate the two cases *before* `nullif(btrim(...), '')` collapses
them. Verified with a self-rolling-back block, 6 checks, all OK: a SKU is set;
null leaves it while still changing the tracking mode; `''` clears it;
whitespace clears it too rather than storing spaces; the §37-15 tracking-mode
guard still refuses UNTRACKED once lots exist; and the audit entry records which
of the two happened (`sku_cleared`).

## Client (Flutter) — following Phase A

The database work above added tables and RPCs the client could not see. This pass
made the client speak the new model, with `flutter analyze` clean and **424 tests
passing** (389 before, +35 for the new code).

**Product identity (0057, 0059).** `Product` gained `sku`, `trackingMode`,
`baseUom`, `uoms` and `barcodes`, each as a typed value rather than a loose map,
and the model's own doc comment was corrected — it claimed the JAN was the key
and that no `product_id` was wired into the stock tables, which 0058 made false.
The card now shows the SKU beside the JAN (one is the supplier's, the other is
this warehouse's, and both get scanned), the base unit, each pack unit with what
it converts to, the tracking mode when it is not the default, and the code count
when more than one barcode reaches the product. A product with nothing to say
shows no chips at all.

The form can now set the SKU and the tracking mode, through
`set_product_identity` rather than `update_product` — a second call because it is
a second decision, and the one the server refuses when lots or serials already
contradict the new mode. A rename therefore never risks that refusal: the
identity call is only made when the identity actually changed, which a test
asserts.

**One scan resolver (§26).** `ScanResolution` and `BarcodeResolver` wrap
`resolve_barcode`, so one call answers for a product barcode, a case code, an
internal SKU alias, a serial number or a shelf label. `countedQuantity` is the
number a counting screen adds per scan — 12 for a case code, 1 for a serial, 0
for a location — so no screen re-derives it. An unrecognised code is a *kind*,
not an error, and a kind this build does not know degrades to `unknown` rather
than throwing, which is what lets a later migration add one. The product form
uses it immediately: scanning a code already registered to another product says
so at the point of scanning instead of failing at save.

**§5's four numbers (0061, 0064).** `StockPosition` carries on-hand, available,
reserved and allocated with the per-status, per-lot parcels behind them, and the
ledger screen now opens with them — the two answer different questions and belong
together, since a number that looks wrong is explained either by a movement or by
a hold. `available` is shown as the emphasised figure because it is the one an
outbound decision is made on, and a negative one is called out in the error
colour rather than clamped to zero. A `stock_levels` row whose `product_id` is
still null (0058's honest case) says so instead of showing four zeroes, and does
not call the RPC at all.

### The screens for the rest of it

The pass above left six reads with a data layer and no UI. All six now have one,
in three batches, each verified before the next started. `flutter analyze` clean
throughout; **479 tests passing** (424 at the start of this work).

**Product detail** — `product_lots`, `product_serials`, `add_product_barcode`,
`remove_product_barcode`, `set_product_uom`, `list_uoms`,
`warehouse_product_settings`, `set_warehouse_product`,
`clear_warehouse_product`. The product list was a master with no detail, so nine
RPCs had nowhere to be called from. Tapping a product now opens it and editing
became an action on the detail; sections rather than tabs, because an operator
opening this is checking one thing and scrolling beats guessing which tab holds
it. The lot and serial sections appear only when `tracking_mode` says they can
exist — an empty "Lots" card would invite someone to look for a button that is
not there. Only the units the product actually has a conversion for are offered
when adding a barcode, because naming any other is refused by the derive trigger.
The per-warehouse settings follow the active warehouse (§22's point is that the
answer differs per building) and show the policy beside the live
on-hand/available, because a reorder point only means something next to what is
on the shelf.

**期限管理 and 予約・引当** — `expiring_lots`, `list_reservations`,
`over_allocated_stock`, `release_reservation`. The expiry horizon is a choice
(7/30/90/180 days) refetched from the server rather than filtered locally,
because the server owns today's date and a tablet with a wrong clock must not be
able to hide an expired lot; expired rows stay in the list with their own pill,
since an expired lot is a decision someone owes. On the reservations screen each
promise shows what is pinned to parcels, what has shipped, and what still has no
shelf behind it — that last number matters because no picker can be sent for it —
and a lapsed reservation shows both facts, ACTIVE *and* lapsed, rather than one
overwriting the other. Over-allocated parcels lead the screen with the reason
spelled out: a shipment took the stock first, which is the deliberate trade-off,
not a defect.

**ロケーション and 補充提案** — `location_tree`, `list_location_types`,
`create_location`, `update_location`, `replenishment_suggestions`. The tree
arrives nested from the server and is rendered as nested `ExpansionTile`s, so
collapsing a zone collapses the zone; a bin shows its quantity and a rack shows
nothing rather than a zero, because "no stock here" and "not somewhere stock is
counted" are different answers. Adding under a node pre-fills that node as the
parent *by code*, which is what is printed on the rack. A location's code is
read-only once created, since every scan and every parent reference uses it.
Switching a node off sends only `is_active`, so it cannot accidentally rewrite
the type or the parent. The replenishment list shows available against the line
(not on-hand against the line) and names the blocked quantity, which is the
explanation for a product that has stock and is on the list anyway.

Menu placement follows where the work happens: 期限管理 with the floor tasks,
補充提案 next to purchase orders (its next step is an order), ロケーション and
予約・引当 with the management group. Each entry is gated on the permission its
own RPC checks, and the server remains the real boundary (§37).

## Phase B — Inbound (§11–§14, §26, §29)

Phase A made the stock model expressive: units of measure, lots, serials,
statuses, a location tree, per-warehouse settings, reservations. Phase B is the
inbound half of the floor — §11's boundary chain, which the spec is explicit
should not be collapsed into one step:

    Purchase Order → Inbound/Delivery → Receiving → QC → Put-away → Available Stock

What was already there: `delivery_plans` / `delivery_plan_lines` play the
document, and `delivery_reconciliations` / `reconciliation_lines` play Receipt
and Receipt Line. What was missing is what the rest of Phase B needs:

- **§12's Item level.** A receipt line said "40 of this JAN arrived". It could
  not say "20 on lot A expiring in March, 20 on lot B expiring in June, into
  RECV-01" — and §12 asks for exactly that, because lot / serial / expiry /
  location / quantity is what a parcel *is*.
- **§13's guarantee.** QC existed as `inspections` / `inspection_items`, but
  completing an inspection only wrote a status onto a document. Receiving had
  already made the goods available, so failed goods were shippable. The spec
  does not leave this to the UI: 「QC FAIL / HOLDの商品が誤って出荷されないことを、
  Flutter UIだけでなくRPC/DB側でも保証する」.

### 0066 — the ledger records what moved, not only how much

§5 made `stock_movements` the canonical source and `stock_levels`, `bin_stock`
and `stock_units` three projections of it. But a ledger row carried only a
quantity, so the projection had to invent the rest: every receipt landed as
`(bin null, lot null, serial null, status OK)`, and every issue drew from
whichever parcel sorted first. Phase A could live with that because nothing
posted a movement that *meant* a particular parcel. Phase B cannot: a parcel
that arrives on lot A has to be on lot A in stock, and goods held for QC have to
land as QC_PENDING rather than be moved out of OK afterwards.

So the identity moves onto the ledger row, beside the rest of the movement, and
the projection stops guessing — it applies what the row says:

- `stock_movements` gains `lot_id`, `serial_id`, `status_id`. The first two use
  the composite foreign keys Phase A established (`(product_id, lot_id) →
  lots(product_id, id)`), so a lot can never be attached to the wrong product,
  and MATCH SIMPLE means a null column still satisfies the constraint — which is
  what lets them sit on a table whose own `product_id` is nullable.
- `apply_stock_unit_delta` gains `bin`, `lot`, `serial` and `status` parameters,
  each defaulting to null. Null means "leave that dimension open": on the way in
  that is OK and no lot; on the way out it is "any matching parcel, available
  first" — the behaviour every pre-Phase-B caller already relies on. The
  three-argument form is dropped rather than kept as a wrapper, because leaving
  it beside a version whose extra parameters all default would make every
  three-argument call ambiguous; a three-argument call now resolves to the new
  function with the identity left open, which is what the old one meant.
- `apply_stock_movement_detail` is the whole posting path — stock level, ledger
  row, identity — and `apply_stock_movement` keeps its old signature and
  delegates, so no existing caller had to change. It takes either handle for the
  product: a caller holding a `product_id` never has to look a barcode up.
- `stock_ledger` shows what the ledger now records: lot code, expiry, serial and
  status code per row.

Two things deliberately left alone. The movement's `bin_id` still does not reach
`stock_units`: at warehouse scope a received unit has no bin, which is precisely
what "arrived but not yet put away" means (§14's pending = on_hand − binned), and
`bin_stock` remains the bin-level projection. And an identity-narrowed issue that
cannot be satisfied still *reports* the shortfall rather than refusing — turning
that into a refusal is §13's job, and it lands in 0068.

Proved on the live schema, all of it rolled back afterwards:

| what | result |
| --- | --- |
| receipt of 10 naming LOT-A | the unit is on LOT-A, and the ledger row carries the lot |
| +5 as QC_PENDING on LOT-B | on hand 15, available 10 — held stock is on hand, not available |
| ship 3 naming LOT-A | LOT-A 7, LOT-B 5 — although LOT-B expires sooner and would otherwise have gone first |
| §5's invariant after all three | `stock_levels.on_hand` 12 = `sum(stock_units)` 12 |
| draw 9 from LOT-A when 7 are there | shortfall −2 reported, LOT-B untouched |
| draw 5 of OK when only QC_PENDING remains | shortfall −5, and the held parcel is still whole |
| receive a serial twice | refused: `serial SN-… is already in stock` |
| post another product's lot | refused: `lot 21 does not belong to product …` |

The third and fifth rows are the ones worth keeping: naming a lot redirects the
draw away from the parcel the default ordering would have taken, and a narrowed
draw that cannot be satisfied leaves everyone else's stock alone instead of
quietly eating it.

All ten security invariants pass.

### 0067 — §12's Item level: what actually came off the pallet

§12 asks for receiving at three levels: Receipt (the delivery), Receipt Line
(the ordered line it answers) and Receipt Item (the parcel). The first two
already existed as `delivery_reconciliations` and `reconciliation_lines`. The
third did not, so a line could only say "40 of this JAN arrived". It could not
say "20 on lot A expiring in March, 20 on lot B expiring in June, into RECV-01"
— which is what a pallet actually is, and what every later step needs: QC
inspects a parcel, put-away moves a parcel, a recall traces a parcel.

The thing to be careful about is §5's rule against counting the same stock
twice. `receipt_items` is therefore **not** a fourth stock projection. It is a
document — the record of what the receiver saw and keyed — and each row carries
`movement_id`, the ledger row it posted. The stock came from the movement; the
item says where that movement came from. Deleting every receipt item would lose
the provenance and change no balance.

What the table carries, and why each part is there:

- `lot_id` / `serial_id`, resolved from the **text** the operator keyed. A lot
  is born when goods bearing it arrive, which is here, so the code goes through
  `upsert_lot` rather than being looked up and rejected.
- `expiry`, kept beside `lot_id` on purpose. The lot record may be corrected
  later; this is the date the receiver read off the carton, which is the number
  an argument with a supplier turns on.
- `location_id` / `bin_id`, resolved from the location **code** — what is
  printed on the rack the operator is standing at.
- `status_id`, so a parcel can arrive already held for QC. 0068 is what makes
  that the default for goods that need inspecting; the column is what makes it
  possible at all.
- Composite foreign keys throughout — `(product_id, lot_id) → lots`,
  `(warehouse_id, location_id) → locations`, and a new
  `bins UNIQUE (warehouse_id, id)` so a parcel's bin is tied to the same
  warehouse as the parcel by the schema rather than by a check in every
  function. `ON DELETE SET NULL (location_id)` names the single column, because
  `warehouse_id` is part of the key and must not be nulled with it.
- `check (serial_id is null or quantity = 1)` — a serialised unit is one thing,
  so a parcel that names one is a parcel of one.

Three functions, and one rule about which gate each goes through. The work lives
in `record_receipt_item_impl`, which checks no permission, because its two
callers arrive through different gates: an operator adding a parcel by hand
comes through `record_receipt_item` (`receiving.confirm` + warehouse scope),
while receiving itself comes through `reconcile_delivery_plan`, which the edge
function has already gated and which therefore must not re-check inside the
database.

`reconcile_delivery_plan` gains an optional `items` array per line, and two
things about it changed:

- **A line with no parcels still gets an item level** — one implicit parcel
  covering the whole line. Without that, every existing caller's receipts would
  be invisible to QC, put-away and traceback.
- **Lines are now created one at a time inside the loop** rather than by a
  single set-based insert. That is not a style preference: each entry's parcels
  have to attach to *that* entry's line, and pairing a line row back to the
  array element it came from afterwards depends on an insert order nothing
  promises. Creating the line and its parcels together removes the question.
  Stock is likewise posted per line rather than aggregated by JAN across the
  delivery, which is what §12's Line level means and what makes a movement's
  reference specific enough to trace back to.

Reads: `receipt_detail` returns the receipt at all three levels (with an
`unlinked_items` bucket, so a parcel of an unexpected JAN that belongs to no
line does not silently vanish from the read), and `lot_provenance` answers the
traceability question directly — given a lot, which delivery brought it in, from
which supplier, to which location.

Proved on the live schema, rolled back afterwards:

| what | result |
| --- | --- |
| a line of 40 sent as two lots (20 + 15) | 3 parcels totalling 40 — the 5 nobody attributed became its own parcel |
| each parcel | points at the ledger row it posted, and at its line |
| §5's invariant | on_hand 40 = sum(stock_units) 40 = sum(parcels) 40 |
| where the stock landed | L-A 20, L-B 15, unattributed 5 — on the lots it arrived on |
| the expiry | on the lot and on the parcel, same date; location recorded as T0067-RECV |
| `receipt_detail` | 1 line, 3 parcels, lots L-A/L-B/(none), status `matched` |
| `lot_provenance('L-A')` | T0067-PLAN / Test supplier / qty 20 / at T0067-RECV |
| a later parcel of 6 held for QC | on hand 46, available 40 |
| parcels adding to 12 against a line of 10 | refused — the disagreement is the operator's to resolve |
| a parcel of 2 carrying one serial | refused |
| a line sent with no parcels | one implicit parcel of 2, status OK |

All ten security invariants pass; the guarded-wrapper count goes from 14 to 16.

### 0068 — §13: QC is a real gate, and the database is where it holds

The spec does not leave this one to the interface:

> QC FAIL / HOLDの商品が誤って出荷されないことを、Flutter UIだけでなく
> RPC/DB側でも保証する。

Before this migration QC was a document. `inspections` and `inspection_items`
recorded what an inspector found, and `complete_inspection` wrote a status onto
the inspection — and that was all it did. Receiving had already made the goods
available the moment they were counted, so a carton that failed inspection was
pickable, shippable and indistinguishable from good stock. Every guard was in
the UI, which means every guard was advisory.

Three changes make it real, and it has to be all three: holding goods on arrival
is pointless if nothing releases them, releasing them is pointless if nothing was
held, and both are pointless if shipping can reach into held stock anyway.

**1. Goods that need inspecting arrive as QC_PENDING.** `products.requires_inspection`,
with a nullable `warehouse_products.requires_inspection` override, because the
answer genuinely differs by both: a product may always need checking (regulated
goods) and a warehouse may check a product the others take on trust (a site with
no QC bench cannot hold stock it will never inspect). Null at the warehouse level
means "follow the product". `receiving_status_for()` resolves the two, and
`record_receipt_item_impl` uses it *as the default only* — a receiver who can see
the carton is wet knows more than a flag does, so a named status still wins.

Setting the flag gets its own call, `set_inspection_requirement`, rather than
another optional parameter on `set_warehouse_product`. There, null already means
"leave this alone", and a three-valued flag whose third value is *also* null
("follow the product") cannot be expressed that way. In a call whose parameter is
the whole point, null is unambiguous.

**2. Completing an inspection is what moves the stock.** `complete_inspection`
now walks the items, and since 0060 each one carries the lot or serial the
inspector was holding — so the release lands on the parcel that was actually
checked rather than on whatever sorts first. Passed goes to OK, failed to
DAMAGED (or `p_fail_status`, or HOLD when the item result is HOLD), and a failed
serial has its own `serial_numbers.status` set to HOLD too. Its return type
changes from the old status text to a report of what moved, because "PARTIAL" on
its own does not tell an inspector whether the thirty they passed are sellable;
the edge function re-reads the inspection afterwards and never looked at the old
value, so nothing downstream breaks.

Two judgement calls inside it. An item that records only a result and a count,
without splitting it, is read as "all of it passed" or "all of it failed" —
unambiguous, and better than moving nothing. And quantity the inspection judged
that was *not* sitting in QC_PENDING is reported as `not_in_qc_pending` rather
than refused: inspecting stock that was never held is a legitimate thing to do,
and blocking the QC bench over a bookkeeping gap it cannot fix from there would
be the wrong trade.

**3. Outbound may only draw available stock.** This is the guarantee itself, and
it lives in `project_stock_movement` rather than in `ship_plan` so that the rule
is derived from the ledger row: `quantity` negative, no status named,
`is_outbound_movement(movement_type)`. Every path that posts an outbound movement
is gated, including one written next year by someone who never read this file.
`apply_stock_unit_delta` gains `p_available_only`, and when it is set the check
runs *before* anything is drawn, so a shipment that cannot be satisfied leaves
the stock exactly as it was rather than half-picked.

Three deliberate exemptions. `ADJUST`, `COUNT` and `RECEIPT_CANCEL` are not
outbound types: writing off damaged goods, correcting a count and undoing a
receipt all *need* to reach non-available parcels, and gating them would leave
held stock impossible to dispose of. And a movement that names a status is exempt
whatever its type, because naming QUARANTINE means "I am moving the quarantined
stock on purpose" — that is how disposal works.

`move_stock_status` gets an `_impl` that takes a lot and serial and returns how
much it managed to move rather than raising. Its two callers want different
things from a shortfall: an operator moving 50 by hand should be told there are
not 50; an inspection being closed should move what is there and report the rest.

Reads: `qc_pending_stock` lists what is waiting, newest expiry first, with the
receipt date beside it so the floor can go from "this is held" to "who sent it"
in one tap.

Proved end to end on the live schema, rolled back afterwards:

| what | result |
| --- | --- |
| receive 40 of a flagged product | on hand 40, **available 0** |
| receive 10 of an unflagged one | on hand 10, available 10 |
| `qc_pending_stock` after receiving | the lot ×40 and the serial ×1 |
| **ship 10 of the held stock** | **refused**: `only 0 of … can be shipped (40 on hand, the rest is held or failed)` |
| after that refusal | on hand still 40, available still 0 — nothing half-picked |
| write off 2 by ADJUST | allowed → 38, because disposal is not shipping |
| complete the inspection (28 pass, 10 fail, 1 serial fail) | released 28, failed 11 to DAMAGED, 10 reported as never held |
| the parcels afterwards | OK 28 (lot QC-L1) + DAMAGED 10 (lot QC-L1) — the lot survived the status change |
| the failed serial | its own record reads HOLD, and shipping it is refused |
| ship the 28 released | fine → on hand 10, available 0 |
| ship one more | refused — the remaining 10 are the damaged ones |
| warehouse override on the unflagged product | arrives QC_PENDING here while the product itself still says not required |
| §5's invariant across all three products | holds |

All ten security invariants pass; 17 guarded wrappers.

### 0069 — §14: put-away off the ledger, with a suggestion worth taking

§14 is mostly a warning about what *not* to build:

> 在庫との二重管理を避けるため、queueの数量を独立した在庫として持たない こと。

and `putaway_tasks` only 「将来必要なら」. The existing `putaway_queue` obeyed the
letter of that — pending was `stock_levels.on_hand` minus the sum of `bin_stock`,
so no second quantity was stored. But a subtraction of two aggregates can only
ever answer "how many", and by Phase B the question has become "which parcel".
A queue that cannot say "the forty on lot QC-L1 that are still held for
inspection" cannot route them anywhere sensible.

0066 had already made the answer available: a unit received at warehouse scope
has `bin_id` null, which *is* "arrived but not yet put away". So the queue stops
subtracting and simply reads the parcels that have no bin yet — a stronger form
of §14's rule, not a weaker one. The queue no longer holds a quantity at all,
derived or otherwise; it is a filter over the stock itself. The corollary is that
put-away has to actually move the parcel, so `confirm_putaway` now sets the
unit's `bin_id` as well as writing `bin_stock` (which keeps being written exactly
as before, so every existing reader still works).

**§13, one step earlier.** `bin_accepts_status` says which bin types may hold
stock that is not shippable, and `confirm_putaway` refuses the rest: held goods
in a pickable bin are held goods a picker will eventually pick. And with no
status named, put-away takes only the *shippable* parcels — held stock has to be
named to be moved. That is deliberate: a dock holding thirty good cartons and ten
failed ones has two destinations, not one, and picking the stricter rule for all
forty would strand the good stock while picking the looser would strand the bad.
Naming it makes the operator say which pile is in their hands.

**The suggestion.** §14 orders the criteria — 同一商品が存在するBin → 同一Zone →
空き容量 → 保管条件 → 回転率 — but two of them are constraints rather than
preferences, and the difference is what makes the feature usable:

- **保管条件 is a hard constraint.** A bin that cannot hold this stock is not a
  worse answer, it is not an answer, so it is filtered out rather than
  down-ranked.
- **空き容量 is a constraint only where a capacity is recorded.** Most bins have
  none, and a suggestion engine that refuses to suggest anything until someone
  measures every shelf is one nobody switches on.

The rest are weighted in the spec's order, so a bin already holding this lot (140)
outranks one holding the product (100), which outranks one merely in the product's
home zone (50). 回転率 is the product's SHIP/PICK/TRANSFER_OUT count over 30 days:
a fast mover is nudged toward a PICKABLE bin, a slow one toward staging. Every
suggestion carries a `reason` string (`同一商品あり / 定位置ゾーン / 空き12`),
because that is the difference between a suggestion an operator follows and one
they tap past.

`backfill_stock_unit_bins` brings the two projections into step for stock already
in bins. It is safe to re-run — it only moves units that have no bin yet, and only
up to what `bin_stock` already says. On this database it was a no-op: no bins and
no stock units existed yet, which is also why the model could change without a
data migration.

Proved on the live schema, rolled back afterwards:

| what | result |
| --- | --- |
| receive 30 of a flagged product on lot P-L1 | one queue row: ×30, lot P-L1, QC_PENDING |
| suggestions for that held parcel | only `T69-QC (QC_HOLD)` — the three pickable bins are filtered out |
| put it in a PICKABLE bin | refused: `bin T69-PICK-A is a PICKABLE bin and cannot hold this stock (it is held or failed)` |
| put 30 into the QC bin | moved 30, pending after 0 |
| the queue afterwards | 0 rows — because the parcel moved, not because a counter was decremented |
| `bin_stock` vs `stock_units` in that bin | 30 and 30 |
| the warehouse total | on hand 30, available 0 — put-away relocates, it does not create or release |
| put away one more | refused: `only 0 … awaits put-away` |
| ranking for 10 shippable units | `T69-PICK-B 100 [同一商品あり]` then `T69-PICK-A 0` |
| a capacity-5 bin, parcel of 10 | not offered |
| the same bin, parcel of 3 | offered |

All ten security invariants pass.

### 0070 — §26's one resolver, with a scan context; §29's attachments

§26's complaint is short and specific: 「全画面が独自にJAN判定しない」. There was
already one resolver, and by 0062 it answered product, serial and location. What
it could not do is the second half of the section — 「Scan Contextを持たせ、…
文脈で判定する」 — and that half is where the value is.

A scanner hands over a string. What the string *means* depends on what the
operator is in the middle of: during picking it is probably a location then a
product; during QC it is probably a lot on a carton. Worse, some identifiers are
not globally unique at all — a lot code is unique only within its product — so
without a context there is no correct answer to give.

`scan_contexts` is the vocabulary: eight steps (入荷 / 検品 / 格納 / ピッキング /
梱包 / 出荷 / 棚卸 / 検索), each with an ordered `expects` array. The order does
three jobs:

1. **It resolves ambiguity.** The first kind that matches wins, so the same
   string is a location during put-away and a product during receiving.
2. **It enables branches that cannot work without it.** Given a product, a lot
   code is exact. Without one, the resolver answers only when exactly one lot in
   the company matches — and when several do it returns
   `kind: "ambiguous"` with the candidates and the reason, rather than picking
   one.
3. **It says whether the scan is what this step wanted.** A resolver that quietly
   accepts a product where a location was expected is how stock ends up in the
   wrong bin, and no amount of per-screen JAN-sniffing fixes that.

New branches: lot, receipt (by its reference), delivery (by its note number),
shipment (by number or tracking number), and task. The task branch reads the
labels this system prints — `PICK-12`, `QC-3`, `COUNT-4`, `TO-9` — a convention
this migration establishes rather than one it found, written down because a
printed task label has to say *something*.

**Carton and pallet are deliberately absent.** §26 lists them; Phase C is where
they get a table. A branch that resolves nothing is worse than no branch, because
it reads as though the feature exists.

**§29 — attachments.** The table was already polymorphic, which is the shape §29
asks for. What it lacked is everything that makes a polymorphic table safe:
`attachment_targets` as the vocabulary of what may be attached to (the eleven
§29 lists, plus `receipt_item`) enforced by a foreign key; a `warehouse_id` so
RLS can scope a row; a `kind` (PHOTO / DELIVERY_NOTE / QC_IMAGE / DAMAGE /
DOCUMENT / LABEL / OTHER), because a delivery note and a damage photo are not the
same evidence; and `deleted_at`, because attachments are *withdrawn*, not deleted
— a photo that settled a claim has to stay findable. `record_attachment` keeps
returning the id rather than a jsonb envelope, since the client reads it as an
int.

Proved on the live schema, rolled back afterwards:

| what | result |
| --- | --- |
| `T70-DOCK` during 格納 | location, expected, rank 1 |
| a JAN during 格納 | product, expected, rank 2 |
| the same JAN during 出荷 | product, expected, rank 3 |
| `SHARED-LOT` on two products, no product in hand | `ambiguous`, 2 candidates, with the reason |
| the same code with product B in hand | that product's lot, expiring on its date |
| the delivery note number | `delivery`, named supplier |
| the receipt reference `T70SUP-00001` | `receipt`, status completed |
| `QC-8` during 検品 | `inspection` |
| the same label during ピッキング | `task` at rank 5 — resolvable, just not what picking wants |
| `ABC123` | `unknown`, rather than raising on a failed cast |
| a delivery note attached to the receipt | recorded with kind DELIVERY_NOTE |
| attaching to `unicorn` | refused: `nothing can be attached to unicorn` |
| after withdrawal | 0 visible, 1 including withdrawn |

**0070b — a correction its own test caught.** 0070 computed `expected` as "is
this the *first* kind the context wants", which made a product scan during
receiving read as unexpected — and receiving very much expects product scans. The
`expects` array is a priority order for resolving ambiguity, not a list with one
legal answer. So `expected` became membership and `expected_rank` carries the
ordering, which is what lets a screen tell "exactly what I asked for" from "fair
enough, carry on". Both are recorded as separate migrations because that is the
order the database actually saw them.

All ten security invariants pass.

### 0071 — exception handling: the difference between recorded and dealt with

§36 lists "Exception handling" last in Phase B and §39 puts it in the Inbound
completion checklist, but no section defines it — so it had to be derived from
what inbound actually produces when things go wrong. Reading the pipeline built
in 0066–0070, the pieces were already there:

- receiving computes `shortfall` / `over` / `unexpected` per line, writes the word
  onto the line, and moves on;
- QC records FAIL and HOLD, and 0068 makes those move the stock;
- put-away can find no bin a parcel is allowed into.

Every one of those is a fact that nobody owns. A status on a row tells you what
happened; it does not tell you who noticed, what was decided, by whom, or whether
someone is still waiting for the supplier to answer. That gap is what "exception
handling" names: the difference between a discrepancy that has been *recorded* and
one that has been *dealt with*.

`exception_types` is the vocabulary (thirteen, across RECEIVING / QC / PUTAWAY /
STOCK / OTHER), each with a severity and a `requires_resolution` flag — false for
the ones worth knowing that need no decision, because making the floor close a
ticket saying "yes, four fewer arrived, and the purchase order already says so"
is how a queue stops being read. `exceptions` is the record: what, where (receipt,
line, parcel, inspection, product, lot — nullable individually, because otherwise
it would be a table per source), how much, who raised it, what was decided.

Two rules shape it.

**An exception never moves stock.** Resolving one may call an existing RPC —
`move_stock_status`, `adjust_stock` — and that RPC posts to the ledger as usual.
The exception records the decision; the ledger records the effect. That is the
same separation §5 draws between a document and a projection, and it is what keeps
§37-4 (「履歴削除で帳尻を合わせない」) true: a resolved shortfall leaves both the
original receipt and the correction visible. `resolve_exception` therefore writes
no movement at all — and the three resolutions that mean someone did something to
the goods (RETURNED / SCRAPPED / CORRECTED) require a note, because a resolution
that is only a word is not a resolution.

**Detection is idempotent.** Exceptions are raised at the moment of detection,
inside the operation that detected them, not by a nightly sweep. So each
automatically raised exception carries a `source_key` naming exactly what it was
raised for (`recon:12:line:34:shortfall`), and that key is unique with
`on conflict do nothing` — §37-12's idempotency rule applied to a derived record
rather than to a stock mutation. A person raising one gets no source key, because
the same concern raised twice is two concerns and swallowing the second would lose
a report.

**Wiring without restating.** `reconcile_delivery_plan` and `complete_inspection`
are long, and restating either to add one call would leave two copies of a
function whose behaviour this migration does not change. So the body is read back
from `pg_get_functiondef` and the call is spliced in at a marker, with an
assertion that the marker was there — if either function is ever rewritten in a
way that removes it, this migration fails loudly instead of silently not wiring
detection up. The same technique 0056 and 0060 used.

One documented guess: EXPIRY_TOO_SOON fires at 30 days. That is the only knob here
worth moving later, and it is deliberately not a per-product column yet, because
no such column exists and inventing one to hold a guess is worse than a documented
default.

Proved on the live schema with one deliberately messy delivery — 30 of 40 arrived,
part of it with no lot on a lot-tracked product, part on a lot expiring in a week,
plus three of a JAN nobody has registered:

| what | result |
| --- | --- |
| exceptions raised by that one receipt | 5 |
| | `LOT_MISSING` (BLOCKER) ×10 |
| | `UNREGISTERED_PRODUCT` (BLOCKER) ×3 |
| | `UNEXPECTED_ITEM` (BLOCKER) ×3 |
| | `SHORTFALL` (WARNING) ×10 — 予定 40 に対して 30 |
| | `EXPIRY_TOO_SOON` (WARNING) ×20 — 残り 7 日 |
| running detection again | 0 more raised; still 5 |
| closing an inspection with 4 failed | `QC_FAIL` ×4, carrying the inspector's note |
| `open_exceptions` order | all four blockers, then the two warnings |
| `exception_summary` | 6 open, 4 blockers |
| resolving as SCRAPPED with no note | refused |
| resolving as ACCEPTED | on hand 30 before, 30 after — the decision moved nothing |
| cancelling a resolved exception | refused |

All ten security invariants pass; 18 guarded wrappers.

### Phase B (Inbound) — done

All seven items of §36's Phase B list are in the database and exercised against
it: Receiving (§11/§12, 0066–0067), QC (§13, 0068), Put-away and its suggestion
(§14, 0069), Barcode flow (§26, 0070/0070b), Attachments (§29, 0070), Exception
handling (0071). §11's chain is now a chain rather than a single step:

    Purchase Order → Inbound/Delivery → Receiving → QC → Put-away → Available Stock

and each arrow is something the database enforces rather than something the UI is
trusted to do in order. The Flutter client is the next piece: nothing above is
reachable from the app yet.

### 0072 — a hole in 0068, found while wiring the receiving client

0068 let a named status override `receiving_status_for()`, on the reasoning that a
receiver who can see the carton is wet knows more than a flag does. That reasoning
is right, but "a named status wins" was too broad in one direction.

The receiving path runs through `reconcile_delivery_plan`, and the edge function
passes its `p_lines` payload through verbatim. So a client could send
`{"quantity": 40, "status": "OK"}` for a product whose flag says QC_PENDING and
receive it straight into shippable stock — which is precisely what §13 asks the
database to prevent. A guarantee a `receiving.confirm` holder can opt out of by
naming a status is a UI convention with extra steps.

The rule that keeps the useful half and closes the hole: **a named status may only
make a parcel more restricted, never less.** If the product requires inspection,
the receiver may name QC_PENDING, HOLD, DAMAGED or QUARANTINE, and is refused if
they name one that counts as available. Nothing is lost — the wet-carton case
names DAMAGED, which is more restrictive, not less.

| what | result |
| --- | --- |
| a client naming `OK` for goods that must be inspected | refused: `… must be inspected, so it cannot be received as OK — record it as QC_PENDING, or as DAMAGED/HOLD if it arrived bad` |
| the wet-carton case (4 DAMAGED + 6 default) | accepted — `DAMAGED x4 + QC_PENDING x6`, on hand 10, available 0 |
| naming `OK` for a product that needs no inspection | fine, available 10 |
| no status named | the flag still decides: OK |

All ten security invariants pass.

## Client (Flutter) — following Phase B

Phase B's database work is only worth having if the floor can reach it. Five
pieces, in the order they were built, because each depends on the one before.

### §26's scan contexts

`BarcodeResolver.resolve` takes the step it is being used in, and the resolution
says whether what came back is something that step expects. `ScanKind` gains lot,
receipt, delivery, shipment, task, inspection and `ambiguous`; `ScanResolution`
gains the document, task and lot fields, `expected` / `expectedRank`, and the
candidate list an ambiguous lot code comes back with.

The distinction worth naming is `isOutOfContext`: "I do not know this code" and
"this is not what you need right now" are different sentences to show an operator,
and only the second one can be answered helpfully. `scanResolutionProvider` is
keyed on the whole request rather than the code, because the same string resolves
two ways in two contexts and one cache key would serve the put-away answer to
receiving.

### The exception queue

A work queue, not a report. Blockers first in the server's order, so the two agree
when the list is long; finished work hidden unless asked for, because a queue that
keeps its finished work is a list nobody reaches the bottom of.

Three decisions worth keeping:

- The resolve sheet asks for the note the server requires on RETURNED / SCRAPPED /
  CORRECTED *before* sending, so an operator fixes a form rather than reading a
  400. And it says, in the sheet, that recording a decision moves no stock —
  because someone choosing 廃棄した will otherwise assume it did.
- An exception type the build has never heard of still displays, using the name
  the server sent. The vocabulary is data (`exception_types`), not a client
  constant.
- Filtering by stage and showing closed rows are questions put to the server, not
  local filters: the work queue and the history are different lists.

### §13's gate, made visible

The gate holds in the database whether or not the UI mentions it — but an operator
who does not know a failure will move the goods out of shippable stock will be
surprised by it, and surprise is how workarounds start. So:

- the inspection detail warns, before the tap, what completing will do;
- afterwards it reports what actually moved — released to OK, held and where, and
  how much was judged that was never in QC_PENDING. "PARTIAL" alone does not
  answer "are the 28 I passed sellable now", which is the question being asked;
- a new screen lists stock held for QC, because held stock is invisible in the
  numbers people normally read: it counts toward on-hand and not toward available,
  so a product can say "100 in stock" and ship nothing.

The edge function now returns `complete_inspection`'s report as `stock_effect`
alongside the inspection, and passes `fail_status` through so a workflow can
quarantine rather than damage without a migration. The inspection repository holds
two clients, because it spans two doors: writes go through the edge function (the
only gate in front of service_role RPCs), while `qc_pending_stock` is an ordinary
guarded read.

### Parcel-level put-away

0069 changed the queue's shape, so the client had to follow — the old model's
`binned_quantity` and `suggested_bin_*` fields no longer exist, and reading them
would have silently shown a zero where a figure used to be. `PutawayTask` is a
parcel now: lot, expiry, serial, stock status, and the ranked suggestions with the
server's reason for each. `confirm_putaway` names the lot and, for held stock, the
status — with no status the server moves only the shippable parcels, so held stock
has to say so to move at all.

`capacity == null` is kept distinct from zero, because that distinction is exactly
why §14's capacity criterion is a preference and not a hard rule.

### §12's parcels in receiving

`ReceivedParcel` is the client's Receipt Item: how many, on which lot, expiring
when, which serial, where it was put. Parcels are optional detail on top of the
line's total rather than a replacement for it, mirroring the server — so an
operator who just counts still gets a receipt, and one who records lots gets a
traceable one. The remainder is shown rather than hidden: it is the part that will
land as one unattributed parcel.

Two behaviours chosen deliberately in the controller:

- **A parcel raises the line to cover it.** A parcel in the operator's hands is
  stock that arrived, and the server refuses a line whose parcels exceed it.
  Lowering the total is left to the operator: silently dropping a parcel to make
  the arithmetic work would lose a record of something physically present.
- **Parcels survive a re-count.** Scanning one more carton of a line whose lots
  are already recorded must not throw the lots away.

The sheet offers exactly one status, DAMAGED, as a checkbox. 0072 refuses a status
that would make a parcel *less* restricted than its product requires, so a picker
would mostly offer choices the server rejects; the case that actually happens on a
dock is "this carton arrived wet".

### Reading a receipt back

`ReceiptDetailScreen` is the reason the Item level exists. A week after a
delivery, "which lot did that bring, and where did it go" is a question somebody
asks, and before parcels were recorded the only answer was to find whoever was on
the dock. The screen shows all three of §12's levels, reached by tapping a row in
the receipt history — a cancelled receipt opens too, because reading what a voided
receipt said is exactly when someone needs to.

Three details carried deliberately:

- **Each parcel shows the ledger row it posted.** That is §5's argument on screen:
  the stock came from the movement, and the parcel only records where the movement
  came from, so nothing is counted twice.
- **The unattributed remainder is named, not blank.** "5 of something" and "5 we
  cannot trace" are different facts.
- **Held units are called out on the receipt that created them** — the figure that
  explains a receipt whose goods are on hand and unusable.

Parcels belonging to no ordered line get their own section rather than vanishing
from the read: a carton nobody ordered is exactly the thing you want to see.
`lot_provenance` is wired in the repository and providers for the traceability
question ("which delivery brought this lot"), ready for the product detail to use.

Deliberately absent: a "this lot-tracked line has no parcels" warning. The plan
line does not carry the product's tracking mode, so the client cannot tell which
lines need one without another read — and 0071 already raises a LOT_MISSING
exception for exactly that case the moment the receipt is posted. A guess here
would be a worse version of a check that already exists.

### §29's attachments, made real

The last gap in Phase B's client surface: `attachment.dart` and
`attachment_repository.dart` only knew the plain table shape from 0031, not what
0070 actually built — a `kind` (photo/delivery note/QC image/damage/document/
label/other), a caption, a byte size, a building, and withdrawal instead of
deletion.

`list()` now reads through `attachments_for` instead of a raw `GET /attachments`
filter, because that is where 0070 put the warehouse scoping and the withdrawn
filter — reading the table directly would have shown withdrawn rows to a client
that has no way to know they should be hidden. `upload()` sends the kind, caption
and the byte size the client already has (no reason to make the server ask
Storage for it). `withdraw()` calls `withdraw_attachment` rather than deleting a
row, matching 0070's actual guarantee: a photo that settled a claim stays
findable.

On the inspection screen, a photo taken during QC is now tagged `QC_IMAGE` with
the building attached, not filed as an undifferentiated blob — §29 asks for the
kind precisely so a later claim can find the right file among everything attached
to a receipt. Tapping a thumbnail opens what it is and, while the inspection is
still open, offers to withdraw it, with the same "withdrawn, not deleted" wording
the confirmation promises actually being what happens server-side.

## Phase C — Outbound (§6, §15–§17, §36)

Phase A left the outbound half half-built on purpose. 0064's header said so
outright: `stock_reservations.reference_type` already accepts `'sales_order'`
and `'shipment'`, and its comment on the loose reference pair reads "the orders
these point at live in tables Phase C builds". What actually existed was two
disconnected halves — a complete Reservation/Allocation engine nothing called,
and a sales order (0034) that was pure bookkeeping, explicitly "not wired into
shipment_plans/picking".

Worth stating plainly, because it changes what Phase C has to build: the ledger
side of shipping is already identity-correct. `apply_stock_movement` delegates to
`apply_stock_movement_detail` (0066), whose insert fires `project_stock_movement`,
which calls `apply_stock_unit_delta` — and 0068 made that draw FEFO from
available-status parcels only, with the shortfall check before anything is taken.
Since the trigger fires on the row and not on the caller, the legacy `ship_plan`
has been drawing stock correctly, lot by lot, since 0068 was applied. Phase C
does not need to rewrite shipping to get that; what it needs is everything
upstream of it.

### 0073 — approving a sales order makes the promise real

The gap this closes: two approved sales orders for the last 10 units on hand
could both say yes, because "approved" promised nothing to inventory. §6's flow
starts `Sales Order -> Reservation`, and nothing was performing that arrow.

Approval now reserves, line by line, and the decisions worth recording are all
about what happens when it cannot:

- **Best-effort, not all-or-nothing.** A line can name a JAN with no product
  record yet — the same "unlinked" case 0067 tolerates on receiving — or ask for
  more than is available. Neither blocks approving the order. The commercial
  question (do we accept this order) and the inventory question (can we back it
  right now) are different, which is §34's own rule about keeping order and
  execution apart. Approval returns which lines got a reservation and which did
  not, with the reason and the numbers, so a shortfall is seen at approval
  rather than discovered at pick time.
- **`stock_available` is read per line inside the loop**, so two lines of the
  same product on one order cannot both be promised the same units. The second
  one sees what the first just took.
- **The reservation is inserted here, not through `reserve_stock`.** That RPC
  re-checks `sales_order.manage` or `inventory.adjust`; an approver holding only
  `sales_order.approve` — the role this function exists for — would be unable to
  finish approving. Approving *is* the authorization for the promise. Gating it
  twice would add no safety, only a trap for the correctly-scoped role.
- **`approve_sales_order` returns jsonb now, not boolean**, which needed a drop
  and recreate: a return type is not something `create or replace` can change.

`create_shipment_from_sales_order` turns an approved order into something the
floor can pick, and **re-keys the reservation from the order to the shipment
rather than creating a second one**. The promise was made once, at approval;
becoming a shipment moves where it is filed, not what it is — which the test
proves by asserting availability is unchanged across the move. A partial unique
index (`sales_order_id where status <> 'cancelled'`) allows at most one live
shipment per order, because a second would draw against reservations the first
already claimed. Every order line becomes a shipment line, including one whose
JAN never resolved: the shipment is what the customer ordered, and a line nobody
could reserve still has to be picked or explained.

Cancelling an approved order releases what it reserved, allocations included,
inlined for the same permission reason as above. A *rejected* order needs no
such logic and has none — rejection only follows SUBMITTED, which is before any
reservation exists.

Tested against live data in one rolled-back block: 100 received through the
ledger, an order for 30 plus a ghost JAN approved with one reservation and
`unlinked_jan_code` reported, availability 100 -> 70, a second order for 90
approved while reserving nothing (`insufficient_available`, available 70), the
shipment created with both lines and the reservation re-keyed to `shipment:12`
with availability unmoved, a second shipment for the same order refused by the
index, `sales_order_detail` showing both the shipment and the reservation, and a
third order approved then cancelled returning availability to 70. All 10
security invariants still pass (18 guarded wrappers).

### 0074 — §16's picking rule, and §15's pick detail

§15 says a pick task carries `stock/lot/serial` and a `source_bin`. Ours carried
a JAN and a quantity, so a picker was told "40 of this product" and the ledger
decided for itself which lot left — FEFO, via 0068's draw order. That is a good
default and the wrong answer whenever reality differs: if the front carton of the
soonest-expiring lot is crushed and the picker takes the next one, nothing
recorded it, and the lot the system believes it shipped is not the lot the
customer received. For a recall that difference is the entire reason to track
lots.

**The shape mirrors receiving, deliberately.** Phase B solved this problem
inbound: a delivery line said "40" and `receipt_items` (0067) recorded which
parcels those were. Outbound is the same table one door over:

    shipment_line  ->  pick_task    (how much to pick — the order)
    receipt_items  ->  pick_items   (which parcels it was — the fact)

`pick_items` is optional detail on top of the task's total, exactly as parcels
are on a receipt. A picker who keys 40 still closes the task; one who scans lots
gets a traceable pick. `picked_quantity` remains the task total — recomputed as
the sum of its parcels — so 0018's generated `variance` and `status` columns keep
working and no existing caller changes.

Three decisions worth keeping:

- **Nothing here moves stock.** 0018 was right that picking is a state of the
  order; the building's stock is unchanged until it ships. The test asserts
  `on_hand` is still 100 after a pick. Drawing the ledger against exactly these
  parcels is 0075's job.
- **Suggestions are not stored.** `pick_candidates` is a read, the same way
  `putaway_suggestions` (0069) is. A suggestion written onto the row would invite
  "was this what the system said or what the picker did", and there is no good
  answer to that. Reality lives in the row; advice lives in a function.
- **The parcel knows its own identity better than the caller.** Given a
  `stock_unit_id`, `record_pick_item` fills lot, serial and bin from it, so a
  scan of a shelf label cannot disagree with what is on that shelf.

§16's rule takes the same three-part shape as 0068's `requires_inspection`: a
product default, a nullable per-warehouse override where null means "follow the
product", and one resolver (`picking_rule_for`). **FEFO is the global default,
not FIFO** — §16 says food prefers it, and more importantly 0068's
`apply_stock_unit_delta` already draws expiry-first, so FEFO is the one setting
where the advice a picker is given matches what the ledger does if nobody names a
lot.

`pick_candidates` orders by the rule and reports what it cannot cover as `short`
rather than raising, because "I can only find 30 of the 40" is something a picker
can act on. It offers only `counts_available` parcels (0068's rule — advice the
ledger would refuse is not advice) and subtracts existing allocations, so two
pickers are not sent to the same box. `pick_task_candidates` asks for what is
still outstanding on the task, so re-opening a part-picked task advises the rest.

`start_pick_list` now fills `product_id` when it seeds tasks, rather than leaning
on 0058's backfill: a task should know its product from the moment it exists.

Tested against live data with a fixture built so **FEFO and FIFO disagree** — lot
A expires sooner but arrived later, lot B expires later but arrived first — which
is the only way to prove a rule is honoured rather than one accidental ordering
looking right. FEFO led with A (take 40, then 10 of B, short 0), FIFO with B,
LIFO with A; clearing the warehouse override fell back to the product's MANUAL
default; `start_pick_list` filled `product_id`; a pick of 30 from the
later-expiring lot recorded that lot; over-picking one parcel and an unknown lot
were both refused by name; `pick_list_detail` carried the rule and the parcel;
removing the last parcel returned the task to unpicked (null, not zero — "not
picked yet" and "picked zero" are different states); and `on_hand` never moved.

### 0075 — shipping draws on what was picked, and keeps the promise

§6's last two arrows, finally connected:

    Sales Order -> Reservation -> Allocation -> Pick -> Pack -> Ship
                   ^^^^^^^^^^^ 0073                            ^^^^ here

**A shipment now posts one movement per parcel**, carrying the lot and serial
`pick_items` recorded. Before this, `ship_plan` posted one JAN-level movement per
line and 0068's draw order chose a lot for itself — right by default, wrong in
exactly the case 0074 exists to capture. Quantity a task carries *without* parcel
detail still posts as before, JAN-level and FEFO-drawn, so a warehouse that never
scans a lot sees no change at all. `greatest(picked - detailed, 0)` splits the
two, per task rather than per JAN, so one line scanned and another keyed still add
up to what left the building.

**Shipping fulfils the reservations filed against it.** It moves no stock — the
movements above did that, and doing it twice is the double count §5 warns about.
What it records is that the promise was kept, so availability rises because the
stock left rather than because the promise was forgotten. How much to fulfil comes
from the ledger, not the order lines, so a plan edited after shipping cannot
credit the wrong amount; and what is already fulfilled is re-read on each pass, so
two reservations for one product on one shipment share it instead of both claiming
all of it.

`fulfil_reservation` is deliberately not called. It re-checks permission against
the caller, and `ship_plan` runs as service_role behind the shipments edge
function, where `auth.uid()` is null and the gate has already been passed — the
same reason 0073 inlined its own inserts.

**Cancelling reverses parcel by parcel.** This is the part worth pausing on: 0018
reversed `shipped_net`, which aggregates per JAN, and a reversal with no lot would
put the quantity back as a *lot-less* parcel. The warehouse total would be right
and the lot attribution silently wrong — the one thing this migration exists to
prevent. Grouping the movements by identity and negating each group's net also
makes cancel idempotent for a plan shipped, cancelled and shipped again. Status is
not restated (the SHIP row carries none, which is what arms 0068's gate), so stock
returns as OK — which is what it must have been, since `record_pick_item` only
accepts a parcel in a shippable condition.

`shipment_parcels` is the read a recall starts from: which lots went to this
customer, and when. SHIP_CANCEL rows are shown as they are, because a reversal is
part of the answer rather than noise.

**A known limit, stated rather than hidden.** `apply_stock_movement_detail` does
not pass `bin_id` down to `apply_stock_unit_delta` (0066: at warehouse scope a
unit is "in the building", and a receipt has no bin until put-away). So a movement
records the bin the picker took from, but the parcel the draw lands on is chosen
by product + lot + status. With one lot split across two bins, `stock_units` can
attribute the decrement to the wrong bin while warehouse and lot totals stay
exactly right. Fixing it means letting a negative movement with a bin draw from
that bin, which would also change transfers and adjustments that name one — a
separate concern for a separate migration.

Tested end to end against live data in one rolled-back block: 30 of lot A and 70
of lot B received plus 50 of an untracked product; a sales order for 40 + 20
approved into two reservations (availability 100 -> 60 and 50 -> 30); a shipment
created from it; **the picker recorded 40 from lot B, the one FEFO did not
suggest**, while the other line was keyed as a bare 20 the pre-0074 way; after
shipping, lot A was untouched at 30 and lot B was 30, the untracked product 30, no
lot-less parcel existed, `shipment_parcels` returned one row per identity, and
both reservations read FULFILLED at their full quantity. Cancelling restored lot B
to exactly 70 (not a nameless pile), the untracked product to 50, and both
reservations to ACTIVE with nothing fulfilled.

### 0076 — §17's cartons: weight, dimensions, status and the label

§17 asks "どの商品がどの箱に入ったか" and lists what a carton should carry.
`shipment_cartons` (0008) had a number and a free-text label; weight, carrier and
tracking lived on the *plan* (0039). That is fine for a single-box shipment and
wrong for three, because **a carrier prices each box** — so weight, dimensions,
type and tracking moved onto the carton. And a carton item with no lot cannot
answer §17's question at all: a recall needs "lot L-B went to this customer in
carton 2", not "something went in carton 2".

Decisions worth keeping:

- **Carton status is a lifecycle, and the plan drives its end.** OPEN while being
  filled, PACKED when the packer closes it, SHIPPED once the plan ships. That
  last transition is a **trigger on `shipment_plans.status`**, not a line in
  `ship_plan`, because the plan's status is reached from more than one place (the
  edge function, `ship_plan`) and a rule that lives on the column cannot be
  bypassed by whichever path is written next year. Un-shipping returns SHIPPED
  boxes to PACKED — closed, not re-opened: changing a box's contents is a thing
  someone says explicitly.
- **Nothing goes in a box that did not come off a shelf.** `packable_quantity` is
  what was picked when the shipment went through picking, and what was ordered
  when it did not. The ceiling is **per product, not per (product, lot)**: 0074
  deliberately keeps the bare-quantity pick path, so a lot picked without being
  scanned would otherwise be unpackable. A consequence worth stating: once
  picking has started, a task with nothing picked yet contributes zero, so
  packing that product waits for the pick to be recorded.
- **A lot code alone is not an identity.** `pack_carton_item` refuses a lot code
  with no JAN and no stock unit, because lot codes are per product — "L-A" names
  a product's lot, not a product. The test asserts that refusal, which is how the
  rule got written down: the first draft of the test made exactly that mistake.
- **A closed box's contents are frozen**; its weight and tracking are not. Those
  are facts about the box rather than about what is inside it, and correcting a
  mistyped tracking number should not require reopening anything.
- **The label is a read.** `carton_label` returns carton n of m, the customer,
  carrier, tracking (the box's own, falling back to the plan's), measurements and
  contents with lot codes. A label stored at pack time would be a copy that goes
  stale the moment a tracking number is corrected.

`autopack_shipment` (0039) split *order lines* into boxes. Once the picker has
recorded parcels the order lines are the wrong source — they cannot say which lot
went in which box — so it now fills from `pick_items` when they exist and falls
back to the lines exactly as before when they do not, the same two-source rule
`ship_plan` follows. Its result says `from_picked_parcels`, because "why does my
carton have no lot on it" should not be a mystery from the outside.

Tested against live data in one rolled-back block: 50 picked as 30 of L-A and 20
of L-B; `packable_quantity` = 50; an empty carton refused a close; a lot code
without a product refused; 30 of L-A packed leaving 20 unpacked; 25 more refused
by name with the numbers; a second carton took the remaining 20 and one more unit
was refused; measurements set and the box closed; a closed box refused an edit,
reopened, and closed again; the label read 1/2 with TRK-1, 12.5 kg and L-A in its
contents; `shipment_packing` showed 50/50/0 across two cartons; shipping flipped
both boxes to SHIPPED and cancelling returned them to PACKED; and autopacking a
second shipment of 10 at 4 per box produced 3 boxes, `from_picked_parcels` true,
with lot L-B on every item.

### 0077 — §15's wave, and the walk it exists to save

A wave that is only a folder holding several pick lists satisfies the word and
none of the point. The substance is `wave_pick_plan`, and the arithmetic it
exists for:

    Three orders, each wanting 10 of the same product from the same rack.
    Three pick lists  -> three walks to that rack, 30 units in three trips.
    One wave          -> one line on the sheet: "R-01-A, lot L-B, take 30",
                         knowing which of the three tasks each unit is for.

That aggregation is a read, the same choice 0074 made for `pick_candidates` and
0069 for `putaway_suggestions` — advice lives in a function you can call again;
what a picker actually took lives in `pick_items`, unchanged by any of this.

**The hard part**: aggregating suggestions across tasks cannot just call
`pick_candidates` per task and add the results — each call would offer the same
parcel to every task, telling one picker to take 30 from a box holding 10. So the
plan walks tasks in priority order carrying a map of what earlier tasks already
claimed, subtracting as it goes. A task that cannot be covered is reported short
rather than silently rounded, in its own list next to the sheet — a picker needs
the stops, a supervisor needs to know the wave cannot be filled before anyone
walks it.

**A wave does not move stock, reserve anything, or change what a pick list
means.** Its lists are ordinary pick lists — `record_pick_item` and
`complete_pick_list` work on them unchanged, and a list can finish on its own
whether or not its wave does. Cancelling a wave releases its lists (nothing
moved, nothing to reverse) and leaves any picking already recorded in place,
because that picking happened.

Tested against live data: 100 units of one product in a single lot (plentiful)
and only 20 of a second product split across two parcels (scarce, so three
orders of 10 cannot all be filled) with three shipments each wanting 10 of both.
The wave built three lists; the sheet aggregated the plentiful product into
**one stop of 30 naming all three tasks**; the scarce product produced two
stops summing to exactly 20 with neither parcel over-promised, and the third
order's 10 came back in `short` rather than silently promised. Assigning
started the wave; handing it back cleared the person without losing progress;
an unpicked wave refused to complete; picking everything and completing closed
every list; cancelling a fresh wave released its list without moving stock; and
an unknown shipment id in the batch was reported, not fatal.

### 0078 — a hole 0074 opened, found by the invariant check it was meant to catch

0074 rewrote `pick_list_detail` to add each task's parcels and picking rule, by
replacing the function wholesale. That function was not the reader, though — since
0051 it had been a **guarded wrapper**: `has_permission('pick.confirm')` plus
`can_access_warehouse` on the list's own warehouse, delegating to
`pick_list_detail_impl` for the actual read (0056 added the warehouse half
specifically because a wrapper with a permission check and no scope check was
exactly the gap found then). Replacing it with a plain body removed both checks
while the grant to `authenticated` stayed in place — a read, callable straight
over PostgREST, that would hand any signed-in user any warehouse's pick list.

`verify_security.sql` caught it on the next run: invariant 3 (guarded wrappers)
and invariant 8 (warehouse-scoped wrappers) both dropped from 18/18 to 17/18,
naming `pick_list_detail`. No functional test would have caught this — the
*behaviour* was right, 0074's own live-data test passed cleanly. Only the *reach*
was wrong, which is precisely what these ten checks exist to catch instead of a
behavioural test.

Fixed forward: 0074's enriched body becomes `pick_list_detail_impl`, and the
wrapper is restored to exactly 0056's shape. Not fixed by editing 0074 itself —
a migration that has run is history, the same rule §37-4 states for the ledger
applied here to schema.

**The lesson, stated so it needn't be re-learned**: before replacing a read
function, check whether a `<name>_impl` sibling exists. If it does, the thing to
edit is the `_impl`, never the wrapper.

### 0079 — a safe way to rename a carton

Found while starting the carton-packing client rewrite (below), not by a user
report. 0076 gave carton items real identity (`lot_id`/`serial_id`), but the
only way left to rename a carton's free-text `label` was the `shipments` edge
function's `PUT .../cartons/:cid` — which replaces the carton's *entire item
list*, and the payload shape it inserts from has no lot or serial columns at
all. Once a carton holds identified parcels, calling that route to rename the
box would silently discard the identity `pack_carton_item` recorded — the
exact traceability §17 exists for. A rename must not be able to do that.

`set_carton_label(p_carton_id, p_label)` touches the `label` column and
nothing else, guarded the same way `set_carton_measurements` already is
(`pack.complete` + warehouse scope, refused once a carton is CANCELLED).
Direct-`authenticated`, no `_impl` sibling — the same posture 0076's own
mutation RPCs use, so it does not appear in `verify_security.sql`'s wrapper
checks (3/8) or its curated edge-gated `mutation_rpcs` list (7); all ten
invariants held at 18/18 after applying it live.

## Client (Flutter) — following Phase C

### Sales order: approval made visible, and the order becomes a shipment

`SalesOrderRepositoryImpl.approve()` posted to `approve_sales_order` and checked
`response.data == true` — the boolean the RPC returned before 0073. Once 0073
changed it to return jsonb (reserved lines and why others were skipped), that
check could never be true again: **every approval on the live app was reporting
failure to the user, even though the database call succeeded and reserved
stock.** Nobody had reached this client since 0073 shipped, so nothing had
caught it. This is the first thing fixed, ahead of anything new: `approve()` now
returns `SalesOrderApprovalResult`, and the detail screen shows what was
actually reserved — a clean approval as a plain confirmation, a shortfall as a
SnackBar with a "詳細" action opening a dialog that names each skipped line and
why (unlinked JAN vs. insufficient available, with the numbers).

`create_shipment_from_sales_order` is now reachable: an approved order with no
shipment yet offers "出荷を作成" as its primary action instead of "完了にする" —
approving only reserves stock (0073), and turning that into something the floor
can pick is a separate, explicit act. Once a shipment exists, the primary action
reverts to closing the order's own bookkeeping, and a reservations card (§6,
made visible) shows each line's `fulfilled / quantity` with a link to open the
shipment. Completing without ever creating a shipment is still possible — 0073
places no such requirement — it is simply no longer the thing offered first.

Tested against the fake repository: a clean approval, a shortfall with its
detail dialog, an approved order with no shipment offering to create one and
navigating straight to it on success, and an approved order that already has
one offering both "出荷を開く" and "完了にする". The old lifecycle test (submit →
approve → complete) now runs submit → approve → **create shipment** → complete,
which is the flow 0073 actually built.

### §15's wave picking, reachable (0077)

New feature module (`lib/features/wave/`) rather than folded into the existing
picking feature: a wave groups pick lists but does not change what one is, and
`record_pick_item`/`complete_pick_list` (picking feature) work on its lists
completely unchanged — wiring it in as a sibling that links out to the existing
`PickListDetailScreen` for the actual recording keeps that boundary honest
instead of duplicating it.

**The sheet (`PickWaveSheetScreen`) is why a wave exists**, so it is built
first and tested hardest: the fixture asks three shipments for 10 of the same
parcel each, and asserts the sheet shows **one card reading "30", not three**,
with `waveSheetForOrders(3)` naming how many orders that card is for. A second
product split thin across two parcels and a third order's shortfall prove the
per-parcel claim-tracking and the shortfall list separately — both come
straight from `wave_pick_plan`'s own aggregation, the client only renders it.

The detail screen exposes the lifecycle 0077 built: assign / hand back (a
`FilledButton`'s enabled state is the refusal — completing is disabled, not
hidden, while `pickedCount < taskCount`, so the reason ("未ピックの明細が残っています")
reads on the button itself rather than in a dialog reached only after tapping
a dead action), complete, and cancel. Assignment needed "who am I" for the
first time in this codebase — `authControllerProvider`'s user id compared
against the wave's `assignedTo` — so `harness.dart` gained
`fakeAuthControllerFor`, a real `AuthController` backed by a repository that
always answers with one fixed user, because the provider's type
(`StateNotifierProvider<AuthController, AuthState>`) accepts nothing looser.

Creating a wave reuses `pickableShipmentsProvider` (already built for starting
a single pick list) behind a multi-select sheet — no new "which shipments are
open" query, just a different selection widget over the same list.

### §16's picking-rule advice, and §15's parcel recording (0074)

`PickListDetailScreen` recorded a pick by overwriting the task's total —
`recordPick(taskId, quantity:)` set what the task's picked quantity *was*, so a
second call after a short pick corrected the figure rather than adding to it.
0074's `pick_items`/`record_pick_item`/`remove_pick_item` are additive, the
same shape `receipt_items` already has on the inbound side: each call records
one more parcel, and the task's total is the sum of what is on it. Wiring
this in meant changing what "recording a pick" means on this screen, not just
adding a field.

`recordPickItem` replaces `recordPick` as the call the dialog makes. The
quantity field now prefills from `task.outstandingQuantity`
(`plannedQuantity - pickedQuantity`, clamped to zero) rather than the running
total, so reopening the dialog after a partial pick starts the operator at
what is still needed, not at the whole plan again. `_TaskCard` renders each
recorded parcel (`L:{lot}` / `S/N:{serial}` or `pickItemNoLot` when neither
was given, plus its quantity and a remove button) and, only when the recorded
sum falls short of the picked total, a `pickItemUnattributed` warning — the
same "recorded but not yet attributed to a lot" shape `parcelUnattributed`
already has for receiving.

Before the dialog opens, `PickingRepositoryImpl.candidatesFor(taskId)` asks
`pick_task_candidates` for §16's advice — which lot to take and why, in the
product's picking-rule order (FIFO/FEFO/LIFO/MANUAL) — but only when the task
resolves to a product; an unlinked JAN has nothing to advise on, and the call
is skipped rather than sent to fail. The dialog shows the top candidate's
server-composed Japanese `reason` string (e.g. "期限が近い順（FEFO）:
2027-01-01") next to a lightbulb icon, and pre-fills the lot code field from
that candidate — a suggestion the operator can overwrite, not a constraint
the dialog enforces; §16 is advisory, not a scan-time gate the way the JAN
check is.

`PickingRepositoryImpl` now carries a second Dio for these RPCs (`_rest`/
`_rpc`, from `restDioProvider`), the same two-Dio shape `ShipmentRepositoryImpl`
already uses for its own split between the edge-gated writes
(`start`/`complete`/`cancel`) and the directly-`authenticated` ones 0074 added.

Tested against the fake repository: recording two parcels for one task shows
both with their own remove button and no unattributed warning once they sum to
the total; the quantity field's prefill is asserted directly on the second
pass (outstanding, not the plan); removing a parcel takes it back off the task
and restores the full plan as the next prefill; and the advisory reason text
and lot pre-fill are asserted from a fixture `PickCandidates` before any
recording happens.

### A carton's own facts and lifecycle, made visible (0076)

The existing carton screens (`ShipmentDetailScreen`, `CartonEditScreen`) predate
0076 and already cover the everyday packing loop — add a box, fill it, print
it — through the `shipments` edge function. That function selects `*` on both
carton tables, so 0076's new columns (`weight_kg`, `length_cm`/`width_cm`/
`height_cm`, `carton_type`, `tracking_number`, `status`) were already arriving
in the response; nothing client-side was reading them. Rather than rebuild the
packing flow around `pack_carton_item`'s per-parcel, lot-aware writes — a
change of the same shape as 0074's on the picking side, but a materially
larger one here since `CartonEditScreen`'s whole-carton replace has no
equivalent to "add one more parcel" — this slice stays scoped to what was
purely missing: the box's own facts and its status.

`Carton` now parses the 0076 fields, with a `CartonStatus` enum (OPEN/PACKED/
SHIPPED/CANCELLED) mirroring `PickListStatus`'s shape. `ShipmentRepository`
gained `setCartonMeasurements`/`closeCarton`/`reopenCarton`, called through the
same PostgREST Dio `autopack`/`setLogistics` already use — no edge function
change required. `_CartonCard` shows a status pill, weight/dimensions/tracking
as chips when set, a "サイズ・重量" sheet (the same edit-sheet shape §21's
`_LogisticsSheet` already established, reused rather than reinvented) for
setting them, and lock/unlock icons for close/reopen.

**The client now enforces what the old edge-function path never checked**:
`onEdit` (which still routes to the old whole-replace `CartonEditScreen`) is
disabled once a carton is PACKED, with a "編集するには箱を開け直してください"
hint in its place — matching `pack_carton_item`'s own rule ("reopen it before
changing what is inside") even though the edit path this client still uses
does not itself enforce it. Closing is disabled on an empty box (the RPC
refuses it; the button says why before the tap). Reopening is offered only
while PACKED — a SHIPPED carton's status came from the plan's own shipping,
and 0076 refuses to reopen one until the shipment itself is undone.

Tested against the fake repository: an open, non-empty carton can be closed;
an empty one's close button stays disabled with its tooltip explaining why; a
packed carton shows its status, blocks the card's own tap from opening the
edit screen, and offers reopen; the measurements sheet pre-fills every field
from the carton and round-trips a changed value back through
`setCartonMeasurements`; clearing a field sends null rather than zero; and an
invalid dimension is refused client-side before any call is made.

### The carton-packing rewrite: additive, lot-aware, bounded by what was picked (0076/0079)

The previous slice deliberately left `CartonEditScreen` alone: it declared a
carton's *final* contents in one call (`updateCarton` — delete every item,
reinsert whatever quantities the operator typed per JAN), with no lot/serial
identity and no server-side ceiling beyond the shipment line's ordered
quantity. That model has no way to represent two lots of the same JAN in one
box, and it let a packer put in more than was actually picked whenever picking
ran short. This slice replaces it with the same additive shape 0074 already
proved out on the picking side: `pack_carton_item` records one parcel at a
time, `remove_carton_item` takes one back, and the ceiling — `packable_quantity`
— comes from `pick_items` when picking ran, falling back to the order only
when it did not.

**Renaming needed its own RPC first.** The only existing way to change a
carton's free-text `label` was still the old `PUT .../cartons/:cid` — full
item replace, no lot/serial columns in its payload. Once cartons carry
identified parcels, that route would silently discard them on every rename.
0079 (`set_carton_label`) closes this the same way 0076 closed the equivalent
gap for measurements: a one-column RPC, found and built *while starting this
client slice*, not by a separate request — the same "found while wiring the
client, fixed forward with its own migration" pattern 0072 and 0078 both
followed earlier in Phase B/C.

**The read changed too.** `Shipment.cartons` (from the `shipments` edge
function) has never joined lot codes or serial numbers — it selects `*` on
`shipment_carton_items`, which only carries the raw `lot_id`/`serial_id`.
`carton_detail`/`shipment_packing` (0076) do the join. `CartonEditScreen` now
reads through a new `shipmentPackingProvider`, which calls `shipment_packing`
directly rather than trying to enrich the edge function's response — text a
join produces is not text worth re-deriving client-side.

`ShipmentRepository` gained `packing(planId)`, `packCartonItem(...)`,
`removeCartonItem(itemId)`, and `setCartonLabel`; `updateCarton` — and
`CartonItem.toJson()`, which existed only to serialize its payload — are
deleted outright rather than left dead, since a future caller finding
`updateCarton` still on the interface would have no way to know it was a
correctness trap. `Carton`/`CartonItem` gained lot/serial/stock-unit fields,
populated only when the read joins them (0076's reads do; the edge function's
`show()` still does not, and callers relying on that path simply see them as
null — a fact about *which read they used*, not a bug).

The rewritten screen shows each product's global packed/packable/unpacked
(`_PackableLineCard`, "追加" opens `_PackDialog` prefilled with what is still
unpacked *for the whole shipment*, not this carton alone — packing more in
this box reduces the same pool any other box draws from) and this carton's
own recorded parcels with lot/serial and a remove button
(`_CartonItemRow`, the same shape `_TaskCard`'s items list already has on the
picking screen). Renaming got its own small dialog (`_RenameDialog`, a real
`StatefulWidget` owning its controller — an earlier draft disposed a bare
`TextEditingController` right after `showDialog` returned, which crashed
whenever the pop animation still referenced it; the fix is the same shape
every other edit dialog in this codebase already uses). A closed (PACKED)
carton disables both "追加" and the remove buttons, with the same
"編集するには箱を開け直してください" hint `_CartonCard` already shows.

Tested against a stateful fake (`FakeShipmentRepository.packingFixture`,
mutated by `packCartonItem`/`removeCartonItem`/`setCartonLabel` the way the
real RPCs would — a shallow "return show(id) unchanged" fake, the convention
the old carton CRUD used, cannot exercise additive semantics at all): packing
a parcel shows it with its lot and updates the line's progress; a second
parcel's dialog prefills from what the *whole shipment* still needs, not this
box; removing a parcel restores both the carton and the line; a fully packed
line shows done with no add button; renaming changes the label without
touching a recorded lot (the exact failure mode 0079 exists to prevent); and
a closed carton's add/remove controls are disabled, not hidden.

### Recall traceability, reachable (0075)

The last RPC from Phase C with no client anywhere: `shipment_parcels` — "which
lots and serials went to this customer, and when," the read a recall starts
from. 0075 built it the same day it built the movements it reads, but nothing
called it until now.

New `ShipmentParcel` domain type, one repository method
(`ShipmentRepository.parcels`), one provider (`shipmentParcelsProvider`), and
a new screen (`ShipmentParcelsScreen`) reached from a history icon on
`ShipmentDetailScreen`'s app bar — available on any shipment, not gated on
its status, since the honest answer for one that has not shipped yet is an
explained empty state rather than a hidden button.

**The response shape needed care.** `shipment_parcels` `returns jsonb`, not
`setof jsonb` — but the jsonb *value* is itself a `jsonb_agg()` array, so
PostgREST's body is that array directly, not a single-row wrapper around it.
The unwrap-if-wrapped pattern every other jsonb-returning RPC in this client
uses (`data is List && data.isNotEmpty ? data.first : data`) would have taken
`data.first` here — the *first parcel*, silently dropping the rest, or
crashing outright once cast back to a list. `lot_provenance` (0067) already
solved this exact shape on the receiving side; `parcels()` reuses its
disambiguation rather than repeating the mistake it exists to avoid:
`data.length == 1 && data.first is List` is the only case that means "wrapped,"
everything else is the array as it stands. A dedicated repository test pins
down a bare-array response specifically, not just the shape every other RPC
test in this codebase happens to use.

Each row renders with its signed quantity (`stock_ops_ui.signed`, the same
helper picking's variance display uses), lot code and expiry, serial number,
and bin — and a SHIP_CANCEL row is shown as it happened, tagged and in red,
rather than filtered out, because a reversal is part of the recall answer,
not noise the read should hide.

### A stale comment, found while closing out this phase

Checking every RPC 0073–0079 built against what the client actually calls
(the same completeness pass this "recall traceability" slice came out of)
turned up one more: the printed carton label template (`LabelTemplates.carton`)
has carried a `ロット {{lot}}` row since before this phase, but
`cartonLabelValues()` fed it a hardcoded `null` with a comment claiming lot
tracking was not modelled yet. It is now — `CartonItem.lotCode`, wired by the
carton-packing rewrite above. `cartonLabelValues()` now shows the lot when
every parcel in the box agrees on one (the same single-vs-ambiguous rule
`product_name`/`jan` already use for a mixed box), and drops the row —
`LabelTemplate.render()` already does this for any row whose variables all
resolve empty — when a box holds two lots of the same JAN rather than naming
only the first and mislabelling the rest. Two new tests in
`shipment_print_test.dart` pin both cases down directly.

### 0080 — the last one: a setting with no way to read what it currently is

Cross-checking every RPC 0073–0079 built against what the client calls (the
same pass that found 0079's and the label's gaps) turned up the last one:
`set_picking_rule` (0074, §16) has never had any client anywhere — not the
read side either. `list_products`, the one read the product screens use,
never learned to return `picking_rule`, so a settings form could not have
shown the current value even if it called the setter blindly.

0080 adds `'picking_rule', p.picking_rule` to `list_products`'s existing
`jsonb_build_object` — one field, no grant or policy change, so it touches
none of `verify_security.sql`'s ten checks (confirmed: 18/18 after applying
it live). Same shape as 0079: a migration written to unblock the client
slice it was found while building, not a separate ask.

`Product` gained `pickingRule` (defaulting to `'FEFO'`, same as the column
and `picking_rule_for`'s own fallback), and `ProductRepository.setPickingRule`
sets the product's own default — `p_warehouse_id` is always null from this
call, leaving a per-warehouse override for later, the same gap
`putawayRule`'s per-warehouse-only setting doesn't have to solve on day one
either. `ProductFormSheet` gained a `pickingRuleLabel`'d dropdown
(FIFO/FEFO/LIFO/MANUAL) next to tracking mode, saved through its own call
only when it actually changed — the same "identity is a second decision"
shape 0057's SKU/tracking-mode split already established, not a fourth
special case invented for this field.

Tested at both layers: `product_repository_test.dart` asserts `list()` reads
`picking_rule` (and still defaults a payload that predates it to `'FEFO'`),
and `set_picking_rule`'s call shape (`p_warehouse_id` null, no boolean
response assumed — the RPC returns jsonb); `product_form_sheet_test.dart`
asserts the rule is saved through its own RPC only when changed, mirroring
the existing identity tests exactly.

With this, every RPC Phase C (0073–0080) built is reachable from the UI.

## Rollout discipline

- One concern per migration; each reversible in intent (inactivate, not destroy).
- After each: `flutter analyze` clean, `flutter test` green, and a DB smoke check
  via the Supabase RPC. Commit per step with a clear message.
