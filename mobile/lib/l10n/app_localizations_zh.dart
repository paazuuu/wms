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
  String get languageTooltip => '选择语言';

  @override
  String get textSizeMenu => '文字大小';

  @override
  String get textSizeNormal => '标准';

  @override
  String get textSizeLarge => '大';

  @override
  String get textSizeXLarge => '特大';

  @override
  String get textSizeXXLarge => '最大';

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
  String get groupManagement => '管理';

  @override
  String get featInspection => '验货';

  @override
  String get featInspectionDesc => '条码与数量核对、不良记录';

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
  String get loading => '加载中…';

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
  String get fieldPhone => '电话';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldContact => '负责人';

  @override
  String get fieldSupplier => '供应商';

  @override
  String get actionComplete => '完成';

  @override
  String get actionContinue => '继续';

  @override
  String get filterAll => '全部';

  @override
  String get unknownSupplier => '未知供应商';

  @override
  String get pickingEmpty => '无待拣货项。';

  @override
  String get noLinesToPick => '无可拣货明细。';

  @override
  String get unnamedProduct => '未命名商品';

  @override
  String get pickingEmptyBody => '等待履约的销售订单将显示在此处。';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total 已拣';
  }

  @override
  String get quantity => '数量';

  @override
  String get actionCancel => '取消';

  @override
  String get actionRecord => '记录';

  @override
  String get working => '处理中…';

  @override
  String get adjustAdd => '增加';

  @override
  String get adjustRemove => '减少';

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
  String get deliveryStatusPartial => '部分送货';

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
  String get scanDeliveryHint => '扫描商品JAN';

  @override
  String get ocrAssist => '拍摄到货单（OCR）';

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
  String get reconReceivedPrev => '已收';

  @override
  String get reconThisTime => '本次';

  @override
  String get reconRemaining => '余';

  @override
  String get completeReconcile => '完成核对';

  @override
  String get reconcileConfirmQ => '完成本次核对？';

  @override
  String get reconcileConfirmBody => '提交当前计数并结束本次核对。';

  @override
  String get reconcileConfirmDiscrepancy => '存在差异（不足・超量・计划外）。仍要完成吗？';

  @override
  String get reconcilePartialQ => '仍有未送达的项目';

  @override
  String reconcilePartialBody(int count) {
    return '还有 $count 件未送达。要存为部分送货并把其余保留在未送达清单中，还是现在标记完成并把其余视为缺货？';
  }

  @override
  String get reconcileKeepOpen => '存为部分送货';

  @override
  String get reconcileFinalizeShort => '标记完成（其余缺货）';

  @override
  String get reconcilePartialSaved => '已存为部分送货（保留未送达项目）';

  @override
  String get reconNoteReference => '备注';

  @override
  String get reconAlreadyDoneQ => '该计划已核对';

  @override
  String get reconAlreadyDoneBody => '再次录入会重复加入库存。如需更正，请在收货记录中取消对应的收货。';

  @override
  String doubleScanWarning(String code) {
    return '$code 已超过计划数量（重复扫描？）';
  }

  @override
  String get receiptHistoryTitle => '收货记录／更正';

  @override
  String get receiptEmpty => '暂无收货记录。';

  @override
  String get receiptEmptyBody => '每次核对该计划都会在此记录收货，并可取消。';

  @override
  String get receiptCancelAction => '取消收货';

  @override
  String get receiptCancelledBadge => '已取消';

  @override
  String get receiptCancelQ => '要取消这次收货吗？';

  @override
  String get receiptCancelBody => '将回退这次收货加入的数量和库存。';

  @override
  String get receiptCancelledDone => '已取消收货';

  @override
  String get showCompletedPlans => '显示已核对';

  @override
  String get hideCompletedPlans => '隐藏已核对';

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
  String get planImportTitle => '导入计划';

  @override
  String get planImportHint => '选择 Excel / PDF / 图片上传，系统会自动解析并登记为计划。';

  @override
  String get planImportChooseFirst => '请选择文件并输入单号。';

  @override
  String planImportedSummary(int count, int total) {
    return '已导入 $count 项，共 $total 件';
  }

  @override
  String get planReadAction => '读取送货单';

  @override
  String get planReading => '读取中…';

  @override
  String get importFormatsHint => '支持 Excel / PDF / 图片';

  @override
  String get importChooseFile => '选择文件';

  @override
  String get changeFile => '更改';

  @override
  String get importHeaderSection => '抬头信息';

  @override
  String get importLinesPreview => '明细预览';

  @override
  String importMoreLines(int count) {
    return '还有 $count 项';
  }

  @override
  String get planReviewTitle => '核对抬头';

  @override
  String get planReviewHint => '已从送货单自动读取。登记前可在此修改错误或空白的字段。';

  @override
  String get planCommitAction => '登记';

  @override
  String get planRegistering => '登记中…';

  @override
  String planPreviewCount(int count, int total) {
    return '$count 项 · $total 件';
  }

  @override
  String get fieldRegistrationNumber => '登记号（T…）';

  @override
  String get fieldCustomerCode => '客户代码';

  @override
  String get fieldDocNumber => '送货单号';

  @override
  String get headerUnreadHint => '无法读取，请手动输入';

  @override
  String get planNeedsReviewBadge => '待确认';

  @override
  String get planUnidentifiedNote =>
      '未能读取公司名称，已归入“UNKNOWN”识别号序列。输入供应商即可重新归属到正确公司。';

  @override
  String get referenceNoLabel => '整理号';

  @override
  String get companyCode => '公司代码';

  @override
  String get totalStockTitle => '总库存（按JAN）';

  @override
  String get sortMenu => '排序';

  @override
  String get sortByStock => '按库存';

  @override
  String get sortByName => '按品名';

  @override
  String get sortByJan => '按JAN';

  @override
  String get stockOnHandUnit => '库存';

  @override
  String get stockEmpty => '暂无库存。';

  @override
  String get stockEmptyBody => '完成核对后，各JAN的总库存会在此汇总。';

  @override
  String get featShipment => '出库';

  @override
  String get featShipmentDesc => '导入出库清单，分装到纸箱并扣减库存';

  @override
  String get shipmentListTitle => '出库';

  @override
  String get shipmentImportTitle => '导入出库清单';

  @override
  String get shipmentEmpty => '暂无出库。';

  @override
  String get shipmentEmptyBody => '导入客户的 Excel / PDF 以开始出库。';

  @override
  String get shipmentSearchHint => '按出库号或客户搜索';

  @override
  String get shipmentStatusOpen => '待装箱';

  @override
  String get shipmentStatusPacking => '装箱中';

  @override
  String get shipmentStatusShipped => '已出库';

  @override
  String get shipmentStatusCancelled => '已取消';

  @override
  String cartonCountLabel(int count) {
    return '$count 箱';
  }

  @override
  String get shipmentLinesSection => '出库清单';

  @override
  String get cartonsSection => '纸箱';

  @override
  String packProgress(int packed, int total) {
    return '已装 $packed / $total';
  }

  @override
  String get addCarton => '添加纸箱';

  @override
  String cartonNoLabel(int no) {
    return '纸箱 #$no';
  }

  @override
  String get cartonLabelHint => '标签（可选）例: A-1';

  @override
  String get cartonEditTitle => '纸箱内容';

  @override
  String get packRemaining => '未装箱';

  @override
  String get packThisCarton => '本箱';

  @override
  String get overpackWarning => '装箱数量超过出库数量。';

  @override
  String get shipConfirmAction => '确认出库';

  @override
  String get shipConfirmQ => '确认这次出库吗？';

  @override
  String get shipConfirmBody => '将从库存中扣除数量并确认出库。';

  @override
  String get shipShortWarning => '部分物品超过现有库存。库存不会降到零以下。仍要确认吗？';

  @override
  String get shipDone => '出库已确认';

  @override
  String get shipCancelAction => '撤销出库';

  @override
  String get shipCancelQ => '撤销这次出库吗？';

  @override
  String get shipCancelBody => '将把扣除的数量加回库存，并把出库重置为未确认。';

  @override
  String get shipCancelledDone => '出库已重置为未确认';

  @override
  String get printOverall => '打印/PDF 清单';

  @override
  String get printAllCartons => '打印/PDF 纸箱';

  @override
  String get printThisCarton => '打印/PDF';

  @override
  String get printDeliverySlip => '打印/PDF 送货单';

  @override
  String get printMenu => '打印/PDF';

  @override
  String get senderSettingsTitle => '寄件人（本公司）设置';

  @override
  String get senderSettingsHint => '保存为默认寄件人。每次打印时可选择包含哪些项目。';

  @override
  String get senderPickTitle => '本次打印的寄件人';

  @override
  String get senderInclude => '打印寄件人信息';

  @override
  String get senderNoneSet => '尚未设置寄件人。';

  @override
  String get senderSaved => '已保存寄件人信息';

  @override
  String get senderPreview => '打印预览';

  @override
  String get fieldCompanyName => '公司名称';

  @override
  String get fieldPostalCode => '邮编';

  @override
  String get fieldFax => '传真';

  @override
  String get fieldNote => '备注';

  @override
  String get deleteCartonQ => '删除这个纸箱吗？';

  @override
  String get actionSave => '保存';

  @override
  String get actionDelete => '删除';

  @override
  String get dashOverview => '概况';

  @override
  String get dashInboundToday => '今日入库';

  @override
  String get dashOutboundToday => '今日出库';

  @override
  String get dashOutstanding => '未交';

  @override
  String get dashTotalStock => '总库存';

  @override
  String get dashLowStock => '库存预警';

  @override
  String get dashTrendTitle => '出入库趋势（14天）';

  @override
  String get dashInbound => '入库';

  @override
  String get dashOutbound => '出库';

  @override
  String get dashOutstandingListTitle => '未交清单';

  @override
  String get dashLowStockListTitle => '库存预警';

  @override
  String get dashNoOutstanding => '没有未交';

  @override
  String get dashNoAlerts => '没有库存预警';

  @override
  String dashCount(int count) {
    return '$count 件';
  }

  @override
  String dashSkuCount(int count) {
    return '$count 个SKU';
  }

  @override
  String dashThreshold(int count) {
    return '阈值 $count';
  }

  @override
  String get whAllWarehouses => '全部仓库';

  @override
  String get whSwitch => '切换仓库';

  @override
  String get whAdd => '添加仓库';

  @override
  String get whAddTitle => '添加仓库';

  @override
  String get whManage => '仓库管理';

  @override
  String get whOverviewTitle => '仓库列表';

  @override
  String get whTotals => '合计';

  @override
  String get whFieldCode => '仓库编码';

  @override
  String get whFieldName => '仓库名称';

  @override
  String get whFieldAddress => '地址';

  @override
  String get whFieldPhone => '电话';

  @override
  String get whFieldTimezone => '时区';

  @override
  String get whFieldActive => '启用';

  @override
  String get whFieldDefaultBins => '创建初始库位';

  @override
  String get whFieldDefaultBinsHelp => '自动创建暂存、质检暂留、出货和普通库位4个。';

  @override
  String get whFieldReceivingBin => '默认收货区';

  @override
  String get whFieldShippingBin => '默认发货区';

  @override
  String get whCodeRequired => '请输入仓库编码';

  @override
  String get whNameRequired => '请输入仓库名称';

  @override
  String whCreated(String name) {
    return '已添加仓库「$name」';
  }

  @override
  String get whInactive => '停用';

  @override
  String get whStatInbound => '待入库';

  @override
  String get whStatOutbound => '待出库';

  @override
  String get whStatSku => 'SKU';

  @override
  String get whStatOnHand => '库存';

  @override
  String get whNoWarehouses => '还没有仓库';

  @override
  String get whBinsTitle => '库位';

  @override
  String get whBinStaging => '暂存';

  @override
  String get whBinPickable => '普通库位';

  @override
  String get whBinPickableStaging => '暂存(可拣)';

  @override
  String get whBinQcHold => '质检暂留';

  @override
  String get whBinShipping => '出货';

  @override
  String get whBinReturns => '退货';

  @override
  String get whBinDamaged => '破损';

  @override
  String get whBinVirtual => '虚拟';

  @override
  String get ledgerTitle => '库存履历';

  @override
  String get ledgerSubtitle => '该商品库存变动的原因';

  @override
  String get ledgerEmpty => '暂无库存变动';

  @override
  String get ledgerBeforeAfter => '变更前 → 变更后';

  @override
  String get mvOpening => '期初';

  @override
  String get mvReceipt => '入库';

  @override
  String get mvReceiptCancel => '入库取消';

  @override
  String get mvPutaway => '上架';

  @override
  String get mvPick => '拣货';

  @override
  String get mvShip => '出库';

  @override
  String get mvShipCancel => '出库取消';

  @override
  String get mvAdjust => '库存调整';

  @override
  String get mvCount => '盘点';

  @override
  String get mvTransferIn => '调拨入库';

  @override
  String get mvTransferOut => '调拨出库';

  @override
  String get qcTitle => '验货';

  @override
  String get qcListEmpty => '还没有验货记录';

  @override
  String get qcListEmptyBody => '可从收货履历开始验货。';

  @override
  String get qcStart => '开始验货';

  @override
  String get qcComplete => '确认验货';

  @override
  String get qcResultPending => '未验';

  @override
  String get qcResultPass => '合格';

  @override
  String get qcResultFail => '不合格';

  @override
  String get qcResultPartial => '部分合格';

  @override
  String get qcResultHold => '暂留';

  @override
  String get qcPassed => '合格数';

  @override
  String get qcFailed => '不良数';

  @override
  String get qcExpected => '预定';

  @override
  String get qcActual => '实数';

  @override
  String get qcDiscrepancy => '差异';

  @override
  String get qcLot => '批次';

  @override
  String get qcNote => '备注';

  @override
  String get qcHold => '设为暂留';

  @override
  String get qcRecord => '记录';

  @override
  String qcUnchecked(int count) {
    return '未验 $count 条';
  }

  @override
  String get qcCompleteBlocked => '仍有未验明细，无法确认';

  @override
  String qcCompleted(String status) {
    return '验货已确认（$status）';
  }

  @override
  String qcFailedUnits(int count) {
    return '不良 $count';
  }

  @override
  String get qcSplitHint => '请输入合格数与不良数（合计即为实数）。';

  @override
  String get qcAttachmentsEmpty => '暂无照片';

  @override
  String get qcAttachmentCamera => '拍照';

  @override
  String get qcAttachmentGallery => '从相册选择';

  @override
  String get whFieldUsesLocations => '按库位管理';

  @override
  String get whFieldUsesLocationsHelp => '关闭时按仓库整体管理库存。仅在需要按货架管理时开启（之后可更改）。';

  @override
  String get whLocationsOn => '库位管理';

  @override
  String get adjTitle => '库存调整';

  @override
  String get adjNew => '调整库存';

  @override
  String get adjEmpty => '还没有调整记录';

  @override
  String get adjEmptyBody => '可按破损、丢失、找到等原因修正库存。';

  @override
  String get adjJan => 'JAN编码';

  @override
  String get adjQuantity => '数量';

  @override
  String get adjReason => '原因';

  @override
  String get adjNote => '备注';

  @override
  String get adjApply => '确认调整';

  @override
  String adjDone(String delta) {
    return '库存已调整（$delta）';
  }

  @override
  String get adjNeedsWarehouse => '请先选择仓库';

  @override
  String get adjJanRequired => '请输入JAN编码';

  @override
  String get adjDeltaRequired => '请输入1以上的数量';

  @override
  String get reasonDamage => '破损';

  @override
  String get reasonLoss => '丢失';

  @override
  String get reasonFound => '找到';

  @override
  String get reasonCorrection => '录入更正';

  @override
  String get reasonReturn => '退货入库';

  @override
  String get reasonOther => '其他';

  @override
  String get cntTitle => '盘点';

  @override
  String get cntEmpty => '还没有盘点记录';

  @override
  String get cntEmptyBody => '开始盘点时会冻结当前库存作为对照。';

  @override
  String get cntStart => '开始盘点';

  @override
  String get cntBlind => '盲盘';

  @override
  String get cntBlindHelp => '盘点完成前不显示理论库存，避免先入为主。';

  @override
  String get cntSystem => '理论';

  @override
  String get cntCounted => '实盘';

  @override
  String get cntVariance => '差异';

  @override
  String get cntHidden => '确认前不显示';

  @override
  String get cntRecord => '输入实盘数';

  @override
  String get cntComplete => '确认盘点';

  @override
  String get cntCancel => '中止盘点';

  @override
  String get cntCompleteQ => '要确定本次盘点吗？';

  @override
  String get cntCompleteBody => '仅对存在差异的行修正库存，并记录为盘点变动。';

  @override
  String get cntCancelQ => '要中止本次盘点吗？';

  @override
  String get cntCancelBody => '已盘点的数值将被丢弃，库存保持不变。';

  @override
  String get cntCancelled => '已中止盘点';

  @override
  String cntProgress(int counted, int total) {
    return '已盘 $counted/$total';
  }

  @override
  String cntCompleted(int lines, String net) {
    return '盘点已确认（调整$lines行，净变动 $net）';
  }

  @override
  String cntUncountedWarn(int count) {
    return '未盘的 $count 行保持原样（不视为0）';
  }

  @override
  String get cntStatusCounting => '盘点中';

  @override
  String get cntStatusCompleted => '已确认';

  @override
  String get cntStatusCancelled => '已中止';

  @override
  String get pickListsTitle => '拣货';

  @override
  String get pickStart => '开始拣货';

  @override
  String get pickChooseShipment => '选择出库单';

  @override
  String get pickNoShipments => '没有待拣货的出库单';

  @override
  String get pickStatusPicking => '拣货中';

  @override
  String get pickStatusPicked => '已拣货';

  @override
  String get pickStatusCancelled => '已中止';

  @override
  String get pickTaskPending => '未拣货';

  @override
  String get pickTaskPicked => '已完成';

  @override
  String get pickTaskShort => '不足';

  @override
  String get pickTaskOver => '超出';

  @override
  String get pickPlanned => '计划';

  @override
  String get pickPickedQty => '拣货数';

  @override
  String get pickVariance => '差异';

  @override
  String get pickBin => '库位';

  @override
  String get pickBinNone => '未指定';

  @override
  String get pickRecord => '记录拣货数';

  @override
  String get pickComplete => '完成拣货';

  @override
  String get pickCompleteQ => '要完成本次拣货吗？';

  @override
  String get pickCompleteBody => '订单将进入打包阶段，出库需另行确认。';

  @override
  String get pickCancelAction => '中止拣货';

  @override
  String get pickCancelQ => '要中止本次拣货吗？';

  @override
  String get pickCancelBody => '已记录的数量将被丢弃，库存保持不变。';

  @override
  String get pickCancelled => '已中止拣货';

  @override
  String pickCompleted(int short, int over) {
    return '拣货已完成（不足$short件・超出$over件）';
  }

  @override
  String get pickCompleteBlocked => '存在未拣货的明细，无法完成';

  @override
  String get transferTitle => '仓库间调拨';

  @override
  String get transferNew => '新建调拨';

  @override
  String get transferEmpty => '暂无调拨';

  @override
  String get transferEmptyBody => '仓库间的调拨会显示在这里。';

  @override
  String get transferSource => '调出仓库';

  @override
  String get transferDestination => '调入仓库';

  @override
  String get transferNeedsTwoWarehouses => '至少需要两个仓库';

  @override
  String get transferLinesTitle => '调拨商品';

  @override
  String get transferAddLine => '添加商品';

  @override
  String get transferLineJan => 'JAN编码';

  @override
  String get transferLineQuantity => '数量';

  @override
  String get transferLineRequired => '请至少添加一件商品';

  @override
  String get transferNote => '备注';

  @override
  String get transferCreate => '创建调拨';

  @override
  String transferCreated(String number) {
    return '已创建调拨 $number';
  }

  @override
  String get transferStatusDraft => '草稿';

  @override
  String get transferStatusPendingApproval => '待审批';

  @override
  String get transferStatusApproved => '已审批';

  @override
  String get transferStatusPicking => '拣货中';

  @override
  String get transferStatusInTransit => '运输中';

  @override
  String get transferStatusReceiving => '接收中';

  @override
  String get transferStatusCompleted => '已完成';

  @override
  String get transferStatusRejected => '已驳回';

  @override
  String get transferStatusCancelled => '已中止';

  @override
  String get transferSubmit => '提交审批';

  @override
  String get transferSubmitted => '已提交审批';

  @override
  String get transferApprove => '批准';

  @override
  String get transferApproveQ => '要批准此次调拨吗？';

  @override
  String get transferApproved => '调拨已批准';

  @override
  String get transferReject => '驳回';

  @override
  String get transferRejectQ => '要驳回此次调拨吗？';

  @override
  String get transferRejected => '调拨已驳回';

  @override
  String get transferCancelAction => '中止调拨';

  @override
  String get transferCancelBody => '库存尚未变动，中止不会影响库存。';

  @override
  String get transferCancelled => '调拨已中止';

  @override
  String get transferStartPicking => '开始拣货';

  @override
  String get transferPickQty => '拣货数';

  @override
  String transferPickProgress(int picked, int total) {
    return '$picked / $total 已拣货';
  }

  @override
  String get transferCompletePicking => '确认出库';

  @override
  String transferCompletePickingBody(String source) {
    return '将从$source扣减已拣数量，并切换为运输中。';
  }

  @override
  String get transferPickIncomplete => '存在未拣货的明细，无法确认出库';

  @override
  String get transferStartReceiving => '开始接收';

  @override
  String get transferReceiveQty => '接收数';

  @override
  String transferReceiveProgress(int received, int total) {
    return '$received / $total 已接收';
  }

  @override
  String get transferCompleteReceiving => '确认接收';

  @override
  String transferCompleteReceivingBody(String destination) {
    return '将把接收数量加到$destination，并完成本次调拨。';
  }

  @override
  String get transferReceiveIncomplete => '存在未接收的明细，无法确认接收';

  @override
  String transferCompleted(int loss) {
    return '调拨已完成（$loss行存在数量差异）';
  }

  @override
  String get transferPlanned => '计划';

  @override
  String get transferLineProductName => '商品名称（可选）';

  @override
  String get featTransfer => '仓库间调拨';

  @override
  String get featTransferDesc => '在仓库之间调拨库存';

  @override
  String get auditTitle => '审计日志';

  @override
  String get auditEmpty => '暂无审计记录';

  @override
  String get auditEmptyBody => '批准、驳回、中止等操作会记录在这里。';

  @override
  String get auditExport => '导出CSV';

  @override
  String get auditExported => '已保存CSV';

  @override
  String get auditExportFailed => 'CSV导出失败';

  @override
  String get auditEntity => '对象';

  @override
  String get auditActor => '操作人';

  @override
  String get auditActorSystem => '系统';

  @override
  String get csvExportTitle => '导出CSV';

  @override
  String get featAuditLog => '审计日志';

  @override
  String get featAuditLogDesc => '查看操作历史并导出CSV';

  @override
  String get featUserManagement => '用户管理';

  @override
  String get featUserManagementDesc => '为已登录的成员分配角色';

  @override
  String get featConnectors => '连接器';

  @override
  String get featConnectorsDesc => '为未来集成而注册的外部系统';

  @override
  String get featAiReview => 'AI 审核';

  @override
  String get featAiReviewDesc => '在生效前确认或拒绝 AI 提取的结果';

  @override
  String get featProducts => '商品主数据';

  @override
  String get featProductsDesc => '按 JAN 码管理商品名称、分类与价格';

  @override
  String get featPurchaseOrders => '采购订单';

  @override
  String get featPurchaseOrdersDesc => '创建、审批并管理对供应商的订单';

  @override
  String get poTitle => '采购订单';

  @override
  String get poNew => '新建采购订单';

  @override
  String get poEmpty => '暂无采购订单';

  @override
  String get poEmptyBody => '点击下方按钮创建一个。';

  @override
  String get poNeedsWarehouse => '尚无仓库';

  @override
  String get poSupplierName => '供应商名称';

  @override
  String get poWarehouse => '入库仓库';

  @override
  String get poExpectedDate => '预计到货日';

  @override
  String get poLinesTitle => '明细';

  @override
  String get poAddLine => '添加明细';

  @override
  String get poNote => '备注';

  @override
  String get poSupplierRequired => '请输入供应商名称';

  @override
  String get poLineRequired => '请至少添加一条明细';

  @override
  String get poCreate => '创建';

  @override
  String get poLineJan => 'JAN 码';

  @override
  String get poLineProductName => '商品名';

  @override
  String get poLineQuantity => '数量';

  @override
  String get poLineUnitPrice => '单价';

  @override
  String get poTotalAmount => '金额';

  @override
  String get poSubmit => '提交';

  @override
  String get poSubmitted => '采购订单已提交';

  @override
  String get poApprove => '批准';

  @override
  String get poApproveQ => '批准此采购订单？';

  @override
  String get poApproved => '采购订单已批准';

  @override
  String get poReject => '驳回';

  @override
  String get poRejectQ => '驳回此采购订单？';

  @override
  String get poRejected => '采购订单已驳回';

  @override
  String get poCancelAction => '取消订单';

  @override
  String get poCancelBody => '取消此采购订单？';

  @override
  String get poCancelled => '采购订单已取消';

  @override
  String get poComplete => '标记完成';

  @override
  String get poCompleteQ => '将此采购订单标记为完成？库存不会变动。';

  @override
  String get poCompleted => '采购订单已完成';

  @override
  String get poStatusDraft => '草稿';

  @override
  String get poStatusSubmitted => '已提交';

  @override
  String get poStatusApproved => '已批准';

  @override
  String get poStatusRejected => '已驳回';

  @override
  String get poStatusCancelled => '已取消';

  @override
  String get poStatusCompleted => '已完成';

  @override
  String get productsTitle => '商品主数据';

  @override
  String get productsShowInactive => '显示已停用商品';

  @override
  String get productsSearchHint => '按商品名或 JAN 码搜索';

  @override
  String get productsEmpty => '暂无商品';

  @override
  String get productsEmptyBody => '点击右下角的 + 添加商品。';

  @override
  String get productActive => '启用';

  @override
  String get productInactive => '停用';

  @override
  String get productNewTitle => '新增商品';

  @override
  String get productEditTitle => '编辑商品';

  @override
  String get productJanCode => 'JAN 码';

  @override
  String get productName => '商品名';

  @override
  String get productCategory => '分类';

  @override
  String get productPrice => '价格';

  @override
  String get productSave => '保存';

  @override
  String get productValidationRequired => '请输入 JAN 码和商品名';

  @override
  String get dashTodayTasks => '今日工作';

  @override
  String get taskPackingWait => '待打包';

  @override
  String get taskShippingWait => '待出库';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '按JAN、单据编号或往来单位名称搜索';

  @override
  String get searchNoQuery => '可跨入库、出库、调拨和商品进行搜索。';

  @override
  String get searchEmpty => '没有匹配结果';

  @override
  String get searchEmptyBody => '请尝试其他关键词。';

  @override
  String get searchKindStock => '商品';

  @override
  String get searchKindDelivery => '入库';

  @override
  String get searchKindShipment => '出库';

  @override
  String get searchKindPickList => '拣货';

  @override
  String get searchKindTransfer => '调拨';

  @override
  String get userMgmtTitle => '用户管理';

  @override
  String get userMgmtEmpty => '暂无用户';

  @override
  String get userMgmtEmptyBody => '成员首次登录后将显示在此处。';

  @override
  String get userMgmtAddRole => '添加角色';

  @override
  String get userMgmtNoRoles => '尚未分配角色';

  @override
  String get userMgmtAllRolesHeld => '该用户已拥有所有角色。';

  @override
  String get userMgmtRemoveRoleTitle => '移除角色？';

  @override
  String userMgmtRemoveRoleBody(String role, String name) {
    return '确定要从 $name 移除 $role 吗？';
  }

  @override
  String get userMgmtRemoveRoleAction => '移除';

  @override
  String get userMgmtWarehousesLabel => '仓库权限';

  @override
  String get userMgmtAddWarehouse => '添加仓库';

  @override
  String get userMgmtNoWarehouses => '未分配仓库（管理员可访问所有仓库，其他角色则无法访问任何仓库）';

  @override
  String get userMgmtAllWarehousesHeld => '该用户已拥有所有仓库的权限。';

  @override
  String get userMgmtRemoveWarehouseTitle => '移除仓库权限？';

  @override
  String userMgmtRemoveWarehouseBody(String warehouse, String name) {
    return '确定要从 $name 移除 $warehouse 吗？';
  }

  @override
  String get userMgmtRemoveWarehouseAction => '移除';

  @override
  String get connectorsTitle => '连接器';

  @override
  String get connectorsEmpty => '尚未注册任何连接器';

  @override
  String get connectorsEmptyBody => '注册的外部系统将显示在此处。';

  @override
  String get connectorNoAdapterYet => '尚未实现同步逻辑——此处仅注册连接信息，不会进行任何同步。';

  @override
  String get connectorEnabled => '已启用';

  @override
  String get connectorDisabled => '已停用';

  @override
  String get connectorNeverRun => '尚无运行记录';

  @override
  String get aiReviewTitle => 'AI 审核';

  @override
  String get aiReviewEmpty => '暂无待审核结果';

  @override
  String get aiReviewEmptyBody => 'AI 提取的结果会显示在此处，直到有人确认或拒绝。';

  @override
  String aiReviewLinesCount(int count) {
    return '提取了 $count 行';
  }

  @override
  String get aiReviewConfirm => '确认';

  @override
  String get aiReviewReject => '拒绝';

  @override
  String get aiReviewRejectTitle => '拒绝该结果？';

  @override
  String get aiReviewRejectHint => '原因（可选）';

  @override
  String get aiReviewConfirmed => '已确认';

  @override
  String get aiReviewRejected => '已拒绝';
}
