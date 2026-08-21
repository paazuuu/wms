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
  String get somethingWentWrong => '出现问题';

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
  String get navDashboard => '仪表板';

  @override
  String get brandSubtitle => '仓库';

  @override
  String get welcomeBack => '欢迎回来';

  @override
  String get operatorName => '操作员';

  @override
  String get scannerReady => '扫描就绪';

  @override
  String get readyToScanTitle => '准备扫描';

  @override
  String get readyToScanBody => '在任何界面使用手持扫描枪，或点按以按条码、SKU 或名称搜索。';

  @override
  String get topbarScanHint => '扫描或搜索条码 / SKU';

  @override
  String get menu => '菜单';

  @override
  String get cameraScan => '用相机扫描';

  @override
  String get groupFieldOperations => '现场作业';

  @override
  String get groupLookup => '查询';

  @override
  String get groupManagement => '管理';

  @override
  String get featInspection => '检验';

  @override
  String get featInspectionDesc => '条码与数量核对、NG 记录';

  @override
  String get featReceiving => '收货';

  @override
  String get featReceivingDesc => '收货采购单，自动开始检验';

  @override
  String get featStockAdjustment => '库存调整';

  @override
  String get featStockAdjustmentDesc => '扫描并附原因增减';

  @override
  String get featStockCount => '盘点';

  @override
  String get featStockCountDesc => '按库位循环盘点';

  @override
  String get featPicking => '拣货';

  @override
  String get featPickingDesc => '扫描完成销售订单';

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
  String get featSuppliersDesc => '供应商目录';

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
  String get comingSoonBody => '服务器 API 已就绪——移动端界面即将推出。';
}
