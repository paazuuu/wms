// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'WMS';

  @override
  String get search => '検索';

  @override
  String get retry => '再試行';

  @override
  String get signOut => 'サインアウト';

  @override
  String get backToMenu => 'メニューに戻る';

  @override
  String get somethingWentWrong => '問題が発生しました';

  @override
  String get language => '言語';

  @override
  String get languageTooltip => '言語を選択';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get navDashboard => 'ダッシュボード';

  @override
  String get brandSubtitle => '倉庫管理';

  @override
  String get welcomeBack => 'おかえりなさい';

  @override
  String get operatorName => '作業者';

  @override
  String get scannerReady => 'スキャン準備完了';

  @override
  String get readyToScanTitle => 'スキャン準備完了';

  @override
  String get readyToScanBody => 'どこでもハンディでスキャン、またはタップしてバーコード・SKU・名称で検索。';

  @override
  String get topbarScanHint => 'バーコード / SKU をスキャンまたは検索';

  @override
  String get menu => 'メニュー';

  @override
  String get cameraScan => 'カメラでスキャン';

  @override
  String get groupFieldOperations => '現場作業';

  @override
  String get groupLookup => '照会';

  @override
  String get groupManagement => '管理';

  @override
  String get featInspection => '検品';

  @override
  String get featInspectionDesc => 'バーコード・数量照合、NG記録';

  @override
  String get featReceiving => '入荷';

  @override
  String get featReceivingDesc => '発注の入荷、検品を自動開始';

  @override
  String get featStockAdjustment => '在庫調整';

  @override
  String get featStockAdjustmentDesc => '理由付きでスキャンして増減';

  @override
  String get featStockCount => '棚卸';

  @override
  String get featStockCountDesc => 'ロケーション別の循環棚卸';

  @override
  String get featPicking => 'ピッキング';

  @override
  String get featPickingDesc => 'スキャンで受注を出荷';

  @override
  String get featProductLookup => '商品照会';

  @override
  String get featProductLookupDesc => 'バーコードをスキャンして商品と在庫を表示';

  @override
  String get featLocations => 'ロケーション';

  @override
  String get featLocationsDesc => '棚・ゾーン・移動';

  @override
  String get featLotsSerials => 'ロット・シリアル';

  @override
  String get featLotsSerialsDesc => 'バッチとシリアルの追跡';

  @override
  String get featPurchaseOrders => '発注';

  @override
  String get featPurchaseOrdersDesc => '発注書の作成・管理';

  @override
  String get featSalesOrders => '受注';

  @override
  String get featSalesOrdersDesc => '受注の閲覧・編集';

  @override
  String get featSuppliers => '仕入先';

  @override
  String get featSuppliersDesc => '仕入先ディレクトリ';

  @override
  String get featWarehouses => '倉庫';

  @override
  String get featWarehousesDesc => '倉庫マスタ';

  @override
  String get featWorkOrders => '作業指示';

  @override
  String get featWorkOrdersDesc => '組立・キッティング';

  @override
  String get featReports => '帳票';

  @override
  String get featReportsDesc => '保存済みレポートとエクスポート';

  @override
  String get comingSoon => '近日対応';

  @override
  String get comingSoonBody => 'このサーバーAPIは準備済みです。モバイル画面が次の予定です。';

  @override
  String get signIn => 'サインイン';

  @override
  String get signInSubtitle => '検品を始めるにはサインイン';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get emailRequired => 'メールアドレスを入力してください';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get show => '表示';

  @override
  String get hide => '非表示';

  @override
  String get searching => '検索中…';

  @override
  String get scanTypeHint => 'バーコード・SKU・名称をスキャンまたは入力';

  @override
  String get scanTypeMessage => 'バーコード・SKU・名称をスキャンまたは入力してください。';

  @override
  String noMatchesFor(String query) {
    return '「$query」に一致する結果がありません。';
  }

  @override
  String get tryDifferentScan => '別のバーコード・SKU・名称をお試しください。';

  @override
  String get inStock => '在庫';

  @override
  String get productLookupEmpty => '商品がまだありません。';

  @override
  String get findProductToAdjust => '調整する商品を検索。';

  @override
  String get findProductToTrace => '追跡する商品を検索。';

  @override
  String get loading => '読み込み中…';

  @override
  String get emptyLocations => 'ロケーションがまだありません。';

  @override
  String get emptyWarehouses => '倉庫がまだありません。';

  @override
  String get emptySuppliers => '仕入先がまだありません。';

  @override
  String get emptySalesOrders => '受注がまだありません。';

  @override
  String get emptyPurchaseOrders => '発注がまだありません。';

  @override
  String get emptyWorkOrders => '作業指示がまだありません。';

  @override
  String get tryDifferentNameCode => '別の名称またはコードをお試しください。';

  @override
  String get tryDifferentOrder => '別の受注番号または顧客をお試しください。';

  @override
  String get tryDifferentPo => '別の発注番号または仕入先をお試しください。';

  @override
  String get tryDifferentWo => '別の作業指示番号・商品・SKUをお試しください。';

  @override
  String get hintLocations => '名称・コードをスキャンまたは検索';

  @override
  String get hintWarehouses => '名称・コード・都市をスキャンまたは検索';

  @override
  String get hintSuppliers => '名称・コード・担当者・メールをスキャンまたは検索';

  @override
  String get hintSalesOrders => '受注番号・顧客・メールをスキャンまたは検索';

  @override
  String get hintPurchaseOrders => '発注番号・仕入先をスキャンまたは検索';

  @override
  String get hintWorkOrders => '作業指示番号・商品・SKUをスキャンまたは検索';

  @override
  String get warehouseDefault => '既定';

  @override
  String get noCustomer => '顧客なし';

  @override
  String get noSupplier => '仕入先なし';

  @override
  String get noProduct => '商品なし';

  @override
  String qtyLabel(int quantity) {
    return '数量 $quantity';
  }

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の明細',
    );
    return '$_temp0';
  }

  @override
  String get statusActive => '有効';

  @override
  String get statusInactive => '無効';

  @override
  String get statusCancelled => 'キャンセル';

  @override
  String get statusDraft => '下書き';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusPending => '保留';

  @override
  String get salesProcessing => '処理中';

  @override
  String get salesShipped => '出荷済み';

  @override
  String get salesDelivered => '配達済み';

  @override
  String get poSent => '送信済み';

  @override
  String get poPartiallyReceived => '一部入荷';

  @override
  String get poReceived => '入荷済み';

  @override
  String get stockIn => '在庫あり';

  @override
  String get stockLow => '在庫僅少';

  @override
  String get stockOut => '在庫切れ';

  @override
  String get inspectionPassed => '合格';

  @override
  String get inspectionFailed => '不合格';

  @override
  String get matchOk => 'OK';

  @override
  String get matchNg => 'NG';

  @override
  String get typeReceiving => '入荷';

  @override
  String get typeShipping => '出荷';

  @override
  String get typeOther => 'その他';

  @override
  String get titleProduct => '商品';

  @override
  String get fieldDescription => '説明';

  @override
  String get fieldPhone => '電話';

  @override
  String get fieldAddress => '住所';

  @override
  String get fieldStatus => 'ステータス';

  @override
  String get fieldCurrency => '通貨';

  @override
  String get fieldCategory => 'カテゴリ';

  @override
  String get fieldBarcode => 'バーコード';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldPrice => '価格';

  @override
  String get fieldSellingPrice => '販売価格';

  @override
  String get fieldMinStock => '最小在庫';

  @override
  String get fieldOnHand => '在庫数';

  @override
  String get fieldLocation => 'ロケーション';

  @override
  String get fieldHasVariants => 'バリエーションあり';

  @override
  String get fieldManager => '管理者';

  @override
  String get fieldTimezone => 'タイムゾーン';

  @override
  String get fieldPriority => '優先度';

  @override
  String get fieldUsers => 'ユーザー';

  @override
  String get fieldLocations => 'ロケーション';

  @override
  String get fieldContact => '担当者';

  @override
  String get fieldWebsite => 'ウェブサイト';

  @override
  String get fieldPaymentTerms => '支払条件';

  @override
  String get fieldNotes => '備考';

  @override
  String get fieldProducts => '商品';

  @override
  String get fieldAisle => '通路';

  @override
  String get fieldShelf => '棚';

  @override
  String get fieldBin => 'ビン';

  @override
  String get fieldCode => 'コード';

  @override
  String get fieldFullLocation => 'フルロケーション';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count点',
    );
    return '$_temp0';
  }

  @override
  String productCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count品目',
    );
    return '$_temp0';
  }

  @override
  String binCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countロケーション',
    );
    return '$_temp0';
  }

  @override
  String get fieldCustomer => '顧客';

  @override
  String get lineItems => '明細';

  @override
  String get noLineItems => '明細がありません。';

  @override
  String get fieldOrderDate => '注文日';

  @override
  String get fieldSubtotal => '小計';

  @override
  String get fieldTax => '税';

  @override
  String get fieldShipping => '送料';

  @override
  String get fieldTotal => '合計';

  @override
  String get fieldSupplier => '仕入先';

  @override
  String get fieldExpected => '予定';

  @override
  String get fieldOrdered => '発注';

  @override
  String get fieldReceived => '入荷';

  @override
  String get fieldRemaining => '残';

  @override
  String get actionComplete => '完了';

  @override
  String get fieldAssemblyProduct => '組立製品';

  @override
  String get fieldComponents => '部品';

  @override
  String get noComponents => '部品がありません。';

  @override
  String get fieldConsumed => '消費';

  @override
  String get fieldProduced => '生産';

  @override
  String get fieldRequired => '必要';

  @override
  String get fieldTarget => '目標';

  @override
  String get fieldStarted => '開始';

  @override
  String productNumber(int id) {
    return '商品 #$id';
  }

  @override
  String get fieldCountedLines => 'カウント済み明細';

  @override
  String get noCountedLines => 'カウント済み明細がありません。';

  @override
  String get fieldCounted => 'カウント';

  @override
  String get fieldUncounted => '未カウント';

  @override
  String get fieldDiscrepancy => '差異';

  @override
  String get fieldMatch => '一致';

  @override
  String get fieldSystem => 'システム';

  @override
  String get fieldName => '名称';

  @override
  String get fieldType => '種別';

  @override
  String get filterAll => 'すべて';

  @override
  String remainingLeft(int count) {
    return '残り $count';
  }

  @override
  String remainingAmount(String amount) {
    return '残り $amount';
  }

  @override
  String get unknownSupplier => '仕入先不明';

  @override
  String get receivingEmpty => '入荷対象がありません。';

  @override
  String get receivingEmptyBody => '送信済みまたは一部入荷の発注がここに表示されます。';

  @override
  String get receivingDone => '残りの入荷はありません。';

  @override
  String get fieldQtyToReceive => '入荷数量';

  @override
  String get receiveStock => '入荷登録';

  @override
  String get actionReceive => '入荷';

  @override
  String get receivingInProgress => '入荷処理中…';

  @override
  String get emptyInspections => '検品がまだありません。';

  @override
  String get inspectionsEmptyBody => '下に引いて更新するか、入荷受入から開始してください。';

  @override
  String get pickingEmpty => 'ピッキング対象がありません。';

  @override
  String get noLinesToPick => 'ピッキングする明細がありません。';

  @override
  String get orderNoLineItems => 'この受注に明細はありません。';

  @override
  String get unnamedProduct => '名称未設定の商品';

  @override
  String get pickListTitle => 'ピッキングリスト';

  @override
  String get customReport => 'カスタムレポート';

  @override
  String get emptyReports => '保存済みレポートがまだありません。';

  @override
  String get reportsEmptyBody => 'バックオフィスで保存したレポートがここに表示されます。';

  @override
  String get reportShared => '共有';

  @override
  String columnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count列',
    );
    return '$_temp0';
  }

  @override
  String get allLocations => '全ロケーション';

  @override
  String get emptyStockCounts => '棚卸がまだありません。';

  @override
  String get pickingEmptyBody => '出荷待ちの受注がここに表示されます。';

  @override
  String get stockCountsEmptyBody => 'バックオフィスで作成した循環棚卸がここに表示されます。';

  @override
  String get receivingDoneBody => 'この発注のすべての明細が入荷済みです。';

  @override
  String receiveInvalidQty(String product) {
    return '「$product」の数量を正しく入力してください。';
  }

  @override
  String receiveExceedsRemaining(String product, int remaining) {
    return '$product：残り $remaining を超えて入荷できません。';
  }

  @override
  String get receiveEnterAtLeastOne => '入荷する数量を1行以上入力してください。';

  @override
  String get receiveSuccess => '入荷しました。検品が自動的に開始されました。';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total ピック済み';
  }

  @override
  String get attachFiles => '添付';

  @override
  String get cameraLabel => 'カメラ';

  @override
  String get scanToRecord => 'スキャンして記録';

  @override
  String get scanToRecordQty1 => 'スキャンして記録（数量1）';

  @override
  String get fastModeOnTooltip => '高速モード：スキャンごとに数量1で記録';

  @override
  String get fastModeOffTooltip => 'スキャンごとに数量を入力';

  @override
  String get fastQtyOneLabel => '数量1';

  @override
  String get actualQuantity => '実数量';

  @override
  String scannedCode(String code) {
    return '読取: $code';
  }

  @override
  String get quantity => '数量';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionRecord => '記録';

  @override
  String get itemRecorded => '項目を記録しました';

  @override
  String get offlineItemQueued => 'オフライン — 項目を同期待ちに追加しました';

  @override
  String filesUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のファイルをアップロードしました',
    );
    return '$_temp0';
  }

  @override
  String offlineFilesQueued(int count) {
    return 'オフライン — $count件のファイルを同期待ちに追加しました';
  }

  @override
  String get completeInspectionQ => '検品を完了しますか？';

  @override
  String get completeInspectionBody => 'この検品を完了にします。完了後も閲覧できます。';

  @override
  String get inspectionCompleted => '検品を完了しました';

  @override
  String get offlineCompletionQueued => 'オフライン — 完了を同期待ちに追加しました';

  @override
  String get sectionItems => '項目';

  @override
  String get sectionAttachments => '添付ファイル';

  @override
  String get noItemsYet => '項目がまだありません。スキャンで記録してください。';

  @override
  String get noAttachments => '添付はありません。クリップから写真やファイルを追加できます。';

  @override
  String get completeInspection => '検品を完了';

  @override
  String completedOn(String date) {
    return '完了 $date';
  }

  @override
  String get actualLabel => '実績';

  @override
  String itemNumber(int id) {
    return '項目 $id';
  }

  @override
  String get working => '処理中…';

  @override
  String get adjustAdd => '追加';

  @override
  String get adjustRemove => '減少';

  @override
  String get reasonType => '理由区分';

  @override
  String get reasonOptional => '理由（任意）';

  @override
  String get notesOptional => 'メモ（任意）';

  @override
  String get onHandAfter => '調整後の在庫';

  @override
  String get saving => '保存中…';

  @override
  String get addStock => '在庫を追加';

  @override
  String get removeStock => '在庫を減らす';

  @override
  String onHandCount(int count) {
    return '在庫 $count';
  }

  @override
  String get enterQtyPositive => '0より大きい数量を入力してください。';

  @override
  String cannotRemoveOnly(int qty, int current) {
    return '$qty を減らせません。在庫は $current のみです。';
  }

  @override
  String stockUpdatedTo(int count) {
    return '在庫を更新しました — 現在 $count。';
  }

  @override
  String get adjustTypeManual => '手動';

  @override
  String get adjustTypeCount => '棚卸';

  @override
  String get adjustTypeDamage => '破損';

  @override
  String get adjustTypeReturn => '返品';

  @override
  String get adjustTypeTransfer => '移動';

  @override
  String get sectionBatches => 'バッチ';

  @override
  String get sectionSerials => 'シリアル';

  @override
  String get noBatches => 'この商品のバッチはありません。';

  @override
  String get noSerials => 'この商品のシリアルはありません。';

  @override
  String get loadingBatches => 'バッチを読み込み中…';

  @override
  String get loadingSerials => 'シリアルを読み込み中…';

  @override
  String get batchExpired => '期限切れ';

  @override
  String get batchValid => '有効';

  @override
  String get fieldExpiry => '有効期限';

  @override
  String get report => 'レポート';

  @override
  String get runningReport => 'レポートを実行中…';

  @override
  String get noData => 'データがありません。';

  @override
  String get reportNoRows => 'このレポートに行がありません。';

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
    );
    return '$_temp0';
  }

  @override
  String get scanBarcode => 'バーコードをスキャン';

  @override
  String get torchOn => 'ライトを点灯';

  @override
  String get torchOff => 'ライトを消灯';

  @override
  String get alignBarcode => '枠内にバーコードを合わせてください';

  @override
  String get scanOrTypeBarcode => 'スキャンまたはバーコードを入力';

  @override
  String get featDelivery => '納品照合';

  @override
  String get featDeliveryDesc => '納品書とExcel予定を照合し過不足を可視化';

  @override
  String get deliveryStatusOpen => '未照合';

  @override
  String get deliveryStatusReconciling => '照合中';

  @override
  String get deliveryStatusCompleted => '照合済み';

  @override
  String get reconPending => '未確認';

  @override
  String get reconMatched => '一致';

  @override
  String get reconShortfall => '不足';

  @override
  String get reconOver => '過剰';

  @override
  String get reconUnexpected => '想定外';

  @override
  String get deliveryPlansTitle => '納品照合';

  @override
  String get deliveryPlansEmpty => '納品予定がありません。';

  @override
  String get deliveryPlansEmptyBody => 'バックオフィスで取り込んだ納品予定（Excel）がここに表示されます。';

  @override
  String get deliveryPlansHint => 'スキャンまたは伝票番号・仕入先で検索';

  @override
  String get deliveryNoMatches => '一致する納品予定がありません。';

  @override
  String get deliverySearchTip => '別の伝票番号または仕入先をお試しください。';

  @override
  String plannedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '予定明細 $count 件',
    );
    return '$_temp0';
  }

  @override
  String get deliveryNumberLabel => '伝票番号';

  @override
  String get deliveryDateLabel => '納品日';

  @override
  String get scanDeliveryHint => '品物のJANをスキャン';

  @override
  String get ocrAssist => '納品書を撮影（OCR補助）';

  @override
  String get ocrScanning => '納品書を解析中…';

  @override
  String ocrFound(int count) {
    return '納品書から $count 件のJANを検出しました';
  }

  @override
  String get ocrNoneFound => '納品書からJANを検出できませんでした。';

  @override
  String get ocrUnavailable => 'この端末ではOCRを利用できません。';

  @override
  String get reconSummaryTitle => '照合状況';

  @override
  String get deliveryPlanned => '予定';

  @override
  String get diffLabel => '差';

  @override
  String get completeReconcile => '照合を完了';

  @override
  String get reconcileConfirmQ => '照合を完了しますか？';

  @override
  String get reconcileConfirmBody => '現在の計数結果を送信して照合を完了します。';

  @override
  String get reconcileConfirmDiscrepancy => '差異があります（不足・過剰・想定外）。このまま完了しますか？';

  @override
  String get reconcileDone => '照合を完了しました';

  @override
  String get reconcileEmptyCounts => 'まだ計数がありません。スキャンして開始してください。';

  @override
  String get unexpectedItem => '想定外の品目';

  @override
  String enterQuantityFor(String code) {
    return '$code の数量';
  }

  @override
  String get noteImageAttached => '納品書を添付しました';

  @override
  String get planImportTitle => '予定を取り込む';

  @override
  String get planImportHint => 'Excel / PDF / 画像を選んでアップロードすると、自動で予定に登録します。';

  @override
  String get pickFile => 'ファイルを選択';

  @override
  String planImportSelected(String name) {
    return '選択: $name';
  }

  @override
  String get planImportAction => '取り込む';

  @override
  String get planImporting => '取り込み中…';

  @override
  String get planImportChooseFirst => 'ファイルを選び、伝票番号を入力してください。';

  @override
  String planImportedSummary(int count, int total) {
    return '$count 品目・合計 $total 本を取り込みました';
  }
}
