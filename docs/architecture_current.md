# Architecture — Current State

_Supersedes `architecture_phase0_snapshot.md`. Verified against the live
Supabase project (`vjunicsfobglmncjucbb`), the Flutter codebase, and the test
suite — see `feature_checklist.md` for the feature-by-feature detail this
document summarizes. Migrations `0010`–`0038` applied._

## 1. High-level shape

One backend, one auth system, one client:

```
Flutter app (mobile / web)
   │
   ├── Supabase Auth (GoTrue)     real sign-in, admin-created accounts only
   │
   └── Supabase (Postgres + Edge Functions, project vjunicsfobglmncjucbb)
         tenancy · warehouses/zones/bins · roles/permissions/audit ·
         receiving → inspection (QC) → attachments (photos) ·
         picking → packing → shipping · stock ledger · adjustments ·
         cycle counts · inter-warehouse transfers · product master ·
         purchase orders · sales orders · supplier/customer directory ·
         work orders (kitting/assembly) · dashboard · global search ·
         ai_analysis (OCR) + human review · connector registry (skeleton) ·
         custom/saved report builder
```

InventorOS (a separate Laravel app this project once called for ~10 screens)
was removed entirely: it was never actually reachable in this deployment, and
the decision was made not to stand it up rather than keep broken menu entries
and a dependency on it. See `migration_plan.md`'s "Post-0028" entry for the
removal itself. Every gap that removal left (product master, purchase/sales
orders, supplier/customer CRM, work orders, image storage, custom reports) has
since been rebuilt natively on Supabase (0031–0038) — see §6 below for what
still has no equivalent.

## 2. Repository layout

- `mobile/` — Flutter app (Riverpod, gen_l10n ja/en/zh, Dio).
- `supabase/migrations/` — `0001`–`0038`, sequential and additive (see
  `migration_plan.md` for what each one did).
- `supabase/functions/` — `delivery-plans`, `import-plan`, `ocr-delivery-note`,
  `shipments`, `warehouses`, `inspections`, `picking`, `transfers`,
  `stock-ops`, `audit-log` (Deno edge functions, all `verify_jwt: true`).
  Everything added since 0029 (warehouse scope, AI review, connectors,
  attachments, product master, purchase/sales orders, trading partners, work
  orders, reports) is a Postgres RPC called directly over PostgREST, not a
  new edge function — the edge-function surface hasn't grown since 0028.
- `docs/` — this file, `feature_checklist.md`, `migration_plan.md`, plus the
  design docs (`architecture_target.md`, `domain_model.md`,
  `permission_model.md`, `workflow_model.md`, `ai_architecture.md`,
  `ui_ux_plan.md`) and the Phase 0 historical snapshot.

## 3. Flutter feature modules (`mobile/lib/features/`)

Every module below is Supabase-backed; none call an external system.

| Module | What it does | Tested? |
|---|---|---|
| auth | Real sign-in (Supabase Auth), session/token refresh | ✅ 41 tests |
| home | Dashboard, feature menu, task-first mobile strip | ✅ |
| delivery | Plan list, import (+ OCR assist), reconciliation, receipts, stock list | ✅ |
| shipment | List, detail, carton edit + JAN/送り状 printing, sender settings | ✅ (printing itself untested) |
| qc | Inbound inspection (pass/fail/hold/partial) + photo attachments | ✅ |
| picking_ops | Pick lists, short/over detection | ✅ |
| stock_ops | Adjustments (reason-coded), cycle counts (blind supported) | ✅ |
| transfers | Inter-warehouse transfer state machine | ✅ |
| warehouse_context | Warehouse picker, overview, add-warehouse wizard | ✅ |
| audit | Audit log viewer, CSV export, per-entity activity timeline | ✅ |
| search | Cross-entity search (stock/delivery/shipment/pick list/transfer) | ✅ |
| admin | Assign/revoke teammate roles + per-user warehouse scope | ✅ |
| connectors | Registry list + enable toggle (skeleton, no adapters) | ✅ |
| ai_review | Human review of AI (OCR) results — confirm/reject | ✅ |
| product | Product master (name/category/price against a JAN) | ✅ |
| purchasing | Purchase orders (draft → submit → approve/reject → complete) | ✅ |
| sales | Sales orders (same lifecycle, outbound side) | ✅ |
| partners | Supplier/customer directory (search, kind filter, contacts) | ✅ |
| work_orders | Kitting/assembly (consume components, produce one output) | ✅ |
| reports | Custom/saved report builder (6 fixed data sources) | ✅ |

## 4. Supabase data model (public schema highlights)

- Tenancy: `companies` → `warehouses` → `zones`/`bins`.
- Access: `app_users`, `roles`, `permissions`, `role_permissions`,
  `user_roles`, `user_warehouses` (admin UI now writes to this — 0029),
  `audit_log` (append-only).
- Delivery/shipment: `delivery_plans`/`delivery_plan_lines`,
  `delivery_reconciliations`/`reconciliation_lines`, `delivery_suppliers`
  (now a general trading-partner directory — `kind`: supplier/customer/both,
  plus contact/phone/email/address/payment terms, 0035),
  `shipment_plans`/`shipment_lines`/`shipment_cartons`/`shipment_carton_items`.
- Inventory: `stock_levels` (snapshot), `stock_movements` (ledger — now also
  carries `WORK_ORDER_CONSUME`/`WORK_ORDER_PRODUCE`, 0036), `bin_stock`,
  `stock_adjustments`, `stock_counts`/`stock_count_lines`.
- Operations: `inspections`/`inspection_items`, `pick_lists`/`pick_tasks`,
  `transfer_orders`/`transfer_order_lines`, `purchase_orders`/
  `purchase_order_lines` (0033), `sales_orders`/`sales_order_lines` (0034),
  `work_orders`/`work_order_components` (0036) — the last three are
  self-contained order-lifecycle documents that never move stock themselves
  (work orders are the exception: completing one does move stock).
- Master data: `products` (jan_code-keyed name/category/price, 0032).
- AI: `ai_analysis` (PENDING_REVIEW/CONFIRMED/REJECTED, idempotent by input
  hash), reviewed via `AiReviewListScreen` (0030).
- Files: `attachments` (polymorphic `entity_type`/`entity_id`, 0031) backed by
  the private `inspection-attachments` Storage bucket — the first and so far
  only file-upload capability in the app.
- Reporting: `report_definitions` (0037) — saved source+filters combinations
  for the report builder.
- Put-away: `putaway_confirmations` (0038) — an idempotency ledger only. The
  queue itself is derived (`stock_levels.on_hand` minus that JAN's `bin_stock`
  per warehouse), so it cannot drift out of step with the balances it reports
  on, and `confirm_putaway` moves stock only via BIN-scoped
  `apply_bin_movement`, leaving the warehouse total untouched.
- Connectors: `connectors` (registry, one seeded row: `inventoros`, disabled),
  `connector_runs` (empty — nothing has ever run).
- RLS is enabled on every table; every write goes through a SECURITY DEFINER
  RPC or an edge function running as service role — nothing is written
  directly from a client's own privileges.

## 5. Cross-cutting capabilities

- **i18n**: gen_l10n, ja (template) / en / zh — every feature added through
  0038 ships all three languages.
- **Theming**: light/dark via `ThemeMode.system`, plus a text-scale setting.
- **Scanning**: one shared surface, `BarcodeScanScreen` (UI spec §11) —
  camera (`mobile_scanner`), torch, success/error sound and vibration
  (Flutter's own platform sounds, no bundled audio), a manual-entry fallback
  for a damaged label, single-shot *or* continuous mode, caller-supplied
  validation (`expectedCode`/`validate`), duplicate suppression with a
  per-use window, and a visible scan history. Plus the keyboard-wedge
  hardware scanner (`ScanBuffer`/`HardwareScanner`), inline `ScanField`
  entry, and an on-device OCR fallback (ML Kit) when the cloud OCR call
  fails. Duplicate timing and history live in framework-free `ScanSession`
  so they are unit-testable; the camera is injectable (`cameraBuilder`) so
  the whole pipeline is covered by widget tests.
- **AI/OCR**: Gemini behind an `AIProvider` interface, results recorded in
  `ai_analysis` and reviewed (confirm/reject) via `AiReviewListScreen` (0030).
- **Auth**: real Supabase Auth sign-in, admin-created accounts only (no
  public sign-up), first sign-in auto-promotes to System Admin. Full test
  coverage added (session storage, token refresh/coalescing, auth
  interceptor, repository, controller state machine — 41 tests).
- **Files**: photo attachments on inspections via a private Storage bucket +
  signed URLs (0031) — the only upload surface today; other entities could
  reuse the same polymorphic table without a schema change.
- **Offline support**: none. The InventorOS-era offline mutation queue was
  removed along with InventorOS itself (it only ever served that dead
  screen); no Supabase-backed feature has an offline queue today.

## 6. Known gaps

See `feature_checklist.md` §3 for the full, itemized list. The short version:
no returns/RMA, no report sources beyond the six built (0037), no 2FA/webhooks/GraphQL, no AI
module beyond OCR (photo ID, damage detection, inventory assistant), no
working connector adapter (the registry exists; nothing syncs), and nobody
has actually signed in on a real device yet — `app_users`/`user_roles`/
`user_warehouses` are all still empty in production, so the real-sign-in and
per-user-scope paths are verified by tests and direct SQL only.
