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
      not move stock and is not wired into delivery_plans/reconciliation.
      Verified live via grants and an aborted-transaction round trip covering
      every transition plus the wrong-state refusals
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
- [ ] Per-warehouse scope (`user_warehouses`) is enforced server-side by RLS
      on every table already, but nothing client-side surfaces "you can act
      in these warehouses" the way permissions now do — the warehouse picker
      still lists every warehouse the *company* has, not just the ones this
      user is scoped to. Deliberately left out of this pass: no real user
      has signed in with a restricted `user_warehouses` row yet to notice,
      and doing it well means changing the warehouse picker's own list
      query, not just gating a menu entry

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

**Other InventorOS-only features never rebuilt on Supabase**
- [ ] Two-factor authentication — ❌
- [ ] Webhooks — ❌
- [ ] GraphQL API — ❌ (Supabase exposes PostgREST + RPC only)
- [ ] Barcode/label printing — ✅ actually **does** exist independently
      (carton/JAN printing via `printing`/`barcode` packages in the shipment
      feature) — not an InventorOS gap

## 3. Everything not implemented, not Supabase-connected, or not tested

Consolidated, in one place, as asked:

**Not implemented at all:**
- Returns / RMA
- Custom report sources beyond the six built (0037): inspections, transfers,
  shipments
- Two-factor authentication, webhooks, GraphQL API
- Any AI module beyond OCR (photo ID, damage detection, inventory assistant)
- Any real connector adapter (the registry exists; nothing syncs)

**Implemented but not tested:**
- `shipment_print.dart` (PDF/label generation) — not covered by any test
  (printing output is inherently hard to assert on in a widget test)

**Implemented and code-complete, but never exercised by a real user:**
- Sign-in itself — `app_users`/`user_roles`/`user_warehouses` are all empty in
  production; only fakes and direct SQL have verified the logic

**Everything else in this document marked ✅ is implemented, wired to Supabase,
and has at least one passing automated test as of this checklist.**
