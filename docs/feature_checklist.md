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
- [ ] Formal put-away task/confirmation step — ⚠️ locations exist and are
      optional per warehouse, but there is no dedicated put-away screen/queue
      distinct from receiving

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

**Reporting**
- [x] Live dashboard (KPIs, today's-tasks counts)
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
- Custom report sources beyond the six built (0037): put-away task tracking,
  inspections, transfers, shipments
- Two-factor authentication, webhooks, GraphQL API
- Any AI module beyond OCR (photo ID, damage detection, inventory assistant)
- Any real connector adapter (the registry exists; nothing syncs)
- Dedicated put-away task/queue distinct from receiving

**Implemented but not tested:**
- `shipment_print.dart` (PDF/label generation) — not covered by any test
  (printing output is inherently hard to assert on in a widget test)

**Implemented and code-complete, but never exercised by a real user:**
- Sign-in itself — `app_users`/`user_roles`/`user_warehouses` are all empty in
  production; only fakes and direct SQL have verified the logic

**Everything else in this document marked ✅ is implemented, wired to Supabase,
and has at least one passing automated test as of this checklist.**
