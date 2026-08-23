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

  @override
  String get loading => '加载中…';

  @override
  String get emptyLocations => '暂无库位。';

  @override
  String get emptyWarehouses => '暂无仓库。';

  @override
  String get emptySuppliers => '暂无供应商。';

  @override
  String get emptySalesOrders => '暂无销售订单。';

  @override
  String get emptyPurchaseOrders => '暂无采购单。';

  @override
  String get emptyWorkOrders => '暂无工单。';

  @override
  String get tryDifferentNameCode => '请尝试其他名称或代码。';

  @override
  String get tryDifferentOrder => '请尝试其他订单号或客户。';

  @override
  String get tryDifferentPo => '请尝试其他采购单号或供应商。';

  @override
  String get tryDifferentWo => '请尝试其他工单号、商品或 SKU。';

  @override
  String get hintLocations => '扫描或按名称、代码搜索';

  @override
  String get hintWarehouses => '扫描或按名称、代码或城市搜索';

  @override
  String get hintSuppliers => '扫描或按名称、代码、联系人或邮箱搜索';

  @override
  String get hintSalesOrders => '扫描或按订单号、客户或邮箱搜索';

  @override
  String get hintPurchaseOrders => '扫描或按采购单号或供应商搜索';

  @override
  String get hintWorkOrders => '扫描或按工单号、商品或 SKU 搜索';

  @override
  String get warehouseDefault => '默认';

  @override
  String get noCustomer => '无客户';

  @override
  String get noSupplier => '无供应商';

  @override
  String get noProduct => '无商品';

  @override
  String qtyLabel(int quantity) {
    return '数量 $quantity';
  }

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 行',
    );
    return '$_temp0';
  }

  @override
  String get statusActive => '启用';

  @override
  String get statusInactive => '停用';

  @override
  String get statusCancelled => '已取消';

  @override
  String get statusDraft => '草稿';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusInProgress => '进行中';

  @override
  String get statusPending => '待处理';

  @override
  String get salesProcessing => '处理中';

  @override
  String get salesShipped => '已发货';

  @override
  String get salesDelivered => '已送达';

  @override
  String get poSent => '已发送';

  @override
  String get poPartiallyReceived => '部分收货';

  @override
  String get poReceived => '已收货';

  @override
  String get stockIn => '有库存';

  @override
  String get stockLow => '库存不足';

  @override
  String get stockOut => '无库存';

  @override
  String get inspectionPassed => '合格';

  @override
  String get inspectionFailed => '不合格';

  @override
  String get matchOk => 'OK';

  @override
  String get matchNg => 'NG';

  @override
  String get typeReceiving => '收货';

  @override
  String get typeShipping => '出货';

  @override
  String get typeOther => '其他';

  @override
  String get titleProduct => '商品';

  @override
  String get fieldDescription => '描述';

  @override
  String get fieldPhone => '电话';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldStatus => '状态';

  @override
  String get fieldCurrency => '币种';

  @override
  String get fieldCategory => '类别';

  @override
  String get fieldBarcode => '条码';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldPrice => '价格';

  @override
  String get fieldSellingPrice => '售价';

  @override
  String get fieldMinStock => '最低库存';

  @override
  String get fieldOnHand => '现有库存';

  @override
  String get fieldLocation => '库位';

  @override
  String get fieldHasVariants => '有变体';

  @override
  String get fieldManager => '负责人';

  @override
  String get fieldTimezone => '时区';

  @override
  String get fieldPriority => '优先级';

  @override
  String get fieldUsers => '用户';

  @override
  String get fieldLocations => '库位';

  @override
  String get fieldContact => '联系人';

  @override
  String get fieldWebsite => '网站';

  @override
  String get fieldPaymentTerms => '付款条件';

  @override
  String get fieldNotes => '备注';

  @override
  String get fieldProducts => '商品';

  @override
  String get fieldAisle => '通道';

  @override
  String get fieldShelf => '货架';

  @override
  String get fieldBin => '货位';

  @override
  String get fieldCode => '代码';

  @override
  String get fieldFullLocation => '完整库位';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String productCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个商品',
    );
    return '$_temp0';
  }

  @override
  String binCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个货位',
    );
    return '$_temp0';
  }

  @override
  String get fieldCustomer => '客户';

  @override
  String get lineItems => '明细';

  @override
  String get noLineItems => '无明细。';

  @override
  String get fieldOrderDate => '下单日期';

  @override
  String get fieldSubtotal => '小计';

  @override
  String get fieldTax => '税费';

  @override
  String get fieldShipping => '运费';

  @override
  String get fieldTotal => '合计';

  @override
  String get fieldSupplier => '供应商';

  @override
  String get fieldExpected => '预期';

  @override
  String get fieldOrdered => '已订购';

  @override
  String get fieldReceived => '已收货';

  @override
  String get fieldRemaining => '剩余';

  @override
  String get actionComplete => '完成';

  @override
  String get fieldAssemblyProduct => '组装产品';

  @override
  String get fieldComponents => '组件';

  @override
  String get noComponents => '无组件。';

  @override
  String get fieldConsumed => '已消耗';

  @override
  String get fieldProduced => '已生产';

  @override
  String get fieldRequired => '所需';

  @override
  String get fieldTarget => '目标';

  @override
  String get fieldStarted => '开始';

  @override
  String productNumber(int id) {
    return '商品 #$id';
  }

  @override
  String get fieldCountedLines => '已盘点明细';

  @override
  String get noCountedLines => '无已盘点明细。';

  @override
  String get fieldCounted => '已盘点';

  @override
  String get fieldUncounted => '未盘点';

  @override
  String get fieldDiscrepancy => '差异';

  @override
  String get fieldMatch => '一致';

  @override
  String get fieldSystem => '系统';

  @override
  String get fieldName => '名称';

  @override
  String get fieldType => '类型';

  @override
  String get filterAll => '全部';

  @override
  String remainingLeft(int count) {
    return '剩余 $count';
  }

  @override
  String remainingAmount(String amount) {
    return '剩余 $amount';
  }
}
