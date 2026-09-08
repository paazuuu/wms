# UI / UX Plan

_Improve information structure, not just decoration (spec §4, §23, §24, §39,
§50, §52). Management and mobile have different jobs._

## 1. Core principle (spec §52)

A WMS is software for **completing floor work**, not just viewing data.

```
Management (wide/PC): view · configure · approve
Mobile (handheld):    scan · verify · complete a task
```

The app already uses one adaptive shell (sidebar on wide, drawer on narrow); we
specialize behavior by width rather than shipping two apps.

## 2. Management surface (spec §23, §39)

- Sidebar (grouped capabilities) + **top warehouse picker** + breadcrumb.
- Global search over items/bins/POs/SOs/customers.
- Filterable tables with a detail drawer/modal, status badges, activity timeline,
  audit history.
- Admin dashboard (spec §23): today's counts (入荷予定/検品待ち/棚入れ待ち/
  ピッキング/梱包待ち/出荷待ち), stock (SKU / on-hand / low-stock), and alerts
  (差異 / 検品NG / 出荷遅延). The current live-KPI dashboard is the seed of this;
  extend it to the staged-flow counts once those flows exist.

## 3. Mobile / handheld surface (spec §24)

Task-first "today's work" list with large tap targets:

```
📥 入荷 12   📦 棚入れ 8   🛒 ピッキング 23   📦 梱包 9   🚚 出荷 17   🔍 棚卸 4
```

Tapping a task opens its scan flow. Minimal typing, one-handed, clear error and
clear completion states. Scanner type (camera / hardware / manual / future RFID)
is abstracted behind one service (spec §25) — screens don't care which.

## 4. Warehouse picker & add (spec §4, §49, §50)

- One warehouse → no picker; show that warehouse's work directly.
- Two+ → persistent picker in the top bar, current context shown; admins get an
  "All warehouses" aggregate (per-warehouse figures + totals).
- Top-level "Add warehouse" → wizard (name, code, address, phone, timezone,
  default receiving/shipping area, active) → optional default bins.

## 5. Status & flow legibility (spec §40)

Every document shows its state as a badge and its history as a timeline. State
machines (receiving / picking / transfer) are surfaced so an operator sees where a
job is and what the next action is. Errors ("wrong item", "over quantity", "out of
scope") are explicit and blocking where they must be.

## 6. Consistency to preserve

Keep the existing design system (`app_colors`, `app_spacing`, `StatusPill`,
`StatusAvatar`, state views), dark mode, ja/en/zh, and the text-scaling option.
New screens reuse these primitives; no hardcoded UI strings (spec §20).

## 7. Sequencing

UI follows data (spec §46): the shell + warehouse picker land with Steps 1–3; each
operational screen (receiving, put-away, picking, packing, shipping, count,
transfer) is built as its backend flow lands, then the full UI/UX pass is Step 14.
