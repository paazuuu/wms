// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'WMS';

  @override
  String get search => '搜索';

  @override
  String get retry => '重试';

  @override
  String get signOut => '退出登录';

  @override
  String get backToMenu => '返回菜单';

  @override
  String get somethingWentWrong => '发生错误';

  @override
  String get language => '语言';

  @override
  String get languageTooltip => '选择语言';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get navDashboard => '仪表盘';

  @override
  String get brandSubtitle => '仓储管理';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get operatorName => '作业员';

  @override
  String get scannerReady => '扫描枪就绪';

  @override
  String get readyToScanTitle => '准备扫描';

  @override
  String get readyToScanBody => '可在任意界面使用手持扫描枪，或点击以按条码、SKU 或名称搜索。';

  @override
  String get topbarScanHint => '扫描或搜索条码 / SKU';

  @override
  String get menu => '菜单';

  @override
  String get cameraScan => '使用相机扫描';

  @override
  String get groupFieldOperations => '现场作业';

  @override
  String get groupLookup => '查询';

  @override
  String get groupManagement => '管理';

  @override
  String get featInspection => '验货';

  @override
  String get featInspectionDesc => '条码与数量核对、不良记录';

  @override
  String get featReceiving => '收货';

  @override
  String get featReceivingDesc => '对采购单收货，并自动开始验货';

  @override
  String get featStockAdjustment => '库存调整';

  @override
  String get featStockAdjustmentDesc => '扫描增减并注明原因';

  @override
  String get featStockCount => '盘点';

  @override
  String get featStockCountDesc => '按库位循环盘点';

  @override
  String get featPicking => '拣货';

  @override
  String get featPickingDesc => '扫描拣货，完成销售订单';

  @override
  String get featProductLookup => '商品查询';

  @override
  String get featProductLookupDesc => '扫描条码查看商品与库存';

  @override
  String get featLocations => '库位';

  @override
  String get featLocationsDesc => '货位、区域与移库';

  @override
  String get featLotsSerials => '批次与序列号';

  @override
  String get featLotsSerialsDesc => '批次与序列号追踪';

  @override
  String get featPurchaseOrders => '采购单';

  @override
  String get featPurchaseOrdersDesc => '创建与管理采购单';

  @override
  String get featSalesOrders => '销售订单';

  @override
  String get featSalesOrdersDesc => '查看与编辑订单';

  @override
  String get featSuppliers => '供应商';

  @override
  String get featSuppliersDesc => '供应商名录';

  @override
  String get featWarehouses => '仓库';

  @override
  String get featWarehousesDesc => '仓库主数据';

  @override
  String get featWorkOrders => '工单';

  @override
  String get featWorkOrdersDesc => '组装与配套';

  @override
  String get featReports => '报表';

  @override
  String get featReportsDesc => '已保存报表与导出';

  @override
  String get comingSoon => '敬请期待';

  @override
  String get comingSoonBody => '该功能的服务器 API 已就绪，移动端界面即将推出。';

  @override
  String get signIn => '登录';

  @override
  String get signInSubtitle => '登录以开始验货';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get emailRequired => '请输入邮箱';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get searching => '搜索中…';

  @override
  String get scanTypeHint => '扫描或输入条码、SKU 或名称';

  @override
  String get scanTypeMessage => '请扫描或输入条码、SKU 或名称。';

  @override
  String noMatchesFor(String query) {
    return '未找到与“$query”匹配的结果。';
  }

  @override
  String get tryDifferentScan => '请尝试其他条码、SKU 或名称。';

  @override
  String get inStock => '库存';

  @override
  String get productLookupEmpty => '暂无商品。';

  @override
  String get findProductToAdjust => '查找要调整的商品。';

  @override
  String get findProductToTrace => '查找要追溯的商品。';
}
