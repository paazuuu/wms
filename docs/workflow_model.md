# Workflow & State Model

_Business flows as explicit state machines (spec §9, §13, §16, §40, §41).
Every state transition checks permission + warehouse scope and writes an
audit/event row. "Business event" and "current state" are kept separate:
events are appended to a log; the current state is a derived/updated field._

## 1. Inbound (receiving)

```
Purchase Order → Expected Receipt → Receiving → Barcode Scan →
Quantity Verification → Inspection → QC Result → Staging / QC Hold →
Put-away → Available Inventory
```

State (kept minimal — spec §9, §40):

```
DRAFT → EXPECTED → RECEIVING → RECEIVED → INSPECTION
   ├── PASS    → STAGED → PUTAWAY_PENDING → PUTAWAY → COMPLETED
   ├── FAIL    → QC_HOLD
   └── PARTIAL → REVIEW
(CANCELLED from any pre-COMPLETED state)
```

- Receiving records counted quantity; discrepancy (expected − received) is stored,
  stock is not forced to expected (spec §10).
- QC PASS moves goods to a PICKABLE/STAGING bin; FAIL moves to QC_HOLD (not
  allocatable); PARTIAL flags review.
- Put-away: Staging → suggested bin → scan bin → scan item → quantity → confirm
  (spec §12). Suggestions are rule/AI-driven (category, temp, size, rotation,
  preferred bin, free capacity) and always human-confirmed.
- Maps onto today's delivery reconciliation: a "reconcile" becomes RECEIVING→
  RECEIVED(+ optional INSPECTION); split-delivery accumulation is preserved.

## 2. Outbound (shipping)

```
Sales Order → Shipment Order → Allocation → Pick List → Picking →
Packing → Shipping
```

State (spec §13, §40):

```
OPEN → ALLOCATED → PICKING → PICKED → PACKING → PACKED →
READY_TO_SHIP → SHIPPED   (CANCELLED before SHIPPED)
```

- Picking (spec §14): pick task per bin/zone in bin order; scan Bin → Item →
  Quantity → Confirm; wrong item ⇒ "⚠ この商品は対象外です"; supports short pick,
  batch/wave, undo/release.
- Packing (spec §15): scan order → scan items → qty → packaging → weight → photo →
  complete. Distinct from Shipping.
- Shipping: carrier, service, 送り状 number, ship datetime, complete. Maps onto
  today's shipment cartons + JAN print + 送り状; adds allocate/pick/pack states.

## 3. Inter-warehouse transfer (spec §16)

```
DRAFT → PENDING_APPROVAL → APPROVED → PICKING → IN_TRANSIT →
RECEIVING → COMPLETED   (REJECTED / CANCELLED)
```

- Self-approval disallowed by default.
- Source warehouse emits `TRANSFER_OUT`; destination emits `TRANSFER_IN` on receive.

## 4. Cycle count / adjustment

- Count session per bin/zone; system qty vs counted qty → variance; approval →
  `ADJUST` movement. Blind-count option (count without seeing system qty).
- Ad-hoc adjustment: reason-coded `ADJUST` movement with audit entry.

## 5. Event ↔ state ↔ AI (spec §41, §42)

Bad: `inventory.quantity = 100`.
Good: append `stock_movement{type, qty, warehouse, bin, reference}` then update the
snapshot. AI events are recorded alongside business events:

```
RECEIVING_STARTED → SCAN_ITEM → AI_ANALYSIS_REQUESTED →
AI_ANALYSIS_COMPLETED → HUMAN_REVIEW → INSPECTION_CONFIRMED → PUTAWAY_CONFIRMED
```

AI events are auditable; only human-confirmed results become WMS transactions.

## 6. Transition guards (spec §40, §47)

Each transition validates: authenticated user, role permission for the action,
tenant boundary, warehouse scope, idempotency key (safe retry from offline queue),
and writes `audit_log`. Illegal transitions are rejected server-side, not merely
hidden in the UI.
