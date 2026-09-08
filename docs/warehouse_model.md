# Warehouse Model

_Multi-warehouse structure and the top-level warehouse experience
(spec §4, §5, §6, §7, §8, §22, §49, §50)._

## 1. Company / warehouse relationship (spec §5)

```
Company (tenant)
  ├── Users / Roles / Permissions
  ├── Warehouse A ── Zone ── Bin
  └── Warehouse B ── Zone ── Bin
```

- Do **not** conflate company and warehouse; one company holds many warehouses.
- Keep FKs flexible: a user may later belong to multiple companies, so avoid
  hard-coding a single company FK path that blocks that.

## 2. `warehouses` (spec §6)

Columns: id, company_id, code, name, description, address, phone, timezone,
status, is_default, created_at, updated_at.
Constraints: code unique within company; inactivate (status) rather than delete;
never physically delete a warehouse that has stock history.

## 3. Location hierarchy (spec §7, §8)

- Practical base: `warehouse → bin`. `zone`/`aisle`/`rack` are optional layers or
  attributes, not mandatory columns — do not force a 4-level hierarchy up front.
- Bin types: STAGING, PICKABLE, PICKABLE_STAGING, QC_HOLD, SHIPPING, RETURNS,
  DAMAGED, VIRTUAL.
  - STAGING: just received; in stock but not normally pickable.
  - QC_HOLD: awaiting/failed inspection; not allocatable.
  - PICKABLE: normal shelf stock.
  - SHIPPING / RETURNS / DAMAGED: staging for those flows.

## 4. Warehouse context & scope (spec §22, §50)

- Each user has `allowed_warehouses`. The active warehouse is a **context** carried
  through the session; queries and writes are scoped to it.
- Enforced in the API/RPC, not just hidden in UI. A user may only read/write in a
  warehouse they are allowed.
- Admin-only "All warehouses" aggregate view (per-warehouse + totals); regular
  operators see only their assigned warehouse(s).

## 5. Top-level UX (spec §4, §49)

- **One warehouse**: no forced picker; the dashboard just shows today's work for
  that warehouse.
- **Two or more**: persistent Warehouse Picker in the top bar, current context
  shown, optional "All" for admins, an "Add warehouse" action at the top level.
- Adding a warehouse is not just UI — it sets up the chain:
  `Add Warehouse → Warehouse Context → Zones/Bins → Users/Permissions →
  Inventory → Operations`.

## 6. Add-warehouse wizard (spec §4.2)

Minimum fields: name, code, address, phone, timezone, default receiving area,
default shipping area, active/inactive.
Optional now / expandable later: zones, bins, and default STAGING / QC_HOLD /
PICKABLE / SHIPPING / RETURNS bins. Auto-creation of default bins is a **toggle**,
not forced.

## 7. Migration note

The current single implicit warehouse becomes the seeded default warehouse of a
seeded default company; existing `stock_levels`/plans/shipments attach to it so
nothing breaks. See `migration_plan.md`.
