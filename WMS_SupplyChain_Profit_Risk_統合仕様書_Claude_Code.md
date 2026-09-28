# WMS Supply Chain Profit & Risk Intelligence 統合仕様書

## 0. 目的

対象リポジトリ:

-   WMS: https://github.com/paazuuu/wms
-   UI参考: https://github.com/paazuuu/galaxy
-   ロジック/UI参考:
    https://github.com/jithinmathws/supplyChainRiskAnalyzer

本仕様では、既存の Flutter + Dart + Supabase WMS に、Supply Chain Risk
Analyzer
の考え方を取り入れた「仕入・物流・原価・販売価格・利益シミュレーション」機能を追加する。

世界貿易ネットワーク分析は今回対象外とする。

重要方針:

1.  `supplyChainRiskAnalyzer` のコードをそのまま移植しない。
2.  NetworkX/Streamlit の構造・UX・計算思想を参考にし、Flutter +
    Supabase に再実装する。
3.  `galaxy`
    は3000以上のUI要素を含むCSS/Tailwind系UIコレクションなので、既存WMSのデザインシステムを壊さず、必要なコンポーネントだけ参考・移植する。
4.  既存WMSの業務画面・在庫・発注・入荷・出荷・倉庫コンテキストを維持する。
5.  シミュレーションは「物流停止」だけでなく、仕入先追加、仕入率変更、送料変更、人件費、倉庫費、通関税、関税、保険、為替、販売価格変更などを同時に試算できるようにする。
6.  「最終顧客へ販売した時にいくら利益/損失になるか」をSKU単位・仕入ロット単位・シナリオ単位で確認できるようにする。

------------------------------------------------------------------------

# 1. 現行WMSとの統合方針

現在のWMSは Flutter + Dart + Supabase を中心に構成され、Supabase Auth /
PostgreSQL / Storage / Realtime / Edge Functions / RPC を利用する。

既存機能として、少なくとも以下を前提にする。

-   Dashboard
-   倉庫コンテキスト
-   複数倉庫
-   入荷
-   検品
-   Put-away
-   Picking
-   Packing
-   Shipping
-   Stock Adjustment
-   Cycle Count
-   Inter-Warehouse Transfer
-   Product Master
-   Purchase Orders
-   Supplier / Customer
-   Sales Orders
-   Work Orders
-   Reports
-   Global Search
-   Audit Log
-   User / Role / Warehouse Scope
-   AI OCR + Human Review

新機能はこれらを置き換えず、横断する分析・シミュレーション層として追加する。

## 新しいトップレベルメニュー

既存の

-   HOME
-   入荷
-   出荷
-   在庫
-   商品
-   発注・受注
-   作業
-   レポート
-   管理

に加えて、

``` text
サプライチェーン
├─ 収益ダッシュボード
├─ 仕入先比較
├─ 原価構造
├─ 物流ルート
├─ 利益シミュレーション
├─ リスク分析
├─ ボトルネック
└─ シナリオ履歴
```

を追加する。

「世界貿易」は今回実装しない。

------------------------------------------------------------------------

# 2. UIデザイン方針

## 2.1 Galaxyをそのままテーマとして適用しない

`paazuuu/galaxy` は Uiverse.io
由来の3000以上のUI要素をまとめたUIライブラリで、CSS/Tailwindベースのコンポーネント集である。

WMSはFlutterなので、HTML/CSSを直接持ち込むのではなく、以下のデザイン原則をFlutter
Widgetとして再現する。

### 採用するUI要素

-   Card
-   Button
-   Input
-   Select
-   Toggle
-   Checkbox
-   Radio
-   Tooltip
-   Notification
-   Loading
-   Status badge
-   Progress indicator

### WMSとして統一するもの

-   Border radius
-   Spacing
-   Typography
-   Status colors
-   Icon style
-   Table style
-   Dialog style
-   Drawer
-   Filter chips
-   KPI cards

Galaxyから個別UIを選んでFlutter Widgetへ移植する。

------------------------------------------------------------------------

# 3. 新しい画面の基本レイアウト

PCでは既存WMSと同じ左ナビゲーションを使用する。

``` text
┌──────────────────────────────────────────────────────────────┐
│ WMS    [神戸倉庫 ▼]       🔍検索       🔔       👤          │
├──────────────┬───────────────────────────────────────────────┤
│ HOME         │ サプライチェーン / 利益シミュレーション      │
│ 入荷         │                                               │
│ 出荷         │ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│ 在庫         │ │売上予定 │ │総原価   │ │粗利益   │          │
│ 商品         │ │¥10.0M  │ │¥7.1M   │ │¥2.9M   │          │
│ 発注・受注   │ └─────────┘ └─────────┘ └─────────┘          │
│ 作業         │                                               │
│ レポート     │ 仕入先 → 物流 → 倉庫 → 顧客                  │
│              │                                               │
│ サプライ     │ Supplier A ─┐                                 │
│ チェーン     │ Supplier B ─┼→ 船 → 通関 → 倉庫 → 顧客       │
│  ├収益分析   │ Supplier C ─┘      ✈ 航空                    │
│  ├仕入先比較 │                                               │
│  ├原価構造   │ [シナリオ作成] [比較] [保存]                 │
│  ├物流ルート │                                               │
│  ├シミュレーション                                           │
│  ├リスク     │                                               │
│  └ボトルネック│                                              │
│ 管理         │                                               │
└──────────────┴───────────────────────────────────────────────┘
```

Mobile/ハンディではシミュレーションを簡略化し、詳細なシナリオ作成はPC中心とする。

------------------------------------------------------------------------

# 4. 収益ダッシュボード

## 目的

「この商品を仕入れて最終顧客に販売したら、実際にいくら残るのか」を表示する。

### KPI

``` text
売上
¥10,000,000

仕入原価
¥4,800,000

物流費
¥900,000

通関・関税
¥350,000

倉庫費
¥400,000

人件費
¥600,000

その他経費
¥250,000

総原価
¥7,300,000

粗利益
¥2,700,000

利益率
27.0%
```

### 重要

「仕入価格だけを原価」としない。

最終原価 =

``` text
仕入価格
+ 国際送料
+ 国内送料
+ 海上/航空運賃
+ 保険
+ 通関費
+ 関税
+ 消費税等の必要税費
+ 為替影響
+ 倉庫費
+ 入荷作業費
+ 検品費
+ 梱包費
+ 人件費
+ その他経費
```

とする。

税金の扱いは「費用化するもの」と「控除/還付対象となるもの」を分けられる設計にする。

------------------------------------------------------------------------

# 5. 仕入先比較

## 画面

``` text
仕入先比較

商品: ABC-001
数量: 1,000

┌──────────┬────────┬────────┬────────┬────────┐
│          │ Supplier A │ Supplier B │ Supplier C │
├──────────┼────────┼────────┼────────┼────────┤
│仕入価格  │ ¥1,000   │ ¥930     │ ¥1,080   │
│掛率      │ 70%      │ 65%      │ 75%      │
│送料      │ ¥80      │ ¥140     │ ¥60      │
│関税      │ ¥40      │ ¥40      │ ¥55      │
│納期      │ 14日     │ 21日     │ 7日      │
│倉庫費    │ ¥35      │ ¥35      │ ¥35      │
│最終原価  │ ¥1,155   │ ¥1,145   │ ¥1,230   │
│販売価格  │ ¥1,800   │ ¥1,800   │ ¥1,800   │
│利益      │ ¥645     │ ¥655     │ ¥570     │
│利益率    │ 35.8%    │ 36.4%    │ 31.7%    │
└──────────┴────────┴────────┴────────┴────────┘
```

「最安仕入先」だけでなく「最終利益がいくらか」を比較する。

------------------------------------------------------------------------

# 6. 仕入先追加シミュレーション

ユーザーが、

``` text
現在:
Supplier Aのみ

変更:
Supplier A
Supplier Bを追加
```

と設定できる。

## 入力

-   新規仕入先
-   対象SKU
-   仕入単価
-   掛率
-   MOQ
-   納期
-   支払条件
-   通貨
-   為替レート
-   船/航空
-   送料
-   保険
-   関税
-   通関費
-   国内配送費
-   倉庫費
-   人件費

## 結果

``` text
Supplier B追加

年間購入量
10,000個

旧原価
¥12,000,000

新原価
¥11,200,000

年間削減
¥800,000

平均納期
14日 → 10日

利益率
22.4% → 24.1%
```

------------------------------------------------------------------------

# 7. 掛率変更シミュレーション

仕入先との掛率をシナリオ化する。

例:

``` text
現在掛率: 70%

Scenario A: 65%
Scenario B: 68%
Scenario C: 75%
```

画面上で即座に、

``` text
掛率 65%
仕入原価 ¥650
総原価   ¥910
販売価格 ¥1,500
利益     ¥590
利益率   39.3%

掛率 75%
仕入原価 ¥750
総原価   ¥1,010
販売価格 ¥1,500
利益     ¥490
利益率   32.7%
```

のように比較する。

------------------------------------------------------------------------

# 8. 物流ルートモデル

物流をGraphとして扱う。

``` text
Supplier
   │
   ├── 船
   │     ├── 上海港
   │     ├── 海上輸送
   │     └── 大阪港
   │
   └── 航空
         ├── 上海空港
         ├── 航空輸送
         └── 関西空港
                   │
                   ▼
                通関
                   │
                   ▼
                倉庫
                   │
                   ▼
                顧客
```

各Edgeに以下を持たせる。

-   transport_mode
-   distance
-   lead_time
-   base_cost
-   cost_per_kg
-   cost_per_unit
-   capacity
-   fuel_surcharge
-   insurance_rate
-   customs_cost
-   tariff_rate
-   handling_cost
-   risk_level

------------------------------------------------------------------------

# 9. 船・航空の代替ルート

同じSupplierから複数ルートを登録できる。

## 海上

``` text
中国Supplier
↓
上海港
↓
船
↓
大阪港
↓
通関
↓
国内配送
↓
倉庫
```

## 航空

``` text
中国Supplier
↓
上海空港
↓
航空
↓
関西空港
↓
通関
↓
国内配送
↓
倉庫
```

比較項目:

  項目                    船        航空
  -------------- ----------- -----------
  輸送費                  安          高
  リードタイム            長          短
  容量                    大          小
  保険              設定可能    設定可能
  通関費            設定可能    設定可能
  関税             HS/設定値   HS/設定値
  リスク            設定可能    設定可能

------------------------------------------------------------------------

# 10. 通関・関税モデル

商品マスターに将来的に以下を持たせる。

-   HS Code
-   原産国
-   課税価格
-   関税率
-   輸入税区分
-   通関費
-   その他輸入関連費用

ルートごとに、

``` text
CIF価格
+ 関税
+ 通関費
+ 港湾/空港費
+ 国内配送
```

を計算できるようにする。

税率はハードコードしない。

将来的に税率マスタ/APIを接続できる構造にする。

------------------------------------------------------------------------

# 11. 原価計算エンジン

## 基本式

``` text
purchase_cost
+ international_freight
+ insurance
+ customs_duty
+ customs_fee
+ port_or_airport_fee
+ domestic_freight
+ warehouse_cost
+ receiving_cost
+ inspection_cost
+ packing_cost
+ labor_cost
+ overhead_cost
= landed_cost
```

## 利益

``` text
sales_revenue
- landed_cost
- sales_related_cost
= profit
```

## 利益率

``` text
profit / sales_revenue × 100
```

------------------------------------------------------------------------

# 12. 人件費

人件費を固定費・変動費に分離する。

例:

``` text
検品
1時間 ¥1,500

入荷処理
1件 ¥300

梱包
1箱 ¥120

ピッキング
1行 ¥80

出荷処理
1件 ¥250
```

SKU/Order/Carton単位に配賦可能にする。

------------------------------------------------------------------------

# 13. 倉庫費

以下を設定可能にする。

-   月額固定費
-   坪/㎡単価
-   パレット単価
-   Bin単価
-   保管日数
-   入出庫作業費
-   電気/設備費
-   共通経費

例:

``` text
倉庫固定費
¥300,000/月

保管
¥15 / unit / month

入荷
¥80 / unit

出荷
¥100 / unit
```

------------------------------------------------------------------------

# 14. シミュレーション画面

## メインUI

``` text
┌──────────────────────────────────────────────┐
│ 利益シミュレーション                         │
├──────────────────────────────────────────────┤
│ Scenario                                      │
│ [現在条件 ▼] [新規シナリオ]                  │
│                                              │
│ 仕入先                                        │
│ ☑ Supplier A                                 │
│ ☑ Supplier B                                 │
│ ☐ Supplier C                                 │
│                                              │
│ 物流                                           │
│ ○ 船                                          │
│ ○ 航空                                        │
│ ○ 自動比較                                    │
│                                              │
│ 掛率          [70%] → [65%]                  │
│ 送料          [¥80] → [¥120]                 │
│ 関税          [5%] → [5%]                    │
│ 倉庫費        [¥35] → [¥40]                  │
│ 人件費        [¥120] → [¥140]                │
│                                              │
│           [シミュレーション実行]              │
└──────────────────────────────────────────────┘
```

------------------------------------------------------------------------

# 15. シミュレーション結果

``` text
┌──────────────────────────────────────────────┐
│ Scenario: Supplier B + 航空                  │
├──────────────────────────────────────────────┤
│ 売上             ¥10,000,000                 │
│ 仕入             ¥5,000,000                  │
│ 物流             ¥900,000                    │
│ 関税             ¥300,000                    │
│ 通関             ¥120,000                    │
│ 倉庫             ¥350,000                    │
│ 人件費           ¥600,000                    │
│ その他           ¥200,000                    │
│ ─────────────────────────────────────────── │
│ 総原価           ¥7,470,000                  │
│ 利益             ¥2,530,000                  │
│ 利益率           25.3%                       │
│                                              │
│ 現在との差       +¥380,000                   │
└──────────────────────────────────────────────┘
```

------------------------------------------------------------------------

# 16. シナリオ比較

最大5シナリオを比較する。

``` text
             現在   Supplier B   航空   船
売上         10M      10M        10M   10M
総原価       7.8M     7.4M       7.9M  7.3M
利益         2.2M     2.6M       2.1M  2.7M
利益率       22%      26%        21%   27%
納期         21日     18日       5日   21日
```

「最良」という評価をシステムが決めるのではなく、ユーザーが利益・納期・リスク等を見て判断できるUIにする。

------------------------------------------------------------------------

# 17. リスク分析

今回は世界貿易リスクではなく、自社物流のリスクだけを対象にする。

## 分析対象

-   Supplier停止
-   Supplierの価格上昇
-   Supplier納期遅延
-   船便停止
-   航空便停止
-   港湾停止
-   空港停止
-   通関遅延
-   倉庫容量不足
-   倉庫停止
-   国内配送停止
-   人員不足
-   コスト急増

------------------------------------------------------------------------

# 18. ボトルネック分析

GraphのNode:

-   Supplier
-   Port
-   Airport
-   Customs
-   Warehouse
-   Distribution Center

Edge:

-   Sea
-   Air
-   Truck
-   Courier
-   Internal Transfer

について、

-   流量
-   容量
-   リードタイム
-   コスト
-   代替経路

を分析する。

例:

``` text
Supplier A
   │
   ▼
上海港
   │
   ▼
大阪港  ← Bottleneck
   │
   ▼
大阪倉庫
```

大阪港の容量を超えた場合、

``` text
負荷 125%
状態: CAPACITY EXCEEDED
```

として警告する。

------------------------------------------------------------------------

# 19. 障害シミュレーション

例:

``` text
Scenario:
「大阪港が14日停止」

初期状態
上海 → 大阪港 → 大阪倉庫

障害
大阪港 ❌

代替:
上海 → 関西空港 → 大阪倉庫

再計算:
追加航空費
追加通関費
追加国内配送費
納期短縮/延長
在庫不足
販売機会損失

最終:
利益への影響
```

------------------------------------------------------------------------

# 20. 仕入先価格変動 + 物流変動を同時に計算

重要機能。

例えば、

``` text
Supplier B
仕入価格 +10%

同時に

海上運賃 +20%

同時に

倉庫費 +5%
```

を一つのScenarioとして計算する。

結果:

``` text
現在利益       ¥2,700,000
Scenario利益   ¥1,940,000

利益差         -¥760,000
```

------------------------------------------------------------------------

# 21. データモデル

既存テーブルを尊重し、新規テーブルを追加する。

推奨:

``` text
supply_chain_suppliers
supply_chain_supplier_products

supply_chain_routes
supply_chain_route_edges
supply_chain_transport_modes

supply_chain_cost_rules
supply_chain_customs_rules
supply_chain_tariff_rules

supply_chain_scenarios
supply_chain_scenario_inputs
supply_chain_scenario_results

supply_chain_risk_events
supply_chain_bottlenecks

supply_chain_profit_snapshots
```

既存:

``` text
products
suppliers
purchase_orders
purchase_order_items
warehouses
inventory
sales_orders
sales_order_items
shipments
```

などとForeign Keyで接続する。

------------------------------------------------------------------------

# 22. Route Edgeデータ例

``` json
{
  "route_id": "route-001",
  "from_node": "supplier-a",
  "to_node": "osaka-port",
  "transport_mode": "sea",
  "lead_time_days": 7,
  "base_cost": 100000,
  "cost_per_kg": 80,
  "capacity_kg": 20000,
  "insurance_rate": 0.003,
  "risk_level": "medium"
}
```

航空:

``` json
{
  "transport_mode": "air",
  "lead_time_days": 2,
  "base_cost": 50000,
  "cost_per_kg": 500,
  "capacity_kg": 5000,
  "insurance_rate": 0.002,
  "risk_level": "low"
}
```

------------------------------------------------------------------------

# 23. Scenario入力

``` json
{
  "supplier_price_multiplier": 1.10,
  "discount_rate": 0.65,
  "freight_multiplier": 1.20,
  "warehouse_cost_multiplier": 1.05,
  "labor_cost_multiplier": 1.00,
  "tariff_multiplier": 1.00,
  "route_override": "air",
  "supplier_enabled": [
    "supplier-a",
    "supplier-b"
  ]
}
```

------------------------------------------------------------------------

# 24. 計算アーキテクチャ

Flutterから直接複雑な計算をしない。

推奨:

``` text
Flutter
   │
   │ scenario input
   ▼
Supabase Edge Function / RPC
   │
   ├─ load products
   ├─ load suppliers
   ├─ load routes
   ├─ load cost rules
   ├─ load tariff rules
   ├─ load warehouse costs
   │
   ▼
Simulation Engine
   │
   ├─ route calculation
   ├─ landed cost
   ├─ bottleneck
   ├─ disruption
   ├─ profit
   └─ risk
   │
   ▼
scenario_results
   │
   ▼
Flutter charts / tables / graph
```

将来、計算が大きくなった場合でもEdge Functionsを独立したSimulation
APIとして拡張できるようにする。

------------------------------------------------------------------------

# 25. NetworkXの扱い

`supplyChainRiskAnalyzer` は NetworkX を利用してGraphを構築している。

しかしWMS本体はFlutter +
Supabaseなので、NetworkXをFlutterへ直接移植しない。

最初の実装では、

-   SQL/RPC
-   Edge Function
-   Dart側の軽量Graph計算

のどれが適切かを機能ごとに判断する。

複雑なCascade Simulationが必要になった場合のみ、Simulation
Engineを独立サービス化する。

------------------------------------------------------------------------

# 26. AIとの連携

将来AIを追加できる。

例えば:

``` text
AI:
「Supplier Aの掛率が70%から75%になった場合、
年間利益は約¥800,000減少する可能性があります。」

AI:
「航空便へ変更すると納期は短縮できますが、
1個あたり物流原価が約¥420増加します。」

AI:
「Supplier Bを追加するとSupplier A停止時の
代替供給能力が増加します。」
```

ただし、AIが最終的な発注判断を自動決定しない。

------------------------------------------------------------------------

# 27. 商品詳細への統合

Product Detailに新しいタブを追加:

``` text
商品
├─ 基本情報
├─ 在庫
├─ 入荷
├─ 出荷
├─ 発注
├─ 仕入先
├─ 原価
└─ 利益シミュレーション
```

### 利益シミュレーション

``` text
販売価格       ¥1,800

仕入先A
最終原価       ¥1,150
利益            ¥650
利益率          36.1%

仕入先B
最終原価       ¥1,090
利益            ¥710
利益率          39.4%

航空便
最終原価       ¥1,380
利益            ¥420
利益率          23.3%
```

------------------------------------------------------------------------

# 28. Supplier Detailへの統合

Supplier Detail:

``` text
仕入先
├─ 基本情報
├─ 取引履歴
├─ 発注
├─ 商品
├─ 掛率
├─ 支払条件
├─ 納期
├─ 物流ルート
├─ 原価
└─ リスク
```

Supplier単位で、

-   平均仕入価格
-   平均納期
-   不良率
-   遅延率
-   利益への影響
-   代替Supplierの有無

を表示する。

------------------------------------------------------------------------

# 29. 発注画面への統合

Purchase Order作成時:

``` text
商品 ABC-001
数量 1,000

仕入先:
[Supplier A ▼]

現在最終原価:
¥1,150

販売予定価格:
¥1,800

予想利益:
¥650 / unit

[利益をシミュレーション]
```

クリックすると、

``` text
Supplier A
Supplier B
Supplier C
```

と比較できる。

------------------------------------------------------------------------

# 30. 発注前チェック

発注確定前に、

``` text
⚠ Profit Warning

今回の条件では利益率が
35.2% → 18.4%
へ低下します。

原因:
仕入価格 +10%
海上運賃 +25%
為替 +5%

[詳細を見る]
[シミュレーション]
[発注を続ける]
```

を表示可能にする。

------------------------------------------------------------------------

# 31. UIコンポーネント

Flutterで以下を共通Widget化する。

``` text
SupplyKpiCard
ProfitKpiCard
CostBreakdownCard
SupplierComparisonTable
ScenarioCard
ScenarioParameterEditor
RouteGraphView
RouteEdgeCard
RiskBadge
BottleneckCard
ProfitWaterfallChart
ScenarioComparisonChart
CostBreakdownChart
SimulationResultPanel
```

Galaxyから参考にするUI:

``` text
Button
Card
Input
Toggle
Checkbox
Radio
Tooltip
Notification
Loader
```

------------------------------------------------------------------------

# 32. Profit Waterfall UI

原価を視覚的に理解できるようにする。

``` text
販売価格
¥1,800
  │
  ├─ 仕入  -¥900
  ├─ 船便  -¥120
  ├─ 関税  -¥45
  ├─ 通関  -¥30
  ├─ 倉庫  -¥80
  ├─ 人件費 -¥75
  └─ その他 -¥50
             ↓
          利益 ¥500
```

------------------------------------------------------------------------

# 33. Route Graph UI

``` text
             ┌─ ✈ 航空 ¥500/kg ─┐
Supplier A ──┤                    ├→ 通関 → 倉庫
             └─ 🚢 船 ¥80/kg ────┘
```

Edgeをタップすると:

``` text
航空輸送

リードタイム: 2日
費用: ¥500/kg
容量: 5,000kg
保険: 0.2%
リスク: Low

[このルートをScenarioに適用]
```

------------------------------------------------------------------------

# 34. リスクUI

``` text
Supply Chain Risk

Supplier A       🟡 Medium
Shanghai Port    🟠 High
Air Route        🟢 Low
Sea Route        🟡 Medium
Osaka Warehouse  🟢 Low
```

リスク値は説明可能なルールベースから開始する。

AIによるブラックボックスなRisk Scoreを最初から導入しない。

------------------------------------------------------------------------

# 35. 開発Phase

## Phase A

基盤:

-   新規DB tables
-   Supplier/Productとの関連
-   Route master
-   Transport mode
-   Cost rule
-   Profit calculation

## Phase B

UI:

-   Supply Chain menu
-   Profit Dashboard
-   Supplier Comparison
-   Cost Breakdown
-   Product Profit Simulation

## Phase C

物流:

-   Sea
-   Air
-   Truck
-   Customs
-   Tariff
-   Insurance
-   Alternative route

## Phase D

Risk:

-   Bottleneck
-   Supplier failure
-   Route failure
-   Warehouse failure
-   Capacity simulation

## Phase E

Scenario:

-   Supplier追加
-   掛率変更
-   送料変更
-   人件費変更
-   倉庫費変更
-   関税変更
-   為替変更
-   販売価格変更
-   複合Scenario

## Phase F

AI:

-   原価変動説明
-   Scenario要約
-   異常値検知
-   発注前分析
-   リスク説明

------------------------------------------------------------------------

# 36. 実装上の重要ルール

### ルール1

既存WMSのテーブルを不用意に破壊しない。

### ルール2

既存の倉庫コンテキストを必ず継承する。

### ルール3

Simulationは実在庫を直接変更しない。

### ルール4

Scenario実行結果はSnapshotとして保存する。

### ルール5

「現在値」と「シミュレーション値」をUIで明確に区別する。

### ルール6

発注・入荷・出荷など実取引への反映はユーザー操作で確定する。

### ルール7

税率・関税率・送料などをコードへハードコードしない。

### ルール8

計算式はテスト可能な独立サービスにする。

### ルール9

Galaxy/UiverseのUIは必要なものだけを採用し、WMS全体のデザイン統一を優先する。

### ルール10

Streamlit UIを移植するのではなく、UX/計算モデルをFlutter
UIへ再設計する。

------------------------------------------------------------------------

# 37. Claude Codeへの実装指示

Claude Codeは最初に必ず以下を確認する。

1.  現在のSupabase schema
2.  Product
3.  Supplier
4.  Purchase Order
5.  Purchase Order Item
6.  Warehouse
7.  Inventory
8.  Sales Order
9.  Shipment
10. 現在のDesign System
11. 現在のNavigation
12. 既存のRepository/Service層

その後、

``` text
Step 1:
既存DBを破壊せずmigration作成

Step 2:
domain/model追加

Step 3:
repository/service追加

Step 4:
profit calculation engine

Step 5:
route model

Step 6:
scenario engine

Step 7:
Supply Chain UI

Step 8:
既存Product/Supplier/Purchase Orderへの導線追加

Step 9:
test

Step 10:
UI polish
```

の順番で進める。

------------------------------------------------------------------------

# 38. 最終的なWMSの完成イメージ

``` text
WMS
│
├─ HOME
│
├─ 入荷
├─ 出荷
├─ 在庫
├─ 商品
├─ 発注・受注
├─ 作業
│
├─ サプライチェーン
│   │
│   ├─ 収益ダッシュボード
│   │
│   ├─ 仕入先比較
│   │
│   ├─ 原価構造
│   │
│   ├─ 物流ルート
│   │      ├─ 船
│   │      ├─ 航空
│   │      ├─ トラック
│   │      └─ 通関
│   │
│   ├─ 利益シミュレーション
│   │      ├─ 仕入先追加
│   │      ├─ 掛率変更
│   │      ├─ 送料変更
│   │      ├─ 関税変更
│   │      ├─ 人件費変更
│   │      ├─ 倉庫費変更
│   │      └─ 販売価格変更
│   │
│   ├─ リスク分析
│   │
│   └─ ボトルネック
│
├─ レポート
└─ 管理
```

## ゴール

最終的にこのWMSは単に、

「商品が何個あるか」

を見るだけではなく、

「この商品を、どの仕入先から、どの掛率で、どの輸送方法で、どの倉庫へ入れ、どの経費をかけて販売したら、最終的にいくら利益が残るか」

を一つの画面で計算できるようにする。

さらに、

「Supplier Aが停止したら？」 「Supplier Bを追加したら？」
「掛率が70%→75%になったら？」 「船→航空に変更したら？」
「関税が上がったら？」 「倉庫費が10%上がったら？」
「販売価格を変更したら？」

を実際のWMSデータを使ってWhat-ifとして比較できることを最終目標とする。

------------------------------------------------------------------------

## 参考プロジェクト

-   WMS: https://github.com/paazuuu/wms
-   Galaxy UI: https://github.com/paazuuu/galaxy
-   Supply Chain Risk Analyzer:
    https://github.com/jithinmathws/supplyChainRiskAnalyzer
