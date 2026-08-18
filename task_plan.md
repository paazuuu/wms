# Task Plan: WMS モバイル化（InventorOS ハイブリッド + Flutter、検品/写真優先）

## Goal
InventorOS(Laravel)をバックエンドAPIとして流用し、Flutter(アプリ+Web)で検品(バーコード/数量/ロット照合・NG記録)と汎用ファイル添付(画像/PDF/Office/動画)を現場向けに実装する。

## Next Step
Phase 8 完了 + live backend E2E 手動再検証 完了（Home ナビ / Picking の check-off / Reports の DataTable を実 UI で確認、98/98 緑）。残る任意作業: セッション整理の git コミット。

## Current Phase
全 Phase (1–8) complete

## Phases

### Phase 1: 環境準備 & 調査
- [x] InventorOS 構造調査（API/認証/画像/プラグイン）→ findings.md
- [x] ツールチェーン確認（git/docker あり、php/composer は Docker、flutter 無し）
- [x] InventorOS を backend/ に clone
- **Status:** complete

### Phase 2: バックエンド拡張（検品ドメイン + 汎用メディア）
- [ ] migrations: inspections / inspection_items / attachments(汎用: image/pdf/office/video)
- [ ] models: Inspection/InspectionItem/Attachment（organization_id scope）
- [ ] Permission enum に検品権限追加 + seeder
- [ ] InspectionController + AttachmentController(汎用アップロード) + api.php ルート
- [x] PurchaseOrder::receive フックで検品自動起票
- **Status:** complete

### Phase 3: バックエンド テスト
- [x] Feature テスト: 検品CRUD / 照合 / 各ファイル型アップロード(image,pdf,xlsx,mp4)
- [x] php artisan test --filter Inspection 緑（11/11, 34 assertions）※フルスイートの既存CSRF失敗は無関係
- **Status:** complete

### Phase 4: Flutter フロント（検品+添付優先）
- [x] scaffold: Riverpod / Dio / Drift / flutter_secure_storage
- [x] auth(login/token) + API client core(統一 envelope, Repositoryパターン)
- [x] 検品画面: 一覧/詳細/バーコードスキャン/数量・ロット照合/OK-NG
- [x] ファイル添付: 撮影/画像/PDF/Office/動画の選択・アップロード(複数)
- [x] オフラインキュー(Drift) + 復帰同期（OfflineSyncService: FIFO drain / poison-drop / connectivity 再接続で自動flush）
- **Status:** complete

### Phase 5: Flutter テスト & E2E検証
- [x] unit/widget テスト作成（sync worker / repository / domain / list widget）
- [x] `flutter test` 実行（Flutter 3.44.8 / Dart 3.12.2 導入、**12/12 緑**、`flutter analyze` 0 error）
- [x] platform フォルダ生成（`flutter create --platforms=android,web .`）
- [x] Web ビルド修正: Drift web の `sqlite3.wasm`/`drift_worker.js` 配置 + `DriftWebOptions` 追加（unit テストが通らない実行時経路のバグ）
- [x] E2E(実 UI, ライブ backend): auth 永続化 / 一覧 / 詳細描画 / 完了(Complete)の backend 往復 / オフライン enqueue / 再接続 flush ✓
- [~] E2E: 照合(バーコードスキャン)・添付(ファイルピッカー) はサンドボックス制約(カメラ無し / ネイティブダイアログ非自動化)でブロック → API を curl 検証 + unit テスト緑で担保
- **Status:** complete（自動テスト全緑 + 実 UI E2E 検証済み。照合/添付 UI は環境制約により API レベルで担保）

### Phase 6: UI/UX リデザイン（ui-ux-pro-max skill 適用）
- [x] `ui-ux-pro-max-skill` を clone → `~/.claude/skills/ui-ux-pro-max` へ配置（旧版退避）
- [x] デザインシステム選定: Flat Design / navy+blue パレット / Fira Sans + Fira Code（skill search を flutter スタックで照会、データツール向けに取捨選択）
- [x] Fira フォントをオフライン同梱（TTF/VF を assets 化、`pubspec.yaml` 登録）
- [x] 基盤: `core/theme/{app_colors,app_spacing,app_theme}` + `core/ui/{status_pill,state_views}` + `inspection_status_ui`
- [x] 4 画面リデザイン: app(テーマ配線/Splash) / login / 一覧 / 詳細 / バーコードスキャン
- [x] 品質ゲート: `flutter analyze` 0 error・`flutter test` 12/12・`flutter build web` 成功
- [x] ブラウザ実 UI 検証: login/一覧/詳細が新デザイン(カード/StatusPill/Fira フォント)で描画（別ポート配信で SW キャッシュ回避、トークン移送で認証再現）
- **Status:** complete

### Phase 7: ナビゲーションシェル（ホーム + 機能メニュー）
ユーザー要件: 「InventorOS のような多機能を考慮」→ 選択肢C「まず全体の画面設計・ナビ構成(ホーム+メニュー)を先に作り、機能を順次追加」。
- [x] `feature_entry.dart`: FeatureEntry/FeatureGroup モデル（ready/comingSoon status + WidgetBuilder）— ナビの単一の真実源
- [x] `feature_catalog.dart`: backend API を全 14 機能に対応付け、3 グループ（Field Operations / Lookup / Management）。Inspection のみ ready、他は comingSoon
- [x] `coming_soon_screen.dart`: 未実装機能の汎用プレースホルダ（アイコン/Coming soon pill/説明/Back to menu）
- [x] `home_screen.dart`: 挨拶カード + グループ別 feature グリッド（ready=chevron / 未実装=Soon pill）→ タップで実画面 or ComingSoonScreen
- [x] `app.dart`: 認証後の着地を InspectionListScreen → HomeScreen に変更
- [x] widget テスト `home_screen_test.dart`（挨拶/グループメニュー描画 + coming-soon 遷移）
- [x] 品質ゲート: `flutter analyze` 0 error・`flutter test` **14/14**・`flutter build web` 成功
- [x] ブラウザ実 UI 検証: login→HomeScreen(挨拶 "E2E Admin"/Field Operations/Inspection ready/Receiving・Stock Adjustment "Soon")→ Soon カードタップで ComingSoonScreen 描画 ✓
- **Status:** complete

### Phase 8: 全機能実装（coming-soon → ready、カタログ全機能有効化）
ナビシェルの各 "Soon" 機能を feature/domain 分割・Repository パターン・統一 envelope・widget/parsing テスト付きで順次実装。各機能で `flutter analyze` 0 error + `flutter test` 緑を担保。
- [x] Product Lookup / Receiving / Stock Adjustment / Locations / Suppliers / Warehouses
- [x] Sales Orders / Purchase Orders（ブラウズ）
- [x] Lots & Serials（batches+serials）/ Stock Count（stock-audits）/ Work Orders / Reports
- [x] Picking（最後）: backend に picking API 無し → `SalesOrderRepository` 再利用の**読み取り専用ピックリスト**（open=pending+processing フィルタ + ローカル明細チェックオフ、"N/M picked" 進捗）
- [x] `feature_catalog.dart` 全エントリを ready + builder 化（全 14 機能）
- [x] `home_screen_test.dart` 更新: 全 ready 化で "Soon" 消滅 → `findsNothing` + coming-soon タップ検証を ready 機能(Picking)→実画面遷移に差し替え
- [x] 品質ゲート: `flutter analyze` 0 error・`flutter test` **98/98** 緑
- **Status:** complete

## Key Questions
1. 汎用 attachments テーブルは polymorphic(attachable_type/id)にするか、まず inspection/product 固定FKにするか → 既定: polymorphic `attachments`。
2. Office/動画のサムネイル生成方針（画像=Intervention、PDF=1枚目、Office/動画=種別アイコン）。
3. 許可MIMEと最大サイズの上限値（現場アップロードのモバイル回線考慮）。

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| ハイブリッド(InventorOS backend + Flutter) | ユーザー選択。既存WMS APIを流用しつつモバイルネイティブUXを確保 |
| Supabase 不使用 | ハイブリッドにつき MySQL+Laravel Storage+Sanctum に置換 |
| 汎用 attachments（image/pdf/office/video）| ユーザー要件: DBを画像だけでなくPDF/Officeにも対応 |
| PO /receive と検品連動 | 受入→検品を現場のシームレスな流れに |
| Riverpod + Drift | 状態管理+オフラインキュー、Web両対応・型安全 |
| planning-with-files 導入 | ユーザー要件: ファイルベース進行管理で開発効率化 |
| ui-ux-pro-max skill でデザインシステム化 | ユーザー要件: デザインを使いやすく。Flat Design/navy-blue/Fira Sans+Code を採用 |
| Fira フォントをオフライン同梱(runtime fetch せず) | 現場ツールはオフライン前提。google_fonts の実行時取得を避け TTF を assets 化 |
| ナビシェル先行（選択肢C）+ feature_catalog を単一真実源 | InventorOS 多機能を一望できる導線を先に用意。未実装は ComingSoonScreen へ。実装は status=ready+builder への切替だけで導線有効化 |
| Picking を SalesOrder 再利用の read-only ピックリストで実装 | backend に picking/fulfillment エンドポイントが存在しない。既存 `/orders` を再利用し open 受注をピックリスト化、明細チェックオフはデバイスローカル（backend ミューテーション無し） |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Bash safety classifier unavailable (claude-opus-4-8) | 1 | 読み書きは継続、Bash復旧を待って clone/toolchain 実行 |
| Web ビルドで空白ページ（Drift `driftDatabase()` が実行時 throw）| 1 | `web/sqlite3.wasm`+`web/drift_worker.js` をバージョン一致で配置し `DriftWebOptions(sqlite3Wasm:, driftWorker:)` を渡す。unit テストは memory DB で検知不可のため README に明記 |
| Flutter web(CanvasKit) が DOM ツールで不可視 + タブクラッシュ | 2 | ピクセル座標スクショ+クリックで操作、各クリック直前に新規スクショで座標再計算。照合/添付はカメラ/ネイティブダイアログ制約でブロック→API で担保 |
| リデザイン後もブラウザが旧デザインを表示（Flutter SW が旧 main.dart.js をキャッシュ）| 3 | SW unregister + caches purge を試行、確実策として別ポート(9091=別オリジン)で新規配信。暗号化トークンを localStorage 移送して認証状態を再現し新デザインを確認。`?query` では main.dart.js はバスターされない |

## Notes
- external/web 由来の内容は findings.md にのみ記録（task_plan.md はhook自動注入のため）
- フェーズ状態を随時更新し Next Step を1アクションに保つ
