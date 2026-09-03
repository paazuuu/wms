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

  @override
  String get unknownSupplier => '未知供应商';

  @override
  String get receivingEmpty => '无待收货项。';

  @override
  String get receivingEmptyBody => '已发送或部分收货的采购单将显示在此处。';

  @override
  String get receivingDone => '无剩余待收货。';

  @override
  String get fieldQtyToReceive => '收货数量';

  @override
  String get receiveStock => '收货入库';

  @override
  String get actionReceive => '收货';

  @override
  String get receivingInProgress => '收货中…';

  @override
  String get emptyInspections => '暂无验货。';

  @override
  String get inspectionsEmptyBody => '下拉刷新，或从采购收货开始一项。';

  @override
  String get pickingEmpty => '无待拣货项。';

  @override
  String get noLinesToPick => '无可拣货明细。';

  @override
  String get orderNoLineItems => '此订单无明细。';

  @override
  String get unnamedProduct => '未命名商品';

  @override
  String get pickListTitle => '拣货单';

  @override
  String get customReport => '自定义报表';

  @override
  String get emptyReports => '暂无已保存报表。';

  @override
  String get reportsEmptyBody => '在后台保存的报表将显示在此处。';

  @override
  String get reportShared => '已共享';

  @override
  String columnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 列',
    );
    return '$_temp0';
  }

  @override
  String get allLocations => '全部库位';

  @override
  String get emptyStockCounts => '暂无盘点。';

  @override
  String get pickingEmptyBody => '等待履约的销售订单将显示在此处。';

  @override
  String get stockCountsEmptyBody => '在后台创建的循环盘点将显示在此处。';

  @override
  String get receivingDoneBody => '此采购单的所有明细均已收货。';

  @override
  String receiveInvalidQty(String product) {
    return '请为“$product”输入有效数量。';
  }

  @override
  String receiveExceedsRemaining(String product, int remaining) {
    return '$product：收货不能超过剩余 $remaining。';
  }

  @override
  String get receiveEnterAtLeastOne => '请至少在一行输入收货数量。';

  @override
  String get receiveSuccess => '已收货。已自动开始验货。';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total 已拣';
  }

  @override
  String get attachFiles => '添加附件';

  @override
  String get cameraLabel => '相机';

  @override
  String get scanToRecord => '扫描商品条码以记录';

  @override
  String get scanToRecordQty1 => '扫描以记录（数量 1）';

  @override
  String get fastModeOnTooltip => '快速模式：每次扫描按数量 1 记录';

  @override
  String get fastModeOffTooltip => '每次扫描时输入数量';

  @override
  String get fastQtyOneLabel => '数量 1';

  @override
  String get actualQuantity => '实际数量';

  @override
  String scannedCode(String code) {
    return '已扫描：$code';
  }

  @override
  String get quantity => '数量';

  @override
  String get actionCancel => '取消';

  @override
  String get actionRecord => '记录';

  @override
  String get itemRecorded => '已记录该项';

  @override
  String get offlineItemQueued => '离线 — 该项已加入同步队列';

  @override
  String filesUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已上传 $count 个文件',
    );
    return '$_temp0';
  }

  @override
  String offlineFilesQueued(int count) {
    return '离线 — $count 个文件已加入同步队列';
  }

  @override
  String get completeInspectionQ => '完成验货？';

  @override
  String get completeInspectionBody => '将此验货标记为完成。完成后仍可查看。';

  @override
  String get inspectionCompleted => '验货已完成';

  @override
  String get offlineCompletionQueued => '离线 — 完成操作已加入同步队列';

  @override
  String get sectionItems => '项目';

  @override
  String get sectionAttachments => '附件';

  @override
  String get noItemsYet => '尚无项目。点击扫描以记录一项。';

  @override
  String get noAttachments => '暂无附件。使用回形针添加照片或文件。';

  @override
  String get completeInspection => '完成验货';

  @override
  String completedOn(String date) {
    return '完成于 $date';
  }

  @override
  String get actualLabel => '实际';

  @override
  String itemNumber(int id) {
    return '项目 $id';
  }

  @override
  String get working => '处理中…';

  @override
  String get adjustAdd => '增加';

  @override
  String get adjustRemove => '减少';

  @override
  String get reasonType => '原因类型';

  @override
  String get reasonOptional => '原因（可选）';

  @override
  String get notesOptional => '备注（可选）';

  @override
  String get onHandAfter => '调整后库存';

  @override
  String get saving => '保存中…';

  @override
  String get addStock => '增加库存';

  @override
  String get removeStock => '减少库存';

  @override
  String onHandCount(int count) {
    return '现有库存 $count';
  }

  @override
  String get enterQtyPositive => '请输入大于零的数量。';

  @override
  String cannotRemoveOnly(int qty, int current) {
    return '无法减少 $qty；现有库存仅 $current。';
  }

  @override
  String stockUpdatedTo(int count) {
    return '库存已更新 — 现有 $count。';
  }

  @override
  String get adjustTypeManual => '手动';

  @override
  String get adjustTypeCount => '盘点';

  @override
  String get adjustTypeDamage => '破损';

  @override
  String get adjustTypeReturn => '退货';

  @override
  String get adjustTypeTransfer => '移库';

  @override
  String get sectionBatches => '批次';

  @override
  String get sectionSerials => '序列号';

  @override
  String get noBatches => '此商品暂无批次。';

  @override
  String get noSerials => '此商品暂无序列号。';

  @override
  String get loadingBatches => '加载批次中…';

  @override
  String get loadingSerials => '加载序列号中…';

  @override
  String get batchExpired => '已过期';

  @override
  String get batchValid => '有效';

  @override
  String get fieldExpiry => '有效期';

  @override
  String get report => '报表';

  @override
  String get runningReport => '运行报表中…';

  @override
  String get noData => '暂无数据。';

  @override
  String get reportNoRows => '此报表未返回任何行。';

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
  String get scanBarcode => '扫描条码';

  @override
  String get torchOn => '打开手电';

  @override
  String get torchOff => '关闭手电';

  @override
  String get alignBarcode => '将条码对准框内';

  @override
  String get scanOrTypeBarcode => '扫描或输入条码';

  @override
  String get featDelivery => '到货核对';

  @override
  String get featDeliveryDesc => '核对到货单与Excel计划，显示过不足';

  @override
  String get deliveryStatusOpen => '待核对';

  @override
  String get deliveryStatusReconciling => '核对中';

  @override
  String get deliveryStatusCompleted => '已核对';

  @override
  String get reconPending => '待确认';

  @override
  String get reconMatched => '一致';

  @override
  String get reconShortfall => '不足';

  @override
  String get reconOver => '超量';

  @override
  String get reconUnexpected => '计划外';

  @override
  String get deliveryPlansTitle => '到货核对';

  @override
  String get deliveryPlansEmpty => '暂无到货计划。';

  @override
  String get deliveryPlansEmptyBody => '在后台从Excel导入的到货计划将显示在此处。';

  @override
  String get deliveryPlansHint => '扫描或按单号/供应商搜索';

  @override
  String get deliveryNoMatches => '无匹配的到货计划。';

  @override
  String get deliverySearchTip => '请尝试其他单号或供应商。';

  @override
  String plannedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '计划明细 $count 项',
    );
    return '$_temp0';
  }

  @override
  String get deliveryNumberLabel => '单号';

  @override
  String get deliveryDateLabel => '到货日';

  @override
  String get scanDeliveryHint => '扫描商品JAN';

  @override
  String get ocrAssist => '拍摄到货单（OCR）';

  @override
  String get ocrScanning => '解析到货单中…';

  @override
  String ocrFound(int count) {
    return '从到货单检测到 $count 个JAN';
  }

  @override
  String get ocrNoneFound => '未能从到货单识别JAN。';

  @override
  String get ocrUnavailable => '此设备无法使用OCR。';

  @override
  String get reconSummaryTitle => '核对情况';

  @override
  String get deliveryPlanned => '计划';

  @override
  String get diffLabel => '差';

  @override
  String get completeReconcile => '完成核对';

  @override
  String get reconcileConfirmQ => '完成本次核对？';

  @override
  String get reconcileConfirmBody => '提交当前计数并结束本次核对。';

  @override
  String get reconcileConfirmDiscrepancy => '存在差异（不足・超量・计划外）。仍要完成吗？';

  @override
  String get reconcileDone => '核对已完成';

  @override
  String get reconcileEmptyCounts => '尚无计数。扫描以开始。';

  @override
  String get unexpectedItem => '计划外商品';

  @override
  String enterQuantityFor(String code) {
    return '$code 的数量';
  }

  @override
  String get noteImageAttached => '已附加到货单';

  @override
  String get planImportTitle => '导入计划';

  @override
  String get planImportHint => '选择 Excel / PDF / 图片上传，系统会自动解析并登记为计划。';

  @override
  String get pickFile => '选择文件';

  @override
  String planImportSelected(String name) {
    return '已选择：$name';
  }

  @override
  String get planImportAction => '导入';

  @override
  String get planImporting => '导入中…';

  @override
  String get planImportChooseFirst => '请选择文件并输入单号。';

  @override
  String planImportedSummary(int count, int total) {
    return '已导入 $count 项，共 $total 件';
  }
}
