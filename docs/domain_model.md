# Domain Model

_Target entities and relationships (spec §5–§19). Additive over the current
Supabase schema. Names are proposals; final column sets are pinned per-migration
in `migration_plan.md`._

## 1. Tenancy & warehouse

```
companies (tenant)
  └── warehouses
        └── zones (optional)
              └── bins  (bin_type: STAGING | PICKABLE | PICKABLE_STAGING |
                         QC_HOLD | SHIPPING | RETURNS | DAMAGED | VIRTUAL)
```

- `companies`: id, name, code, status.
- `warehouses`: id, company_id, code (unique per company), name, description,
  address, phone, timezone, status, is_default. Inactivate, never hard-delete a
  warehouse with stock history (spec §6).
- `zones`: id, warehouse_id, code, name (optional hierarchy).
- `bins`: id, warehouse_id, zone_id?, code, bin_type, is_active, attributes jsonb
  (aisle/rack/temp/capacity kept as attributes, not forced columns — spec §7).

## 2. Master data

- `products` (extend existing): id, sku, barcode, name, name_ja, name_zh, name_en,
  category_id, brand, manufacturer, model, unit, weight, dimensions, status.
  Future: variants, packaging, case/inner qty, UOM conversion, serial, lot, expiry
  (spec §19). Multilingual via columns now; translation table if it grows (§20).
- `product_categories`: id, company_id, name(+translations), parent_id?.
- `suppliers`: reconcile the current `delivery_suppliers` into a general supplier
  master (id, company_id, code, name, reg_no…). Keep delivery references working.
- `customers`: id, company_id, code, name, reg_no… (outbound counterpart).

## 3. Inventory (event/state separation — spec §17, §41)

Never rely on a bare `quantity`. Three concerns:

- `inventory` (snapshot): (warehouse_id, bin_id?, product_id/jan_code, on_hand,
  allocated, available) — fast reads. Supersedes today's flat `stock_levels`;
  `stock_levels` is migrated in as the on_hand snapshot for the default warehouse.
- `stock_movements` (ledger): id, company_id, warehouse_id, bin_id?, product ref,
  type (RECEIPT | PUTAWAY | PICK | SHIP | ADJUST | TRANSFER_IN | TRANSFER_OUT |
  COUNT), quantity (+/-), reference_type, reference_id, user_id, created_at.
- Derived ledger view: Opening + Receipt + Transfer In + Adjustment± − Pick − Ship
  − Transfer Out = current, always reconstructable (spec §18). Every movement
  answers "why did stock change?" with before/after/reason/reference/user.

Rule: a stock change inserts a `stock_movement` inside a transaction, then updates
`inventory`. Both, atomically, or neither.

## 4. Inbound documents

- `purchase_orders` / `purchase_order_lines`: expected inbound. The current
  `delivery_plans`/`delivery_plan_lines` are the concrete 納品予定 and map onto this
  (a delivery plan is an expected receipt against a PO or standalone).
- `receipts` (receiving sessions) / `receipt_lines`: the current
  `delivery_reconciliations`/`reconciliation_lines` generalize to this — a receiving
  event with counted quantities and a QC outcome.
- `inspections` / `inspection_items`: QC against a receipt line (product code, JAN,
  lot, serial, expected/actual, condition, expiry, label, photo, comment; result
  PASS | FAIL | PARTIAL | HOLD — spec §10). Discrepancy is stored (e.g. −4), stock
  is **not** forced to expected.

## 5. Outbound documents

- `sales_orders` / `sales_order_lines`: demand.
- `shipments` / `shipment_lines` / `shipment_cartons` / `shipment_carton_items`:
  the current shipment model, extended with allocation + pick/pack/ship states.
- `pick_lists` / `pick_tasks`: allocation → picking work (batch/wave, bin order).

## 6. Movement between warehouses

- `transfer_orders`: id, transfer_number, source_warehouse_id,
  destination_warehouse_id, status, requested_by, approved_by, approved_at,
  shipped_at, received_at (spec §16). Self-approval disallowed by default.
  Emits TRANSFER_OUT at source and TRANSFER_IN at destination.

## 7. AI, attachments, audit (separate stores)

- `ai_analysis`: AI results with confidence + review state (see `ai_architecture.md`).
- `attachments`: polymorphic (entity_type, entity_id) with hash, mime, size,
  uploader, storage path (spec §32) — mirrors the InventorOS design in `findings.md`.
- `audit_log`: sensitive operations as event_type + JSON details (`permission_model.md`).

## 8. Relationship map

```
company ─< warehouse ─< zone ─< bin
company ─< product >─ category
company ─< supplier ;  company ─< customer
purchase_order ─< po_line          sales_order ─< so_line
purchase_order ─< receipt ─< receipt_line ─ inspection ─< inspection_item
sales_order ─< shipment ─< shipment_line ; shipment ─< carton ─< carton_item
transfer_order (source_wh, dest_wh)
inventory (warehouse, bin, product)  ;  stock_movements ─ reference→(any doc)
attachments (→ any)  ;  ai_analysis (→ product/inspection/attachment)  ;  audit_log
```
