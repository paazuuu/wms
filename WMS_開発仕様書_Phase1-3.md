# 倉庫管理システム（WMS）開発仕様書

## 概要
Flutter + Supabase によるクロスプラットフォーム対応WMS。

### 技術構成
- Flutter
- Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
- Supabase Storage に画像・PDF・動画保存
- バーコード: Code128 / Code39 / JAN(EAN13) / QR

## データベース
- Users
- Companies
- Warehouses
- Locations
- Products
- ProductImages
- Inventory
- Lots
- StockHistory
- PurchaseOrders
- SalesOrders
- Picking
- PickingDetails
- Shipping
- ShippingDetails
- Inspection
- InspectionPhotos
- Labels
- BarcodeHistory
- AuditLogs
- Notifications
- Settings

## Phase1（MVP）
### 商品管理
- 商品マスター
- カテゴリ
- JAN・商品コード
- メーカー
- 価格
- 商品画像複数登録
- PDF・動画添付

### 在庫管理
- ロケーション
- 在庫数量
- ロット
- 有効期限
- 在庫履歴

### バーコード
- 自動発番
- バーコード生成
- QR生成

### ラベル印刷
- 40x30
- 50x30
- 60x40
- A4
- Zebra/SATO/Brother/TSC対応

### 入出庫
- 入庫登録
- 出庫登録
- 写真保存
- ロケーション登録

### 検品
- バーコード照合
- 数量照合
- ロット照合
- 写真添付
- コメント
- NG履歴

### 画像管理
- 商品画像
- 入荷写真
- 出荷写真
- 検品写真
- PDF
- MP4

## Phase2
### 発注
- 発注書
- 入荷予定
- 発注履歴

### 仕入
- 仕入先
- 仕入価格
- 納品書管理

### 受注
- 受注管理
- 出荷指示

### ピッキング
- ピッキングリスト
- ハンディ対応
- 完了管理

### 棚卸
- バーコード棚卸
- 差異管理
- 承認

### 帳票
- 納品書
- 請求書
- ピッキングリスト
- 棚卸表
- CSV/PDF

## Phase3
### RFID
- RFIDタグ
- 一括読取

### AI画像認識
- 破損検知
- ラベル認識
- 商品認識

### OCR
- 納品書
- 請求書
- 送り状

### BI
- 在庫分析
- ABC分析
- 回転率
- ダッシュボード

### 他システム連携
- ヤマト
- 佐川
- 日本郵便
- freee
- マネーフォワード
- 弥生
- Shopify
- 楽天
- Amazon

## 将来設計
マルチテナント対応、権限管理、API公開、監査ログ、リアルタイム更新、バックアップ。
