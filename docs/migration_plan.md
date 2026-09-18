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

Still open, and now the last piece of §37: the edge functions' own
`warehouse_id` query filters.

## Rollout discipline

- One concern per migration; each reversible in intent (inactivate, not destroy).
- After each: `flutter analyze` clean, `flutter test` green, and a DB smoke check
  via the Supabase RPC. Commit per step with a clear message.
