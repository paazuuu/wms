# WMS 仕入先ファイル起点の入荷・検品・在庫更新 追加仕様書

対象: `paazuuu/wms`  
構成: Flutter + Dart + Supabase  
目的: 実際の電話・メールによる仕入注文を前提に、仕入先から受領したPDF・画像・Excel等のファイルをAIで解析し、入荷予定・分納・検品・在庫更新までを一貫して管理する。

---

## 1. 今回の業務前提

本WMSでは、現時点ではシステムから仕入先へ正式な発注を送信することを主目的としない。

実際の業務は以下を基本とする。

```text
担当者
 ↓
仕入先へ電話・メールで注文
 ↓
仕入先から注文確認書・納品予定・納品書・請求書等を受領
 ↓
WMSへファイルアップロード
 ↓
AI/OCRで内容解析
 ↓
既存Product Master・Supplierと照合
 ↓
AI解析結果を人間が確認
 ↓
入荷予定を作成/更新
 ↓
実際の商品が到着
 ↓
入荷受付
 ↓
検品
 ↓
合格数量のみ在庫へ反映
 ↓
棚入れ
```

### 重要

「発注」と「入荷」を同じイベントとして扱わない。

仕入先との電話・メールでの注文は、WMS上では将来的にPurchase Orderとして管理できるようにするが、Phase 1では「仕入先から受領したファイルを根拠にしたInbound/Expected Receipt」を中心にする。

---

# 2. 既存仕様との整合性

現在のWMS仕様には以下が既に存在する。

- 入荷予定
- 入荷受付
- 検品
- 棚入れ
- Purchase Orders
- Supplier
- AI OCR
- Attachment
- AI結果DB
- 在庫Ledger
- `RECEIVE` / `PUT_AWAY`等のStock Movement

また、現在仕様ではReceivingを

```text
EXPECTED
 ↓
RECEIVING
 ↓
RECEIVED
 ↓
INSPECTION
 ├─ PASS → PUTAWAY
 ├─ FAIL → QC_HOLD
 └─ PARTIAL → REVIEW
```

とする設計になっている。

この方向性は維持する。

ただし、現在の「予定日」と「実際の入荷日」「検品日」の関係は、分納を考慮して明確に分離する必要がある。

---

# 3. 最重要修正：予定日と実績日を分離する

## NG

以下のように1つの日付を共有しない。

```text
入荷予定日 = 2026/10/10
検品日     = 2026/10/10
実際入荷日 = 2026/10/10
```

これは分納時に破綻する。

---

## 正しい設計

最低でも以下を分離する。

```text
expected_arrival_date
actual_received_date
inspection_started_at
inspection_completed_at
putaway_completed_at
```

意味:

| 項目 | 意味 |
|---|---|
| expected_arrival_date | 仕入先から提示された入荷予定日 |
| actual_received_date | 実際に商品が到着した日 |
| inspection_started_at | 実際に検品を開始した日時 |
| inspection_completed_at | 実際に検品を完了した日時 |
| putaway_completed_at | 棚入れ完了日時 |

---

# 4. 検品日は「予定日から自動確定」しない

ユーザーが希望する「入荷予定日に検品日を設定できる」UI自体は残してよい。

ただし、意味を以下にする。

```text
入荷予定日
[2026/10/10]

検品予定日
[2026/10/10]
```

これは「予定」である。

実際に商品が10/12に到着した場合、

```text
予定入荷日      10/10
実際の入荷日    10/12
予定検品日      10/10
実際の検品開始  10/12
実際の検品完了  10/12
```

とする。

### UI上の推奨

実際の入荷受付を確定したとき、

```text
実際の入荷日
[2026/10/12]

検品予定日
[2026/10/12] ← 初期値として自動提案

[検品開始]
```

とする。

つまり、

**「検品予定日は実際の入荷日を初期値として提案する」**

のであって、

**「検品日を入荷予定日に固定する」**

仕様にはしない。

---

# 5. 分納を必須要件にする

例えば仕入先から、

```text
商品A 100個
商品B 50個
商品C 30個
```

というファイルを受領したとする。

予定:

```text
10/10
A 100
B 50
C 30
```

しかし実際には、

### 10/10

```text
A 60
B 50
C 0
```

### 10/15

```text
A 40
B 0
C 30
```

と分納される可能性がある。

この場合、1つのReceivingレコードを上書きしてはいけない。

---

# 6. Expected ReceiptとActual Receiptを分離

推奨構造:

```text
Inbound Document
      │
      └── Expected Receipt
              │
              ├── Receipt #1
              │      ├── A 60
              │      ├── B 50
              │      └── 10/10
              │
              └── Receipt #2
                     ├── A 40
                     ├── C 30
                     └── 10/15
```

### Expected Receipt

「仕入先から届く予定」を表す。

### Actual Receipt

「実際に届いた1回分」を表す。

---

# 7. 数量管理

Expected Receipt Lineには最低限、

```text
product_id
expected_quantity
received_quantity
remaining_quantity
unit
status
```

を持たせる。

計算:

```text
remaining_quantity
=
expected_quantity - total_received_quantity
```

例:

```text
商品A
予定       100
1回目入荷   60
2回目入荷   40
残          0
```

表示:

```text
商品A
予定 100
入荷済 60
残 40
```

さらに2回目を受け付けた後:

```text
商品A
予定 100
入荷済 100
残 0
```

---

# 8. 超過入荷にも対応

予定100個に対して110個届く場合がある。

```text
予定       100
実績       110
差異       +10
```

この場合、勝手に110個を通常在庫に確定しない。

```text
OVER_RECEIPT
```

として警告する。

UI:

```text
⚠ 予定数量を10個超えています

予定数量  100
到着数量  110
超過       10

[全量受入]
[100個のみ受入]
[保留]
```

権限によって承認可能にする。

---

# 9. 不足・分納・超過を明確に区別

状態:

```text
EXPECTED
PARTIALLY_RECEIVED
RECEIVED
OVER_RECEIVED
CANCELLED
CLOSED
```

例:

```text
予定 100
入荷 60
残 40

→ PARTIALLY_RECEIVED
```

```text
予定 100
入荷 100

→ RECEIVED
```

```text
予定 100
入荷 110

→ OVER_RECEIVED
```

---

# 10. 仕入先ファイルを「入荷の根拠」とする

仕入先から来るファイルは、単なる添付ファイルとして保存するだけではなく、入荷情報の根拠として扱う。

対応候補:

- 注文確認書
- 発注確認書
- 納品予定表
- 納品書
- 請求書
- PDF
- Excel
- CSV
- 画像
- スキャン書類

Attachment:

```text
attachment
 ├─ id
 ├─ supplier_id
 ├─ warehouse_id
 ├─ file_name
 ├─ mime_type
 ├─ storage_path
 ├─ hash
 ├─ uploaded_by
 ├─ created_at
 └─ document_type
```

---

# 11. 請求書をそのまま「入荷」とみなさない

これは非常に重要。

請求書には、

```text
商品名
数量
単価
金額
請求日
```

が書かれていても、

**実際にその数量の商品が倉庫に到着したとは限らない。**

そのため、

```text
請求書
```

と

```text
入荷実績
```

を同一視しない。

AIが請求書から100個と判断しても、

```text
AI:
商品A 100個
```

↓

```text
WMS:
入荷予定候補 100個
```

までにする。

実際に到着して検品された数量だけが、

```text
Actual Receipt
```

となる。

---

# 12. AI処理フロー

推奨:

```text
ファイルアップロード
        ↓
Document Type判定
        ↓
OCR
        ↓
Structured Extraction
        ↓
Supplier特定
        ↓
Product照合
        ↓
数量・単位・日付抽出
        ↓
既存Inboundとの照合
        ↓
AI候補生成
        ↓
Human Review
        ↓
Expected Receipt作成/更新
```

AIが直接在庫数量を書き換えてはいけない。

---

# 13. AI抽出データ

AIの出力例:

```json
{
  "supplier": "ABC商事",
  "document_type": "delivery_schedule",
  "document_number": "ABC-20261001",
  "document_date": "2026-10-01",
  "expected_arrival_date": "2026-10-10",
  "warehouse": "神戸倉庫",
  "lines": [
    {
      "supplier_product_name": "商品A",
      "supplier_code": "A-001",
      "quantity": 100,
      "unit": "個"
    }
  ]
}
```

AI結果は必ず、

```text
AI Analysis
      ↓
Human Review
      ↓
Confirmed WMS Data
```

とする。

---

# 14. 商品照合

仕入先ファイルの商品名とWMSの商品名が完全一致するとは限らない。

例:

```text
ファイル:
「ABC ボルト M8 100本」

Product Master:
SKU: BOLT-M8
商品名: M8ボルト
JAN: 4901234567890
```

AIは候補を提示する。

```text
AI候補

M8ボルト
SKU: BOLT-M8
一致度: 97%

[この商品で確定]
[別の商品を選択]
```

低信頼の場合は自動確定しない。

---

# 15. AIの信頼度

最低限:

```text
HIGH
MEDIUM
LOW
```

または数値:

```text
confidence: 0.97
```

を保存する。

推奨:

```text
>= 0.95
```

でも重要な数量変更はHuman Reviewを通す。

AIが高信頼でも、在庫を直接変更しない。

---

# 16. 入荷予定画面

PC:

```text
入荷予定

[検索] [仕入先] [倉庫] [予定日] [状態]

RCV-00125
ABC商事
予定 160
入荷済 60
残 100
予定日 10/10
状態 一部入荷

RCV-00126
XYZ商事
予定 50
入荷済 0
残 50
予定日 未定
状態 入荷待ち
```

「予定日未定」を正式に許可する。

仕入先から日付をもらっていない場合、

```text
expected_arrival_date = NULL
```

とする。

勝手に今日や明日を設定しない。

---

# 17. 入荷予定の詳細画面

```text
ABC商事

入荷予定番号
RCV-00125

仕入先
ABC商事

倉庫
神戸倉庫

予定入荷日
2026/10/10

予定検品日
2026/10/10

────────────────

商品A
予定 100
入荷済 60
残 40

商品B
予定 50
入荷済 50
残 0

────────────────

添付ファイル
注文確認書.pdf
請求書.pdf

AI解析
✓ 完了
確認済み
```

---

# 18. Actual Receipt画面

実際に商品が到着したら、

```text
入荷受付

RCV-00125

今回の入荷

商品A
予定残 40
今回入荷 [40]

商品B
予定残 0
今回入荷 [0]

[入荷確定]
```

分納の場合:

```text
第1回入荷
2026/10/10
商品A 60
商品B 50
```

次回:

```text
第2回入荷
2026/10/15
商品A 40
商品C 30
```

として別Receiptを作る。

---

# 19. 検品はActual Receipt単位で行う

これは重要。

Expected Receipt単位ではなく、

```text
Actual Receipt
      ↓
Inspection
```

とする。

例:

```text
Receipt #1
10/10
商品A 60
商品B 50
      ↓
Inspection #1
      ↓
PASS
```

```text
Receipt #2
10/15
商品A 40
商品C 30
      ↓
Inspection #2
      ↓
PASS / PARTIAL / FAIL
```

こうすることで分納でも日付・数量・検品履歴が壊れない。

---

# 20. 検品予定日と実績日

Inspectionには最低限:

```text
scheduled_inspection_date
inspection_started_at
inspection_completed_at
```

を持つ。

通常の初期値:

```text
scheduled_inspection_date
=
actual_received_date
```

とする。

ただし、倉庫都合で翌日検品することも可能。

例:

```text
実際入荷日       10/10
検品予定日       10/11
実際検品開始     10/11 09:00
実際検品完了     10/11 10:30
```

---

# 21. 在庫更新タイミング

AI解析時には在庫を増やさない。

Expected Receipt作成時にも在庫を増やさない。

Actual Receiptでも、検品前の商品を通常のAvailable Stockに入れない。

推奨:

```text
AI解析
 ↓
Expected Receipt
 ↓
Actual Receipt
 ↓
Inspection
 ↓
PASS
 ↓
Stock Movement: RECEIVE
 ↓
Staging / Put-away
 ↓
Available Stock
```

不合格:

```text
Inspection FAIL
 ↓
QC_HOLD
```

---

# 22. 在庫Ledger

AI:

```text
+0
```

Expected Receipt:

```text
+0
```

Actual Receipt:

```text
+0 または受入中数量として別管理
```

Inspection PASS:

```text
RECEIVE +60
```

Inspection FAIL:

```text
QC_HOLD 60
```

Put-away:

```text
PUT_AWAY
```

最終的なAvailable Stockは、確定したStock Movementから算出する。

---

# 23. 仕入先ファイルと既存入荷の重複防止

同じPDFを2回アップロードしても二重登録しない。

Attachmentに:

```text
file_hash
```

を保存する。

さらにAI解析結果に:

```text
source_attachment_id
document_number
supplier_id
```

を保存する。

同じファイル・同じ書類番号を検出した場合:

```text
⚠ この書類は既に登録されています。

既存:
RCV-00125

[既存データを開く]
[別書類として登録]
```

---

# 24. 仕入先ファイルから既存入荷を更新する

例えば最初に、

```text
注文確認書
商品A 100
予定日 未定
```

を登録。

後日、

```text
納品予定表
商品A 100
予定日 10/10
```

が来た場合は、新規入荷を作るのではなく、

```text
既存 Expected Receipt
      ↓
expected_arrival_date を更新
```

する。

さらに、

```text
納品書
商品A 60
```

が来た場合は、

```text
Actual Receipt候補
商品A 60
```

を作成し、人間確認後に確定する。

---

# 25. 「予定日」は変更履歴を残す

例えば:

```text
10/01
予定日 未定

10/05
予定日 10/10

10/09
予定日 10/12

10/12
実際入荷
```

この履歴をAudit Logに残す。

UI:

```text
入荷予定履歴

10/01  予定日: 未定
10/05  予定日: 10/10
10/09  予定日: 10/12
10/12  実際入荷
```

---

# 26. ファイルからのAI更新画面

新しい専用画面を追加する。

```text
仕入先ファイル取込

[ ファイルをアップロード ]

対応:
PDF / Excel / CSV / JPG / PNG

────────────────

解析中...

仕入先
ABC商事 ✓

書類
納品予定表 ✓

商品
3件

数量
180

予定日
2026/10/10

────────────────

AI判定

商品A → M8ボルト       98%
商品B → ナットM8       96%
商品C → ワッシャー      71%

⚠ 商品Cは確認が必要

[確認して入荷予定を作成]
```

---

# 27. AI Review画面

AIが既存商品と照合した結果を人間が確認する。

```text
┌──────────────────────────────┐
│ AI解析結果                   │
├──────────────────────────────┤
│ 商品A                       │
│ AI: M8ボルト                │
│ SKU: BOLT-M8                │
│ 信頼度: 98%                 │
│ [✓ 確定] [変更]             │
├──────────────────────────────┤
│ 商品C                       │
│ AI: ワッシャー              │
│ 信頼度: 71%                 │
│ ⚠ 要確認                    │
│ [商品を選択]                 │
└──────────────────────────────┘
```

---

# 28. Mobileは「入荷予定作成」より「現物確認」を優先

仕入先ファイルの取込・AI ReviewはPC/Web中心。

Mobileは、

```text
今日の入荷

[入荷受付 3]
[検品待ち 5]
[棚入れ待ち 7]

[バーコードスキャン]
```

を中心にする。

現場作業員が請求書PDFを細かく編集するUIにはしない。

---

# 29. 将来の「システムから発注」と互換性を持たせる

Phase 1:

```text
電話/メール注文
 ↓
仕入先ファイル
 ↓
AI
 ↓
Expected Receipt
```

将来:

```text
WMSから発注
 ↓
Purchase Order
 ↓
仕入先確認
 ↓
Expected Receipt
 ↓
Actual Receipt
 ↓
Inspection
```

どちらも最終的には、

```text
Expected Receipt
      ↓
Actual Receipt
      ↓
Inspection
      ↓
Stock
```

に合流させる。

したがって、Phase 1のためにPurchase Orderを削除したり、特殊な一時テーブルだけで構築したりしない。

---

# 30. 推奨データ構造

概念的には以下を推奨する。

```text
Supplier
   │
   └── Inbound Document
           │
           ├── Attachment
           │
           ├── AI Analysis
           │
           └── Expected Receipt
                   │
                   ├── Expected Receipt Lines
                   │
                   ├── Actual Receipt #1
                   │      └── Inspection #1
                   │
                   ├── Actual Receipt #2
                   │      └── Inspection #2
                   │
                   └── Actual Receipt #N
                          └── Inspection #N
```

将来的には、

```text
Purchase Order
       │
       └── Expected Receipt
```

を追加する。

---

# 31. 状態遷移

## Expected Receipt

```text
DRAFT
 ↓
EXPECTED
 ↓
PARTIALLY_RECEIVED
 ↓
RECEIVED
 ↓
CLOSED
```

例外:

```text
CANCELLED
OVER_RECEIVED
ON_HOLD
```

## Actual Receipt

```text
CREATED
 ↓
RECEIVING
 ↓
RECEIVED
 ↓
INSPECTION
 ↓
COMPLETED
```

## Inspection

```text
SCHEDULED
 ↓
IN_PROGRESS
 ↓
PASS
```

または:

```text
IN_PROGRESS
 ↓
PARTIAL
 ↓
REVIEW
```

または:

```text
IN_PROGRESS
 ↓
FAIL
 ↓
QC_HOLD / RETURN
```

---

# 32. 今回の仕様変更で特に修正する既存仕様

以下を既存仕様から修正する。

### 修正1

現在:

```text
入荷予定日
```

のみで入荷・検品の日付を扱う。

↓

変更:

```text
予定入荷日
実際入荷日
予定検品日
実際検品開始日時
実際検品完了日時
```

を分離。

### 修正2

現在:

```text
PO → Receiving
```

中心。

↓

Phase 1:

```text
Supplier Document
 → AI Analysis
 → Expected Receipt
 → Actual Receipt
 → Inspection
```

を正式な入口として追加。

### 修正3

現在の単一Receivingだけではなく、

```text
Expected Receipt
  └─ Actual Receipt 1
  └─ Actual Receipt 2
  └─ Actual Receipt N
```

の1対多構造を採用。

### 修正4

AIが直接在庫を更新しない。

```text
AI
 ↓
Candidate
 ↓
Human Review
 ↓
WMS Transaction
 ↓
Stock Movement
```

とする。

### 修正5

請求書・納品書・注文確認書を区別する。

```text
document_type:
  purchase_confirmation
  delivery_schedule
  delivery_note
  invoice
  other
```

請求書だけではActual Receiptを自動確定しない。

---

# 33. 実装優先順位

## P0

1. Expected ReceiptとActual Receiptを分離
2. 分納対応
3. 予定日・実績日を分離
4. Inspectionの予定日・実績日を分離
5. Supplier File Upload
6. AI OCR / Structured Extraction
7. Human Review
8. AI結果からExpected Receiptを作成
9. Actual ReceiptからInspectionを作成
10. 検品結果からStock Movementを生成
11. 重複ファイル・重複書類防止

## P1

1. 仕入先ごとの商品照合
2. 過去の仕入先ファイルとの照合
3. 予定日の変更履歴
4. PDF/Excel/CSVの高度な解析
5. 入荷予定Dashboard
6. 分納履歴Timeline

## P2

1. WMSからPurchase Order作成
2. 発注承認
3. 仕入先へのメール送信
4. 発注書PDF
5. 発注提案
6. 在庫から自動発注候補生成

---

# 34. 最終的な業務フロー

このWMSでは、最終的に以下の2つの入口を持つ。

### 現在の入口

```text
電話/メールで注文
        ↓
仕入先からファイル
        ↓
WMSへアップロード
        ↓
AI解析
        ↓
Human Review
        ↓
Expected Receipt
        ↓
Actual Receipt
        ↓
Inspection
        ↓
PASS
        ↓
Put-away
        ↓
Inventory
```

### 将来の入口

```text
WMSで発注
        ↓
Purchase Order
        ↓
仕入先確認
        ↓
Expected Receipt
        ↓
Actual Receipt
        ↓
Inspection
        ↓
PASS
        ↓
Put-away
        ↓
Inventory
```

2つの入口は違っても、入荷以降の業務フローは共通化する。

---

# 35. 重要な設計原則

以下をClaude Code実装時の必須ルールとする。

1. AI解析だけで在庫を増やさない。
2. Expected Receiptだけで在庫を増やさない。
3. 請求書数量を実入荷数量とみなさない。
4. 予定入荷日と実際入荷日を分離する。
5. 予定検品日と実際検品日時を分離する。
6. 分納を前提にActual Receiptを複数作れるようにする。
7. 各Actual Receiptに独立したInspectionを紐付ける。
8. 検品合格数量だけを通常在庫に反映する。
9. 不合格数量はQC_HOLD等で隔離する。
10. AI結果と確定WMSデータを別管理する。
11. AIの低信頼結果はHuman Reviewへ送る。
12. 同じファイル・書類を二重登録しない。
13. 予定日の変更履歴を残す。
14. 将来Purchase Orderを追加してもExpected Receipt以降の構造を変更しない。
15. 在庫更新はStock Movement/Ledger経由で行い、画面から直接数量を書き換えない。

---

## 36. 完成形のイメージ

```text
             仕入先
               │
       電話 / メール注文
               │
               ▼
       ┌──────────────┐
       │ Supplier File │
       │ PDF/Excel/画像 │
       └──────┬───────┘
              ▼
         AI / OCR
              │
              ▼
       Human Review
              │
              ▼
      Expected Receipt
       予定数量・予定日
              │
       ┌──────┼──────┐
       ▼      ▼      ▼
   Receipt1 Receipt2 Receipt3
       │      │      │
       ▼      ▼      ▼
  Inspection Inspection Inspection
       │      │      │
       ▼      ▼      ▼
     PASS   PARTIAL   FAIL
       │      │        │
       ▼      ▼        ▼
   Stock    Review   QC Hold
       │
       ▼
    Put-away
       │
       ▼
   Available Stock
```

この構造を今回のWMSの「仕入・入荷」の基本モデルとする。


---

# 37. Product Masterを商品ライブラリーの上位基盤として追加

## 基本原則

**1商品 = 1つの自社Product ID** とする。

仕入先ごとの名称・コードはProduct IDに紐付く別データとして管理する。

例:

```text
Product ID: PRD-000001
自社標準名: Hex Bolt M8 x 50 mm

ABC商事: 「M8 六角ボルト 50本」
XYZ株式会社: 「六角ボルト M8×50」
DEF工業: 「HEX BOLT M8」
```

同一商品を仕入先ごとに別Productとして登録しない。

---

# 38. ナビゲーション

```text
商品ライブラリー
    ├─ 商品一覧
    ├─ 商品マスタ
    ├─ 仕入先商品名
    ├─ 商品カテゴリ
    └─ 商品属性
```

「商品マスタ」は「商品ライブラリー」の下にタブ/サブメニューとして配置する。

Product Masterは正規データ、商品ライブラリーはそのデータを閲覧・操作するUIとする。

---

# 39. Product Master

Product Masterは「商品そのもの」を表す。

最低限:

```text
Product ID
自社標準名
英語標準名
SKU
JAN / Barcode
Brand
Model Number
Category
Unit
Specifications
Status
```

仕入先の商品名はProduct Master本体に固定カラムで増やさず、Supplier Product Mappingで管理する。

---

# 40. Supplier Product Mapping

以下の固定カラム方式は禁止する。

```text
supplier_a_name
supplier_b_name
supplier_c_name
```

仕入先は増えるため、独立テーブルを使用する。

```text
product_supplier_mapping

id
product_id
supplier_id
supplier_product_name
supplier_product_code
supplier_model_number
supplier_barcode
supplier_unit
last_seen_at
is_active
```

1商品に何社でも仕入先を紐付けられるようにする。

---

# 41. 自社名をメイン、仕入先名をサブ表示

商品ライブラリーでは自社標準名をメイン表示する。

```text
Hex Bolt M8 x 50 mm
SKU: BOLT-M8-50

仕入先:
ABC商事「M8 六角ボルト 50本」
XYZ株式会社「六角ボルト M8×50」
```

仕入先の原文はサブ表示し、検索対象にも含める。

---

# 42. 未登録商品の初回ファイル取込

仕入先ファイルをAI/OCRで解析した後、Product Masterと照合する。

```text
仕入先ファイル
 ↓
AI/OCR
 ↓
Supplier特定
 ↓
Product Master照合
```

既存商品に一致すれば既存Product IDへ紐付ける。

一致しなければ `NEW PRODUCT CANDIDATE` とする。

未登録商品をいきなり商品ライブラリーへ確定登録しない。

---

# 43. AIによる自社商品名提案

未登録商品の場合、AIが自社標準商品名を英語で提案する。

例:

```text
仕入先: ABC商事

仕入先商品名:
ステンレス 六角ボルト M8×50 50本入

AI提案:
Stainless Steel Hex Bolt M8 x 50 mm
```

提案ルール:

- 原則英語
- 商品種別を明確にする
- サイズ・型番等の重要属性を含める
- 仕入先名を含めない
- 仕入先独自のマーケティング表現をそのまま採用しない
- 簡潔で再利用可能な名称にする

AIは自動確定せず、

```text
AI提案
 ↓
Human Review
 ↓
Product Master登録
```

とする。

仕入先の日本語名は原文のままSupplier Product Nameとして保存する。

---

# 44. Product Matching優先順位

既存商品との照合は以下を基本とする。

1. Supplier Product Code
2. JAN / Barcode
3. Manufacturer Part Number
4. Model Number
5. Brand + Model
6. Supplier Product Name Mapping
7. Product Attributes
8. AI Semantic Matching

識別子が一致する場合は商品名の類似度より識別子を優先する。

低信頼の場合:

```text
⚠ 商品照合が必要

候補1
Hex Bolt M8 x 50 mm  68%

候補2
Hex Bolt M8 x 40 mm  61%

[商品を選択]
[新商品を作成]
```

---

# 45. Supplier Product Mappingによる複数仕入先対応

例えば:

```text
PRD-000123
Stainless Steel Hex Bolt M8 x 50 mm

ABC商事
「ステンレス 六角ボルト M8×50 50本」
コード: AB-001

XYZ株式会社
「SUS M8ボルト 50mm」
コード: XYZ-8812
```

すべて同じProduct IDを参照する。

1商品:N仕入先、1仕入先:N商品に対応する。

---

# 46. 商品詳細UI

```text
Hex Bolt M8 x 50 mm
Product ID: PRD-000001
SKU: BOLT-M8-50

基本情報
自社商品名
英語標準名
カテゴリ
単位
JAN
型番

仕入先
ABC商事
  「M8 六角ボルト 50本」
  仕入先コード: AB-M8-50

XYZ株式会社
  「六角ボルト M8×50」
  仕入先コード: XYZ-8812

AI認識用別名
M8 bolt
Hex bolt M8
M8 六角ボルト
```

---

# 47. Product Master確定後の自動連携

ユーザーが新商品を確定すると、同時に:

```text
Product Master
 ↓
Product ID発行
 ↓
Supplier Product Mapping作成
 ↓
AI解析結果をProduct IDへ紐付け
 ↓
Expected Receipt LineをProduct IDへ更新
 ↓
数量・予定日を確定
 ↓
Receivingへ連携
```

AI解析結果に商品名文字列だけを残し続けず、確定後は必ず `product_id` へ解決する。

---

# 48. 初回ファイルから入荷予定まで自動連携

例えば:

```text
ABC商事
「ステンレス 六角ボルト M8×50 50本」
数量: 100
納品予定: 10/10
```

AIが未登録と判断し、

```text
Stainless Steel Hex Bolt M8 x 50 mm
```

を提案。

ユーザーが採用すると:

```text
Product ID: PRD-000123

Supplier Mapping:
ABC商事
「ステンレス 六角ボルト M8×50 50本」
```

を作成し、そのまま:

```text
Expected Receipt
Product: PRD-000123
Quantity: 100
Expected Arrival: 10/10
```

まで自動生成する。

---

# 49. 2回目以降は自動認識

次回同じ仕入先から同じ商品名が来た場合:

```text
Supplier Mapping
 ↓
PRD-000123
 ↓
Expected Receipt
```

とし、人間が毎回商品を選択しない。

別の仕入先が別名で送ってきた場合も、初回だけ人間が同一商品として確認すれば、その仕入先のMappingを追加する。

---

# 50. 商品検索

商品ライブラリー検索では以下を検索対象にする。

```text
Internal Product Name
SKU
JAN
Barcode
Supplier Product Name
Supplier Product Code
Manufacturer Part Number
AI Aliases
```

そのため、仕入先の日本語名を検索しても自社商品を見つけられる。

---

# 51. Product Masterと商品ライブラリーの役割

## Product Master

「この商品は何なのか」を確定する正規データ。

## 商品ライブラリー

日常的に商品を検索・閲覧・編集するUI。

商品ライブラリーには以下を統合表示する。

```text
Product Master
Supplier Mapping
Stock
Purchase History
Receiving History
Inspection History
Images
Documents
AI認識履歴
```

---

# 52. 商品詳細から履歴まで確認

Product Detailから:

```text
基本情報
仕入先
在庫
価格
発注履歴
入荷履歴
検品履歴
添付書類
AI認識履歴
```

を確認できるようにする。

仕入先ごとの過去価格や入荷履歴もProduct ID単位で追跡する。

---

# 53. Product Masterを中心とした最終フロー

```text
仕入先
 ↓
仕入先ファイル
 ↓
AI/OCR
 ↓
Supplier Product
 ↓
Product Master Matching
 ├─ 既存商品 → Product IDへ紐付け
 └─ 未登録 → AI英語名提案 → Human Review → Product Master登録
 ↓
Supplier Product Mapping
 ↓
Expected Receipt
 ↓
Actual Receipt
 ↓
Inspection
 ↓
Stock Movement
 ↓
Inventory
```

---

# 54. 必須ルール

1. 1商品に対して1つのProduct IDを持つ。
2. 仕入先ごとの商品名・コードはProduct IDとは別に管理する。
3. 仕入先名を自社Product Nameに入れない。
4. 仕入先商品名は原文のまま保存する。
5. 自社標準商品名は原則英語で統一する。
6. AIは未登録商品の自社英語名を提案できる。
7. AIは新商品を勝手に確定しない。
8. 同一商品候補が存在する場合は既存Product IDへの紐付けを優先候補とする。
9. Supplier Product Mappingは1商品:N仕入先に対応する。
10. 1仕入先から複数の別名・商品コードが来る場合にも対応する。
11. Product IDが確定したらExpected Receiptへ自動連携する。
12. Expected ReceiptからActual Receipt、Inspection、Stock MovementまでProduct IDを維持する。
13. AI解析結果と確定WMSデータを別管理する。
14. 同一商品・同一仕入先の次回ファイル取込では既存Mappingを利用して自動照合する。
15. Product Masterは将来のWMS発注機能でも唯一の商品基準として使用する。

---

# 55. 将来のWMS発注機能との統合

将来的には:

```text
仕入先を選択
 ↓
Product Masterから商品選択
 ↓
数量入力
 ↓
Purchase Order
 ↓
Expected Receipt
```

とする。

仕入先ファイル起点のフローとWMS発注起点のフローは、どちらも最終的にExpected Receiptへ合流する。

```text
仕入先ファイル → AI → Product Master → Expected Receipt
WMS発注        → Purchase Order → Expected Receipt
```

これにより、商品データ・仕入先別名称・入荷・検品・在庫が二重管理されない。
