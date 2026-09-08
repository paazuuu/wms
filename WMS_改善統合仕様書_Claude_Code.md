# WMS 改善統合仕様書

## 4つの成熟OSSを「先生」として、既存 `paazuuu/wms` を実務型AI-WMSへ進化させるためのClaude Code向け仕様書

-   作成日: 2026-09-09
-   対象リポジトリ: `https://github.com/paazuuu/wms`
-   基本方針:
    **既存システムを捨てず、成熟OSSの業務モデル・UX・データ設計・倉庫フローを吸収して改善する**
-   重要:
    この文書は「別のWMSを丸ごとコピーする指示」ではない。既存コードを調査し、互換性と既存実装を維持しながら段階的に改善する。

------------------------------------------------------------------------

# 1. この仕様書の目的

現在の `paazuuu/wms` は、Flutter +
Supabase/PostgreSQLを中心に、商品・在庫・入出庫・検品・画像添付・バーコード・オフライン同期などの基礎が既に存在する。

一方で、現在の課題は単純な機能不足だけではない。

特に以下を改善する。

1.  倉庫業務を実務の流れとして明確にする
2.  1倉庫だけを前提にしたUI/DB設計を避ける
3.  倉庫が2つ以上になった場合、トップレベルから倉庫を追加・切替・管理できるようにする
4.  「入荷」「検品」「棚入れ」「ピッキング」「梱包」「出荷」「棚卸」「倉庫間移動」を明確な業務状態として扱う
5.  PC管理画面とスマホ/ハンディ画面を、それぞれの現場用途に最適化する
6.  ロール・権限・倉庫単位のアクセス制御を明確化する
7.  AI/OCR/画像認識を後から自然に追加できるアーキテクチャにする
8.  AIが認識した情報をWMS本体のデータと分離して保存できるようにする
9.  日本語・中国語・英語を前提とした多言語設計にする
10. 将来のRFID、BI、外部ERP、EC、配送会社APIなどを追加しやすくする
11. 現在動いている機能を壊さない
12. いきなり全面書き換えせず、調査→設計→migration→backend→UI→testの順に進める

------------------------------------------------------------------------

# 2. 最重要方針

## 2.1 既存プロジェクトを捨てない

Claudeは最初から別WMSを作り直してはいけない。

現在のリポジトリには、少なくとも以下の既存資産がある。

-   Flutter mobile
-   Supabase/PostgreSQL
-   Backend API
-   Inspection
-   InspectionItem
-   Attachment
-   Barcode
-   Offline queue
-   Purchase Order受入時の検品起票
-   画像/PDF/Office/動画添付
-   テスト
-   Phase 1〜3仕様

これらをまず調査し、再利用できるものは残す。

## 2.2 「成熟OSSから学ぶ」が目的

参考にする4プロジェクト:

### Teacher A: OCA WMS

https://github.com/OCA/wms

主に学ぶもの:

-   WMSのモジュール分割
-   Barcode
-   Put-away
-   Availability
-   Reordering
-   Dispatch/Release Channel
-   Reporting
-   物理デバイス連携
-   倉庫業務の粒度

### Teacher B: Sentry WMS

https://github.com/hightower-systems/sentry-wms

主に学ぶもの:

-   Receiving
-   Put-away
-   Picking
-   Packing
-   Shipping
-   Cycle Counting
-   Bin Transfer
-   Inter-Warehouse Transfer
-   Barcode scanner
-   Warehouse Picker
-   Mobile/Floor Operations
-   実務的な状態遷移
-   Audit Log
-   具体的なAPI設計
-   テスト可能なサービス層

### Teacher C: ERPNext

https://github.com/frappe/erpnext

主に学ぶもの:

-   Company
-   Warehouse
-   Item/Product
-   Purchase Order
-   Purchase Receipt
-   Sales Order
-   Pick List
-   Stock Entry
-   Stock Ledger
-   Serial/Batch
-   業務ドキュメント同士の関連
-   在庫トランザクション
-   API
-   大規模ERPとしてのデータ整合性

### Teacher D: OpenBoxes

https://github.com/openboxes/openboxes

主に学ぶもの:

-   実務的な在庫管理
-   倉庫・在庫移動
-   物流/供給の考え方
-   物品単位での在庫追跡
-   現実の倉庫業務を意識したモデル

------------------------------------------------------------------------

# 3. 最終的なシステム像

最終的には以下を目標とする。

``` text
                         WMS
                          │
          ┌───────────────┼────────────────┐
          │               │                │
       管理Web          Mobile          AI Layer
          │               │                │
   ┌──────┼──────┐    ┌───┼────┐      ┌────┼─────┐
   │      │      │    │   │    │      │    │     │
 会社   倉庫   商品   Scan 入荷 出荷   OCR Vision LLM
   │      │      │
   └──────┼──────┘
          │
       PostgreSQL
          │
   ┌──────┼──────────────────────┐
   │      │       │       │      │
在庫   履歴    検品    AI結果   Audit
```

WMS本体とAIを完全に分離する。

AIは「WMSの代わり」ではない。

AIは、

-   認識
-   OCR
-   候補生成
-   異常検知
-   商品照合
-   画像分析
-   自然言語検索
-   自動入力支援

を担当し、最終的な在庫・入出庫・検品確定はWMSのトランザクションとして保存する。

------------------------------------------------------------------------

# 4. 最重要UI要件: トップ画面と倉庫管理

## 4.1 倉庫が1つの場合

ユーザーが所属する会社に倉庫が1つしかない場合:

``` text
┌───────────────────────────────────┐
│ WMS                    神戸倉庫 ▼ │
├───────────────────────────────────┤
│                                   │
│ 今日の作業                         │
│                                   │
│ 入荷予定       12                  │
│ 検品待ち        4                  │
│ 棚入れ待ち      7                  │
│ ピッキング     18                  │
│ 梱包待ち        6                  │
│ 出荷待ち       10                  │
│                                   │
└───────────────────────────────────┘
```

初期状態でユーザーが毎回「倉庫を選ぶ」必要はない。

## 4.2 倉庫が2つ以上の場合

**トップレベルで倉庫を追加・切替できるようにする。**

重要要件:

-   Dashboard上部に現在のWarehouse Contextを表示
-   Warehouse Pickerを常時表示
-   「すべての倉庫」表示を管理者だけ許可してもよい
-   「倉庫を追加」ボタンをトップレベルから利用可能にする
-   倉庫作成後、その倉庫にLocation/Bin/Zoneを作成できる
-   ユーザーごとに利用可能な倉庫を設定できる
-   ロールごとに操作可能な倉庫範囲を制御する

推奨UI:

``` text
┌─────────────────────────────────────┐
│ WMS     [ 神戸倉庫 ▼ ]     🔔 👤    │
├─────────────────────────────────────┤
│                                     │
│ 倉庫                                │
│                                     │
│ ● 神戸倉庫                           │
│   在庫 12,430 SKU                    │
│                                     │
│ ● 大阪倉庫                           │
│   在庫 8,210 SKU                     │
│                                     │
│ ＋ 倉庫を追加                        │
│                                     │
└─────────────────────────────────────┘
```

### 倉庫追加ウィザード

最低限:

-   倉庫名
-   倉庫コード
-   住所
-   電話
-   タイムゾーン
-   デフォルト入荷エリア
-   デフォルト出荷エリア
-   有効/無効

将来:

-   Zone
-   Bin
-   Staging
-   QC Hold
-   Pickable
-   Shipping
-   Returns

を設定できる。

------------------------------------------------------------------------

# 5. Company / Tenant / Warehouseの関係

推奨構造:

``` text
Tenant / Organization
        │
        ├── Users
        ├── Roles
        ├── Permissions
        │
        ├── Warehouse A
        │      ├── Zone
        │      │    ├── Bin
        │      │    └── Bin
        │      └── ...
        │
        └── Warehouse B
               ├── Zone
               └── Bin
```

重要:

**CompanyとWarehouseを混同しない。**

1会社に複数倉庫を持てる。

将来、1ユーザーが複数会社に所属する必要が出る可能性も考え、DBのFKを直接固定しすぎない。

------------------------------------------------------------------------

# 6. Warehouseモデル

最低限:

``` text
warehouses
- id
- tenant_id / company_id
- code
- name
- description
- address
- phone
- timezone
- status
- is_default
- created_at
- updated_at
```

制約:

-   codeはcompany/tenant内でunique
-   削除ではなくactive/inactiveを基本とする
-   既に在庫履歴がある倉庫は物理DELETEしない

------------------------------------------------------------------------

# 7. Location / Zone / Bin

倉庫の中を階層化する。

``` text
Warehouse
  └─ Zone
      └─ Aisle
          └─ Rack
              └─ Bin
```

ただし、最初から4階層をDB上の必須にしない。

実用上は:

``` text
warehouse
  └─ location/bin
```

を基本にして、

``` text
zone
aisle
rack
```

は属性または任意階層として追加可能にする。

------------------------------------------------------------------------

# 8. Bin Type

Sentryの考え方を参考にする。

最低限:

-   STAGING
-   PICKABLE
-   PICKABLE_STAGING
-   QC_HOLD
-   SHIPPING
-   RETURNS
-   DAMAGED
-   VIRTUAL

### STAGING

入荷直後の商品。

在庫には存在するが、通常のピッキング対象にはしない。

### QC_HOLD

検品待ち/不合格。

通常在庫として引き当てない。

### PICKABLE

通常の棚在庫。

### SHIPPING

出荷準備中。

### RETURNS

返品。

### DAMAGED

破損品。

------------------------------------------------------------------------

# 9. 入荷フロー

入荷は単なる「在庫+1」ではなく、明確な業務フローとして設計する。

``` text
Purchase Order
      ↓
Expected Receipt
      ↓
Receiving
      ↓
Barcode Scan
      ↓
Quantity Verification
      ↓
Inspection
      ↓
QC Result
      ↓
Staging / QC Hold
      ↓
Put-away
      ↓
Available Inventory
```

状態例:

``` text
DRAFT
EXPECTED
RECEIVING
RECEIVED
INSPECTION_PENDING
QC_PASSED
QC_FAILED
STAGED
PUTAWAY_PENDING
PUTAWAY
COMPLETED
CANCELLED
```

ただし、状態を増やしすぎない。

実装では「業務イベント」と「現在状態」を分離する。

------------------------------------------------------------------------

# 10. 入荷検品

検品項目:

-   商品コード
-   JAN/UPC/EAN
-   ロット
-   シリアル
-   予定数量
-   実数量
-   外装
-   商品状態
-   期限
-   ラベル
-   写真
-   コメント

結果:

``` text
PASS
FAIL
PARTIAL
HOLD
```

不一致:

``` text
Expected: 100
Received: 96
```

の場合、

``` text
差異数量 = -4
```

を保存。

勝手に在庫を100にしない。

------------------------------------------------------------------------

# 11. AI検品

AIは検品結果を直接確定してはいけない。

``` text
画像
 ↓
AI
 ↓
AI判定
 ↓
confidence
 ↓
人間確認
 ↓
WMS確定
```

例:

``` text
AI:
商品一致        98%
数量            12
破損            false
ラベル一致      97%
```

UI:

``` text
AI判定

商品: 一致        98% ✓
数量: 12          ✓
破損: なし        96% ✓
ラベル: 一致      97% ✓

[ 確定 ] [ 要確認 ] [ NG ]
```

AIの判断は監査可能にする。

------------------------------------------------------------------------

# 12. Put-away

Sentry/OCAから学ぶ。

入荷後の商品はStagingへ入り、その後Put-awayする。

``` text
Staging
   ↓
Suggested Bin
   ↓
Worker scans Bin
   ↓
Worker scans Item
   ↓
Quantity
   ↓
Confirm
```

AI/ルールによる候補:

-   商品カテゴリ
-   温度帯
-   サイズ
-   重量
-   回転率
-   既存在庫
-   商品のpreferred bin
-   空き容量

将来、AIによるPut-away提案を追加可能にする。

------------------------------------------------------------------------

# 13. 出庫フロー

基本:

``` text
Sales Order
      ↓
Shipment Order
      ↓
Allocation
      ↓
Pick List
      ↓
Picking
      ↓
Packing
      ↓
Shipping
```

状態:

``` text
OPEN
ALLOCATED
PICKING
PICKED
PACKING
PACKED
READY_TO_SHIP
SHIPPED
CANCELLED
```

ただし、状態の乱立を避ける。

「現在の業務状態」と「イベント履歴」を分離する。

------------------------------------------------------------------------

# 14. Picking

Sentry/ERPNextを参考にする。

必要機能:

-   Pick List
-   Pick Task
-   Batch Picking
-   Wave Picking
-   Warehouse/Zone指定
-   Bin順序
-   Barcode確認
-   Short Pick
-   Pick完了
-   Undo/Release

例:

``` text
Pick Task #000123

A-01-01
ボールペン
予定 20
```

スキャン:

``` text
Bin Barcode
 ↓
Item Barcode
 ↓
Quantity
 ↓
Confirm
```

誤商品なら:

``` text
⚠ この商品は対象外です
```

------------------------------------------------------------------------

# 15. Packing

PackingとShippingを分離する。

Packing:

-   注文スキャン
-   商品スキャン
-   数量確認
-   梱包資材
-   重量
-   写真
-   梱包完了

Shipping:

-   配送会社
-   サービス
-   送り状番号
-   出荷日時
-   出荷完了

------------------------------------------------------------------------

# 16. 倉庫間移動

重要。

2倉庫以上になったら必須機能。

``` text
神戸倉庫
   ↓
Transfer Order
   ↓
Picking
   ↓
Approval
   ↓
In Transit
   ↓
大阪倉庫
   ↓
Receiving
   ↓
Completed
```

SentryのTransfer Orderの考え方を参考にする。

必要項目:

``` text
transfer_order
- id
- transfer_number
- source_warehouse_id
- destination_warehouse_id
- status
- requested_by
- approved_by
- approved_at
- shipped_at
- received_at
```

状態:

``` text
DRAFT
PENDING_APPROVAL
APPROVED
PICKING
IN_TRANSIT
RECEIVING
COMPLETED
REJECTED
CANCELLED
```

自己承認禁止を基本とする。

------------------------------------------------------------------------

# 17. 在庫モデル

単純な `inventory.quantity` だけに依存しない。

少なくとも:

``` text
inventory
stock_movements
stock_history
```

を分ける。

在庫は、

``` text
Opening
+ Receipt
+ Transfer In
+ Adjustment +
- Pick
- Ship
- Transfer Out
- Adjustment -
```

で追跡可能にする。

------------------------------------------------------------------------

# 18. Stock Ledger / Audit

ERPNextから学ぶ。

すべての在庫変動を追跡可能にする。

例:

``` text
2026-09-09 10:00
Product A
Warehouse: Kobe
Bin: A-01-01

Before: 100
Change: +20
After: 120

Reason: RECEIPT
Reference: PO-000123
User: user@example.com
```

後から「なぜ在庫が20増えたのか」が必ず分かること。

------------------------------------------------------------------------

# 19. 商品マスター

既存仕様を拡張する。

最低限:

``` text
product
- id
- sku
- barcode
- name
- name_ja
- name_zh
- name_en
- category_id
- brand
- manufacturer
- model
- unit
- weight
- dimensions
- status
```

将来:

-   SKU variants
-   Packaging
-   Case quantity
-   Inner quantity
-   UOM conversion
-   Serial
-   Lot
-   Expiry

------------------------------------------------------------------------

# 20. 多言語

最初から:

-   日本語
-   简体中文
-   English

を設計。

商品名についても、必要なら多言語フィールドまたはtranslation
tableを使用する。

UI文字列をハードコードしない。

``` text
"入荷"
```

ではなく、

``` text
inventory.receiving
```

のようなtranslation keyを使う。

------------------------------------------------------------------------

# 21. Role / Permission

最低限:

### System Admin

すべて

### Company Admin

会社内の管理

### Warehouse Manager

倉庫管理

### Receiving

入荷

### Inspector

検品

### Put-away Operator

棚入れ

### Picker

ピッキング

### Packer

梱包

### Shipper

出荷

### Inventory Controller

棚卸・在庫調整

### Viewer

閲覧のみ

権限は「画面が見える」だけではなく、API側でも強制する。

------------------------------------------------------------------------

# 22. Warehouse Scope

ユーザーに、

``` text
allowed_warehouses
```

を持たせる。

例:

``` text
山田
  → 神戸倉庫
  → 大阪倉庫

王
  → 神戸倉庫

李
  → 大阪倉庫
```

APIでも必ずチェックする。

UIで隠すだけでは不十分。

------------------------------------------------------------------------

# 23. トップDashboard

管理者:

``` text
┌─────────────────────────────────────────┐
│ WMS   [神戸倉庫 ▼]                       │
├─────────────────────────────────────────┤
│                                         │
│ 今日                                    │
│                                         │
│ 入荷予定       12       検品待ち     4  │
│ 棚入れ待ち      7       ピッキング  18  │
│ 梱包待ち        6       出荷待ち    10  │
│                                         │
│ 在庫                                   │
│ SKU 12,430   在庫 98,230   低在庫 42   │
│                                         │
│ ⚠ 差異 3件                              │
│ ⚠ 検品NG 2件                            │
│ ⚠ 出荷遅延 1件                          │
└─────────────────────────────────────────┘
```

倉庫が2つ以上の場合:

``` text
[神戸倉庫 ▼]
[大阪倉庫]
[すべて]
```

------------------------------------------------------------------------

# 24. Mobile / Handheld UI

Mobileは管理画面の縮小版にしない。

現場作業中心。

``` text
今日の作業

📥 入荷
12

📦 棚入れ
8

🛒 ピッキング
23

📦 梱包
9

🚚 出荷
17

🔍 棚卸
4
```

各作業を押すとスキャン画面。

------------------------------------------------------------------------

# 25. Scanner設計

対応:

-   JAN/EAN13
-   Code128
-   Code39
-   QR
-   将来GS1
-   将来RFID

スキャン結果は共通サービスにする。

``` text
ScannerService
   ├─ Camera
   ├─ Hardware Scanner
   ├─ Manual Input
   └─ RFID
```

業務画面はScannerの種類を意識しない。

------------------------------------------------------------------------

# 26. Offline

既存のOfflineSyncServiceを維持・強化する。

対象:

-   Scan
-   Receive
-   Pick
-   Count
-   Inspection
-   Attachment metadata

重要:

在庫確定など競合しやすい処理は、server側でidempotencyを持つ。

------------------------------------------------------------------------

# 27. AI Layer

AIは独立モジュールにする。

例:

``` text
ai/
  product_identification
  ocr
  image_inspection
  damage_detection
  document_extraction
  inventory_assistant
```

Provider abstraction:

``` text
AIProvider
  ├─ OpenAI
  ├─ Anthropic
  ├─ Gemini
  └─ Local Model
```

特定AI APIにDB/業務ロジックを直接結合しない。

------------------------------------------------------------------------

# 28. AI結果DB

WMSの正規データとAI結果を分離する。

例:

``` text
ai_analysis
- id
- tenant_id
- warehouse_id
- product_id nullable
- inspection_id nullable
- attachment_id nullable
- provider
- model
- task_type
- input_uri
- input_hash
- output_json
- confidence
- status
- reviewed_by
- reviewed_at
- created_at
```

AIが間違っても元データを壊さない。

------------------------------------------------------------------------

# 29. AI商品登録

目標:

``` text
写真
 ↓
OCR
 ↓
Barcode
 ↓
AI Vision
 ↓
商品候補検索
 ↓
候補ランキング
 ↓
人間確認
 ↓
Product Master
```

AIが勝手に確定登録しない。

------------------------------------------------------------------------

# 30. OCR

対象:

-   納品書
-   商品ラベル
-   JAN/UPC/EAN
-   送り状
-   請求書
-   箱ラベル

OCR結果はraw textとstructured JSONの両方を保存。

------------------------------------------------------------------------

# 31. AI検品

AIは、

-   商品一致
-   ラベル一致
-   数量
-   破損
-   色
-   型番
-   サイズ
-   期限

などを候補として返す。

最終判定:

``` text
AI_RESULT
↓
HUMAN_REVIEW
↓
WMS_CONFIRMED_RESULT
```

------------------------------------------------------------------------

# 32. Attachment

既存の画像/PDF/Office/動画対応を維持。

すべてに:

-   hash
-   mime type
-   size
-   uploader
-   created_at
-   storage path
-   entity type
-   entity id

を持たせる。

AI処理対象にできるようにする。

------------------------------------------------------------------------

# 33. Audit Log

重要操作:

-   商品変更
-   在庫調整
-   入荷確定
-   検品確定
-   出荷
-   倉庫追加
-   倉庫変更
-   ロール変更
-   権限変更
-   AI結果承認
-   倉庫間移動承認

をログ化。

可能ならevent type + JSON details。

------------------------------------------------------------------------

# 34. 外部連携

将来:

-   Shopify
-   Amazon
-   楽天
-   freee
-   マネーフォワード
-   弥生
-   ヤマト
-   佐川
-   日本郵便
-   ERP
-   POS

を想定。

外部システムを直接WMS内部ロジックに埋め込まない。

Connector/Adapter層を作る。

------------------------------------------------------------------------

# 35. API設計

REST APIを基本とする。

例:

``` text
GET    /api/v1/warehouses
POST   /api/v1/warehouses
GET    /api/v1/warehouses/{id}
PATCH  /api/v1/warehouses/{id}

GET    /api/v1/inventory
GET    /api/v1/items/{barcode}

POST   /api/v1/receiving
POST   /api/v1/receiving/{id}/confirm

GET    /api/v1/putaway/pending
POST   /api/v1/putaway/confirm

POST   /api/v1/picking/batches
POST   /api/v1/picking/confirm

POST   /api/v1/packing/verify
POST   /api/v1/packing/complete

POST   /api/v1/shipping/complete

POST   /api/v1/transfers
POST   /api/v1/transfers/{id}/approve
POST   /api/v1/transfers/{id}/receive

POST   /api/v1/ai/analyze
POST   /api/v1/ai/{id}/review
```

------------------------------------------------------------------------

# 36. DB Migration方針

既存テーブルを確認してからmigrationする。

絶対に:

``` text
DROP DATABASE
```

や無計画な全テーブル再作成をしない。

既存データとの互換性を考える。

Migration:

``` text
001_xxx
002_xxx
003_xxx
...
```

を維持。

------------------------------------------------------------------------

# 37. Seed Data

現在の「空っぽに見える」問題を改善するため、開発環境では実務サンプルデータを用意する。

最低:

``` text
Company:
  Demo Trading Co.

Warehouses:
  神戸倉庫
  大阪倉庫

Zones:
  A/B/C

Bins:
  A-01-01
  A-01-02
  B-01-01
  QC-01
  STAGE-01
  SHIP-01

Users:
  管理者
  倉庫管理者
  入荷担当
  検品担当
  ピッカー
  梱包担当
  出荷担当

Products:
  20〜50商品

Purchase Orders:
  5件

Sales Orders:
  10〜20件

Inspections:
  PASS
  FAIL
  PARTIAL

Transfers:
  神戸→大阪
```

これにより、起動した時点で「実際にどう使うか」が分かるようにする。

------------------------------------------------------------------------

# 38. Demo Scenario

Demo Modeでは以下を体験できるようにする。

## Scenario A: 入荷

``` text
PO-0001
商品A × 100

Scan PO
↓
Scan Product
↓
Receive 100
↓
Inspection
↓
PASS
↓
Staging
↓
Put-away
↓
A-01-01
```

## Scenario B: 不良

``` text
商品B × 50

Received 50
Inspection:
  47 PASS
  3 FAIL

PASS → Inventory
FAIL → QC_HOLD
```

## Scenario C: 出荷

``` text
SO-0001
商品A × 10
商品B × 5

Pick
↓
Pack
↓
Ship
```

## Scenario D: 倉庫間移動

``` text
神戸 20
↓
Transfer Order
↓
Approval
↓
Pick
↓
In Transit
↓
大阪 Receiving
↓
大阪 +20
```

------------------------------------------------------------------------

# 39. UI/UX改善方針

現在のUIを単純に装飾するのではなく、情報構造を改善する。

管理画面:

-   Sidebar
-   Top warehouse selector
-   Breadcrumb
-   Search
-   Filter
-   Table
-   Detail Drawer/Modal
-   Status badge
-   Activity timeline
-   Audit history

Mobile:

-   大きな操作ボタン
-   スキャン中心
-   少ない入力
-   片手操作
-   エラーを明確に表示
-   作業完了を明確に表示

------------------------------------------------------------------------

# 40. 状態遷移は必ず図にして実装

例えばReceiving:

``` text
EXPECTED
   ↓
RECEIVING
   ↓
RECEIVED
   ↓
INSPECTION
   ├── PASS → PUTAWAY
   ├── FAIL → QC_HOLD
   └── PARTIAL → REVIEW
```

Picking:

``` text
OPEN
 ↓
ALLOCATED
 ↓
PICKING
 ↓
PICKED
 ↓
PACKING
 ↓
PACKED
 ↓
SHIPPED
```

Transfer:

``` text
DRAFT
 ↓
PENDING_APPROVAL
 ↓
APPROVED
 ↓
PICKING
 ↓
IN_TRANSIT
 ↓
RECEIVING
 ↓
COMPLETED
```

状態変更には必ず権限チェックを入れる。

------------------------------------------------------------------------

# 41. 「業務イベント」と「状態」を分離

悪い例:

``` text
inventory.quantity = 100
```

だけ変更。

良い例:

``` text
stock_movement
  type = RECEIPT
  quantity = 20
  warehouse_id = ...
  bin_id = ...
  reference_type = PURCHASE_ORDER
  reference_id = ...
```

そして現在在庫を更新。

これにより監査、BI、AI分析、外部連携が容易になる。

------------------------------------------------------------------------

# 42. AIと業務イベントの関係

例:

``` text
RECEIVING_STARTED
      ↓
SCAN_ITEM
      ↓
AI_ANALYSIS_REQUESTED
      ↓
AI_ANALYSIS_COMPLETED
      ↓
HUMAN_REVIEW
      ↓
INSPECTION_CONFIRMED
      ↓
PUTAWAY_CONFIRMED
```

AIのイベントをAudit/Eventとして残せる設計にする。

------------------------------------------------------------------------

# 43. 4つの「先生」から取り入れる優先順位

## OCA WMS

最優先:

-   モジュール分割
-   Barcode
-   Put-away
-   Availability
-   Reordering
-   Dispatch/Release
-   Physical device integration

## Sentry

最優先:

-   Receiving
-   Put-away
-   Picking
-   Packing
-   Shipping
-   Cycle Count
-   Bin Transfer
-   Inter-Warehouse Transfer
-   Warehouse Picker
-   Mobile Scanner
-   Audit
-   実務状態遷移

## ERPNext

最優先:

-   Company
-   Warehouse
-   Stock Ledger
-   Purchase
-   Sales
-   Pick List
-   Stock Entry
-   Serial/Batch
-   業務ドキュメント間の関係
-   在庫整合性

## OpenBoxes

最優先:

-   倉庫/在庫移動
-   物品管理
-   供給
-   実務物流
-   在庫追跡

------------------------------------------------------------------------

# 44. Claudeへの実装指示

## Phase 0: 調査

最初にコードを書かない。

以下を調査:

``` text
backend/
mobile/
supabase/
docs/
```

既存:

-   tables
-   migrations
-   API
-   routes
-   models
-   repositories
-   services
-   providers
-   screens
-   tests

を確認。

既存実装と仕様書の差分を作る。

------------------------------------------------------------------------

# 45. Claudeに作らせる分析ファイル

以下を作成:

``` text
docs/
  architecture_current.md
  architecture_target.md
  domain_model.md
  workflow_model.md
  warehouse_model.md
  permission_model.md
  ai_architecture.md
  ui_ux_plan.md
  migration_plan.md
  oss_reference_matrix.md
```

------------------------------------------------------------------------

# 46. 実装順序

## Step 1

Warehouse/Locationモデルを完成

## Step 2

Top-level Warehouse Picker / Add Warehouse

## Step 3

Role / Permission / Warehouse Scope

## Step 4

Receiving

## Step 5

Inspection

## Step 6

Put-away

## Step 7

Picking

## Step 8

Packing

## Step 9

Shipping

## Step 10

Cycle Count

## Step 11

Inter-Warehouse Transfer

## Step 12

Audit / Stock Ledger

## Step 13

Seed/Demo Scenario

## Step 14

UI/UX全面改善

## Step 15

AI Layer

## Step 16

OCR / Vision

## Step 17

BI / External Connectors

------------------------------------------------------------------------

# 47. 実装ルール

1.  既存機能を壊さない
2.  migration-first
3.  API側で権限を検証
4.  tenant/company境界を必ず検証
5.  warehouse scopeを必ず検証
6.  在庫変更はtransaction
7.  idempotencyを考慮
8.  Audit Logを残す
9.  UIだけでセキュリティを実現しない
10. AI結果を直接本番データに確定しない
11. 外部APIを直接UIに書かない
12. Provider/Service/Repositoryを分離
13. 既存テストを維持
14. 新機能にはunit/integration testを追加
15. 大規模な一括rewriteを避ける

------------------------------------------------------------------------

# 48. 完了条件

## Warehouse

-   [ ] 1会社に複数倉庫を作成できる
-   [ ] トップ画面から倉庫追加できる
-   [ ] トップ画面から倉庫切替できる
-   [ ] ユーザーの利用可能倉庫を制御できる
-   [ ] 倉庫ごとにLocation/Binを持てる

## Receiving

-   [ ] PO
-   [ ] Receiving
-   [ ] Barcode
-   [ ] Quantity
-   [ ] Inspection
-   [ ] Staging
-   [ ] Put-away

## Outbound

-   [ ] Sales Order
-   [ ] Allocation
-   [ ] Picking
-   [ ] Packing
-   [ ] Shipping

## Inventory

-   [ ] Stock
-   [ ] Stock Movement
-   [ ] Stock Ledger
-   [ ] Adjustment
-   [ ] Cycle Count
-   [ ] Transfer

## Security

-   [ ] Roles
-   [ ] Permissions
-   [ ] Warehouse scope
-   [ ] Audit

## AI

-   [ ] AI provider abstraction
-   [ ] OCR
-   [ ] Image analysis
-   [ ] AI result storage
-   [ ] Human review
-   [ ] Audit

## UX

-   [ ] PC Dashboard
-   [ ] Warehouse Picker
-   [ ] Add Warehouse
-   [ ] Mobile operation dashboard
-   [ ] Barcode scan
-   [ ] Clear error state
-   [ ] Demo data

------------------------------------------------------------------------

# 49. 特に重要な設計判断

## 「倉庫をトップで追加したい」

これは単なるUI追加ではない。

以下をセットで実装する。

``` text
Top Dashboard
    ↓
Warehouse List
    ↓
Add Warehouse
    ↓
Warehouse Context
    ↓
Zones/Bins
    ↓
Users/Permissions
    ↓
Inventory
    ↓
Operations
```

倉庫を追加した瞬間に、

-   default staging
-   default receiving
-   default shipping
-   QC hold

などを必要に応じて作成できるようにする。

ただし、自動生成は設定可能にする。

------------------------------------------------------------------------

# 50. 「すべての倉庫」ビュー

管理者のみ:

``` text
All Warehouses

神戸:
  Inventory 12,430
  Receiving 12
  Picking 18

大阪:
  Inventory 8,210
  Receiving 4
  Picking 9

合計:
  Inventory 20,640
```

通常作業者は自分の担当倉庫だけ。

------------------------------------------------------------------------

# 51. 将来のAI Assistant

将来的に、

> 「神戸倉庫で在庫が少ない商品を教えて」

> 「今日出荷予定なのにピッキングされていない注文は？」

> 「大阪倉庫に移した方がいい商品は？」

> 「この商品の写真から商品マスターを作って」

などをAIに質問できるようにする。

AI AssistantはDBに直接書き込まず、WMSの安全なAPI/Toolを呼び出す。

------------------------------------------------------------------------

# 52. 重要なUX原則

WMSは「データを見るソフト」ではなく「現場作業を完了させるソフト」。

したがって、

``` text
管理画面:
情報を見る・設定する・承認する

Mobile:
スキャンする・確認する・作業を完了する
```

と役割を分ける。

------------------------------------------------------------------------

# 53. 最終目標

最終的なシステムは、

**一般的なWMS** + **AI** + **多言語** + **スマホ/ハンディ** +
**複数倉庫** + **柔軟なAPI** + **監査可能な在庫**

を統合したものとする。

単なるGoodsMartクローン、Sentryクローン、ERPNextクローンにはしない。

4つのOSSから成熟した考え方を取り入れながら、`paazuuu/wms`
独自のシステムとして発展させる。

------------------------------------------------------------------------

# 54. Claude Codeへの最終指示

この仕様書を読み終えたら、いきなり大量のコードを書かないこと。

まず以下を行う。

### 1.

既存リポジトリを調査。

### 2.

現在実装されている機能と、この仕様書との差分を作成。

### 3.

DBの現状と目標DBモデルを比較。

### 4.

既存データを壊さないmigration計画を作成。

### 5.

以下を優先して実装:

``` text
Multi-Warehouse
  ↓
Warehouse Picker
  ↓
Warehouse Add
  ↓
Location/Bin
  ↓
Warehouse Scope
  ↓
Receiving
  ↓
Inspection
  ↓
Put-away
  ↓
Picking
  ↓
Packing
  ↓
Shipping
  ↓
Cycle Count
  ↓
Inter-Warehouse Transfer
```

### 6.

その後AI Layerを実装。

### 7.

各段階でテストを実行。

### 8.

既存機能が壊れた場合は、新機能を優先せず回帰を修正。

### 9.

UIは「機能を増やす」だけではなく、実務シナリオを最初から最後まで操作できるようにする。

### 10.

最終的にDemo Seed Dataを入れ、初めて起動したユーザーでも、

``` text
会社
 ↓
倉庫
 ↓
商品
 ↓
入荷
 ↓
検品
 ↓
棚入れ
 ↓
受注
 ↓
ピッキング
 ↓
梱包
 ↓
出荷
```

を一連の流れとして確認できる状態にする。

------------------------------------------------------------------------

# 55. 参照プロジェクト

-   OCA WMS: https://github.com/OCA/wms
-   Sentry WMS: https://github.com/hightower-systems/sentry-wms
-   ERPNext: https://github.com/frappe/erpnext
-   OpenBoxes: https://github.com/openboxes/openboxes
-   現在のWMS: https://github.com/paazuuu/wms

## 注意

参照プロジェクトのコードをそのままコピーするのではなく、ライセンスを確認し、設計思想・データモデル・業務フロー・UXを参考にする。

特に、ライセンス上の互換性が不明なコードを直接コピーしない。

------------------------------------------------------------------------

# 56. 優先順位の最終版

### P0 --- 絶対に必要

-   Multi-Warehouse
-   Warehouse Picker
-   Add Warehouse
-   Location/Bin
-   Warehouse Scope
-   Role/Permission
-   Stock Ledger
-   Receiving
-   Inspection
-   Put-away
-   Picking
-   Packing
-   Shipping
-   Audit

### P1 --- 実務運用

-   Cycle Count
-   Adjustment
-   Transfer Order
-   Batch/Wave Picking
-   Short Pick
-   Returns
-   Demo Seed
-   Reports
-   Notifications

### P2 --- AI/自動化

-   OCR
-   Product Recognition
-   AI Inspection
-   Damage Detection
-   AI Product Registration
-   AI Put-away Suggestion
-   AI Inventory Assistant

### P3 --- 高度機能

-   RFID
-   BI
-   External ERP
-   Shopify
-   Amazon
-   楽天
-   配送会社API
-   自動発注
-   需要予測

------------------------------------------------------------------------

# 57. 最終原則

**「機能をたくさん作る」のではなく、「倉庫の仕事を最後まで完了できるシステムを作る」。**

そして、

**「AIがWMSを置き換える」のではなく、「WMSの業務をAIで高速・正確・省力化する」。**

さらに、

**「1倉庫のWMS」ではなく、「1会社 → 複数倉庫 → 複数ロケーション →
複数ユーザー → 複数業務」を最初から設計する。**

これを本プロジェクトの基本方針とする。
