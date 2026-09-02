# 納品照合（Delivery Reconciliation）— バックエンド契約

納品書とサプライヤー事前Excelを突き合わせ、「何が納品され／何が不足・過剰・想定外か」を
可視化する機能のサーバ側契約。**PCでExcelを取り込む人**と**ハンディで検品する人**が別々に
作業するため、予定データは共有DBに保存する（モバイルはこのAPIを参照するだけ）。

この契約はDB非依存で書いてある（Supabase / Cloudflare D1 / Neon など任意のRDBで実装可）。
モバイルクライアントの実装は `mobile/lib/features/delivery/` を参照。

---

## 1. フロー

```
[PC・バックオフィス]                 [共有DB]                [ハンディ端末]
 サプライヤーExcel  ──取り込み──▶  delivery_plans   ──GET──▶  納品予定一覧
                                    + _lines                    │
                                                                ▼
                                              スキャン主＋OCR補助で計数
                                                                │
                              reconciliation_lines ◀──POST──  照合を完了
```

- Excel取り込み（PC側）: `delivery_plans` と `delivery_plan_lines` を作成する。**モバイルは予定を作らない**。
- 照合（ハンディ）: 予定を読み込み、JANスキャン（＝実績）とOCR補助で数量を確定し、結果をPOST。

---

## 2. データモデル

### delivery_plans（納品予定ヘッダ）
| カラム | 型 | 説明 |
|---|---|---|
| id | int (PK) | |
| delivery_number | text | 伝票番号（例 `0901`） |
| supplier_name | text? | 仕入先名（例 新東光通商） |
| supplier_code | text? | 仕入先コード |
| customer_code | text? | お客様コード（例 `5001033`） |
| delivery_date | text? | 納品日（表示用文字列 `26/08/06` 等） |
| registration_number | text? | 適格請求書 登録番号（例 `T3122001027817`） |
| status | text | `open` / `reconciling` / `completed` |
| created_at | timestamp | |

### delivery_plan_lines（納品予定明細）
| カラム | 型 | 説明 |
|---|---|---|
| id | int (PK) | |
| delivery_plan_id | int (FK) | |
| jan_code | text | **照合キー**（JAN/EAN-13） |
| product_code | text? | 商品番号（例 `30232955`） |
| product_name | text | 品名 |
| spec | text? | 規格 |
| planned_quantity | int | 予定数量（＝Excelの数量） |
| unit_price | int? | 単価（円） |
| amount | int? | 金額（円） |
| tax_rate | numeric? | 税率（例 `10.0`） |

### delivery_reconciliations（照合セッション）
| カラム | 型 | 説明 |
|---|---|---|
| id | int (PK) | |
| delivery_plan_id | int (FK) | |
| operator_id | int? | 検品担当 |
| note_reference | text? | 撮影した納品書画像への参照（Storageキー/URL） |
| status | text | `completed` 等 |
| created_at | timestamp | |

### reconciliation_lines（照合結果明細）
| カラム | 型 | 説明 |
|---|---|---|
| id | int (PK) | |
| reconciliation_id | int (FK) | |
| plan_line_id | int? | 予定明細ID（想定外はnull） |
| jan_code | text | |
| planned_quantity | int | 記録時点の予定数量 |
| actual_quantity | int | 実績数量 |
| status | text | `matched`/`shortfall`/`over`/`unexpected`（サーバ側で再計算・保存） |
| source | text | `scan`/`ocr`/`manual`（実績の由来） |

> 明細ステータスはモバイルでも即時計算して表示するが、確定値はサーバが
> `planned_quantity` と `actual_quantity` から再計算して保存する（クライアントを信用しない）。

### Excel列 → フィールド対応（画像の納品書より）
| 納品書の列 | フィールド |
|---|---|
| JANコード / 商品コード | `jan_code` |
| 商品番号 | `product_code` |
| 品名 | `product_name` |
| 規格 | `spec` |
| 数量 | `planned_quantity` |
| 単価 | `unit_price` |
| 金額 | `amount` |
| 税率 | `tax_rate` |

---

## 3. REST エンドポイント

ベース: `/api/v1`（`mobile/lib/core/config/app_config.dart`）。認証は既存のBearerトークン。

### GET `/delivery-plans?status=&search=&per_page=50`
一覧。`status` は `open` / `reconciling`。`search` は伝票番号・仕入先の部分一致。
```json
{ "data": [
  { "id": 12, "delivery_number": "0901", "supplier_name": "新東光通商",
    "supplier_code": "83231", "customer_code": "5001033",
    "delivery_date": "26/08/06", "registration_number": "T3122001027817",
    "status": "open", "line_count": 2 }
] }
```

### GET `/delivery-plans/{id}`
明細付き1件。
```json
{ "data": {
  "id": 12, "delivery_number": "0901", "supplier_name": "新東光通商",
  "status": "open",
  "lines": [
    { "id": 101, "jan_code": "4902505632037", "product_code": "30232955",
      "product_name": "パイロット サインペン BP05 LPU", "spec": "B1L80EFSULPU",
      "planned_quantity": 100, "unit_price": 440, "amount": 44000, "tax_rate": 10.0 }
  ]
} }
```

### POST `/delivery-plans/{id}/reconcile`
照合結果を送信。`lines` は計数されたJANごとに1件（予定にある行は `line_id` 付き、
想定外は `line_id` 無し）。`complete=true` で予定を `completed` に遷移。
```json
// request
{ "complete": true,
  "note_reference": "deliveries/12/note-20260806.jpg",
  "lines": [
    { "line_id": 101, "jan_code": "4902505632037", "actual_quantity": 100, "source": "scan" },
    { "jan_code": "4560000000004", "actual_quantity": 3, "source": "ocr" }
  ] }
// response: 更新後の delivery_plan（GET /delivery-plans/{id} と同形）
```

サーバ側の処理:
1. `delivery_reconciliations` を1件作成。
2. 各 `lines[]` を `reconciliation_lines` に保存し、`planned_quantity` を予定から解決、
   `status` を `planned vs actual` で再計算。
3. 予定にあるのに送られてこなかったJANは `actual_quantity=0` / `status=shortfall`（未入荷）として補完保存。
4. `complete=true` なら `delivery_plans.status='completed'`、そうでなければ `reconciling`。

---

## 4. 明細ステータス判定（サーバ・クライアント共通）
```
actual == 0            → pending    （未確認 / 未入荷）
actual == planned      → matched    （一致）
0 < actual < planned   → shortfall  （不足）
actual > planned       → over       （過剰）
plan に無い JAN         → unexpected （想定外）
```
