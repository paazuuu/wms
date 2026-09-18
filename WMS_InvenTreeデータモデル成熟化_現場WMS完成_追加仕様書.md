# WMS InvenTreeデータモデル成熟化・現場WMS完成 追加仕様書

## 1. 目的

`paazuuu/wms` を **Flutter + Supabase/PostgreSQL** のまま発展させる。

方針は「InvenTreeへ置換」ではなく、

- InvenTreeから **Product / Stock / Lot / Serial / Expiry / Location / BOM / Traceability** の成熟したデータモデルを吸収
- OCA WMS / Sentry WMS等から **Receiving / QC / Put-away / Picking / Packing / Carton / Shipping / Cycle Count / Transfer** の現場フローを吸収
- 現在のWMSを「在庫CRUD」ではなく、実際の倉庫作業を最後まで完結できるWMSにする

ことである。

## 2. 現在のWMSを壊さない

2026-09時点で `architecture_current.md` / `feature_checklist.md` には、multi-warehouse、roles、receiving、QC、put-away、picking、packing、shipping、stock ledger、cycle count、transfer、product、purchase/sales order、partners、work orders、audit、barcode、OCR等が既に存在する。

したがって、今後は全面作り直しではなく **additive migration + 既存RPC互換 + 段階移行** を原則とする。

絶対に戻さない：

- Django
- Laravel / InventorOS
- 別PostgreSQL
- 別Auth
- Node.js backendへの置換
- Flutter以外のMobile framework

基盤は固定：

```text
Flutter
  ↓
Supabase Auth
  ↓
Supabase PostgreSQL
  ├─ RPC / Edge Functions
  ├─ Storage
  └─ API / Realtime
```

---

# 3. 最重要改善：ProductとStockを分離

現在の `products` はJAN中心で、stock系にも商品情報が重複している。

今後は、

```text
Product
  ↓
Stock / Stock Unit
  ↓
Location
```

を明確にする。

### Product

```text
products
- id                    ← 内部不変ID
- sku
- name
- category_id
- brand
- default_uom_id
- weight
- dimensions
- tracking_mode
- active
```

### Barcode

JANを内部主キーにしない。

```text
product_barcodes
- id
- product_id
- barcode
- barcode_type
- is_primary
- quantity_per_scan
```

同一商品に、

```text
JAN
EAN/UPC
社内SKU
ケースコード
QR
物流ラベル
```

を複数登録できるようにする。

---

# 4. Lot / Serial / Expiryを第一級データにする

最低限：

```text
lots
- id
- product_id
- lot_code
- manufacture_date
- expiry_date
- supplier_id
- received_at
```

```text
serial_numbers
- id
- product_id
- serial_number
- lot_id
- status
```

Stock側では、

```text
product_id
warehouse_id
bin_id
lot_id
serial_id
quantity
uom
status
received_at
expiry_date
```

を追跡可能にする。

Productごとに、

```text
UNTRACKED
LOT
SERIAL
LOT_AND_SERIAL
EXPIRY
```

等のtracking modeを持たせる。

---

# 5. Stock Statusと数量を分離

`on_hand = 100` だけでは弱い。

概念として、

```text
ON_HAND
AVAILABLE
RESERVED
ALLOCATED
QC_PENDING
HOLD
QUARANTINE
DAMAGED
EXPIRED
BLOCKED
```

を扱えるようにする。

特に、

```text
available
≠
on_hand
```

を明確にする。

原則：

```text
Available
= 使用可能なOn Hand
  - Reserved
  - Blocked/Hold等
```

二重計上しないよう、実装上の正規ソースを決める。

---

# 6. ReservationとAllocationを追加

理想フロー：

```text
Sales Order
   ↓
Reservation
   ↓
Allocation
   ↓
Pick
   ↓
Pack
   ↓
Ship
```

- Reservation = 注文のために確保
- Allocation = 実際に取る在庫候補を割当
- Pick = 現場で実際に取った
- Ship = 倉庫から出た

**Allocationしただけでは在庫を減らさない。**

---

# 7. Locationを成熟させる

現在の、

```text
Warehouse
 └ Zone
    └ Bin
```

は維持しつつ、汎用treeにする。

```text
locations
- id
- warehouse_id
- parent_id
- code
- name
- location_type
- barcode
- active
- pickable
- receivable
- shipping
- quarantine
- virtual
```

`parent_id` による階層なら、

```text
Warehouse
 └ Zone
    └ Aisle
       └ Rack
          └ Shelf
             └ Bin
```

にも対応できる。

---

# 8. Location Typeを導入

例：

```text
RECEIVING
QC
STORAGE
PICKING
PACKING
SHIPPING
QUARANTINE
DAMAGED
RETURN
TRANSIT
VIRTUAL
```

これにより「この棚は通常保管可能か？」をデータとして判定できる。

Virtual Locationも重要。

```text
RECEIVING
QC
SHIPPING
TRANSIT
DAMAGED
```

などを通常Locationとして扱えるようにする。

---

# 9. Stock Ledgerを中心にする

現在の `stock_movements` をWMSの帳簿として強化する。

数量変化は原則すべてMovementにする。

例：

```text
RECEIPT
QC_RELEASE
PUTAWAY
PICK
SHIP
ADJUSTMENT
TRANSFER_OUT
TRANSFER_IN
RETURN
DAMAGE
SCRAP
WORK_ORDER_CONSUME
WORK_ORDER_PRODUCE
```

Flutterから直接quantityを書き換えない。

```text
Flutter
 ↓
RPC / transaction
 ↓
stock movement
 ↓
stock snapshot
```

を原則にする。

---

# 10. MovementにReferenceを持たせる

```text
movement_id
product_id
quantity
from_location_id
to_location_id
movement_type
reference_type
reference_id
actor_id
created_at
idempotency_key
```

これで、

```text
PO
Receipt
Pick
Shipment
Transfer
Work Order
Count
RMA
```

まで逆引きできる。

**履歴を削除して帳尻を合わせない。訂正は逆方向Movementで行う。**

---

# 11. Purchase OrderとReceivingを分離

正しい業務境界：

```text
Purchase Order
      ↓
Inbound / Delivery
      ↓
Receiving
      ↓
QC
      ↓
Put-away
      ↓
Available Stock
```

PO = 発注・商取引。

Receiving = 実際に届いた物。

Stock = 実際に受け入れた物。

同一概念にしない。

---

# 12. Receivingを第一級データにする

推奨：

```text
receipts
receipt_lines
receipt_items
```

Receipt：

```text
supplier
warehouse
received_at
status
reference_po
carrier
tracking_number
operator
```

Line：

```text
product
expected_qty
received_qty
rejected_qty
short_qty
over_qty
```

Item：

```text
lot
serial
expiry
location
quantity
```

---

# 13. QCを独立させる

```text
QC_PENDING
QC_PASS
QC_FAIL
QC_HOLD
PARTIAL
```

QC FAIL / HOLDの商品が誤って出荷されないことを、Flutter UIだけでなくRPC/DB側でも保証する。

---

# 14. Put-awayを強化

現在の派生Put-away Queue設計は維持する。

在庫との二重管理を避けるため、

> queueの数量を独立した在庫として持たない

こと。

将来必要なら、

```text
putaway_tasks
- id
- warehouse_id
- receipt_id
- product_id
- lot_id
- from_location
- suggested_location
- target_location
- quantity
- priority
- status
- assigned_to
```

を追加する。

さらに、

```text
同一商品が存在するBin
 ↓
同一Zone
 ↓
空き容量
 ↓
保管条件
 ↓
回転率
```

でPut-away候補を出す。

---

# 15. PickingをOrderとTaskに分離

```text
Sales Order
 ↓
Shipment
 ↓
Pick Wave / Pick List
 ↓
Pick Task
 ↓
Picked
 ↓
Packing
```

Pick Task：

```text
pick_task
- pick_list_id
- product_id
- stock/lot/serial
- source_bin
- required_qty
- picked_qty
- status
- operator_id
```

将来、

- Wave picking
- Batch picking
- Zone picking
- 優先順位
- 作業員割当

へ拡張できる。

---

# 16. Picking Ruleを追加

Product / Warehouse単位で、

```text
FIFO
FEFO
LIFO
MANUAL
```

を扱えるようにする。

食品等ではFEFOを優先。

候補在庫は、

```text
expiry
lot
location
quantity
```

から決定する。

---

# 17. Packing / Cartonを第一級にする

現在のCarton/autopackをさらに成熟させる。

```text
cartons
- id
- shipment_id
- carton_number
- carton_type
- weight
- length
- width
- height
- tracking_number
- status
```

```text
carton_items
- carton_id
- product_id
- lot_id
- serial_id
- quantity
```

理想：

```text
Shipment
 ├─ Carton 1
 │   ├─ Product A
 │   └─ Product B
 ├─ Carton 2
 │   └─ Product C
 └─ Carton 3
```

「どの商品がどの箱に入ったか」を追跡可能にする。

---

# 18. Returns / RMAを追加

現在の明確なGap。

```text
returns
return_lines
return_receipts
return_inspections
```

フロー：

```text
Customer
 ↓
RMA
 ↓
Return Receiving
 ↓
Inspection
 ├─ RESTOCK
 ├─ REPAIR
 ├─ QUARANTINE
 └─ SCRAP
```

返品を単なるStock Adjustmentにしない。

---

# 19. BOM / Work OrderをInvenTree型に成熟化

現在のkitting/assemblyを発展させる。

```text
BOM
- product_id
- version
- effective_from
- effective_to
```

BOM Line：

```text
component
quantity
optional
substitute
scrap/attrition
```

Work Order開始時には、

```text
Current BOM
     ↓
BOM Snapshot
     ↓
Work Order
```

とする。

将来BOM v2になっても、過去の製造記録を壊さない。

---

# 20. Work Order Allocation

```text
Work Order
 ↓
BOM
 ↓
Required Qty
 ↓
Stock Allocation
 ↓
Consume
 ↓
Produce
```

重要：

**AllocationしただけではStockを減らさない。**

Consume時にStock Ledgerを動かす。

---

# 21. UOMを追加

例えば、

```text
PCS = 1
BOX = 12 PCS
CASE = 144 PCS
```

を扱えるようにする。

```text
uoms
- id
- code
- name
- type
```

```text
product_uoms
- product_id
- uom_id
- conversion_factor
- barcode
```

これにより、

```text
箱を1回スキャン
→ 12個

ケースを1回スキャン
→ 144個
```

が可能になる。

---

# 22. Warehouse Productを追加

Product全体の情報と、倉庫固有設定を分離。

```text
warehouse_products
- warehouse_id
- product_id
- default_bin
- min_stock
- max_stock
- reorder_point
- pick_priority
- putaway_rule
```

同じ商品でも、

```text
大阪 → A-01
神戸 → B-03
東京 → C-10
```

のように設定可能。

---

# 23. Inventory Countを成熟化

現在のCycle Countを、

```text
Count Plan
 ↓
Count Task
 ↓
Blind Count
 ↓
Variance
 ↓
Recount
 ↓
Supervisor Approval
 ↓
Adjustment
```

に発展させる。

差異があれば自動的に再カウント対象にできる。

---

# 24. Warehouse Task Engine

現場作業を共通Taskモデルにする。

```text
warehouse_tasks
- id
- warehouse_id
- task_type
- reference_type
- reference_id
- priority
- status
- assigned_to
- source_location
- target_location
- started_at
- completed_at
```

task_type：

```text
RECEIVE
QC
PUTAWAY
PICK
PACK
SHIP
COUNT
TRANSFER
RETURN
```

Dashboard：

```text
今日の作業
├─ 入庫 12
├─ QC 4
├─ 棚入れ 8
├─ ピッキング 23
├─ 梱包 6
└─ 棚卸 2
```

---

# 25. MobileはTask First

スマホ：

```text
ホーム
 ↓
今日のタスク
 ↓
作業開始
 ↓
スキャン
 ↓
確認
 ↓
完了
```

PC：

```text
Dashboard
Orders
Inbound
Outbound
Inventory
Reports
Products
Partners
Administration
```

Flutterの同一コードベースを維持しつつ、Responsive / Adaptive UIでUXを分ける。

---

# 26. Barcode Resolverを共通化

全画面が独自にJAN判定しない。

```text
scan
 ↓
Barcode Resolver
 ├─ Product
 ├─ Lot
 ├─ Serial
 ├─ Location
 ├─ Shipment
 ├─ Carton
 ├─ Pallet
 └─ Task
```

Scan Contextを持たせ、

```text
Picking中
→ Location scan
→ Product scan
→ Quantity
```

のように文脈で判定する。

---

# 27. Idempotency + Concurrency

すべてのStock Mutationで、

```text
receiving
putaway
pick
ship
transfer
adjustment
count
return
work order
```

にidempotencyを適用する。

同じ操作が2回届いても1回だけ処理する。

さらに同時作業に備え、

```text
transaction
row lock / atomic update
available quantity check
```

をRPC側で行う。

Flutterだけで数量整合性を保証しない。

---

# 28. Audit Trail

最低限、

```text
誰が
いつ
何を
何個
どこから
どこへ
なぜ
```

を追跡する。

例：

```text
User: Tanaka
Product: ABC-001
Qty: 5
From: A-01-03
To: PACK-01
Reason: PICK
Reference: PICK-20260920-001
```

---

# 29. Attachment

既存のpolymorphic `attachments` を汎用化。

対象候補：

```text
Product
Receiving
QC
Stock
Shipment
Carton
Return
Adjustment
Count
Work Order
```

写真・PDF・納品書・検品画像等を紐付ける。

---

# 30. AIは「候補生成」に限定

```text
Image
 ↓
OCR / Vision
 ↓
Suggestion
 ↓
Human Review
 ↓
Confirmed Domain Data
```

AIが直接Stock数量や入出庫を確定しない。

将来：

- 商品画像認識
- ラベル認識
- 箱サイズ推定
- 破損検出
- 数量推定
- 棚画像解析
- Inventory Assistant

を追加できる。

---

# 31. Replenishment

将来Product + Warehouse単位で、

```text
minimum_stock
maximum_stock
reorder_point
preferred_supplier
lead_time
```

を持つ。

不足時：

```text
Replenishment Suggestion
```

を生成する。

---

# 32. Owner / 委託在庫

3PL等への拡張余地として、

```text
stock_owner
```

を考慮する。

例：

```text
自社在庫
A社委託在庫
B社預かり在庫
```

UIは後回しでよいが、データモデルを壊さない。

---

# 33. Cost

会計システムを作らなくても、

```text
unit_cost
currency
cost_source
received_cost
```

を保持できるようにする。

将来、

- FIFO valuation
- weighted average
- landed cost

へ拡張可能にする。

---

# 34. OrderとExecutionを混ぜない

最重要ルール。

```text
Purchase Order / Sales Order
= 商取引

Receipt / Pick / Pack / Ship
= 倉庫実行
```

例えば、

```text
Sales Order COMPLETED
```

だけではStockを減らさない。

実際に、

```text
SHIP
```

された時にStockを減らす。

---

# 35. 推奨最終Domain Model

```text
MASTER
├─ Product
├─ Barcode
├─ Category
├─ UOM
├─ Lot
├─ Serial
├─ Supplier
├─ Customer
├─ Warehouse
├─ Location
└─ Warehouse Product

INBOUND
├─ Purchase Order
├─ Inbound Shipment
├─ Receipt
├─ Receipt Line
├─ QC
└─ Put-away

INVENTORY
├─ Stock
├─ Stock Unit
├─ Bin Stock
├─ Reservation
├─ Allocation
├─ Stock Movement
├─ Adjustment
├─ Cycle Count
└─ Transfer

OUTBOUND
├─ Sales Order
├─ Shipment
├─ Pick Wave
├─ Pick List
├─ Pick Task
├─ Packing
├─ Carton
├─ Carton Item
└─ Shipping

RETURN
├─ RMA
├─ Return
├─ Return Receipt
└─ Return Inspection

MANUFACTURING
├─ BOM
├─ BOM Version
├─ Work Order
├─ Material Allocation
├─ Consumption
└─ Production

SYSTEM
├─ Users
├─ Roles
├─ Permissions
├─ Audit
├─ Attachments
├─ AI Analysis
└─ Reports
```

---

# 36. 実装優先順位

## Phase A — Inventory Core

最優先：

1. Product internal ID
2. Product Barcodes
3. UOM
4. Lot
5. Serial
6. Expiry
7. Stock Status
8. Stock Identity / Stock Unit
9. Location tree
10. Warehouse Product
11. Available / Reserved
12. Reservation / Allocation

## Phase B — Inbound

1. Receiving
2. QC
3. Put-away
4. Put-away suggestion
5. Barcode flow
6. Attachments
7. Exception handling

## Phase C — Outbound

1. Sales Order
2. Shipment
3. Reservation
4. Allocation
5. Pick List
6. Pick Task
7. Wave / Batch picking
8. Packing
9. Carton
10. Weight / dimensions
11. Label
12. Shipping

## Phase D — Inventory Control

1. Cycle Count
2. Recount
3. Adjustment approval
4. Transfer
5. Returns / RMA
6. Quarantine
7. Damage / Scrap
8. Traceability

## Phase E — Manufacturing

1. BOM
2. BOM version
3. Work Order
4. Allocation
5. Consume
6. Produce
7. Disassembly
8. Substitution
9. Scrap / attrition

## Phase F — Intelligence

1. Replenishment
2. Put-away recommendation
3. Pick optimization
4. OCR
5. Product recognition
6. Damage detection
7. Inventory assistant
8. BI

---

# 37. DB設計の絶対ルール

1. FlutterからStock quantityを直接変更しない。
2. Stock mutationはtransaction/RPC経由。
3. Stock Movementはappend-onlyを基本とする。
4. 履歴削除で帳尻を合わせない。
5. Correctionは逆方向Movement。
6. OrderとWarehouse Executionを分離。
7. ProductとStockを分離。
8. JAN/Barcodeを内部主キーにしない。
9. Lot/Serial/Expiryを後付けにしない。
10. Locationを単なる文字列にしない。
11. AI結果と確定業務データを分離。
12. Stock MutationにIdempotency Key。
13. 権限をFlutter UIだけに依存しない。
14. RLS + SECURITY DEFINER RPC / Edge Functionを維持。
15. 過去Transactionが将来のMaster変更で意味を変えないようにする。

---

# 38. Claude Codeへの実装指示

一度に全面改修しない。

必ず：

```text
1. 現在schema確認
2. migration確認
3. RPC確認
4. Flutter repository/controller/screen確認
5. domain model設計
6. additive migration
7. DB/RPC tests
8. Flutter unit/widget tests
9. regression tests
10. UI
```

の順番。

既存の、

```text
stock_movements
stock_levels
bin_stock
products
shipment_plans
pick_lists
inspections
transfer_orders
work_orders
```

を破壊的に削除しない。

---

# 39. 「完成」の判定

## Inventory

- [ ] Product internal ID
- [ ] Barcode aliases
- [ ] Lot
- [ ] Serial
- [ ] Expiry
- [ ] UOM
- [ ] Location hierarchy
- [ ] Stock status
- [ ] Stock ledger
- [ ] Reservation
- [ ] Allocation

## Inbound

- [ ] Purchase Order
- [ ] Receiving
- [ ] QC
- [ ] Put-away
- [ ] Exception handling

## Outbound

- [ ] Sales Order
- [ ] Shipment
- [ ] Picking
- [ ] Packing
- [ ] Carton
- [ ] Label
- [ ] Shipping

## Inventory Control

- [ ] Adjustment
- [ ] Cycle Count
- [ ] Recount
- [ ] Transfer
- [ ] Returns/RMA
- [ ] Quarantine
- [ ] Damage/Scrap

## Manufacturing

- [ ] BOM
- [ ] BOM version
- [ ] Work Order
- [ ] Material allocation
- [ ] Consume
- [ ] Produce

## Operational UX

- [ ] PC dashboard
- [ ] Mobile task-first UI
- [ ] Barcode resolver
- [ ] Hardware scanner
- [ ] Camera scanner
- [ ] Idempotent retry
- [ ] Audit timeline
- [ ] Attachments

## Intelligence

- [ ] OCR
- [ ] Human review
- [ ] Replenishment
- [ ] Put-away suggestion
- [ ] Pick optimization
- [ ] Vision AI

---

# 40. 最終方針

このWMSをInvenTreeのクローンにはしない。

### InvenTreeから吸収

- Product / Part model
- ProductとStockの分離
- Lot / Serial / Expiry
- Location hierarchy
- BOM
- Build allocation
- Traceability
- Future stock / replenishment
- Purchasing concepts

### OCA / Sentry等から吸収

- Barcode workflow
- Receiving
- Put-away
- Picking
- Wave / Batch
- Packing
- Carton
- Shipping
- Cycle Count
- Transfer
- Warehouse Task
- Mobile operation

### `paazuuu/wms` 独自の強み

- Flutter
- Supabase
- 日本語 / 英語 / 中国語
- 日本のJAN
- 送り状
- ラベル印刷
- AI OCR
- Human Review
- 写真・添付
- PC + Mobile
- Multi-warehouse

最終目標：

> **InvenTreeより現場作業に強く、一般的なCRUD型WMSより在庫データモデルが成熟した、Flutter + Supabase製の実運用WMS。**

## 参考

- `paazuuu/wms` — 現在の実装・migration・feature checklist
- InvenTree — Inventory / Stock / BOM / Build / Tracking
- OCA WMS — WMS業務モデル
- Sentry WMS — Barcode / Mobile / Receiving / Picking / Packing / Shipping
- ERPNext — Purchase / Sales / Stock Ledger / Manufacturing
- OpenBoxes — Inventory / Supply Chain / Location / Traceability

**コードをコピーするのではなく、ドメインモデル・状態遷移・現場フローを学習対象とする。**
