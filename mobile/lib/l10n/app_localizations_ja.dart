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
}
