# OSS Reference Matrix

_What each "teacher" OSS contributes, and where it lands in `paazuuu/wms`
(spec §2.2, §43). We learn patterns; we clone nothing (spec §53)._

## Teachers

- **OCA WMS** — https://github.com/OCA/wms (Odoo, AGPL)
- **Sentry WMS** — https://github.com/hightower-systems/sentry-wms
  (Flask + React/React-Native, Apache-2.0 since v1.7.0)
- **ERPNext** — https://github.com/frappe/erpnext (Frappe/Python, GPLv3)
- **OpenBoxes** — https://github.com/openboxes/openboxes (Grails, MPL/EPL)

> Licenses differ (AGPL/GPL are copyleft). We take **ideas and data-model shapes**,
> not code. No source is copied into this repo.

## Contribution → target mapping

| Concept | OCA | Sentry | ERPNext | OpenBoxes | Lands in |
|---|:--:|:--:|:--:|:--:|---|
| Module decomposition | ★ | | | | architecture_target §4 |
| Warehouse / Company / tenant | | ★ | ★ | ★ | warehouse_model |
| Zones / Bins / Bin types | | ★ | | ★ | warehouse_model §3 |
| Barcode / scanner service | ★ | ★ | | | ui_ux_plan §3 (§25) |
| Put-away (+ suggestions) | ★ | ★ | | | workflow_model §1 |
| Availability / reordering | ★ | | ★ | ★ | domain_model §3 (later) |
| Receiving | | ★ | ★ | | workflow_model §1 |
| Inspection / QC | | ★ | | | workflow_model §1, ai_architecture |
| Picking (batch/wave, bin order) | | ★ | ★ | | workflow_model §2 |
| Packing (weight, verify) | | ★ | | | workflow_model §2 |
| Shipping / dispatch | ★ | ★ | | | workflow_model §2 |
| Cycle count / blind count | | ★ | | | workflow_model §4 |
| Bin transfer | | ★ | | ★ | workflow_model §3 |
| Inter-warehouse transfer | | ★ | ★ | ★ | workflow_model §3 |
| Stock ledger / stock entry | | | ★ | ★ | domain_model §3, migration 0013 |
| Serial / batch / lot | | | ★ | ★ | domain_model §2 (future) |
| PO / Purchase receipt | | | ★ | | domain_model §4 |
| Sales order / Pick list | | | ★ | | domain_model §5 |
| Document relationships / integrity | | | ★ | | domain_model §8 |
| Audit / event log | | ★ | ★ | | permission_model §5 |
| Testable service layer | | ★ | | | architecture_target §4 |
| Physical logistics realism | | | | ★ | workflow_model |
| Item-level tracking | | | ★ | ★ | domain_model §2 |

★ = a primary source we lean on for that concept (spec §43 priority lists).

## Priority order (spec §43)

- **Sentry** — closest to our shape (mobile scanner + floor ops + practical state
  machines + audit). Primary teacher for the operational flows (Steps 4–12).
- **ERPNext** — the authority for stock ledger, document relationships, and
  inventory integrity. Primary teacher for the ledger (Step 12) and master data.
- **OCA WMS** — module decomposition, put-away, availability, device integration.
- **OpenBoxes** — realism check for warehouse/stock movement and logistics.

## Also on hand: InventorOS (current backend)

Not a "teacher" from the spec, but the app's existing Laravel backend
(`findings.md`) already implements warehouses, `organization_id` multi-tenancy,
locations, PO (`/receive` `/send` `/cancel`), stock-adjustments, stock-audits,
suppliers, work-orders, reports, barcode lookup, and a permission enum. Its schema
and permission conventions are a concrete, in-house reference for the Supabase
target model — and it can later be wrapped as a Connector (spec §34) rather than
remaining a parallel core.
