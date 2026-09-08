# Architecture — Target State

_Where `paazuuu/wms` is heading per `WMS_改善統合仕様書_Claude_Code.md`.
Evolution, not rewrite: keep what works, absorb mature WMS patterns._

## 1. Guiding principles (spec §1, §2, §47, §53)

1. Do not throw the existing system away; reuse Flutter, Supabase, offline queue,
   scanning, i18n, delivery/shipment/stock, inspection/attachments.
2. Learn business models from four "teacher" OSS projects (OCA WMS, Sentry WMS,
   ERPNext, OpenBoxes) — see `oss_reference_matrix.md`. Clone none of them.
3. Migration-first, additive, non-breaking. No `DROP DATABASE`, no big rewrites.
4. Security is enforced **server-side** (API/RPC), never by hiding UI.
5. Stock changes are **transactions recorded as movements**, then the snapshot is
   updated — never a bare `quantity =` mutation.
6. AI never commits WMS data directly; results are stored separately and confirmed
   by a human.

## 2. Target topology (spec §3)

```
                         WMS
                          │
          ┌───────────────┼────────────────┐
       管理Web          Mobile           AI Layer
          │               │                 │
   company / warehouse / product      OCR · Vision · LLM
          │               │                 │
          └──────── PostgreSQL (Supabase) ───┘
                          │
   inventory · stock_movements · inspection · ai_analysis · audit_log
```

WMS core and AI are fully separated. AI does recognition/OCR/candidate
generation/anomaly detection; the WMS records the final transaction.

## 3. Consolidation decision

The Supabase Postgres is the **system of record** we grow, because it backs the
features actually in use and is reachable from the deployed app. The target model
adds, in Supabase, the concepts the InventorOS schema already proves out
(company/tenant, warehouse, location, PO/SO, stock ledger, roles) rather than
depending on an external Laravel service the user does not run. InventorOS stays
a **reference** for proven schema/permission shapes (`findings.md`), and its REST
surface can later become one Connector among others (spec §34), not the core.

Rationale: one data model, one auth story, one deployment. Dual-backend drift is
the current top source of "half the app is dead."

## 4. Layered design (spec §27, §35, §47.12, §34)

- **DB / migrations** — additive SQL under `supabase/migrations/`, sequential.
- **Backend logic** — Postgres RPCs + Deno edge functions. Every state change:
  checks permission + tenant + warehouse scope, runs in a transaction, writes a
  `stock_movement` (if stock changes) and an `audit_log` row, and is idempotent.
- **Repository / Service / Provider** separation in Flutter (already the pattern).
- **AI layer** — `AIProvider` abstraction (OpenAI/Anthropic/Gemini/local) writing
  to `ai_analysis`; business code depends on the abstraction, not a vendor.
- **Connector/Adapter layer** — external systems (Shopify, carriers, freee,
  InventorOS…) behind adapters; never embedded in core logic.

## 5. Target domain (summary; details in the model docs)

- Tenancy: `companies` → `warehouses` → `zones`/`bins`; `users` with roles and a
  per-user `allowed_warehouses` scope. (`warehouse_model.md`, `permission_model.md`)
- Master data: `products` with multilingual names, categories, UOM; suppliers;
  customers. (`domain_model.md`)
- Inbound: PO → expected receipt → receiving → inspection (QC) → staging →
  put-away → available. (`workflow_model.md`)
- Outbound: SO → allocation → pick list → picking → packing → shipping.
- Inventory: `inventory` snapshot + `stock_movements` + derived ledger; adjustments,
  cycle count, inter-warehouse transfer. (`domain_model.md`, `workflow_model.md`)
- Audit: `audit_log` for every sensitive operation. (`permission_model.md`)
- AI: `ai_analysis` results with confidence + human review. (`ai_architecture.md`)

## 6. UI target (spec §4, §23, §24, §39, §52)

- **Management (wide/PC)**: sidebar, top warehouse picker, breadcrumb, search,
  filterable tables, detail drawers, status badges, activity timeline, audit view.
- **Mobile/handheld**: task-first ("today's work" counts → tap → scan flow),
  large buttons, minimal input, clear error + completion states.
- One warehouse → no forced picker; two+ → top-level picker, "all warehouses"
  admin view, add-warehouse wizard. Details in `ui_ux_plan.md`.

## 7. Non-negotiables carried from current state

Keep: delivery reconciliation (incl. split accumulation), shipment cartons + JAN
printing + 送り状, sender profile, dashboard KPIs, offline queue, scanner service,
ja/en/zh i18n, dark mode, text scaling, the existing test suite.
