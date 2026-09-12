# Architecture — Current State

_Supersedes `architecture_phase0_snapshot.md`. Verified against the live
Supabase project (`vjunicsfobglmncjucbb`), the Flutter codebase, and the test
suite — see `feature_checklist.md` for the feature-by-feature detail this
document summarizes._

## 1. High-level shape

One backend, one auth system, one client:

```
Flutter app (mobile / web)
   │
   ├── Supabase Auth (GoTrue)     real sign-in, admin-created accounts only
   │
   └── Supabase (Postgres + Edge Functions, project vjunicsfobglmncjucbb)
         tenancy · warehouses/zones/bins · roles/permissions/audit ·
         receiving → inspection (QC) · picking → packing → shipping ·
         stock ledger · adjustments · cycle counts · inter-warehouse
         transfers · dashboard · global search · ai_analysis (OCR) ·
         connector registry (skeleton)
```

InventorOS (a separate Laravel app this project once called for ~10 screens)
was removed entirely: it was never actually reachable in this deployment, and
the decision was made not to stand it up rather than keep broken menu entries
and a dependency on it. See `migration_plan.md`'s "Post-0028" entry for the
removal itself, and `feature_checklist.md` for what that leaves as a real gap
(no product master, no purchase/sales orders, no supplier/customer CRM, no
work orders, no custom report builder — none of that has a Supabase
equivalent today).

## 2. Repository layout

- `mobile/` — Flutter app (Riverpod, gen_l10n ja/en/zh, Dio).
- `supabase/migrations/` — `0001`–`0028`, sequential and additive (see
  `migration_plan.md` for what each one did).
- `supabase/functions/` — `delivery-plans`, `import-plan`, `ocr-delivery-note`,
  `shipments`, `warehouses`, `inspections`, `picking`, `transfers`,
  `stock-ops`, `audit-log` (Deno edge functions, all `verify_jwt: true`).
- `docs/` — this file, `feature_checklist.md`, `migration_plan.md`, plus the
  design docs (`architecture_target.md`, `domain_model.md`,
  `permission_model.md`, `workflow_model.md`, `ai_architecture.md`,
  `ui_ux_plan.md`) and the Phase 0 historical snapshot.

## 3. Flutter feature modules (`mobile/lib/features/`)

Every module below is Supabase-backed; none call an external system.

| Module | What it does | Tested? |
|---|---|---|
| auth | Real sign-in (Supabase Auth), session/token refresh | ❌ no tests (see `feature_checklist.md`) |
| home | Dashboard, feature menu, task-first mobile strip | ✅ |
| delivery | Plan list, import (+ OCR assist), reconciliation, receipts, stock list | ✅ |
| shipment | List, detail, carton edit + JAN/送り状 printing, sender settings | ✅ (printing itself untested) |
| qc | Inbound inspection (pass/fail/hold/partial) | ✅ |
| picking_ops | Pick lists, short/over detection | ✅ |
| stock_ops | Adjustments (reason-coded), cycle counts (blind supported) | ✅ |
| transfers | Inter-warehouse transfer state machine | ✅ |
| warehouse_context | Warehouse picker, overview, add-warehouse wizard | ✅ |
| audit | Audit log viewer, CSV export, per-entity activity timeline | ✅ |
| search | Cross-entity search (stock/delivery/shipment/pick list/transfer) | ✅ |
| admin | Assign/revoke teammate roles | ✅ |
| connectors | Registry list + enable toggle (skeleton, no adapters) | ✅ |

## 4. Supabase data model (public schema highlights)

- Tenancy: `companies` → `warehouses` → `zones`/`bins`.
- Access: `app_users`, `roles`, `permissions`, `role_permissions`,
  `user_roles`, `user_warehouses` (this last one has no UI writing to it yet
  — see gap list below), `audit_log` (append-only).
- Delivery/shipment: `delivery_plans`/`delivery_plan_lines`,
  `delivery_reconciliations`/`reconciliation_lines`, `delivery_suppliers`,
  `shipment_plans`/`shipment_lines`/`shipment_cartons`/`shipment_carton_items`.
- Inventory: `stock_levels` (snapshot), `stock_movements` (ledger),
  `bin_stock`, `stock_adjustments`, `stock_counts`/`stock_count_lines`.
- Operations: `inspections`/`inspection_items`, `pick_lists`/`pick_tasks`,
  `transfer_orders`/`transfer_order_lines`.
- AI: `ai_analysis` (PENDING_REVIEW/CONFIRMED/REJECTED, idempotent by input
  hash) — no `products`, `attachments`, `purchase_orders`, `sales_orders`,
  `customers`, or `work_orders` tables exist.
- Connectors: `connectors` (registry, one seeded row: `inventoros`, disabled),
  `connector_runs` (empty — nothing has ever run).
- Storage: no bucket has been created; there is no image/attachment upload
  anywhere in the app today.
- RLS is enabled on every table; every write goes through a SECURITY DEFINER
  RPC or an edge function running as service role — nothing is written
  directly from a client's own privileges.

## 5. Cross-cutting capabilities

- **i18n**: gen_l10n, ja (template) / en / zh.
- **Theming**: light/dark via `ThemeMode.system`, plus a text-scale setting.
- **Scanning**: hardware keyboard-wedge scanner, camera scan
  (`mobile_scanner`), on-device OCR fallback (ML Kit) when the cloud OCR call
  fails, manual `ScanField` entry.
- **AI/OCR**: Gemini behind an `AIProvider` interface, results recorded in
  `ai_analysis`. No human-review screen for those results yet (the RPCs
  exist; nothing calls them).
- **Auth**: real Supabase Auth sign-in, admin-created accounts only (no
  public sign-up), first sign-in auto-promotes to System Admin.
- **Offline support**: none. The InventorOS-era offline mutation queue was
  removed along with InventorOS itself (it only ever served that dead
  screen); no Supabase-backed feature has an offline queue today.

## 6. Known gaps

See `feature_checklist.md` §3 for the full, itemized list. The short version:
no product master, no purchase/sales orders, no supplier/customer CRM beyond
delivery-scoped suppliers, no work orders, no custom report builder, no image
storage, no AI human-review UI, no working connector adapter, no per-user
warehouse-scope management screen, and the entire auth stack has zero
automated test coverage.
