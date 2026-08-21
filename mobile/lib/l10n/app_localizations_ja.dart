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
}
