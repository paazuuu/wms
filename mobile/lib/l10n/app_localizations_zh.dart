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
  String get errorPermissionDenied => '您没有执行此操作的权限。';

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
  String get receiptEmpty => '没有明细';

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
  String get importLinesEmpty => '暂无明细，可通过“添加明细”输入。';

  @override
  String get importAddLine => '添加明细';

  @override
  String get importEditLine => '编辑明细';

  @override
  String get importLineJan => 'JAN 码';

  @override
  String get importLineProduct => '商品名称';

  @override
  String get importLineQuantity => '数量';

  @override
  String get importSplitLine => '拆分该行';

  @override
  String get importMergeDuplicates => '合并相同 JAN';

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
  String get noRoleAssigned => '尚未分配角色权限';

  @override
  String get noRoleAssignedBody => '您已登录，但账号还没有被分配角色，因此暂时没有可用的功能。请联系管理员为您分配权限。';

  @override
  String get whNoAssignedWarehouse => '尚未为您分配仓库';

  @override
  String get whNoAssignedWarehouseBody =>
      '您的账号还没有被分配到任何仓库，因此无法查看库存或进行作业。请联系管理员为您分配仓库。';

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
  String get adjConfirmQ => '确认执行此次调整？';

  @override
  String get adjConfirmIrreversible => '此操作无法撤销。';

  @override
  String get adjConfirmAction => '调整';

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
  String get featSalesOrders => '销售订单';

  @override
  String get featSalesOrdersDesc => '创建、审批并管理来自客户的订单';

  @override
  String get featPartners => '往来单位';

  @override
  String get featPartnersDesc => '管理供应商与客户的联系方式及交易条件';

  @override
  String get featWorkOrders => '工单';

  @override
  String get featWorkOrdersDesc => '组装/套装：消耗部件，产出成品';

  @override
  String get featReports => '报表生成器';

  @override
  String get featReportsDesc => '选择数据源、筛选并保存以便复用';

  @override
  String get reportTitle => '报表生成器';

  @override
  String get reportSource => '数据源';

  @override
  String get reportSourceStockMovements => '库存流水';

  @override
  String get reportSourceInspections => '验货';

  @override
  String get reportSourceTransfers => '仓库间调拨';

  @override
  String get reportSourceShipments => '出库';

  @override
  String get reportSourcePurchaseOrders => '采购订单';

  @override
  String get reportSourceSalesOrders => '销售订单';

  @override
  String get reportSourceWorkOrders => '工单';

  @override
  String get reportSourceAuditLog => '审计日志';

  @override
  String get reportSourceProducts => '商品主数据';

  @override
  String get reportWarehouse => '仓库';

  @override
  String get reportAllWarehouses => '所有仓库';

  @override
  String get reportFilterStatus => '状态（可选）';

  @override
  String get reportFilterJan => 'JAN 码（可选）';

  @override
  String get reportFilterCategory => '分类（可选）';

  @override
  String get reportDateFrom => '起始日期';

  @override
  String get reportDateTo => '结束日期';

  @override
  String get reportRun => '运行';

  @override
  String get reportSave => '保存';

  @override
  String get reportSaveTitle => '保存报表';

  @override
  String get reportName => '报表名称';

  @override
  String get reportSaved => '报表已保存';

  @override
  String get reportEmpty => '没有匹配的数据';

  @override
  String reportRowCount(int count) {
    return '$count 行';
  }

  @override
  String get reportSavedTitle => '已保存的报表';

  @override
  String get reportSavedEmpty => '暂无已保存的报表';

  @override
  String get woTitle => '工单';

  @override
  String get woNew => '新建工单';

  @override
  String get woEmpty => '暂无工单';

  @override
  String get woEmptyBody => '点击下方按钮创建一个。';

  @override
  String get woNeedsWarehouse => '尚无仓库';

  @override
  String get woWarehouse => '作业仓库';

  @override
  String get woOutputTitle => '成品';

  @override
  String get woOutputQuantity => '成品数量';

  @override
  String get woOutputRequired => '请输入成品的 JAN 码和数量';

  @override
  String get woComponentsTitle => '部件';

  @override
  String get woAddComponent => '添加部件';

  @override
  String get woComponentRequired => '请至少添加一个部件';

  @override
  String get woComponentQuantity => '所需数量';

  @override
  String woComponentCount(int count) {
    return '$count 个部件';
  }

  @override
  String get woNote => '备注';

  @override
  String get woCreate => '创建';

  @override
  String get woLineJan => 'JAN 码';

  @override
  String get woLineProductName => '商品名';

  @override
  String get woStart => '开始作业';

  @override
  String get woStarted => '工单已开始';

  @override
  String get woComplete => '标记完成';

  @override
  String get woCompleteQ => '完成此工单？部件库存将被消耗，成品库存将增加。';

  @override
  String get woCompleted => '工单已完成';

  @override
  String get woCancelAction => '取消工单';

  @override
  String get woCancelBody => '取消此工单？';

  @override
  String get woCancelled => '工单已取消';

  @override
  String get woStatusDraft => '草稿';

  @override
  String get woStatusInProgress => '作业中';

  @override
  String get woStatusCompleted => '已完成';

  @override
  String get woStatusCancelled => '已取消';

  @override
  String get partnersTitle => '往来单位';

  @override
  String get partnersSearchHint => '按名称或编码搜索';

  @override
  String get partnersEmpty => '暂无往来单位';

  @override
  String get partnersEmptyBody => '点击右下角的 + 添加。';

  @override
  String get partnerKindAll => '全部';

  @override
  String get partnerKindSupplier => '供应商';

  @override
  String get partnerKindCustomer => '客户';

  @override
  String get partnerKindBoth => '供应商/客户';

  @override
  String get partnerNewTitle => '新增往来单位';

  @override
  String get partnerEditTitle => '编辑往来单位';

  @override
  String get partnerName => '名称';

  @override
  String get partnerCode => '编码';

  @override
  String get partnerContactName => '联系人';

  @override
  String get partnerPhone => '电话';

  @override
  String get partnerEmail => '邮箱';

  @override
  String get partnerAddress => '地址';

  @override
  String get partnerPaymentTerms => '交易条件';

  @override
  String get partnerNotes => '备注';

  @override
  String get partnerSave => '保存';

  @override
  String get partnerValidationRequired => '请输入名称';

  @override
  String get soTitle => '销售订单';

  @override
  String get soNew => '新建销售订单';

  @override
  String get soEmpty => '暂无销售订单';

  @override
  String get soEmptyBody => '点击下方按钮创建一个。';

  @override
  String get soNeedsWarehouse => '尚无仓库';

  @override
  String get soCustomerName => '客户名称';

  @override
  String get soWarehouse => '出库仓库';

  @override
  String get soRequestedShipDate => '期望发货日';

  @override
  String get soLinesTitle => '明细';

  @override
  String get soAddLine => '添加明细';

  @override
  String get soNote => '备注';

  @override
  String get soCustomerRequired => '请输入客户名称';

  @override
  String get soLineRequired => '请至少添加一条明细';

  @override
  String get soCreate => '创建';

  @override
  String get soLineJan => 'JAN 码';

  @override
  String get soLineProductName => '商品名';

  @override
  String get soLineQuantity => '数量';

  @override
  String get soLineUnitPrice => '单价';

  @override
  String get soTotalAmount => '金额';

  @override
  String get soSubmit => '提交';

  @override
  String get soSubmitted => '销售订单已提交';

  @override
  String get soApprove => '批准';

  @override
  String get soApproveQ => '批准此销售订单？';

  @override
  String get soApproved => '销售订单已批准';

  @override
  String get soReject => '驳回';

  @override
  String get soRejectQ => '驳回此销售订单？';

  @override
  String get soRejected => '销售订单已驳回';

  @override
  String get soCancelAction => '取消订单';

  @override
  String get soCancelBody => '取消此销售订单？';

  @override
  String get soCancelled => '销售订单已取消';

  @override
  String get soComplete => '标记完成';

  @override
  String get soCompleteQ => '将此销售订单标记为完成？库存不会变动。';

  @override
  String get soCompleted => '销售订单已完成';

  @override
  String get soStatusDraft => '草稿';

  @override
  String get soStatusSubmitted => '已提交';

  @override
  String get soStatusApproved => '已批准';

  @override
  String get soStatusRejected => '已驳回';

  @override
  String get soStatusCancelled => '已取消';

  @override
  String get soStatusCompleted => '已完成';

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
  String get productDeactivateQ => '停用此商品？';

  @override
  String get productDeactivateBody => '停用后，将无法在入库、出库等操作中选择此商品。';

  @override
  String get productDeactivateAction => '停用';

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
  String aiReviewConfidence(String percent) {
    return '置信度 $percent%';
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

  @override
  String get featPutaway => '上架';

  @override
  String get featPutawayDesc => '将已收货的库存分配到货位';

  @override
  String get nextStepPutaway => '前往上架';

  @override
  String get nextStepPacking => '前往包装';

  @override
  String get nextStepInspection => '前往检验';

  @override
  String get putawayTitle => '上架';

  @override
  String get putawayNeedsWarehouse => '请先选择仓库';

  @override
  String get putawayNeedsWarehouseBody => '上架作业只在单个仓库内进行。请在上方的仓库切换中选择目标仓库。';

  @override
  String get putawayLocationsOff => '该仓库未启用货位管理';

  @override
  String get putawayLocationsOffBody =>
      '不使用货位的仓库没有上架作业。在仓库设置中启用货位管理后，作业会出现在这里。';

  @override
  String get putawayEmpty => '没有待上架的库存';

  @override
  String get putawayEmptyBody => '所有已收货的商品都已分配到货位。';

  @override
  String putawayPendingCount(int count) {
    return '$count 个商品';
  }

  @override
  String get putawayQueueHint => '已收货但尚未分配货位的库存。点击后扫描货位条码。';

  @override
  String get putawayPendingLabel => '待上架';

  @override
  String get putawayNoSuggestion => '无推荐货位';

  @override
  String putawaySuggested(String code) {
    return '推荐：$code';
  }

  @override
  String get putawayScanLocation => '扫描货位';

  @override
  String get putawayScanLocationHint => '扫描货架条码';

  @override
  String putawayBinNotFound(String code) {
    return '该仓库没有名为「$code」的货位';
  }

  @override
  String putawayBinInactive(String code) {
    return '$code 是已停用的货位';
  }

  @override
  String get putawayBinCurrent => '该货位当前库存';

  @override
  String get putawayBinEmpty => '空';

  @override
  String get putawayThisTime => '本次上架数量';

  @override
  String putawayOfPending(int pending) {
    return '/ 剩余 $pending';
  }

  @override
  String get putawayQuantityRequired => '请输入 1 以上的数量';

  @override
  String putawayQuantityTooLarge(int max) {
    return '待上架数量最多为 $max';
  }

  @override
  String get putawayConfirm => '确认上架';

  @override
  String putawayConfirmed(int quantity, String bin, int pendingAfter) {
    return '已将 $quantity 放入 $bin（剩余 $pendingAfter）';
  }

  @override
  String get actionOk => '确定';

  @override
  String scanWrongItem(String expected) {
    return '商品不符（应为 $expected）';
  }

  @override
  String scanExpecting(String expected) {
    return '目标：请将 $expected 对准取景框';
  }

  @override
  String get scanNothingYet => '尚未扫描';

  @override
  String scanAcceptedCount(int count) {
    return '已扫描 $count 件';
  }

  @override
  String get scanResultOk => 'OK';

  @override
  String get scanResultDuplicate => '重复（已忽略）';

  @override
  String get scanResultNg => 'NG';

  @override
  String get scanManualEntry => '手动输入';

  @override
  String get scanManualEntryHint => 'JAN / 条码';

  @override
  String get scanDone => '完成';

  @override
  String get pickScanToConfirm => '请扫描该商品的 JAN 后再确定数量';

  @override
  String get pickScanned => '扫描已确认';

  @override
  String get pickScanAction => '扫描';

  @override
  String get taskInboundPlanned => '预计入库';

  @override
  String get actionEdit => '编辑';

  @override
  String get autopackAction => '自动计算箱数';

  @override
  String autopackTotal(int total) {
    return '总数量 $total';
  }

  @override
  String get autopackPerCarton => '每箱数量';

  @override
  String get autopackHint => '输入每箱可装的数量，系统会算出所需箱数。';

  @override
  String autopackBoxes(int boxes) {
    return '箱数 $boxes';
  }

  @override
  String autopackEven(int per) {
    return '每箱 $per 个';
  }

  @override
  String autopackSplit(int full, int per, int last) {
    return '$full 箱 × $per 个 ＋ 最后一箱 $last 个';
  }

  @override
  String get autopackConfirm => '按此箱数创建';

  @override
  String autopackDone(int boxes, int per) {
    return '已创建 $boxes 箱（每箱 $per 个）';
  }

  @override
  String get printCartonLabels => '打印全部箱标签';

  @override
  String get printThisLabel => '箱标签';

  @override
  String get shipLogisticsSection => '配送信息';

  @override
  String get shipLogisticsUnset => '未填写';

  @override
  String get shipWeight => '重量';

  @override
  String shipWeightKg(double kg) {
    final intl.NumberFormat kgNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String kgString = kgNumberFormat.format(kg);

    return '$kgString kg';
  }

  @override
  String get shipWeightInvalid => '请输入 0 以上的重量';

  @override
  String get shipCarrier => '配送公司';

  @override
  String get shipTracking => '运单号';

  @override
  String get auditEventAiAnalysisCompleted => 'AI 分析完成';

  @override
  String get auditEventAiConfirmed => '已确认 AI 结果';

  @override
  String get auditEventAiRejected => '已拒绝 AI 结果';

  @override
  String get auditEventAttachmentUploaded => '已上传附件';

  @override
  String get auditEventCountCancelled => '盘点已取消';

  @override
  String get auditEventCountCompleted => '盘点已完成';

  @override
  String get auditEventCountStarted => '盘点已开始';

  @override
  String get auditEventInspectionConfirmed => '已确认检验';

  @override
  String get auditEventInspectionStarted => '检验已开始';

  @override
  String get auditEventInventoryAdjusted => '库存已调整';

  @override
  String get auditEventPartnerCreated => '已创建往来单位';

  @override
  String get auditEventPartnerUpdated => '已更新往来单位';

  @override
  String get auditEventPickListCancelled => '拣货已取消';

  @override
  String get auditEventPickListCompleted => '拣货已完成';

  @override
  String get auditEventPickListStarted => '拣货已开始';

  @override
  String get auditEventProductCreated => '已创建商品';

  @override
  String get auditEventProductUpdated => '已更新商品';

  @override
  String get auditEventPurchaseOrderApproved => '采购单已批准';

  @override
  String get auditEventPurchaseOrderCancelled => '采购单已取消';

  @override
  String get auditEventPurchaseOrderCompleted => '采购单已完成';

  @override
  String get auditEventPurchaseOrderCreated => '已创建采购单';

  @override
  String get auditEventPurchaseOrderRejected => '采购单已拒绝';

  @override
  String get auditEventPurchaseOrderSubmitted => '采购单已提交';

  @override
  String get auditEventPutawayConfirmed => '已确认上架';

  @override
  String get auditEventReceivingCancelled => '收货已取消';

  @override
  String get auditEventReceivingConfirmed => '收货已确认';

  @override
  String get auditEventReportDeleted => '报表已删除';

  @override
  String get auditEventReportSaved => '报表已保存';

  @override
  String get auditEventSalesOrderApproved => '销售单已批准';

  @override
  String get auditEventSalesOrderCancelled => '销售单已取消';

  @override
  String get auditEventSalesOrderCompleted => '销售单已完成';

  @override
  String get auditEventSalesOrderCreated => '已创建销售单';

  @override
  String get auditEventSalesOrderRejected => '销售单已拒绝';

  @override
  String get auditEventSalesOrderSubmitted => '销售单已提交';

  @override
  String get auditEventShipmentAutopacked => '已自动装箱';

  @override
  String get auditEventShipmentCancelled => '发货已取消';

  @override
  String get auditEventShipmentCompleted => '发货已完成';

  @override
  String get auditEventShipmentLogisticsSet => '已设置配送信息';

  @override
  String get auditEventTransferApproved => '调拨已批准';

  @override
  String get auditEventTransferCancelled => '调拨已取消';

  @override
  String get auditEventTransferCreated => '已创建调拨';

  @override
  String get auditEventTransferPickingStarted => '调拨拣货已开始';

  @override
  String get auditEventTransferReceived => '调拨已接收';

  @override
  String get auditEventTransferReceivingStarted => '调拨收货已开始';

  @override
  String get auditEventTransferRejected => '调拨已拒绝';

  @override
  String get auditEventTransferShipped => '调拨已发出';

  @override
  String get auditEventTransferSubmitted => '调拨已提交';

  @override
  String get auditEventUserRoleAssigned => '已分配角色';

  @override
  String get auditEventUserRoleRevoked => '已撤销角色';

  @override
  String get auditEventUserWarehouseAssigned => '已授予仓库权限';

  @override
  String get auditEventUserWarehouseRevoked => '已撤销仓库权限';

  @override
  String get auditEventWorkOrderCancelled => '工单已取消';

  @override
  String get auditEventWorkOrderCompleted => '工单已完成';

  @override
  String get auditEventWorkOrderCreated => '已创建工单';

  @override
  String get auditEventWorkOrderStarted => '工单已开始';

  @override
  String get dashNotificationsTitle => '通知';

  @override
  String get dashNotificationsEmpty => '目前没有需要处理的通知';

  @override
  String notifCount(int count) {
    return '$count 件';
  }

  @override
  String get notifFailedInspection => '检验不合格';

  @override
  String get notifOutstandingPlans => '待入库';

  @override
  String get notifPutawayPending => '待上架';

  @override
  String get notifOpenPicking => '拣货中';

  @override
  String get sidebarCollapse => '折叠菜单';

  @override
  String get sidebarExpand => '展开菜单';

  @override
  String get menuFilter => '筛选菜单';

  @override
  String get menuFilterNoMatch => '没有匹配的菜单项';

  @override
  String get unknownLocation => '找不到该页面。请从菜单中重新选择。';

  @override
  String get close => '关闭';

  @override
  String get shortcutsTitle => '键盘快捷键';

  @override
  String get shortcutsHelp => '显示键盘快捷键';

  @override
  String get shortcutFocusScan => '聚焦扫描框';

  @override
  String get shortcutToggleSidebar => '折叠或展开菜单';

  @override
  String get shortcutGlobalSearch => '打开全局搜索';

  @override
  String get shortcutSwitchTab => '切换到第 N 个标签';

  @override
  String get shortcutShowHelp => '显示此列表';

  @override
  String get productSku => 'SKU';

  @override
  String get productSkuHint => '内部编号（可选）';

  @override
  String get productTracking => '追踪方式';

  @override
  String get trackUntracked => '不追踪';

  @override
  String get trackLot => '批次';

  @override
  String get trackSerial => '序列号';

  @override
  String get trackLotAndSerial => '批次＋序列号';

  @override
  String get trackExpiry => '有效期';

  @override
  String get productBaseUnit => '基本单位';

  @override
  String productCodeCount(int count) {
    return '$count 个条码';
  }

  @override
  String productPackUnit(String code, String factor, String base) {
    return '$code = $factor$base';
  }

  @override
  String productScanAlreadyUsed(String name) {
    return '该条码已属于「$name」';
  }

  @override
  String get stockPositionTitle => '库存明细';

  @override
  String get stockAvailable => '可用';

  @override
  String get stockReserved => '已预留';

  @override
  String get stockAllocated => '已分配';

  @override
  String get stockUnavailable => '不可发货';

  @override
  String get stockOverPromised => '预留超过可用库存';

  @override
  String get stockNotLinkedToProduct => '该JAN尚未登记到商品主数据';

  @override
  String stockPositionLot(String code) {
    return '批次 $code';
  }

  @override
  String get stockPositionNoParcels => '暫无明细';

  @override
  String get productDetailTitle => '商品详情';

  @override
  String get productEdit => '编辑';

  @override
  String get productBarcodesSection => '条码';

  @override
  String get productBarcodeAdd => '添加条码';

  @override
  String get productBarcodePrimary => '主条码';

  @override
  String get productBarcodeType => '类型';

  @override
  String get productBarcodeUnit => '单位（可选）';

  @override
  String productBarcodeQtyPerScan(String qty) {
    return '1次扫描 = $qty';
  }

  @override
  String get productBarcodeRemoveQ => '要删除该条码吗？';

  @override
  String get productBarcodeRemoveBody => '将无法再通过该条码扫描到商品。商品本身保留。';

  @override
  String get productBarcodeEmpty => '暂无条码';

  @override
  String get productUnitsSection => '单位';

  @override
  String get productUnitAdd => '添加单位';

  @override
  String get productUnitFactor => '换算数';

  @override
  String get productUnitBase => '基本';

  @override
  String get productLotsSection => '批次';

  @override
  String get productLotsEmpty => '暂无批次记录';

  @override
  String productLotExpiryOn(String date) {
    return '有效期 $date';
  }

  @override
  String productLotDaysLeft(int days) {
    return '剩余$days天';
  }

  @override
  String get productLotExpired => '已过期';

  @override
  String productLotSerialCount(int count) {
    return '$count 个序列号';
  }

  @override
  String get productSerialsSection => '序列号';

  @override
  String get productSerialsEmpty => '暂无序列号记录';

  @override
  String get productSerialFilterAll => '全部';

  @override
  String get serialInStock => '在库';

  @override
  String get serialShipped => '已发货';

  @override
  String get serialReturned => '退货';

  @override
  String get serialScrapped => '废弃';

  @override
  String get serialHold => '保留';

  @override
  String get whpSection => '本仓库设置';

  @override
  String get whpNone => '本仓库没有专用设置';

  @override
  String get whpNoWarehouse => '选择仓库后可设置';

  @override
  String get whpEdit => '设置';

  @override
  String get whpDefaultLocation => '默认库位';

  @override
  String get whpDefaultLocationHint => '货架编号（留空即清除）';

  @override
  String get whpMinStock => '最小库存';

  @override
  String get whpReorderPoint => '补货点';

  @override
  String get whpMaxStock => '最大库存';

  @override
  String get whpPickPriority => '拣货优先级';

  @override
  String get whpPutawayRule => '上架规则';

  @override
  String get putawayManual => '手动';

  @override
  String get putawayFixed => '固定库位';

  @override
  String get putawayConsolidate => '合并到同品';

  @override
  String get putawayNearestEmpty => '最近的空位';

  @override
  String get whpLeadTime => '提前期（天）';

  @override
  String get whpSupplier => '首选供应商';

  @override
  String get whpClear => '删除本仓库设置';

  @override
  String get whpClearQ => '要删除本仓库的设置吗？';

  @override
  String get whpClearBody => '默认库位与补货点将被清除，也不会再出现在补货建议中。';

  @override
  String get whpNeedsReorder => '低于补货点';

  @override
  String get featExpiringLots => '有效期管理';

  @override
  String get featExpiringLotsDesc => '列出临期与过期批次';

  @override
  String get featReservations => '预留与分配';

  @override
  String get featReservationsDesc => '为订单预留的库存及其分配来源';

  @override
  String get featLocations => '库位';

  @override
  String get featLocationsDesc => '区域·通道·货架·层的层级与类型';

  @override
  String get featReplenishment => '补货建议';

  @override
  String get featReplenishmentDesc => '低于补货点的商品与建议订购量';

  @override
  String get expiryTitle => '有效期管理';

  @override
  String expiryHorizon(int days) {
    return '$days天内';
  }

  @override
  String get expiryEmpty => '没有临期批次';

  @override
  String get expiryEmptyBody => '此期间内没有到期批次。放宽期间可查看更久之后的情况。';

  @override
  String expiryExpiredCount(int count) {
    return '已过期 $count 件';
  }

  @override
  String expirySoonCount(int count) {
    return '临期 $count 件';
  }

  @override
  String get reservationsTitle => '预留与分配';

  @override
  String get reservationsEmpty => '没有预留';

  @override
  String get reservationsEmptyBody => '为订单或发货预留的库存会显示在这里。';

  @override
  String get reservationStatusActive => '有效';

  @override
  String get reservationStatusFulfilled => '已履行';

  @override
  String get reservationStatusReleased => '已释放';

  @override
  String get reservationStatusAll => '全部';

  @override
  String get reservationLapsed => '已失效';

  @override
  String reservationFor(String type, String id) {
    return '$type $id';
  }

  @override
  String get refSalesOrder => '销售订单';

  @override
  String get refShipment => '发货';

  @override
  String get refTransfer => '调拨';

  @override
  String get refWorkOrder => '工单';

  @override
  String get refManual => '手动';

  @override
  String reservationQuantity(String qty) {
    return '预留 $qty';
  }

  @override
  String reservationAllocated(String qty) {
    return '已分配 $qty';
  }

  @override
  String reservationUnallocated(String qty) {
    return '未分配 $qty';
  }

  @override
  String reservationFulfilled(String qty) {
    return '已发货 $qty';
  }

  @override
  String get reservationRelease => '释放';

  @override
  String get reservationReleaseQ => '要释放该预留吗？';

  @override
  String get reservationReleaseBody => '预留的库存将恢复可用，分配也会取消。记录会保留。';

  @override
  String get reservationAllocationsTitle => '分配来源';

  @override
  String get reservationNoAllocations => '尚未选择来源';

  @override
  String get overAllocatedTitle => '分配超额';

  @override
  String get overAllocatedBody => '库存低于已分配数量：发货先取走了。需要释放分配或补充库存。';

  @override
  String overAllocatedRow(String quantity, String allocated, String over) {
    return '库存 $quantity / 已分配 $allocated（超额 $over）';
  }

  @override
  String get locationsTitle => '库位';

  @override
  String get locationsEmpty => '暂无库位';

  @override
  String get locationsEmptyBody => '登记区域或货架后，将在此显示为层级。';

  @override
  String get locationsNoWarehouse => '选择仓库后可查看';

  @override
  String get locationAdd => '添加库位';

  @override
  String get locationCode => '编号';

  @override
  String get locationName => '名称（可选）';

  @override
  String get locationType => '类型';

  @override
  String get locationParent => '上级库位（可选）';

  @override
  String get locationBarcode => '标签条码（可选）';

  @override
  String get locationShowInactive => '显示停用';

  @override
  String get locationPickable => '可拣货';

  @override
  String get locationReceivable => '可收货';

  @override
  String get locationShipping => '发货';

  @override
  String get locationQuarantine => '隔离';

  @override
  String get locationVirtual => '虚拟';

  @override
  String get locationInactive => '停用';

  @override
  String locationOnHand(String qty) {
    return '库存 $qty';
  }

  @override
  String get locTypeStorage => '存储';

  @override
  String get locTypePicking => '拣货';

  @override
  String get locTypeReceiving => '收货';

  @override
  String get locTypeQc => '质检';

  @override
  String get locTypePacking => '包装';

  @override
  String get locTypeShipping => '发货';

  @override
  String get locTypeQuarantine => '隔离';

  @override
  String get locTypeDamaged => '破损';

  @override
  String get locTypeReturn => '退货';

  @override
  String get locTypeTransit => '在途';

  @override
  String get locTypeVirtual => '虚拟';

  @override
  String get replenishmentTitle => '补货建议';

  @override
  String get replenishmentEmpty => '没有需要补货的商品';

  @override
  String get replenishmentEmptyBody => '设置了补货点的商品均高于补货点。';

  @override
  String replenishmentSuggest(String qty) {
    return '建议订购 $qty';
  }

  @override
  String replenishmentShortfall(String qty) {
    return '距补货点 $qty';
  }

  @override
  String replenishmentBlocked(String qty) {
    return '其中不可发货 $qty';
  }

  @override
  String replenishmentLeadTime(int days) {
    return '提前期 $days 天';
  }

  @override
  String get replenishmentNoWarehouse => '选择仓库后可查看';

  @override
  String get exceptionsTitle => '异常・不一致';

  @override
  String get exceptionsEmpty => '没有未处理的异常';

  @override
  String get exceptionsEmptyBody => '入库、检验、上架中发现的不一致会显示在这里。';

  @override
  String get exceptionsNoWarehouse => '选择仓库后显示';

  @override
  String get exceptionsAllCategories => '全部工序';

  @override
  String get exceptionCategoryReceiving => '入库';

  @override
  String get exceptionCategoryQc => '检验';

  @override
  String get exceptionCategoryPutaway => '上架';

  @override
  String get exceptionShowClosed => '同时显示已处理';

  @override
  String get exceptionSeverityBlocker => '需处理';

  @override
  String get exceptionSeverityWarning => '注意';

  @override
  String get exceptionSeverityInfo => '参考';

  @override
  String get exceptionAcknowledge => '已确认';

  @override
  String get exceptionAcknowledged => '已确认';

  @override
  String get exceptionResolve => '记录处理';

  @override
  String get exceptionResolved => '已处理';

  @override
  String get exceptionCancelled => '已取消';

  @override
  String get exceptionResolveTitle => '记录处理结果';

  @override
  String get exceptionResolutionLabel => '处理';

  @override
  String get exceptionResolutionAccepted => '按现状受理';

  @override
  String get exceptionResolutionSupplierClaim => '联系供应商';

  @override
  String get exceptionResolutionReturned => '已退回';

  @override
  String get exceptionResolutionScrapped => '已废弃';

  @override
  String get exceptionResolutionCorrected => '已订正录入';

  @override
  String get exceptionResolutionRecounted => '已重新盘点';

  @override
  String get exceptionResolutionNoAction => '无需处理';

  @override
  String get exceptionNoteLabel => '备注（可选）';

  @override
  String get exceptionNoteRequiredLabel => '备注（必填）';

  @override
  String get exceptionNoteHint => '写明做了什么';

  @override
  String get exceptionNoteRequired => '该处理需要填写备注';

  @override
  String get exceptionStockNotMovedHint => '这里仅记录处理结果。如需变动库存，请通过库存调整进行。';

  @override
  String exceptionQuantity(int qty) {
    return '数量 $qty';
  }

  @override
  String exceptionLot(String lot, String expiry) {
    return '批次 $lot / 期限 $expiry';
  }

  @override
  String exceptionRaisedAt(String date) {
    return '$date 提出';
  }

  @override
  String exceptionOpenCount(int count) {
    return '未处理 $count 件';
  }

  @override
  String exceptionBlockerCount(int blockers, int open) {
    return '需处理 $blockers 件（未处理 $open 件）';
  }

  @override
  String get featExceptions => '异常处理';

  @override
  String get featExceptionsDesc => '确认并处理入库、检验、上架的不一致';

  @override
  String get heldStockTitle => '待检验库存';

  @override
  String get heldStockEmpty => '没有待检验的库存';

  @override
  String get heldStockEmptyBody => '入库时需要检验的商品会留在这里，直到检验完成。期间无法出库。';

  @override
  String get heldStockNoWarehouse => '选择仓库后显示';

  @override
  String get qcEffectTitle => '库存变动';

  @override
  String get qcEffectNothingMoved => '判定对象不在待检验库存中，因此库存未变动。';

  @override
  String get featHeldStock => '待检验库存';

  @override
  String get featHeldStockDesc => '查看检验完成前无法出库的库存';

  @override
  String heldStockTotal(int units, int parcels) {
    return '共 $units 件（$parcels 明细）无法出库';
  }

  @override
  String heldStockQuantity(int qty) {
    return '$qty 件';
  }

  @override
  String heldStockLot(String lot) {
    return '批次 $lot';
  }

  @override
  String heldStockExpiry(String date) {
    return '期限 $date';
  }

  @override
  String heldStockDays(int days) {
    return '已 $days 天';
  }

  @override
  String qcWillHold(int qty) {
    return '确认后不合格 $qty 件将转为无法出库的库存';
  }

  @override
  String qcEffectReleased(int qty) {
    return '合格 $qty 件已可出库';
  }

  @override
  String qcEffectHeld(int qty, String status) {
    return '不合格 $qty 件已移至 $status';
  }

  @override
  String qcEffectNotHeld(int qty) {
    return '其中 $qty 件不在待检验库存中，库存未变动';
  }

  @override
  String get putawayNoSuggestionBody => '本仓库没有可放置的货位';

  @override
  String get putawayNoHeldBin => '没有可存放不可出库库存的货位（待检、破损等）';

  @override
  String putawayLot(String lot) {
    return '批次 $lot';
  }

  @override
  String get parcelAddTitle => '记录包裹';

  @override
  String get parcelAdd => '添加包裹';

  @override
  String get parcelRemove => '删除此包裹';

  @override
  String get parcelQuantity => '数量';

  @override
  String get parcelQuantityRequired => '请输入数量';

  @override
  String get parcelLot => '批次（可选）';

  @override
  String get parcelLotHint => '纸箱上的批次';

  @override
  String get parcelExpiry => '期限（可选）';

  @override
  String get parcelExpiryNone => '未填写';

  @override
  String get parcelSerial => '序列号（可选）';

  @override
  String get parcelSerialHelp => '填写序列号时数量为 1';

  @override
  String get parcelSerialIsOne => '序列号需按 1 件记录';

  @override
  String get parcelLocation => '存放位置（可选）';

  @override
  String get parcelLocationHint => '货架或区域代码';

  @override
  String get parcelDamaged => '到货时已破损';

  @override
  String get parcelDamagedHelp => '记录为破损，无法出库。';

  @override
  String get parcelNote => '备注（可选）';

  @override
  String get parcelNoneYet => '未记录批次或序列号';

  @override
  String get parcelAllAttributed => '已全部记录';

  @override
  String parcelUnattributed(int qty) {
    return '未记录 $qty';
  }

  @override
  String parcelOverLine(int parcelled, int counted) {
    return '包裹合计 $parcelled 超过计数 $counted';
  }

  @override
  String parcelLotShort(String lot) {
    return 'L:$lot';
  }

  @override
  String get receiptDetailTitle => '入库明细';

  @override
  String get receiptLineNoParcels => '未记录批次或序列号';

  @override
  String get receiptParcelUnattributed => '未记录批次部分';

  @override
  String get receiptUnlinkedTitle => '订单外入库';

  @override
  String get receiptUnlinkedBody => '未关联到订单明细的包裹。';

  @override
  String receiptTotalUnits(int units) {
    return '共 $units 件';
  }

  @override
  String receiptHeldUnits(int units) {
    return '其中 $units 件无法出库';
  }

  @override
  String receiptLinePlannedActual(int planned, int actual) {
    return '预定 $planned / 实收 $actual';
  }

  @override
  String receiptParcelLot(String lot) {
    return '批次 $lot';
  }

  @override
  String receiptParcelExpiry(String date) {
    return '期限 $date';
  }

  @override
  String receiptParcelMovement(int id) {
    return '库存流水 #$id';
  }

  @override
  String get attachmentKindPhoto => '照片';

  @override
  String get attachmentKindDeliveryNote => '送货单';

  @override
  String get attachmentKindQcImage => '检验照片';

  @override
  String get attachmentKindDamage => '破损照片';

  @override
  String get attachmentKindDocument => '文件';

  @override
  String get attachmentKindLabel => '标签';

  @override
  String get attachmentKindOther => '其他';

  @override
  String get attachmentWithdraw => '撤回';

  @override
  String get attachmentWithdrawQ => '要撤回此附件吗？';

  @override
  String get attachmentWithdrawBody => '将从列表中移除，但记录仍会保留。';

  @override
  String get attachmentWithdrawn => '已撤回附件';

  @override
  String get attachmentWithdrawnBadge => '已撤回';

  @override
  String attachmentSize(int kb) {
    return '$kb KB';
  }

  @override
  String get attachmentNoCaption => '无说明';
}
