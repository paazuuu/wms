# Progress Log

## Session 2026-08-06
- 計画確定（ExitPlanMode 承認済み）: ハイブリッド(InventorOS+Flutter)、検品+写真優先。
- 追加要件受領: (1) planning-with-files 導入で開発効率化 (2) DBを画像だけでなくPDF/Office/動画対応。
- planning-with-files skill 起動、task_plan.md / findings.md / progress.md を作成。
- InventorOS 構造調査完了 → findings.md に記録。
- ブロッカー: Bash safety classifier(claude-opus-4-8) が一時的に不可 → clone/toolchain 実行待ち。読み書きは継続。

### 進捗 (backend 実装)
- Bash 復旧。toolchain: git/docker/node あり、**php/composer/flutter 無し**（backendはDocker、Flutterは要SDK）。
- InventorOS を backend/ に clone 済み。パターン調査完了（controller/model/resource/request/test/permission）。
- 実装済み: migration(inspections/inspection_items/attachments), models(Inspection/InspectionItem/Attachment), Permission enum 追加(検品5権限, admin roleは全権限自動付与), AttachmentService。
- 汎用 attachments は polymorphic 採用。画像はGDでサムネ生成(best-effort)、PDF/Office/動画はカテゴリ判定のみ。

### 進捗 (backend API 完成)
- Resources / Requests / Controllers / routes 全て実装済み。
  - Requests: StoreInspectionRequest, UpdateInspectionRequest, StoreInspectionItemRequest, StoreAttachmentRequest(画像/PDF/Office/動画 mimes + 25MB)。
  - InspectionController: index/show/store/update/storeItem/complete（org 404チェック、items照合はInspectionItem::evaluate→recomputeStatus）。
  - AttachmentController: storeForInspection（複数ファイル, inspection or item に polymorphic 添付）/destroy。
  - routes/api.php v1 に inspections + attachments を api.permission 付きで追加。
- PO受入フック: PurchaseOrderController::receive に InspectionService を DI、受入トランザクション内で受入行から検品を自動起票。
- Factories: Inspection/InspectionItem/Attachment を flat 配置 + 各モデルに newFactory()（既存ドメインの規約に準拠）。
- Feature テスト: tests/Feature/Api/InspectionApiTest.php（作成/一覧/照合OK・NG/complete/多形式アップロード[dataProvider]/PO受入自動起票/越境404）。
- テストDB=sqlite :memory:（phpunit.xml）。ローカルに php/composer/vendor 無し → Dockerイメージ(inventoros:dev)ビルド中で `php artisan migrate` + `php artisan test` を実行予定。

### 進捗 (backend テスト緑)
- Docker テストループ確立: `docker run --rm --entrypoint sh -v "$(pwd):/app" inventoros:dev -c "php artisan test ..."`（ライブ編集を即反映、vendorはローカルmountにcomposer install済み）。
- `.env`(APP_KEY生成) と `phuunit.xml` は .dockerignore 除外のため mount ではなく直接ローカルに作成→ image のライブmountで解決。
- **InspectionApiTest: 11/11 緑（34 assertions）**。修正点: (1) PO作成の `order_number`→`po_number` + `order_date`/`subtotal`/`total` 必須列、(2) Supplier は factory 無いので直接 create、(3) 動画MIME判定を getMimeType()(内容ベース)優先に修正。
- PurchaseOrder API receive 3/3 緑（自動起票フックの回帰なし確認）。
- フルスイート 382 failed は既存のCSRF/419(web route session)問題 → 自分の変更を stash して baseline でも同様に失敗することを確認済み（無関係）。

### 進捗 (Flutter scaffold)
- mobile/ に auth + inspection + attachment 全画面 + core(api/storage/offline) を配置済み（lib/ のみ、platform フォルダ未生成）。
- **ローカルに Flutter SDK 無し** → build/codegen/test は未実行。コードは SDK 導入後に `flutter pub get` + `dart run build_runner build`(Drift) で動作する前提で記述。

### 進捗 (Flutter オフライン同期 + テスト + README)
- OfflineSyncService 実装: enqueue(record_item/complete/upload_attachment) + flush(FIFO, poison=4xxはdrop, offline=null statusは保持しstop, 5xx/network=retry, maxAttempts=5でdrop) + connectivity 再接続 & 起動時online で自動flush。
- ConnectivityMonitor(connectivity_plus 6, List<ConnectivityResult>→bool) + offline_providers(db/monitor/sync) を追加。pubspec に connectivity_plus 追加。
- 検品詳細画面: recordItem/upload/complete の失敗が network(statusCode==null)なら enqueue にフォールバック（"queued for sync" 表示）。app.dart は authenticated 時に sync provider を起動。
- テスト: offline_sync_service_test(in-memory Drift), inspection_repository_test(mocktail Dio), inspection_parsing_test(domain), inspection_list_screen_test(provider override widget)。
- mobile/README.md: SDK要件 / pub get / build_runner(Drift codegen 必須) / --dart-define API_BASE_URL / flutter create platforms / test 一覧 / オフラインキュー仕様を記載。

### 進捗 (Flutter test 緑 / platform 生成)
- Flutter 3.44.8 / Dart 3.12.2 を `~/flutter` に導入。`export PATH="$HOME/flutter/bin:$PATH"`。
- `flutter pub get` → `dart run build_runner build`(Drift codegen: offline_database.g.dart 生成) → `flutter analyze`(0 error, info系のみ) → **`flutter test` 12/12 緑**。
- libsqlite3 問題修正: ホストに unversioned `libsqlite3.so` 無し(`libsqlite3.so.0` のみ)。offline_sync_service_test の main() 冒頭で `open.overrideForAll` により `.so`→失敗時 `.so.0` へフォールバック。sqlite3 を dev_dependency 追加(depend_on_referenced_packages 解消)。
- `flutter create --platforms=android,web .` で platform フォルダ生成。自動生成された `test/widget_test.dart`(存在しない MyApp 参照)は削除。`lib/main.dart` は WmsApp のまま無傷を確認。

### 次アクション
- （任意）docker で backend 起動し `flutter run -d chrome` で E2E(login→照合→添付→完了 + オフライン→再接続同期) を手動検証。自動テストは全緑につきコード実装は完了。

## Session 2026-08-07 (E2E 手動検証 + Web ビルド修正)

### Web ビルド不具合の発見と修正
- `flutter run -d chrome` は Claude からアクセスできない隔離 Chrome プロファイルを使うため、代替として `flutter build web --dart-define=API_BASE_URL=http://localhost:8080/api/v1` → `python3 -m http.server 9090` で配信し、Claude の Chrome タブから `http://localhost:9090/` を開いて検証。
- **Drift web 初期化バグを修正**: web ターゲットでは SQLite が WebAssembly で動くため、`web/sqlite3.wasm`(sqlite3 2.9.4) と `web/drift_worker.js`(drift 2.31.0) をバージョン一致で配置する必要がある。無いと最初の `driftDatabase()` 呼び出しが実行時 throw → 空白ページ。unit テストは `NativeDatabase.memory()` を直接使うため**この経路を通らず検知不可**。
- 修正: 両バイナリを upstream GitHub releases から取得し `web/` に配置。`OfflineDatabase` に `DriftWebOptions(sqlite3Wasm:, driftWorker:)` を渡す（web引数は web ビルドで必須）。`mobile/README.md` に「Web (Drift/SQLite) assets」節を追記。

### 実 UI で検証できたこと（ライブ backend, Docker: app@8080）
- **Auth 永続化 + 一覧がライブ backend データを表示** ✓
- **一覧 → 詳細ナビゲーション + 詳細が実データを描画**（items/バーコード/数量/match result/添付）✓
- **完了(Complete)がライブ backend に往復**: INS-000002 の `completed_at` が UI クリックで 2026-08-05T23:24:55 にセットされたことを curl で確認 ✓
- **オフラインフォールバック**: `docker compose stop app` で backend 停止中に完了ボタン → *"Offline — completion queued for sync"* スナックバー表示、Drift キューに enqueue ✓
- **再接続フラッシュ**: backend 再起動 + リロード後にキューが drain（後続リロードで `/complete` リクエストが再発火しない = 既に replay 済みで削除）✓

### 環境制約でブロックされたこと（コード欠陥ではない）
- **バーコードスキャン照合(照合)**: サンドボックスにカメラデバイスが無く、`barcode_scan_screen.dart` に手動入力フォールバックが無い(MobileScanner のみ)。API(recordItem OK/NG)は前セッションで curl 検証済み + unit テスト緑。
- **ファイル添付(添付)**: ネイティブ OS ファイルピッカーダイアログは CDP で自動操作不可。multipart アップロード(image/pdf/xlsx/mp4)は前セッションで curl 検証済み + unit テスト緑。

### 遭遇した環境問題
- CanvasKit レンダラの Flutter web は `<canvas>` に描画するため DOM ベースのツール(find/get_page_text/read_page)で中身が見えず、ピクセル座標のスクショ+クリックのみ。
- Flutter レイアウトのスケールが compact/spread-out 間で揺れ、古い座標のクリックが別行/空白に着弾 → 各クリック直前に新規スクショを取り座標を再計算して解決。
- CDP `Page.captureScreenshot` がアニメーション中に断続的にタイムアウト、ページ遷移アニメ中にタブがクラッシュ（3タブ死亡）→ ピクセルレベル E2E の継続は環境的に不安定と判断し、検証結果の文書化に切替。
- `connectivity_plus` は web ではブラウザの online/offline イベントに依存し特定サーバ到達性は見ない。backend 停止でもブラウザが online なら再接続 flush はトリガーされず、リロード時の起動 flush 経路(`service.start()` の isOnline probe)が実際に効く経路。

## Session 2026-08-07 — UI/UX リデザイン（ui-ux-pro-max skill 適用）
- 追加要件: (1) 使用できる状態まで開発継続 (2) `ui-ux-pro-max-skill` を導入 (3) デザインを使いやすくリデザイン。
- **skill 導入**: `github.com/nextlevelbuilder/ui-ux-pro-max-skill` を clone → `.claude/skills/ui-ux-pro-max` を `~/.claude/skills/` へ配置（旧版は `/tmp/ui-ux-pro-max.bak-20260807` に退避）。ハーネスが skill を認識。
- **デザインシステム選定**（skill の search.py を `--stack flutter` で照会し、現場データツール向けに取捨選択）:
  - スタイル = **Flat Design**（グラデ/ドロップシャドウ無し、境界線で分離、高コントラスト navy+blue）。
  - パレット = Primary/CTA 青 `#0369A1`、navy `#0F172A`(見出し/tertiary)、bg `#F8FAFC`、error `#DC2626`。dark も定義。
  - フォントペア = "Dashboard Data" → **Fira Sans**(UI) + **Fira Code**(コード/数量/バーコードの等幅)。
  - キーワード汚染で混入した Newsletter/Playfair 系は不採用（データツールに不適と判断）。
- **フォントはオフライン同梱**（現場ツールのため runtime fetch せず TTF を assets 化）: FiraSans 400/500/600/700 + FiraCode 可変フォント(VF, 400/600)。`pubspec.yaml` に登録。
- **作成した基盤**: `core/theme/{app_colors,app_spacing,app_theme}.dart`（自前 ColorScheme + Flat な ThemeData light/dark、52px タッチ、FadeUpwards 遷移）、`core/ui/{status_pill,state_views}.dart`（StatusPill/StatusAvatar/Loading/Empty/Error）、`inspection/presentation/inspection_status_ui.dart`（status→tone/icon/label の単一マッピング）。
- **4画面リデザイン**: `app.dart`(テーマ配線+ブランド Splash)、login（navy フラット+BrandMark+@/lock アイコン+可視トグル）、一覧（境界カード+StatusAvatar+StatusPill+chevron）、詳細（HeaderCard/NoteCard/ItemCard(Fira Code バーコード)/AttachmentTile/Scan FAB/完了バナー）、バーコードスキャン（reticle オーバーレイ+トーチ+ハプティクス）。
- **品質ゲート**: `flutter analyze` 0 error/warning（既存テストの info lint 7 件のみ）。`flutter test` 12/12 緑（テスト可視文字列は温存）。`flutter build web` コンパイル成功。
- **ブラウザ実 UI 検証**（build/web を配信 → Claude Chrome タブ）:
  - Flutter service worker が旧 `main.dart.js` をキャッシュしていたため、別ポート(9091=別オリジン)で新規配信して回避。localStorage の暗号化トークンを移送して認証状態を再現。
  - login（navy フラット/Fira Sans/丸角フィールド/青 CTA）、一覧（カード/StatusAvatar/StatusPill "Pending"・"Failed"/"Receiving · N items"）、詳細（HeaderCard "Failed"、Items 2、Fira Code バーコード、"PENDING"/"NG" pill、Expected/Actual chip、quantity_mismatch、AttachmentTile e2e.png、Scan FAB、完了バナー）が全て新デザインで描画されることを確認 ✓
- **学び**: Flutter web の SW は積極キャッシュ。新ビルドを確認するには SW unregister + caches purge、または別オリジン(別ポート)配信が確実。`?query` だけでは `main.dart.js` はバスターされない。

## Session 2026-08-08 — ナビゲーションシェル（ホーム + 機能メニュー、選択肢C）
- ユーザー要件「InventorOS のような多機能を考慮」→ 選択肢C:「まず全体の画面設計・ナビ構成(ホーム+メニュー)を先に作り、機能を順次追加」を実装。
- **設計方針**: `feature_catalog.dart` をナビの単一の真実源に。backend の全 API を 14 機能 × 3 グループ（Field Operations / Lookup / Management）へマップ。各 `FeatureEntry` は `FeatureStatus`(ready/comingSoon) と `WidgetBuilder?` を持ち、Inspection のみ ready、他は comingSoon。実装追加は該当エントリを `ready` + `builder` に切替えるだけで導線が有効化される（差分最小）。
- **作成ファイル**（feature/domain 分割、各小ファイル）:
  - `features/home/domain/feature_entry.dart`（FeatureEntry/FeatureGroup、@immutable、`isReady` getter）
  - `features/home/domain/feature_catalog.dart`（const カタログ + top-level `_inspectionList` builder で const 参照可能に）
  - `features/home/presentation/coming_soon_screen.dart`（未実装機能の汎用プレースホルダ: アイコンタイル/Coming soon pill/説明/roadmap 注記/Back to menu）
  - `features/home/presentation/home_screen.dart`（挨拶カード + グループヘッダ + `GridView`(maxCrossAxisExtent 260) の feature カード。ready=chevron / 未実装=Soon pill、タップで実画面 or ComingSoonScreen へ push）
- **配線変更**: `app.dart` の認証後着地を `InspectionListScreen` → `HomeScreen` に変更（既存 offlineSync ブート/Splash/BrandMark は温存）。
- **テスト**: `test/features/home/presentation/home_screen_test.dart` — オフライン FakeAuthRepository で authenticated 状態を作り、(1) 挨拶+グループメニュー描画、(2) Soon 機能タップ→ComingSoonScreen 遷移 を検証。
- **品質ゲート**: `flutter analyze` **0 error**（info lint のみ、新規テストの const lint は修正済）、`flutter test` **14/14 緑**（既存 12 + 新規 2）、`flutter build web --dart-define=API_BASE_URL=http://localhost:8080/api/v1` 成功。
- **ブラウザ実 UI 検証**（ライブ backend app@8080、別ポート 9094 = 別オリジンで SW キャッシュ回避）:
  - login(e2e@test.com/password123) → **HomeScreen 描画**: 挨拶カード "Welcome back / E2E Admin / e2e@test.com"、"Field Operations" グループ、Inspection(ready=chevron)、Receiving・Stock Adjustment("Soon" pill) ✓
  - Soon カードタップ → **ComingSoonScreen 描画**: AppBar タイトル、機能アイコンタイル、"Coming soon" info pill、機能名/説明、roadmap 注記、"Back to menu" ボタン ✓
- **学び/注意点**:
  - 再ビルド時に `--dart-define=API_BASE_URL` を付け忘れると default `http://localhost/api/v1`(ポート無し)に落ち、ログインが *"No connection to the server."* になる。web ビルドは必ず dart-define 付きで。
  - Flutter web の入力ハンドラはマウント完了前だとクリック/タイプを取りこぼす → ページ描画後に一度スクショで確認してから入力すると確実。
  - CDP スクショはページ遷移アニメ中に断続タイムアウト → 直後にリトライで取得可（タブは生存）。

## Session 2026-08-08 (続き) — 全機能実装（カタログ全 ready 化）
- ナビシェルの "Soon" 機能を1つずつ実装（feature/domain 分割・Repository パターン・統一 envelope・80%目標のwidget/parsing テスト付き）。各機能で `flutter analyze` 0 error + `flutter test` 緑を担保。
- 実装順: Product Lookup → Receiving → Stock Adjustment → Locations → Suppliers → Warehouses → Sales Orders → Purchase Orders → Lots & Serials → Stock Count → Work Orders → Reports → **Picking**。
- **Picking（最後の Soon）**: backend に picking/fulfillment エンドポイントが無いため、既存 `SalesOrderRepository`/domain を再利用した**読み取り専用ピックリスト**として実装。
  - `features/picking/application/picking_providers.dart`: `pickListsProvider`（open = pending+processing の受注のみ client-side フィルタ）。
  - `features/picking/presentation/picking_list_screen.dart`（open 受注のブラウズ）+ `pick_list_screen.dart`（ConsumerStatefulWidget、ローカル `Set<int>` で明細チェックオフ、"N / M picked" 進捗 pill、backend ミューテーション無し）。
  - `feature_catalog.dart` の `picking` を ready + `_picking` builder に切替 → **カタログ全 14 機能が ready**。
- **home_screen_test 更新**: 全機能 ready 化により "Soon" バッジが消滅。(1) `find.text('Soon')` を findsNothing に、(2) coming-soon タップ検証を「ready 機能(Picking)タップ→実画面(PickingListScreen)遷移」に差し替え（salesOrderRepository を空 fake で override しネットワーク不要化）。
- **品質ゲート**: `flutter analyze` **0 error**、`flutter test` **98/98 緑**（Picking で +4: list 2 + detail 2）。
- 残: 全機能が read/参照系で実装済み。検品(+写真)以外は read-only ブラウズ。任意で live backend への E2E 手動検証、git コミットで整理。

## Session 2026-08-08 (続き2) — live backend E2E 手動再検証
- ユーザー選択: 「1. live backend での E2E 手動再検証」。Docker backend-app-1@8080 起動、`build/web`(dart-define=API_BASE_URL=…8080/api/v1) を別ポート 9096 で配信、Chrome 実 UI で検証。
- **データ準備**: DemoDataSeeder 実行（ScreenshotSeeder→倉庫/kit・assembly商品/WorkOrder/SavedReports を idempotent updateOrCreate で追加）。ログインは org2 の `e2e-test@inventoros.test` / `E2ETestPassword123!`（org1 の e2e@test.com は org2 のデモデータが見えず空だったため切替）。org2 は 8 orders / 3 reports / 2 work-orders / 18 products など可視。
- **Picking**: seed 受注は明細0行だったため API POST `/api/v1/orders`（product 13&4, qty 3/5）で **ORD-20260808-0001**(id9, pending, 2行) を作成 → 実 UI で PickingListScreen が open 受注のみ表示(8件中4件=pending/processing) → PickList を開き 2 明細をチェックオフ → StatusPill が **"0/2"→"1/2"→"2/2 picked"**（allPicked で success tone/check_circle）に遷移 ✓。SKU=Fira Code, Qty pill も描画。
- **Reports**: ReportsListScreen が 3 レポート（Monthly Product Summary/6col/Shared 他）を描画 → "Monthly Product Summary" タップ → LoadingView "Running report…" → **ReportResultScreen の DataTable が 18 rows**（列: Name/SKU/Stock/Price/category/Active、SKU=Fira Code、null セルは "—"）で描画 ✓。ReportResult パース + `_ReportTable` の nested vertical/horizontal scroll → DataTable が live で機能。
- **HomeScreen**: 認証後 14 機能すべて ready（Soon バッジ無し）、挨拶 "E2E Test User"、3 グループ描画 ✓。
- **結論**: 自動テスト 98/98 緑に加え、live backend で Home[ナビ] / Picking[インタラクティブ check-off] / Reports[データ豊富な DataTable] を実 UI で確認。他機能は同一 Repository/feature recipe の read-only ブラウズで均質、パース/widget テストで担保済み。検品・Stock Count は org2 で 0 件のため空ステート表示（想定通り）。
- **注記**: E2E 用にローカル Docker test DB に DemoDataSeeder 実行 + テスト注文 1 件を作成（dev/test セットアップ、本番影響なし）。
