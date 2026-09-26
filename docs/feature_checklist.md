# WMS Feature Checklist

_A snapshot of what actually exists today, verified against the live Supabase
project (`vjunicsfobglmncjucbb`), the Flutter codebase, and the test suite —
not against what a doc says was planned. Written after removing InventorOS
entirely (see `migration_plan.md`'s "Post-0028" entry); the app is Supabase-only
now._

Legend: ✅ built, wired to Supabase, and covered by an automated test · ⚠️ built
and wired, but with a real gap noted next to it (no test, no UI, unused) ·
❌ not built at all.

## 1. Roadmap steps (spec §46 numbering)

- [x] Step 1 — Multi-warehouse (companies/warehouses/zones/bins)
- [x] Step 2 — Warehouse picker / per-warehouse context
- [x] Step 3 — Roles, permissions, scope, **and real sign-in** (Supabase Auth,
      replacing the old InventorOS Sanctum login)
- [x] Step 4 — Receiving → inspection (QC) workflow
- [x] Step 5 — Put-away (optional locations)
- [x] Step 6 — Stock counts & adjustments
- [x] Step 7 — Picking
- [x] Step 8 — Packing/shipping (cartons, JAN printing, 送り状)
- [x] Step 9 — Stock ledger (movements + derived on-hand)
- [x] Step 10–12 — Warehouse ops consolidation, audit log, stock ledger RPCs
- [ ] Step 13 — Seed/demo data — **deliberately skipped** (would have written
      fictitious records into the live production database; not revisited)
- [x] Step 14 — UI/UX overhaul (dashboard task counts, global search,
      per-document activity timeline)
- [x] Step 15–16 — `ai_analysis` result store + `AIProvider` abstraction,
      Gemini OCR re-pointed through it
- [x] Step 17 — Connector/adapter **skeleton** (registry + run-log tables,
      `connector.manage` permission) — ⚠️ no adapter actually implemented;
      InventorOS is registered as a row, disabled, nothing syncs

## 2. Core WMS domain areas

**Inbound**
- [x] Receiving confirmation → QC inspection (pass/fail/hold/partial) → stock
- [x] Purchase orders (0033) — a self-contained order lifecycle (draft →
      submit → approve/reject → cancel/complete), `purchase_order.view`/
      `.manage`/`.approve`-gated, self-approval refused. Distinct from a
      delivery plan (an already-shipped delivery used for QC reconciliation);
      completing a PO is a bookkeeping close, not a receiving event — it does
      not move stock. Verified live via grants and an aborted-transaction
      round trip covering every transition plus the wrong-state refusals
- [x] Purchase Order → Delivery Plan (0083) — the inbound sibling of 0073's
      Sales Order → Reservation → Shipment wire: an APPROVED purchase order
      can turn into a delivery plan (`create_delivery_plan_from_purchase_order`),
      copying its lines across for reconciliation to work from. Deliberately
      reserves nothing — there is no stock yet to set aside on the way in —
      so no stock moves here either. At most one delivery plan per order
      (unique index); `purchase_order_detail` reports the plan it became, the
      same shape `sales_order_detail` already had for its shipment. Verified
      live via an aborted-transaction round trip (create → submit → approve →
      create the plan → read it back via the detail RPC → the wrong-state and
      double-create refusals) plus the 10 security invariants unchanged
- [x] Formal put-away task/confirmation step (0038) — `putaway.confirm` has
      existed since 0012 with nothing implementing it. The queue is
      **derived** (`stock_levels.on_hand` minus the sum of that JAN's
      `bin_stock` per warehouse), so anything that raises warehouse stock
      shows up as put-away work automatically and no work table can drift.
      A dedicated `PutawayQueueScreen` + confirm sheet: scan the shelf →
      see what it already holds → confirm the quantity. `confirm_putaway`
      moves stock only via `apply_bin_movement` (BIN-scoped), so the
      warehouse total never changes — only where the stock sits — and a
      repeated idempotency key replays instead of double-posting. Verified
      live via grants and an aborted-transaction round trip covering the
      queue, bin lookup, a partial confirm, the idempotent replay,
      over-put-away refusal and the dashboard counters

**Outbound**
- [x] Pick list → picking (short/over detection) → packing (cartons) →
      shipping, all Supabase-backed
- [x] Sales orders (0034) — the outbound counterpart to purchase orders: the
      same self-contained lifecycle (draft → submit → approve/reject →
      cancel/complete), `sales_order.view`/`.manage`/`.approve`-gated,
      self-approval refused. Distinct from a shipment plan (an already-
      committed shipment feeding picking/packing/shipping); completing a
      sales order is a bookkeeping close, not a shipping event — it does not
      move stock. `customer_id` reuses `delivery_suppliers` (already a
      generic trading-partner reference via `shipment_plans.party_id`).
      Verified live via grants and an aborted-transaction round trip
      covering every transition, reject, and the wrong-state refusals
- [x] Sales Order → Reservation → Shipment (0073) — approving a sales order
      reserves stock per line, best-effort (an unlinked JAN or a shortfall is
      reported, not blocking); `create_shipment_from_sales_order` turns an
      APPROVED order into a shipment plan and re-files the reservation under
      it rather than making a second one. `ship_plan` (0075) marks the
      shipment's reservations kept from what actually left; the manual
      `fulfil_reservation` action added below is for promises that never
      reach a shipment
- [x] Order-first demand (0084/0085): approval reserves what exists and
      leaves the rest as a derived backorder; `open_demand` is the purchasing
      worklist (backordered / free / incoming / to buy per product);
      `fill_backorders` promises free stock oldest-first or to a chosen order;
      `create_purchase_order_from_demand` raises one purchase order for many
      sales orders and links it to them (`purchase_order_line_demands`);
      a purchase order may arrive over several delivery plans, and an
      imported plan can be linked to the order it delivers; an order may ship
      in several shipments, only what is promised ships, and a short pick
      goes back to backorder. Client: the 受注残・発注 screen, per-line state on
      sales/purchase order detail, 発注に紐付け on reconciliation
- [x] Purchase earmarks and 見込み (0086): goods that arrive on a purchase go
      to the orders it was linked to, automatically at receipt; quantity
      beyond the links is bought ahead (見込み), counted as incoming and
      free for the next order once landed; links are edited by hand at
      creation (per supplier, a product may be split across suppliers) and
      afterwards from the purchase-order detail; incoming is one total per
      product across every supplier, broken down per purchase order
- [ ] Returns / RMA — ❌ never existed on the Supabase side

**Inventory**
- [x] Stock adjustments (reason-coded)
- [x] Cycle counts (blind counting supported)
- [x] Inter-warehouse transfers (full state machine: draft → approval →
      picking → in-transit → receiving → completed)
- [x] Stock ledger (movement history per JAN, derived on-hand)

**Master data**
- [x] Product master (name, category, price, barcode) (0032) — a `products`
      table keyed by `jan_code` (the same barcode already used throughout
      stock/receiving/picking, not a new identifier), RLS-gated on
      `product.view`/`product.manage`. A `ProductListScreen` (search, add,
      edit, activate/deactivate) added to the home menu. Verified live via
      grants and an aborted-transaction round trip (create/list/update/
      deactivate + duplicate-JAN rejection). This is separate master data,
      not wired into `stock_levels`/`stock_movements`/`bin_stock` — those
      keep their own denormalized `product_name`, unchanged
- [x] Full supplier/customer management (CRUD, contacts, terms) (0035) —
      `delivery_suppliers` extended in place into a general trading-partner
      directory (`kind`: supplier/customer/both, plus contact/phone/email/
      address/payment terms/notes), rather than a second `customers` table
      forking the two existing FKs (`delivery_plans.supplier_id`,
      `shipment_plans.party_id`) apart. `partner.view`/`.manage`-gated CRUD
      RPCs; the pre-existing open read policy on the table is untouched, so
      delivery-note import and shipment lookups keep working unchanged. A
      `TradingPartnerListScreen` (search, kind filter, add/edit,
      activate/deactivate) added to the home menu. Verified live via grants
      and an aborted-transaction round trip (create/list-by-kind/update/
      deactivate, including the "both" kind matching either filter)
- [x] Work orders / assembly / kitting (0036) — scoped to assembly/kitting
      (many components consumed → one output produced), inside one
      warehouse. Unlike purchase/sales orders, completing one DOES move
      stock: two new `stock_movements` types (`WORK_ORDER_CONSUME`/
      `WORK_ORDER_PRODUCE`) post through the existing `apply_stock_movement`,
      so a kitted item's history is traceable the same way a pick or
      adjustment already is. draft → start → complete (or cancel before
      anything moved), `work_order.view`/`.manage`-gated. Disassembly (one
      input → many components) would reuse this same shape and is a natural
      follow-up. Verified live via grants and an aborted-transaction round
      trip that seeded known stock levels and confirmed the exact before/
      after quantities and ledger entries on completion

**People & access**
- [x] 11 roles, 22 permissions, audit-logged role/permission checks
- [x] Real sign-in (Supabase Auth) — code-complete, `flutter analyze` clean
- [x] Auth test coverage — 41 tests added covering `SupabaseSession`,
      `SupabaseSessionStorage` (including keychain-failure resilience),
      `SupabaseTokenRefresher` (refresh-coalescing race), a full fake-Dio-adapter
      suite for `SupabaseAuthInterceptor` (header injection, proactive refresh,
      401-retry-once, anon-key fallback) and `AuthRepositoryImpl` (login/
      currentUser/logout against a fake GoTrue+PostgREST transport), and
      `AuthController`'s state machine against a fake repository
- [ ] **Nobody has actually signed in yet** — `app_users`, `user_roles`, and
      `user_warehouses` all have 0 rows in the live database. The flow has
      never been exercised by a real device/person, only by widget tests
      against fakes and direct SQL checks
- [x] Admin UI to assign/revoke roles (`UserManagementScreen`)
- [x] Per-user warehouse scope (`user_warehouses`, 0029) — admin UI to
      assign/revoke a user's warehouse access, same screen as roles.
      `can_access_warehouse` still lets system_admin/company_admin through
      regardless of this table; it only restricts everyone else

**Audit & AI**
- [x] Append-only audit log, company-wide viewer, CSV export, per-entity
      activity timeline
- [x] `ai_analysis` result store (PENDING_REVIEW/CONFIRMED/REJECTED,
      idempotent reuse by input hash)
- [x] Gemini OCR for delivery-note extraction, behind an `AIProvider`
      interface (`qwen` is a reserved, unimplemented slot)
- [x] Human review UI for AI results (`AiReviewListScreen`, 0030) — lists
      PENDING_REVIEW `ai_analysis` rows, confirm/reject with an optional
      rejection reason. Only OCR (`ocr_delivery_note`) produces analyses
      today, so it's the only shape the screen renders
- [ ] AI beyond OCR (product-photo identification, damage detection,
      inventory assistant — spec §27's other modules) — ❌ not started

**Files & attachments**
- [x] Image/attachment storage (0031) — a private `inspection-attachments`
      Storage bucket + a polymorphic `attachments` table (RLS: read gated on
      `inspection.view`, no direct insert policy — every write goes through
      `record_attachment`, gated on `inspection.confirm`), wired to
      inspections first. `InspectionDetailScreen` gets a photo strip: add via
      camera or gallery while the inspection is open, thumbnails render off a
      time-limited signed URL (the bucket is private). Verified live via
      grants (`anon`/`public` refused, `authenticated` allowed) and an
      aborted-transaction round trip. Entity-keyed (`entity_type`/`entity_id`,
      no FK) so other entities can attach files later without a redesign

**Connectors**
- [x] Registry + run-log schema, `connector.manage` permission, read/enable
      screen
- [ ] Any actual external system integration (Shopify, carriers, freee,
      InventorOS, or otherwise) — ❌ none implemented; the skeleton is
      deliberately unwired per your explicit choice

**Packing / labels / shipping (UI spec §17–§21)**
- [x] 箱数自動計算 (§18) — enter the units per carton and the box count is
      computed and shown before anything is created, then `autopack_shipment`
      does the division server-side. Fills sequentially, so a mixed order
      packs as [A6][A4+B2][B3] rather than wasting a box per SKU. Refuses to
      merge into existing cartons
- [x] Per-carton label with its own QR (§17/§19) — `SHP:<no>|BOX:n/total`,
      readable at the dock with no network, plus a JAN barcode when the box
      holds a single SKU. A mixed box prints "N 品目" instead of naming one
      item and lying about the rest
- [x] Label templates (§20) — `{{variable}}` substitution over the variable
      set the spec lists, with rows dropped when all their variables are
      empty (no `ロット` label with nothing after it). Print preview is the
      system print dialog, which every print path already goes through
- [x] Shipping details (§21) — weight / carrier / tracking on the shipment,
      `pack.complete`-gated, with unset fields shown as 未入力 rather than as
      a zero. 出荷確定 already required a confirmation dialog
- [ ] Label templates beyond the carton label (商品/入荷/棚/パレット) — named in
      §20; deliberately not defined until a flow prints them, since an unused
      template is the fake completeness §53 forbids
- [ ] Direct printer integrations (Zebra/SATO/Brother/TSC) — §19 lists these
      as future work; today everything goes through the system print / PDF
      dialog

**Dashboard alerts (UI spec §30)**
- [x] A colour-coded alert list — 🔴検品NG／🟠入荷待ち／🟡棚入れ待ち／🔵ピック待ち —
      each row opening straight into the relevant work ("クリックで該当業務へ
      直接移動"). Three of the four counts already existed in
      `dashboard_metrics`; the missing one, 検品NG (inspections that came
      back FAIL — a problem, not a queue), was added in 0041
- [x] Deliberately narrower than the always-visible task-count strip
      (`TodayTasksRow`, which the mockup's own Japanese heading also calls
      "今日の作業" — reused here it would have put two differently-shaped
      sections under one label, so this one is titled 通知 instead): only
      rows with something to report appear, and an all-clear state reads as
      an explicit "nothing needs attention" line rather than either a list
      of zeros or the section silently vanishing
- [x] Same permission gating as the rest of the menu (§37) — a row's tap
      resolves through the same `entryById` that hides anything the signed-
      in user cannot open, so a notification can't open a screen its own
      catalog entry would have been hidden for

**Audit trail readability (UI spec §29)**
- [x] "誰が・いつ・何をした" — until now the audit trail's "who" was a bare
      `auth.uid()` uuid and its "what" was the raw `event_type` code
      (`purchase_order.approved`). `audit_log_query`/`audit_log_for_entity`
      (0040) now resolve the actor through `app_users` (mirrors
      `auth.users`, existed since 0012 — no new table), returning
      `actor_name`/`actor_email` alongside the uuid; a genuinely actor-less
      entry (bootstrap, a cron job) stays null rather than resolving to a
      false name
- [x] Every one of the 55 `log_audit(...)` event codes in the schema is
      mapped to a human phrase in three languages (`AuditEventLabels`) — the
      per-record timeline, the full Audit Log screen, and its filter chips
      all show the phrase; the raw code stays visible as a small monospace
      caption for anyone cross-referencing a ticket. An event code the map
      doesn't recognise still renders (humanized fallback), so a future
      migration that adds one without updating this list degrades instead
      of breaking
- [x] CSV export gained `actor_name`/`actor_email` columns alongside the
      existing `actor_user_id`

**Permission-aware UI (UI spec §37)**
- [x] The home menu, sidebar, dashboard feature grid, and today's-tasks/
      outstanding shortcuts now hide anything the signed-in user holds no
      permission for, instead of listing every screen for every user and
      letting a tap land on an RLS-filtered blank view or a server refusal
      with no explanation. A whole section (e.g. "Management") disappears
      when nothing in it is open to that user, rather than showing an empty
      heading
- [x] Backed by `my_access()` (existed since 0012, previously unused by the
      client — login/currentUser called the roles-only `my_roles()` instead)
      — one round trip for roles *and* permissions, folded into `AuthUser`.
      An admin role is granted every permission explicitly at the database,
      so there is no separate "is admin" client-side bypass to keep in sync
- [x] This is a UI convenience only, not the security boundary: every RPC and
      RLS policy still re-checks `has_permission()` itself regardless of what
      the menu decided to show, exactly as the spec asks ("UIだけでなくSupabase
      RLS/RPC側でも権限を検証する")
- [~] Per-warehouse scope (`user_warehouses`) — **the note that used to sit
      here was wrong, and the error mattered.** It claimed the scope was
      "enforced server-side by RLS on every table already," so that only the
      client-side picker needed narrowing. Auditing it found the opposite:
      `can_access_warehouse()` (0012) and the admin UI that assigns scope
      (0029) both exist, but **nothing ever called the function** — verified
      against the live database, not just the source: zero RLS policies
      reference `user_warehouses` or `can_access_warehouse`, and zero RPCs
      or edge functions did either. A user restricted to one warehouse was
      not restricted at all; every warehouse-scoped RPC and edge function
      accepted whatever `warehouse_id` the caller sent. Narrowing only the
      picker would have made this *look* fixed while leaving the hole open.
  - RLS alone could not have fixed it even where it applies: these tables are
    read and written through `SECURITY DEFINER` RPCs, which bypass RLS by
    running as the function owner — the same structural gap as the audit-log
    RPCs in 0043. The check has to live inside the functions.
  - Also subtler than a bolt-on guard: most of these RPCs treat
    `p_warehouse_id IS NULL` as "every warehouse" (a deliberate
    all-warehouses view), so `if not can_access_warehouse(p_warehouse_id)`
    alone does nothing for a restricted caller who simply omits the filter.
    Read paths have to *fall back to the caller's scoped set* rather than to
    everything.
  - **Batch 1 done (0044)**: added `accessible_warehouse_ids()` (the caller's
    ids, or null meaning unrestricted — admins and trusted server-side
    callers, same null-`auth.uid()` convention as `has_permission()`), and
    wired enforcement into the two functions every stock-quantity change in
    the app funnels through (`apply_stock_movement` for warehouse-level
    stock, `apply_bin_movement` for bin-level, where the warehouse is derived
    from the bin rather than trusted from a parameter), so every
    transfer/pick/ship/receive/count/work-order path inherits the check at
    once via nested calls (`SECURITY DEFINER` does not reset `auth.uid()`).
    Plus the entry points that bypass both (`confirm_putaway`,
    `start_stock_count`) and `warehouse_overview()` itself — the RPC that
    actually feeds the warehouse picker, which is what delivers the original
    "narrow the picker" ask as a real restriction rather than a cosmetic one.
  - Safe to switch on now specifically because `app_users` is **empty** —
    nobody has ever signed in, so no live user could be newly locked out.
    The first sign-in stays safe by design: `bootstrap_first_admin()` (0024)
    makes user #1 `system_admin`, and admins resolve to unrestricted.
  - Operational consequence worth knowing: from user #2 on, a role alone is
    no longer enough — a non-admin with **no** `user_warehouses` rows now
    resolves to *zero* warehouses (empty picker, and writes refused with
    `not permitted: warehouse.scope required`). That is deny-by-default, and
    exactly the semantics `can_access_warehouse()` was always written to
    have; it just never ran before. Admins must assign warehouses as well as
    a role — the user-management screen already supports both.
  - **Batch 2 done (0045)**: the list/index reads behind each list screen —
    `pick_list_index`, `purchase_order_index`, `sales_order_index`,
    `work_order_index`, `transfer_order_index`, `putaway_queue`. Fixed in
    the WHERE clause rather than as a guard, for the reason above: the
    no-filter case now falls back to `accessible_warehouse_ids()` instead of
    to every warehouse. Reads filter rather than raise (an out-of-scope
    warehouse yields nothing), except `putaway_queue`, whose warehouse is a
    required argument — there an out-of-scope request raises rather than
    being mistaken for "nothing to put away". `transfer_order_index` matches
    on *either* end, so a user scoped only to the destination still sees
    what is arriving.
  - **Batch 3 done (0046)**: `create_purchase_order`,
    `create_sales_order`, `create_work_order` — the remaining writes that
    name a warehouse. Each already checked the warehouse exists; the added
    check asks whether this caller may use it, placed right after the
    existing `has_permission()` guard.
  - [ ] Still open, and smaller than what is now covered: the read helpers
    taking a required warehouse (`dashboard_metrics`, `global_search`,
    `stock_ledger`, `stock_availability`, `bin_by_code`,
    `bin_stock_overview`, `default_staging_bin`,
    `warehouse_uses_locations`), plus the edge functions' own
    `warehouse_id` query filters (delivery-plans, shipments,
    warehouses/bins, picking, transfers, inspections, stock-ops).
  - [ ] Separately noticed, not changed here: `warehouse_overview()` is
    granted to `anon`, so a caller with only the anon key can still read the
    warehouse list (scope resolves to unrestricted for a null
    `auth.uid()`). Same class of stale grant as the audit-log RPCs in 0043,
    but revoking it could break a pre-login screen, so it needs a look at
    the sign-in flow first rather than a silent revoke.

**Confirmation on dangerous operations (UI spec §36)**

Audited against the spec's own list of 8 operations that must ask before
acting ("ただし確認ダイアログを乱用しない" — but don't overuse them elsewhere):

- [x] 出荷確定 (ship confirm) — `ShipmentDetailScreen._confirmShip`, already
      warns separately when a line would go short
- [x] 在庫調整 (stock adjustment) — was missing: `_newAdjustment` applied the
      bottom sheet's draft straight to the ledger with no confirmation step.
      Added a confirm dialog between the sheet and the write, showing the JAN
      and signed delta and stating the write can't be undone
- [x] 棚卸確定 (stock count complete) — `StockCountDetailScreen._complete`,
      already surfaces an uncounted-lines warning inside the same dialog
- [x] Transfer完了 (`completeReceiving`, the step that actually moves stock) —
      `TransferDetailScreen`, via its shared `_confirm` helper
- [x] POキャンセル / SOキャンセル — `PurchaseOrderDetailScreen` /
      `SalesOrderDetailScreen`, both via the same `_confirm` helper pattern
- [x] 商品無効化 (product deactivation) — was missing: `_toggleStatus` wrote
      `status = 'inactive'` directly on tap. Added a confirm dialog, but only
      on the active→inactive transition; reactivating stays a single tap
      since it undoes nothing and isn't destructive (the spec's "don't
      overuse" side)
- [ ] 倉庫削除 (warehouse delete) — no such operation exists anywhere in the
      app (no screen, no repository method, no RPC). Nothing to confirm;
      not built speculatively just to have something to gate (§53)

Every other `showDialog` call already in the app (bottom-sheet-style forms,
quantity entry, filters, the autopack box-size prompt, the sender picker) is
a data-entry or picker dialog, not a destructive action, and was left alone
— adding a confirmation there would be exactly the overuse the spec warns
against.

**Loading / error / empty consistency (UI spec §33, §34)**

Audited every screen backed by `AsyncValue.when(...)` (33 presentation files)
and every list-rendering screen, checking for silent gaps — a spinner that
never resolves into a message, a blank screen instead of an empty state, an
error swallowed with no retry. Result: already consistent, no changes
needed.

- [x] Every full-screen async load routes `loading`/`error`/`data` through
      the shared `LoadingView`/`ErrorStateView` (`core/ui/state_views.dart`)
      — one exception, `DashboardMetricsSection`, which intentionally uses a
      compact inline spinner and a small retry card instead, because it's one
      section of a taller scrollable page, not the whole screen; the rest of
      the dashboard (the feature menu) stays usable while it loads or fails
- [x] Every list screen shows an explicit `EmptyStateView` (icon + title +
      guidance) rather than an empty `ListView` — verified across all 30
      list-rendering screens; the two screens with two `EmptyStateView` calls
      (`GlobalSearchScreen`, `PickListIndexScreen`, `PutawayQueueScreen`) each
      distinguish a genuinely different state (no query yet vs. no results;
      not started vs. nothing to do), not a duplicate
- [x] The dashboard's embedded watch lists (outstanding plans, low stock,
      §30's notification row) use a smaller inline "all clear" pattern
      instead of the full-page `EmptyStateView` — appropriate since they're
      cards within a larger page, not the page itself, but still an explicit
      message rather than the section silently vanishing
- [x] `TodayTasksRow`'s horizontal chip strip is fixed-length by design
      (always the same 8 tiles, showing 0 rather than omitting a tile), so it
      was never a candidate for an empty state — noted here only to record
      that its lack of one was checked, not missed
- [x] **Permission denied** (§34's own explicit example — "悪い:
      `PostgrestException`") was a real gap: every `has_permission()` guard
      across the RPCs raises the exact same shape,
      `not permitted: <code> required`, and it was reaching `ErrorStateView`
      verbatim — provable because an existing test
      (`user_management_screen_test.dart`) had baked in that raw text as its
      expected output. Reachable in practice, not just in theory: most
      `FeatureEntry`s gate their menu entry on a "view OR manage" pair (§37),
      so a view-only user routinely opens a screen whose write actions need
      the stronger permission, and the RPC's own check is the first place
      that becomes visible. `humanizeApiErrorMessage()` (`core/api/
      api_error_text.dart`) recognises the pattern and swaps in a localized
      "この操作を行う権限がありません。"; wired into `ErrorStateView` itself so
      every one of the ~30 screens using it is covered by one change, no
      per-screen edits. The test that had the wrong expectation baked in was
      corrected to assert the friendly text instead
- [x] The write-side equivalent — `_snack(f.message, ...)` after a failed
      action — is now covered too. Each screen builds its own SnackBar (or,
      in a few forms, sets an inline `_error` string) locally rather than
      through a shared helper, so this took three passes across 27 files
      rather than one central fix: the initial 3 stock-ops screens, 11 more
      whose write actions gained a real permission check during the
      edge-function audit above, and a final batch of 13 covering every
      remaining screen with a write action (purchase/sales/work orders,
      the report builder, put-away confirm, product master, trading
      partners, user management, AI review, connectors). Two call shapes
      needed the same treatment: a `_snack(f.message, ...)` SnackBar, and a
      `setState(() => _error = f.message)` inline error shown via `Text` in
      a form sheet (`putaway_confirm_sheet.dart`, and the product/
      trading-partner add/edit sheets) — both now route through
      `humanizeApiErrorMessage()` before display. Verified with one
      permission-denied widget test per file group (following the
      `failWith`-on-a-fake-repository pattern), not per file — the wiring
      is identical everywhere, so one proof per call shape plus the
      existing generic `humanizeApiErrorMessage()` unit tests cover the
      logic; the remaining files were verified by `flutter analyze` +
      the full `flutter test` suite staying green
- [ ] "Connection warning" as its own distinct state (§34 lists it alongside
      Loading/Empty/Error/Retry/Permission denied) doesn't exist separately
      — a dropped connection surfaces through the same generic
      `ErrorStateView`/SnackBar path as any other failure, with `Retry`
      already in place. Not built speculatively: no distinct offline-banner
      UI exists to hang it off, and the app has no offline mode (see
      `architecture_current.md` §5)

**Form UX (UI spec §35)**

Audited against the spec's 5 bullets:

- [x] 必須項目を最初に (required fields first) — already true everywhere: every
      form in the app is short (4-6 fields) with required fields ordered
      ahead of optional ones (e.g. the product form: JAN/name, then the
      optional category/price)
- [x] 詳細設定は折りたたみ (advanced settings collapsed) — no form has enough
      fields to need progressive disclosure; adding a collapsible section
      where nothing is actually advanced would be complexity for its own
      sake, not a fix
- [x] バーコード入力はスキャナー優先 (scanner before manual keying) — was a real
      gap: the product form's and stock adjustment form's JAN fields were
      plain numeric `TextField`s with no scan affordance, unlike every
      barcode-driven list/search screen in the app (which already pair a
      `ScanField` with a camera button). Added a scan icon
      (`Icons.qr_code_scanner_outlined`) next to both JAN fields that pushes
      the shared `BarcodeScanScreen` and fills the field with the result —
      hidden on the product form when editing, since the JAN is fixed once
      created
- [x] 数量入力は大きな数字UI (large-number UI for quantity entry) — was a real
      gap: the transfer pick/receive quantity dialog and the stock count
      line dialog both used an ordinary-sized, left-aligned text field for
      the one number each dialog exists to collect. Both now render the
      count centered in `textTheme.displaySmall`, like a number pad's
      display. Left the stock adjustment form's quantity field at normal
      size on purpose — there it's one field among several in a longer form
      (JAN, direction, reason, note), not a single-purpose "how much"
      dialog, and blowing it up would look inconsistent with the rest of
      that form rather than clearer
- [x] 保存成功後は次の業務へ自然に遷移 (after a successful save, transition
      naturally to the next task) — done, and the earlier hesitation turned
      out to point at the answer. The open question was what "the next task"
      is per save, plus whether auto-navigating away is ever unwanted (an
      operator who wants to re-read what they just recorded). Resolved by
      **not** auto-navigating: the success SnackBar now carries a
      `SnackBarAction` for the next step, so the next task is one tap away
      while the screen the operator just finished on stays put. That also
      made it one shared pattern rather than a per-screen judgment call,
      using the SnackBars these screens already showed.
  - Three hand-offs, each one where the physical work genuinely continues:
    検品確定 → 棚入れ (`PutawayQueueScreen` — goods that just passed QC are
    exactly what put-away works from); ピッキング完了 → 梱包
    (`ShipmentDetailScreen` for **that** pick list's own shipment, since
    `PickList.shipmentPlanId` is already on hand — not the shipping list);
    照合完了 → 検品 (`ReceiptHistoryScreen`, which is where a QC pass is
    actually started, since QC is per receipt). The reconciliation one
    captures its `Navigator` before the screen pops, since its own context
    is gone by the time the action can be tapped, and is offered for a
    partial save too — that posts a receipt just the same.
  - Deliberately **not** given a next step: the PO/SO/work-order approval
    screens. Those state machines are bookkeeping closes that move no stock
    and start no physical task (their own header comments say so), so
    inventing a hand-off would be a guess; and 棚入れ確定 already pops back
    to the queue, which is the right place when there is more to put away.
  - Verified by widget test on two of the three (inspection, picking),
    asserting both that the action is offered and that the screen did *not*
    navigate away on its own.

**Inter-warehouse Transfer state visibility (UI spec §22)**
- [x] "現在状態をUIで明確に表示" — already satisfied, same pattern as every
      other document lifecycle in the app (PO/SO/work orders): a
      `StatusPill` (label + icon + colour) for the current
      `TransferStatus`, all 9 states (draft/pending/approved/picking/
      in-transit/receiving/completed/rejected/cancelled) individually
      mapped, plus the source→destination warehouse row and a live
      "X/Y picked" or "X/Y received" progress line while those two states
      are active. Not turned into a dedicated multi-step stepper: that
      would be a one-off pattern used nowhere else in the app, and a
      single clearly-labelled current-state badge already answers "where
      is this transfer right now"

**Stock count (UI spec §23)**
- [x] Location → 商品 → 理論数量 → 実数量 → 差異 flow, blind counting (実数量だけ
      入力, system quantity withheld while a blind count is open), and a
      variance list on completion — all already built and tested (§17).
- [x] **承認権限を分離する (separate the approval permission)** — audited
      and found genuinely unenforced: `count.perform`/`count.approve` have
      existed as distinct permissions since migration 0012, but the
      `stock-ops` edge function that backs every stock-count mutation
      never checked either of them — it ran entirely on the service-role
      client with `// TODO(auth): require count.perform/count.approve for
      the caller.` comments left in place. In practice this meant **any
      signed-in user, regardless of role, could start, record, complete
      (posting real variance adjustments to the ledger), or cancel any
      cycle count in the company.** The same file also had an unenforced
      `// TODO(auth): require inventory.adjust` on stock adjustments.
      Fixed by having the edge function validate the caller's own JWT
      (`supabase.auth.getUser()`) and then call `has_permission()` under
      that identity — `count.perform` gates start/record/cancel,
      `count.approve` gates complete (the step that actually moves stock),
      `inventory.adjust` gates the adjustment endpoint. Deployed as
      `stock-ops` v3.
  - Caught a real footgun while building this: `has_permission()` itself
    treats a null `auth.uid()` as "allow" (intended for trusted
    server-side/service-role callers with no user context, e.g. an RPC
    invoked from another RPC), which would have let an unauthenticated or
    malformed-token caller through unchecked if `has_permission()` were
    called naively. The fix calls `auth.getUser()` first to confirm a real
    signed-in user before trusting the permission check at all.
  - Not independently verified against the live deployed function: this
    session's outbound network is proxied and does not reach
    `*.supabase.co` directly, so the fix is verified by code review
    (`auth.getUser()` is supabase-js's documented per-request JWT
    validation) and by confirming the Flutter client already attaches a
    real bearer token to every `stock-ops` request (`dio_client.dart`),
    not by an end-to-end HTTP call.
  - The client's error message for this case ("not permitted: ... required")
    is the same shape the RPC-based checks elsewhere in the app already
    raise, so it's covered by §34's `humanizeApiErrorMessage()` — wired
    into the three `_snack(...)` call sites in the stock-ops screens that
    previously showed `f.message` raw, since this fix is what makes that
    error newly reachable there.
- [x] **Same gap audited across every other edge function** — the
      `stock-ops` fix above was one instance of a systemic pattern: any
      edge function older than the app's now-universal
      "every RPC checks `has_permission()`" convention runs on the
      service-role client and could have a mutation with no permission
      check at all. Audited every edge function under `supabase/functions`
      and found the same gap, in two shapes, in seven more of them:
      - `inspections` — POST start, PATCH item, POST complete: zero checks
        (no TODO even acknowledged it). Any signed-in user could confirm a
        QC pass/fail on any delivery.
      - `picking` — POST start, PATCH record, POST complete, POST cancel:
        one had a TODO referencing a permission code (`picking.perform`)
        that **does not exist** in the live `permissions` table; the other
        three had zero checks.
      - `transfers` — the whole 8-endpoint lifecycle (create through
        complete-receiving) had TODOs referencing `transfer.request`,
        which likewise does not exist. Any signed-in user could create,
        approve/reject, pick, or receive any inter-warehouse transfer.
      - `delivery-plans` — POST reconcile, POST receipt-cancel: zero checks.
        Any signed-in user could post a receiving reconciliation
        (adjusting stock) or void one.
      - `shipments` — POST ship, POST cancel, and all three carton
        endpoints: zero checks. Any signed-in user could confirm/cancel a
        shipment (deducting/restoring stock) or edit its cartons.
      - `warehouses` — POST create, PATCH update: TODOs referencing
        `warehouse.manage` left unimplemented.
      - `import-plan` — the shared `commit()` helper behind both the
        multipart one-shot save and the reviewed-JSON commit: zero checks.
        Any signed-in user could register an inbound delivery or outbound
        shipment plan.

      Fixed all seven the same way as `stock-ops`, factored into a shared
      `supabase/functions/_shared/require_permission.ts` (`callerPermitted()`
      confirms a real signed-in user via `auth.getUser()`, then trusts
      `has_permission()` under that identity — the same null-`auth.uid()`
      footgun from the stock-ops fix applies here too, so every fix follows
      the same "confirm the user first" rule). Every TODO-referenced
      permission code was checked against the live `permissions` table
      before use rather than trusted verbatim, which is how the two
      nonexistent codes above were caught. Permission mapping used:
      `inspection.confirm` (inspections), `pick.confirm` (picking),
      `transfer.create`/`transfer.approve`/`transfer.receive` (transfers —
      create covers the source/requesting side's whole lifecycle, approve
      gates the approve/reject decision, receive covers the destination
      side), `receiving.confirm` (delivery-plans, and import-plan's
      delivery-plan target), `ship.complete`/`pack.complete` (shipments —
      complete gates ship/cancel, pack gates the carton edits leading up
      to it; pack.complete also gates import-plan's shipment target),
      `warehouse.manage` (warehouses). Deployed as `inspections` v2,
      `picking` v2, `transfers` v2, `delivery-plans` v5, `shipments` v3,
      `warehouses` v4, `import-plan` v6.
  - Same verification limitation as the stock-ops fix: not independently
    exercised over live HTTP (this session's outbound network cannot reach
    `*.supabase.co` directly), verified by code review and by
    `flutter analyze`/`flutter test` passing against the client side.
  - `humanizeApiErrorMessage()` wired into every screen whose action is
    now gated by one of these checks and whose SnackBar previously showed
    `f.message` raw: `InspectionDetailScreen`, `PickListDetailScreen`,
    `PickListIndexScreen`, `TransferDetailScreen`, `TransferListScreen`,
    `ReconciliationScreen`, `ReceiptHistoryScreen`, `ShipmentDetailScreen`,
    `CartonEditScreen`, `AddWarehouseScreen`, `PlanImportScreen`. A
    permission-denied widget test was added for one representative
    mutation per newly-fixed function, following the same
    `failWith`-on-a-fake-repository pattern as the stock-ops tests.
  - [x] **Follow-up, now fixed**: `audit_log_query`, `audit_log_for_entity`,
    and `audit_event_types` (the RPCs behind the `audit-log` edge function,
    a thin read-only proxy) had no `has_permission('audit.view')` check at
    all — and were additionally granted to `anon`, meaning any
    unauthenticated caller with just the anon key, not only any signed-in
    user, could read the full audit trail. Migration 0043 adds the check
    (converting the three functions from `sql` to `plpgsql` so they can
    `raise exception`, matching the idiom `list_ai_analysis` already uses)
    and revokes the `anon`/`public` grants, matching the grant shape every
    other read RPC in the app already uses. The `anon` revoke matters on
    its own: `has_permission()` treats a null `auth.uid()` as "allow" (for
    trusted server-side calls with no user context), and an anon-key call
    has a null `auth.uid()` the same way — adding the permission check
    alone would not have closed that hole, only revoking the grant does.
    Verified live: `anon` can no longer execute any of the three
    (`has_function_privilege` false), `authenticated`/`service_role`
    still can, and each function's live definition now raises
    `not permitted: audit.view required` for a caller without it — the
    same message shape `humanizeApiErrorMessage()` already recognizes, and
    the client already routes every read failure through it via
    `ErrorStateView`, so no client-side change was needed for this one.

**AI UI (UI spec §31)**

"AIはWMS確定データを直接書き換えない" was already true and stays true — confirmed
by re-reading both places an OCR result reaches a human: `PlanImportScreen`
edits a normal form before `commitPlan()` writes anything, and
`AiReviewListScreen`'s confirm/reject only flip the `ai_analysis` row's own
status (documented in the screen's own header comment: not an undo for
whatever the import already did with the lines — it's a record of "was this
AI call trustworthy," decoupled from the write path on purpose).

- [x] **信頼度 (confidence)** was a real gap on two levels. The domain model
      and `AiReviewListScreen`'s card already had a `confidence` field
      parsed and ready — but it was never rendered anywhere, so the spec's
      mockup line ("信頼度 94%") was simply missing. Worse: the field was
      *always null* in every real row, because `ocr-delivery-note`
      hardcoded `p_confidence: null` — Gemini was never asked for one.
      Fixed both: the OCR prompt and response schema now ask Gemini for a
      0–1 self-assessment of its own read quality, clamped defensively and
      stored genuinely (not fabricated client-side if the model omits it —
      stays null and the UI shows nothing for that row, same as before).
      `AiReviewListScreen` now shows "信頼度 NN%" per result, in the error
      colour below 60%. Deployed as `ocr-delivery-note` v8.
- [x] The mockup's third action, [修正] (edit before registering), already
      exists — just not on `AiReviewListScreen`, which the app's own design
      note (`ai_architecture.md` §8) explains was deliberately kept to a
      flat confirm/reject because per-field candidate structure doesn't
      exist yet (OCR is still the only task type). The actual edit point is
      `PlanImportScreen`'s review step: every header field it reads
      (delivery number, supplier, registration number, customer code, doc
      number) is a normal editable `TextField`, pre-filled from the OCR
      read and flagged when unread, before `[登録]` commits anything.
- [x] **Line items in `PlanImportScreen` were read-only** — fixed. Every row
      is now tap-to-edit (JAN, product name, quantity — the JAN field also
      gained a scan button per §35), deletable, and there's an "行を追加" for
      one OCR missed entirely. Added the two operations the spec's own
      wording invited ("分解と結合表記も可能です"): a per-row 分割 (split) that
      roughly halves a line's quantity into a second row — the operator
      then fine-tunes either half using the same edit dialog, so split
      doesn't need its own quantity prompt — and a bulk 同じJANをまとめる
      (merge) that sums every group of duplicate JANs into one row,
      surfaced only when a duplicate actually exists. `_lines`, not the
      original `ImportPreview.lines`, is what `commitPlan()` now sends, so
      every edit actually reaches the write.
- [x] **納品書番号 on the *review* screen** (`AiReviewListScreen`) was
      missing because nothing ever populated `ai_analysis.delivery_plan_id`
      for an `ocr-delivery-note` call, even though the caller
      (`ReconciliationScreen`) already had the plan's id in scope the whole
      time — it just wasn't threaded through. Fixed the whole path: the
      scanner interface gained an optional `deliveryPlanId` parameter (all
      4 implementations updated), `RemoteDeliveryNoteScanner` forwards it as
      `plan_id` in the multipart form (a field name the edge function's own
      doc comment already anticipated), `ocr-delivery-note` reads it and
      passes it to `record_ai_analysis` (deployed as v9), and
      `list_ai_analysis` (0042) now left-joins `delivery_plans` to return
      `delivery_number` alongside it — verified live via an aborted
      transaction. `AiReviewListScreen` shows it at the top of the card
      when present; a standalone OCR call (no plan yet) still shows
      nothing, not a guess.
- [ ] Future items the spec itself lists as future (商品画像認識・破損検知・
      商品自動登録候補・棚入れ候補・在庫分析) remain unbuilt, matching
      `ai_architecture.md` §8's "still open" list — not started here,
      consistent with not building ahead of a real need (§53)

**Warehouse context (UI spec §4)**
- [x] Switching the current warehouse switches every warehouse-scoped feature
      with it. Receiving and Shipping were the two that still ignored it —
      their list endpoints (`delivery-plans`, `shipments` edge functions) now
      take an optional `warehouse_id`, and the providers pass the active
      scope. A null scope stays the deliberate "all warehouses" view, and an
      older client that sends nothing still gets every warehouse, so the
      change is backward compatible
- [x] Fixed along the way: `Shipment.fromJson` sorted the `lines`/`cartons`
      fallback in place, which is a const empty list whenever the key is
      absent — i.e. on every row the *list* endpoint returns. Parsing a
      shipment list threw "Cannot modify an unmodifiable list"; only detail
      fixtures (which always carry both keys) were covered before

**Scanning & operator UX (UI spec §11/§16)**
- [x] One shared scanning component — camera, torch, success/error sound,
      vibration, manual-entry fallback, continuous scan, duplicate
      suppression, scan history and a visible result, all in
      `BarcodeScanScreen`. Adopted by QC receiving (continuous, with a
      shortened duplicate window because one scan is one piece there),
      picking, and put-away
- [x] Barcode-gated quantity confirm in picking (§16) — a pick quantity
      cannot be recorded until the task's own JAN is scanned; a wrong JAN
      sounds the error tone and keeps the gate shut. Typing the code via the
      scanner's manual fallback is not a way around it (it is validated the
      same way), so a damaged label still does not stop the job
- [x] +1 / +5 quick quantity buttons in the pick dialog (§16)

**Reporting**
- [x] Live dashboard (KPIs, today's-tasks counts) — the today's-tasks strip
      now carries §3's full row: 入荷予定・検品待ち・棚入れ待ち・ピッキング・
      梱包待ち・出荷待ち・棚卸・倉庫間移動, each a real count that opens its
      own screen
- [x] Global cross-entity search
- [x] Audit log CSV export
- [x] Custom/saved report builder (0037) — `report.view` has existed since
      0012 (one of the original 22 permissions) but nothing ever
      implemented it until now. A fixed set of six safe, server-defined
      data sources (stock ledger, purchase/sales/work orders, audit log,
      product master) — never arbitrary user SQL — each with a small
      structured filter set (warehouse, status, JAN, category, date range).
      `report.manage`-gated save/delete lets a chosen source+filters
      combination be named and reused. A `ReportBuilderScreen` (pick
      source → filter → run → generic results table → optionally save)
      added to the home menu. Verified live via grants and an
      aborted-transaction round trip covering every source, a
      non-matching filter (empty array, not an error), an unknown-source
      rejection, and the full saved-definition CRUD cycle
- [x] Report sources for the warehouse day itself (0047) — the original six
      covered stock, orders, audit and master data but nothing about what was
      *inspected*, what *moved between warehouses*, or what *shipped*. Three
      sources added: `inspections` (passed/failed quantity and failed-line
      count per inspection, with delivery number and inspector — so the
      report answers "which suppliers keep sending bad stock"), `transfers`
      (both warehouse ends, the three lifecycle timestamps, and requested vs
      received quantity so a shortfall in transit shows as a column
      difference), and `shipments` (line/carton counts with §21's weight,
      carrier and tracking number). The same migration closed a §37 hole
      `run_report` still had: being `security definer` it bypassed RLS and had
      no `accessible_warehouse_ids()` fallback, so a scoped operator could
      report across every warehouse. Aggregates verified with a rolled-back
      data test specifically to rule out JOIN-induced row inflation. Two
      documented judgment calls: `products` stays unscoped (company-wide
      master data with no warehouse column), and `audit_log` rows with a null
      `warehouse_id` are excluded for scoped callers (company-level events
      have no warehouse to test; admins still see everything). The warehouse
      filter stays inside `p_filters` rather than becoming a positional
      `p_warehouse_id` — its meaning is source-dependent ("either end" for
      transfers, nothing for products), and the three-argument signature
      keeps saved `report_definitions` rows working

**Web-app conventions the shell was missing** — six gaps found by reviewing
the shell against what a browser-based dashboard is expected to do, then
closed one per commit. Each was a real "this feels unfinished" rather than a
missing feature.

- [x] **URL routing.** `go_router` had been in pubspec since early on and was
      never wired up: the shell held a nested `Navigator` and swapped screens
      imperatively, so the app had exactly one URL. Browser back did nothing,
      nothing could be bookmarked or shared, and a reload always dropped the
      operator back on the dashboard — the expensive one for a system people
      keep open in a tab all day. Every top-level feature now has a location
      derived from its catalog id (`FeatureEntry.path`), so the catalog is the
      single source of truth for both menu and routing table. Scanned codes go
      in the path too. Sign-in state moved to a single `redirect`, so a session
      ending *any* way — including a token quietly expiring — lands on login.
      Deliberately left on Flutter's default hash URLs (`/#/inspection`):
      path-based URLs need a host rewrite rule, and without it a reload on
      `/inspection` 404s, breaking the very thing the change delivers.
      Detail screens still have no URL of their own (a route per entity with
      typed params) — recorded as follow-up rather than half-built.
- [x] **Breadcrumbs.** The top bar named the current screen and nothing else,
      so a screen opened from a dashboard tile gave no sense of where it sat.
      Now dashboard › section › screen, built by a pure function over the
      catalog rather than a navigation history, so it is right however the
      operator arrived. The section step is text, not a link — it groups
      screens without being one.
- [x] **Collapsible sidebar.** Was a fixed 268px, a fifth of a 1280px laptop
      spent permanently on navigation. Collapses to a 76px icon rail with
      labels in tooltips and section headings as rules; the choice persists per
      operator. Collapsing trades labels for width, never access.
- [x] **Menu filter.** Eighteen entries with no way to narrow them. Matches
      label *and* description, because that is where the words operators
      actually type live ("approve" finds the order screens, whose labels say
      neither). The precision cost is documented and tested rather than tuned
      away.
- [x] **Tabs.** There was no way to read a purchase order while checking
      stock. Screens now open as tabs kept mounted in an `IndexedStack`, so
      switching away costs no scroll position, filter or half-filled form —
      asserted by a test that scrolls, leaves, returns and compares offsets.
      Each tab has its own `Navigator`. The strip stays hidden until a second
      screen is open, so nobody has to learn about tabs to use the app. A scan
      reuses the stock tab rather than adding one per scan.
- [x] **Keyboard shortcuts.** Ctrl/Cmd+K (scan box), Ctrl/Cmd+B (sidebar),
      Ctrl/Cmd+Shift+F (search), Alt+1…9 (tabs), F1 (the list). Chosen around
      what a browser will not surrender: Ctrl+W and Ctrl+1…9 are the host's,
      so tab switching uses Alt and closing a tab has no binding at all.
      Flutter's `CallbackShortcuts` proved unusable here — it resolves through
      the focus chain, and this shell sits inside the router's navigator, so
      the first navigation moved focus above it and shortcuts silently died
      (Alt+1 worked, Alt+2 did nothing; a test caught it). Replaced with
      `GlobalShortcuts`, a `HardwareKeyboard` handler at the same level the
      barcode scanner already uses. That surfaced a latent scanner bug too:
      modified keystrokes reporting a `character` were being fed into the scan
      buffer, so a shortcut press could end up inside a later barcode.

**Other InventorOS-only features never rebuilt on Supabase**
- [ ] Two-factor authentication — ❌
- [ ] Webhooks — ❌
- [ ] GraphQL API — ❌ (Supabase exposes PostgREST + RPC only)
- [ ] Barcode/label printing — ✅ actually **does** exist independently
      (carton/JAN printing via `printing`/`barcode` packages in the shipment
      feature) — not an InventorOS gap

**Client reachability pass (RPCs that existed with no caller anywhere,
closed out 9/25–9/26)** — an audit comparing every `create or replace
function` in `supabase/migrations/` against every `/rpc/` call the Flutter
client actually makes turned up RPCs built, tested at the SQL level, and
then never wired to a screen. Each of the following got a screen (or an
action on an existing one), a repository method, tests, and — where the RPC
needed one — a migration, all re-verified against the live project's 10
security invariants:
- [x] `bin_stock_overview` (0016) — a new screen off the location tree: every
      bin in a warehouse and what is actually in it, not just the
      per-location rollup the tree already showed
- [x] `stock_reconciliation` (0061) — a new screen: every place
      `stock_levels.on_hand` and what `stock_units` sums to disagree,
      previously checkable only by hand-written SQL
- [x] `raise_exception` / `cancel_exception` / `list_exception_types` (0071)
      — the exception queue could show what receiving/QC raised
      automatically, but an operator had no way to report something the
      system did not catch, or to withdraw one raised in error
- [x] `record_receipt_item` (0067) — the receipt detail screen was read-only;
      a parcel found after a reconciliation already closed had no way in
      except raw SQL
- [x] `fulfil_reservation` (0064) — `release_reservation`'s missing sibling,
      now a manual "mark as fulfilled" action beside release. (Corrected
      9/26: this first claimed `fulfilled_quantity` always stayed 0, but
      `ship_plan` (0075) already fulfils shipment reservations inline. The
      manual action covers manual and order-filed promises only)
- [x] `allocate_stock` / `release_allocation` / `reserve_stock` (0064) — the
      reservations screen can now pin a promise to parcels (FEFO), un-pin one
      parcel, and make a manual reservation by JAN (0084 pass)
- [x] `open_demand` / `fill_backorders` / `create_purchase_order_from_demand`
      / `link_delivery_plan_to_purchase_order` (0084) — new, and reachable
      from day one
- [x] `unlinked_jan_codes` / `product_id_coverage` (0058) — a new screen: the
      registration worklist those two RPCs were built to be, never reachable
      before
- [x] `INTERNAL_USE` adjustment reason (0082) — stock the company consumed
      itself had no reason code of its own and always fell into OTHER
- [x] Purchase Order → Delivery Plan (0083) — see the Inbound section above;
      found while re-verifying end-to-end that a manually entered receipt or
      shipment computes correctly, which it does (both post through the one
      `apply_stock_movement_detail` choke point and its `stock_units`-sync
      trigger) — but purchase orders had no structural link to the delivery
      plan that receives them, unlike sales orders' link to their shipment
- Confirmed false positives while auditing (already reachable, some other
  way, no work needed): `carton_detail` (surfaced through
  `shipment_packing`'s own response), `carton_label` (deliberately
  duplicated client-side so label printing needs no network round trip),
  `pick_candidates` (an internal helper of `pick_task_candidates`),
  `pick_list_detail`/`pick_list_index`/`transfer_order_index`/
  `transfer_order_detail`/`stock_count_detail`/`warehouse_overview`/
  `stock_availability`/`inspection_detail`/`audit_log_query`/
  `audit_event_types` (all edge-function-routed, not called via `/rpc/`
  directly), `putaway_suggestions` (embedded in `putaway_queue`'s response)
- Deliberately still not pursued: `set_product_base_uom` (a
  narrow one-time correction tool, refused once any stock movement exists —
  not a routine gap), `list_attachment_targets`/`list_scan_contexts` (every
  caller already knows its own entity type/scan context from the screen it
  is on, so no form would use the vocabulary read)

## 3. Everything not implemented, not Supabase-connected, or not tested

Consolidated, in one place, as asked:

**Not implemented at all:**
- Returns / RMA
- Two-factor authentication, webhooks, GraphQL API
- Any AI module beyond OCR (photo ID, damage detection, inventory assistant)
- Any real connector adapter (the registry exists; nothing syncs)

**Implemented but not tested:**
- Browser history integration (`context.go` pushes an entry via
  `routeInformationUpdated`) — go_router's own behaviour, but it needs a real
  browser to verify, so no widget test covers it
- `shipment_print.dart` (PDF/label generation) — not covered by any test
  (printing output is inherently hard to assert on in a widget test)

**Implemented and code-complete, but never exercised by a real user:**
- Sign-in itself — `app_users`/`user_roles`/`user_warehouses` are all empty in
  production; only fakes and direct SQL have verified the logic

**Everything else in this document marked ✅ is implemented, wired to Supabase,
and has at least one passing automated test as of this checklist.**
