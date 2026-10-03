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
  String get errorInspectionCompleted => '该检验已完成。请重新打开查看最新结果。';

  @override
  String get errorReceiptInspected => '检验已完成的入库无法取消。如需修正库存，请使用库存调整。';

  @override
  String get errorInspectionClosedReceiveNew =>
      '该入库的检验已完成。追加的商品请作为同一到货计划的新入库进行核对。';

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
  String get reconcileConfirmDiscrepancy => '存在差异（不足、超量、计划外）。仍要完成吗？';

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
  String get cartonStatusOpen => '装箱中';

  @override
  String get cartonStatusPacked => '已装箱';

  @override
  String get cartonStatusShipped => '已出库';

  @override
  String get cartonStatusCancelled => '已取消';

  @override
  String get cartonMeasurementsAction => '编辑尺寸/重量';

  @override
  String get cartonMeasurementsSection => '尺寸/重量';

  @override
  String get cartonTypeHint => '类型（可选）例：60尺寸';

  @override
  String get cartonLength => '长';

  @override
  String get cartonWidth => '宽';

  @override
  String get cartonHeight => '高';

  @override
  String cartonDimensionsCm(String length, String width, String height) {
    return '$length × $width × $height cm';
  }

  @override
  String get cartonClose => '封箱';

  @override
  String get cartonCloseEmptyHint => '空箱无法封箱';

  @override
  String get cartonClosed => '已封箱';

  @override
  String get cartonReopen => '重新打开';

  @override
  String get cartonReopened => '已重新打开';

  @override
  String get cartonMustReopenToEdit => '请先重新打开此箱才能编辑';

  @override
  String get cartonAddParcel => '添加';

  @override
  String get cartonPackQuantity => '装箱数量';

  @override
  String cartonUnpackedCount(int qty) {
    return '剩余 $qty';
  }

  @override
  String get cartonLineDone => '已装完';

  @override
  String get cartonRenameAction => '重命名';

  @override
  String get cartonRenameTitle => '纸箱名称';

  @override
  String get cartonSerialNumber => '序列号';

  @override
  String get cartonContentsSection => '此箱内容';

  @override
  String get cartonContentsEmpty => '尚未装入任何物品';

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
  String get reasonInternalUse => '内部消耗';

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
    return '拣货已完成（不足$short件、超出$over件）';
  }

  @override
  String get pickCompleteBlocked => '存在未拣货的明细，无法完成';

  @override
  String get pickItemNoLot => '未记录批次';

  @override
  String get pickItemRemove => '撤销此记录';

  @override
  String pickItemUnattributed(int qty) {
    return '未记录 $qty';
  }

  @override
  String get pickLotCode => '批次编号';

  @override
  String get pickLotCodeHint => '可选';

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
  String get featProducts => '商品库';

  @override
  String get featProductsDesc => '本公司的商品：列表中编辑，照片中查看与添加';

  @override
  String get featUnlinkedJan => '未关联的JAN码';

  @override
  String get featUnlinkedJanDesc => '尚未关联商品的JAN码列表';

  @override
  String get unlinkedJanTitle => '未关联的JAN码';

  @override
  String unlinkedJanCoverage(int linked, int rows) {
    return '已关联 $linked / $rows';
  }

  @override
  String get unlinkedJanReady => '所有JAN码均已关联商品';

  @override
  String get unlinkedJanEmpty => '没有未关联的JAN码';

  @override
  String get unlinkedJanEmptyBody => '库存、入库、出库等记录均已关联商品。';

  @override
  String unlinkedJanRows(int qty) {
    return '$qty 条';
  }

  @override
  String get unlinkedJanSeenAsUnknown => '名称不明';

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
  String get reportCountry => '国家';

  @override
  String get reportAllCountries => '所有国家（每行显示国家）';

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
  String get poCreateDeliveryPlan => '创建入库计划';

  @override
  String get poCreateDeliveryPlanQ => '要根据此采购订单创建入库计划吗？';

  @override
  String poDeliveryPlanCreated(int lines) {
    return '已创建入库计划（$lines 条明细）';
  }

  @override
  String get poOpenDeliveryPlan => '打开入库计划';

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
  String get productsTitle => '商品库';

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
  String get shipmentParcelsAction => '出库批次记录';

  @override
  String get shipmentParcelsTitle => '出库批次记录';

  @override
  String get shipmentParcelsEmpty => '尚未出库';

  @override
  String get shipmentParcelsEmptyBody => '出库确认后，实际发出的批次和序列号会显示在这里。';

  @override
  String get shipmentParcelReversalTag => '已撤销';

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
  String get productRequiresInspection => '到货必须检品';

  @override
  String get productRequiresInspectionHint =>
      '开启后，此商品到货时将保留为待检品（QC_PENDING），需完成检品后才能拣货或出库。';

  @override
  String get productPickingRule => '拣货顺序';

  @override
  String get productPickingRuleHint => '库存的默认领用顺序。仓库可单独覆盖此设置。';

  @override
  String get pickRuleFifo => '先进先出（FIFO）';

  @override
  String get pickRuleFefo => '效期优先（FEFO）';

  @override
  String get pickRuleLifo => '后进先出（LIFO）';

  @override
  String get pickRuleManual => '每次手动选择（MANUAL）';

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
  String get productUnitRemoveQ => '要删除此单位吗？';

  @override
  String get productUnitRemoveBody => '此包装单位将无法再选择。基本单位或仍被条码引用的单位无法删除。';

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
  String get productSerialChangeStatus => '更改状态';

  @override
  String get productSerialStatus => '状态';

  @override
  String get productSerialNote => '备注（可选）';

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
  String get featStockReconciliation => '库存对账';

  @override
  String get featStockReconciliationDesc => '库存水位与实际库存不一致之处';

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
  String get reservationFulfil => '标记为已出库';

  @override
  String get reservationFulfilTitle => '记录为已出库';

  @override
  String get reservationFulfilBody => '不会移动库存。出库另有记录，这里只记录承诺已经兑现。';

  @override
  String get reservationFulfilQuantity => '数量';

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
  String get stockReconciliationTitle => '库存对账';

  @override
  String get stockReconciliationEmpty => '没有差异';

  @override
  String get stockReconciliationEmptyBody => '库存水位与实际库存一致。';

  @override
  String get stockReconciliationReasonUnlinked => '未关联商品的JAN码';

  @override
  String get stockReconciliationReasonDrift => '数量差异';

  @override
  String stockReconciliationLevels(int qty) {
    return '库存水位 $qty';
  }

  @override
  String stockReconciliationUnits(int qty) {
    return '实际库存 $qty';
  }

  @override
  String stockReconciliationDrift(String diff) {
    return '差额 $diff';
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
  String get binStockAction => '按库位查看库存';

  @override
  String get binStockTitle => '按库位查看库存';

  @override
  String get binStockEmpty => '此仓库没有库位';

  @override
  String get binStockBinEmpty => '空';

  @override
  String binStockTotalUnits(int qty) {
    return '共 $qty 件';
  }

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
  String get exceptionsTitle => '异常、不一致';

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
  String get exceptionRaise => '登记异常';

  @override
  String get exceptionRaiseTitle => '登记一个异常';

  @override
  String get exceptionRaiseType => '类型';

  @override
  String get exceptionRaiseJanCode => 'JAN码（可选）';

  @override
  String get exceptionRaiseQuantity => '数量（可选）';

  @override
  String get exceptionRaiseNoTypes => '没有可登记的异常类型';

  @override
  String get exceptionCancel => '撤销';

  @override
  String get exceptionCancelTitle => '要撤销该异常吗？';

  @override
  String get exceptionCancelBody => '用于误登记的情况，不会记录处理结果。';

  @override
  String get exceptionCancelReasonLabel => '原因（可选）';

  @override
  String get featExceptions => '异常处理';

  @override
  String get featExceptionsDesc => '确认并处理入库、检验、上架的不一致';

  @override
  String get heldStockTitle => '无法出库的库存';

  @override
  String get heldStockEmpty => '没有无法出库的库存';

  @override
  String get heldStockEmptyBody => '待检、保留、隔离、破损等库存会列在这里，无法出库。';

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
  String get receiptAddParcelTooltip => '添加包裹';

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

  @override
  String soApprovedWithReservations(int reserved) {
    return '已批准订单（已预留 $reserved 项）';
  }

  @override
  String soApprovedWithSkips(int reserved, int skipped) {
    return '已批准订单（已预留 $reserved 项、未预留 $skipped 项）';
  }

  @override
  String get soApprovalSkipDetail => '详情';

  @override
  String get soSkippedLinesTitle => '未能预留的明细';

  @override
  String get soSkipUnlinkedJan => '该商品尚未注册';

  @override
  String soSkipInsufficientAvailable(int available, int requested) {
    return '库存不足（现有 $available / 需要 $requested）';
  }

  @override
  String get soReservationsTitle => '预留情况';

  @override
  String get soReservationFulfilled => '已出库';

  @override
  String get soCreateShipment => '创建出库单';

  @override
  String get soCreateShipmentQ => '要从此订单创建出库单吗？';

  @override
  String soShipmentCreated(int lines) {
    return '已创建出库单（$lines 项明细）';
  }

  @override
  String get soOpenShipment => '打开出库单';

  @override
  String get featWave => '波次拣货';

  @override
  String get featWaveDesc => '将多个出库单合并为一次巡查';

  @override
  String get waveListTitle => '波次拣货';

  @override
  String get waveEmpty => '暂无波次';

  @override
  String get waveEmptyBody => '可将多个出库单合并，一次巡查完成拣货。';

  @override
  String get waveCreate => '创建波次';

  @override
  String get waveChooseShipments => '选择出库单（可多选）';

  @override
  String get waveNoShipments => '没有可用的出库单';

  @override
  String get waveSelectAtLeastOne => '请至少选择一个出库单';

  @override
  String waveCreated(String code, int lists) {
    return '已创建波次 $code（$lists 个出库单）';
  }

  @override
  String waveCreatedWithSkips(String code, int lists, int skipped) {
    return '已创建波次 $code（$lists 个加入、$skipped 个跳过）';
  }

  @override
  String get waveStatusOpen => '未开始';

  @override
  String get waveStatusPicking => '进行中';

  @override
  String get waveStatusDone => '已完成';

  @override
  String get waveStatusCancelled => '已取消';

  @override
  String waveListsProgress(int picked, int total) {
    return '$picked / $total 项';
  }

  @override
  String get waveUnassigned => '未指派';

  @override
  String get waveAssignToMe => '由我负责';

  @override
  String get waveUnassign => '取消指派';

  @override
  String get waveViewSheet => '查看拣货表';

  @override
  String get waveSheetTitle => '拣货表';

  @override
  String get waveSheetEmpty => '没有可拣货的明细';

  @override
  String waveSheetTotalUnits(int total) {
    return '合计 $total 件';
  }

  @override
  String waveSheetForOrders(int count) {
    return '对应 $count 个出库单';
  }

  @override
  String get waveShortfallTitle => '缺货';

  @override
  String waveShortfallUnits(int short) {
    return '缺 $short 件';
  }

  @override
  String get waveLists => '包含的出库单';

  @override
  String get waveComplete => '完成波次';

  @override
  String get waveCompleteQ => '要完成此波次吗？其中所有出库单都将结单。';

  @override
  String waveCompleted(int count) {
    return '波次已完成（$count 项）';
  }

  @override
  String get waveIncomplete => '仍有未拣货的明细';

  @override
  String get waveCancelAction => '取消波次';

  @override
  String get waveCancelQ => '要取消此波次吗？其出库单将被释放，已记录的拣货将保留。';

  @override
  String get waveCancelled => '波次已取消';

  @override
  String get featDemand => '欠货与采购';

  @override
  String get featDemandDesc => '用库存满足待发订单，并统一采购缺口';

  @override
  String get demandTitle => '欠货与采购';

  @override
  String get demandEmpty => '没有等待中的订单';

  @override
  String get demandEmptyBody => '已批准但库存不足、未能预留的订单数量会汇总在这里。';

  @override
  String get demandFillAll => '全部从库存预留';

  @override
  String get demandFillAllQ => '将按批准时间从早到晚，把空闲库存预留给等待中的订单。是否继续？';

  @override
  String get demandNothingToFill => '没有可预留的库存';

  @override
  String demandFilled(int units) {
    return '已预留 $units 件';
  }

  @override
  String demandPoCreated(int links) {
    return '已创建采购单（关联 $links 个订单明细）';
  }

  @override
  String demandCreatePo(int count) {
    return '创建采购单（$count 个品项）';
  }

  @override
  String get demandBackordered => '欠货';

  @override
  String get demandCanFillNow => '可立即预留';

  @override
  String get demandIncoming => '在途';

  @override
  String get demandToPurchase => '需采购';

  @override
  String get demandAvailable => '空闲库存';

  @override
  String demandNeedsPurchase(int count) {
    return '需采购 $count';
  }

  @override
  String demandFillable(int count) {
    return '可预留 $count';
  }

  @override
  String get demandCovered => '已安排';

  @override
  String demandFillNow(int count) {
    return '从库存预留（$count）';
  }

  @override
  String demandWaitingOrders(int count) {
    return '等待中的订单 $count 个';
  }

  @override
  String demandLineStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return '订购 $ordered 、已预留 $promised 、欠 $backordered 、采购中 $onOrder';
  }

  @override
  String get demandLineFill => '为此订单预留';

  @override
  String get demandLineFillQuantity => '预留数量';

  @override
  String demandLineFillMax(int max) {
    return '最多 $max';
  }

  @override
  String get demandPoTitle => '按欠货采购';

  @override
  String get demandPoHint => '数量默认为需采购数。少订也可以——不足部分可以从其他渠道补足。';

  @override
  String demandPoLineHint(int backordered, int toPurchase) {
    return '欠货 $backordered 、需采购 $toPurchase';
  }

  @override
  String get demandQuantity => '采购数';

  @override
  String get demandOrdered => '订购';

  @override
  String get demandPromised => '已预留';

  @override
  String get demandShipped => '已发货';

  @override
  String soSkipPartial(int reserved, int backordered) {
    return '已预留 $reserved 、欠货 $backordered';
  }

  @override
  String soCreateShipmentReadyQ(int units) {
    return '将把已预留但未发货的 $units 件加入发货。是否继续？';
  }

  @override
  String get soShipRemaining => '发出剩余部分';

  @override
  String get soFillFromStock => '从库存预留';

  @override
  String get soMoreActions => '更多操作';

  @override
  String get soReadyToShip => '待发货';

  @override
  String get soShipments => '发货';

  @override
  String get soShipmentShipped => '已发货';

  @override
  String get soShipmentOpen => '进行中';

  @override
  String get soLineUnlinked => '该 JAN 未登记商品，无法预留';

  @override
  String soLineOnOrder(int count) {
    return '采购中 $count';
  }

  @override
  String get soFillLine => '为此明细预留';

  @override
  String get poCreateRemainingDeliveryPlan => '为剩余部分创建到货计划';

  @override
  String get poDeliveryPlans => '到货计划';

  @override
  String get poPlanReceived => '已到货';

  @override
  String get poPlanOpen => '待到货';

  @override
  String get poLinePlanned => '计划';

  @override
  String get poLineReceived => '已到货';

  @override
  String get poLineOutstanding => '未到货';

  @override
  String get poLineForOrders => '本采购对应的订单';

  @override
  String get reconOpenPurchaseOrder => '打开采购单';

  @override
  String get reconLinkPurchaseOrder => '关联采购单';

  @override
  String get reconNoPurchaseOrderToLink => '没有可关联的采购单';

  @override
  String reconLinkedPurchaseOrder(String number) {
    return '已关联到 $number';
  }

  @override
  String reservationAllocatedShort(int allocated, int short) {
    return '已分配 $allocated 件（$short 件未找到库存）';
  }

  @override
  String reservationAllocatedDone(int allocated) {
    return '已分配 $allocated 件';
  }

  @override
  String reservationManualNoProduct(String jan) {
    return '找不到 JAN 为 $jan 的商品';
  }

  @override
  String get reservationManualCreated => '已创建预留';

  @override
  String get reservationManualAdd => '手动预留';

  @override
  String get reservationReleaseAllocation => '取消分配';

  @override
  String get reservationAllocate => '分配库存';

  @override
  String get reservationManualNote => '用途、备注';

  @override
  String get reservationManualSubmit => '预留';

  @override
  String get demandPoNeedSupplier => '请输入供应商';

  @override
  String demandPoOverLinked(int linked, int quantity) {
    return '关联 $linked 超过采购数 $quantity';
  }

  @override
  String demandPoLineOverLinked(int backordered) {
    return '超过该订单的欠货 $backordered';
  }

  @override
  String demandPoCreateN(int count) {
    return '创建采购单（$count 家）';
  }

  @override
  String demandPoProductHint(int backordered, int toPurchase, int incoming) {
    return '欠货 $backordered 、需采购 $toPurchase 、在途 $incoming';
  }

  @override
  String demandPoProductTotal(int total) {
    return '该商品采购合计 $total';
  }

  @override
  String get demandPoSplitSupplier => '拆分到其他供应商';

  @override
  String get demandPoRemoveRow => '移除此供应商';

  @override
  String get demandPoLinksTitle => '本采购用于哪些订单';

  @override
  String get demandPoAutoLink => '按先后自动分配';

  @override
  String get demandPoNoWaiting => '没有等待的订单——全部为预购';

  @override
  String demandPoLineWaiting(int backordered, int onOrder) {
    return '欠货 $backordered 、采购中 $onOrder';
  }

  @override
  String demandPoRowSummary(int linked, int ahead) {
    return '已关联 $linked 、预购（未关联）$ahead';
  }

  @override
  String demandPosCreated(int count) {
    return '已创建 $count 张采购单';
  }

  @override
  String get demandAheadOnly => '仅预购';

  @override
  String demandIncomingBreakdown(int incoming) {
    return '在途 $incoming（按供应商）';
  }

  @override
  String demandIncomingBreakdownAhead(int incoming, int ahead) {
    return '在途 $incoming（其中预购 $ahead）';
  }

  @override
  String demandIncomingPo(int outstanding) {
    return '待到 $outstanding';
  }

  @override
  String demandIncomingPoAhead(int outstanding, int ahead) {
    return '待到 $outstanding（预购 $ahead）';
  }

  @override
  String get demandIncomingAhead => '预购在途';

  @override
  String get poLinkEditTitle => '关联销售订单';

  @override
  String poLinkOverOrdered(int ordered) {
    return '超过该订单的订购数 $ordered';
  }

  @override
  String poLinkSaved(int linked, int reserved, int released) {
    return '已保存关联（关联 $linked、从到货预留 $reserved、释放 $released）';
  }

  @override
  String poLinkLineSummary(int quantity, int received) {
    return '采购 $quantity 、已到货 $received';
  }

  @override
  String get poLinkHint =>
      '到货会自动预留给已关联的订单。更改关联时，本采购已预留的数量也会随之转移。未关联的数量作为预购库存，留给下一张订单。';

  @override
  String get poLinkNoCandidates => '没有等待该商品的已批准订单';

  @override
  String poLinkCandidateStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return '订购 $ordered 、已预留 $promised 、欠 $backordered 、采购中 $onOrder';
  }

  @override
  String poLinkFilled(int filled) {
    return '已从本采购到货预留 $filled';
  }

  @override
  String get poLinkQuantity => '关联数';

  @override
  String poLinkReleaseWarning(int count) {
    return '保存后将解除该订单已预留的 $count 个';
  }

  @override
  String get poLinkReleaseTitle => '要解除预留吗？';

  @override
  String get poLinkReleaseBody =>
      '已到货并预留的商品将从以下订单中移除。移除的数量会转给其他关联订单，若没有则回到可用库存。';

  @override
  String poLinkReleaseLine(String order, int count) {
    return '$order：解除 $count 个';
  }

  @override
  String get poLinkReleaseConfirm => '解除并保存';

  @override
  String poLineLinkedAhead(int linked, int ahead) {
    return '关联订单 $linked 、预购 $ahead';
  }

  @override
  String get poLinkEdit => '编辑关联';

  @override
  String poDemandFilled(int filled) {
    return '（到货已预留 $filled）';
  }

  @override
  String get transferStatusExported => '已出口';

  @override
  String get transferExportBadge => '出口';

  @override
  String transferCrossBorderExport(String country) {
    return '这是跨境调拨至$country。出库即从库存中扣除，不会有入库。';
  }

  @override
  String transferCrossBorderReceived(String country) {
    return '$country的仓库已设置为接收跨境货物，将像普通调拨一样入库。';
  }

  @override
  String get transferExportNotice => '跨境调拨：出库即从实际库存扣除，不会入库。发出的数量计入“海外仓库虚拟库存”。';

  @override
  String get transferCrossBorderReceivedNotice => '跨境调拨：目的仓库接收跨境货物，因此会入库。';

  @override
  String transferCompletePickingExportBody(String warehouse) {
    return '货物从$warehouse出库，并作为出口从库存中扣除。本次调拨无需入库即完成。';
  }

  @override
  String get whRoleEdit => '国家与角色';

  @override
  String get whRoleSaved => '已保存仓库国家与角色';

  @override
  String get whRoleCountry => '国家';

  @override
  String get whRoleCountryCode => '国家代码（2位字母）';

  @override
  String get whRoleReceivesCrossBorder => '接收跨境调拨并持有库存';

  @override
  String get whRoleReceivesCrossBorderHint =>
      '关闭时，从其他国家调拨到本仓库的货物在出库时即从库存扣除。若要从本仓库向个别客户发货，请开启。';

  @override
  String get countryJP => '日本';

  @override
  String get countryCN => '中国';

  @override
  String get countryOther => '其他';

  @override
  String get supplierNamesSection => '各供应商的叫法';

  @override
  String get supplierNamesHint =>
      '登记各供应商的商品名和编号后，可按其叫法搜索，也用于核对到货单。发货单据上打印本公司的商品名。';

  @override
  String get supplierNamesEmpty => '尚未登记';

  @override
  String get supplierNameAdd => '添加叫法';

  @override
  String get supplierNameEdit => '编辑叫法';

  @override
  String get supplierNameSaved => '已保存叫法';

  @override
  String get supplierNameNoSuppliers => '请先登记供应商';

  @override
  String get supplierNameSupplier => '供应商';

  @override
  String get supplierNameName => '供应商的商品名';

  @override
  String get supplierNameCode => '供应商的编号（可选）';

  @override
  String get supplierNameNote => '备注（可选）';

  @override
  String supplierNameCodeLabel(String code) {
    return '编号 $code';
  }

  @override
  String poLineSupplierName(String name) {
    return '供应商叫法：$name';
  }

  @override
  String get featVirtualStock => '海外仓库虚拟库存';

  @override
  String get featVirtualStockDesc => '按月查看海外仓库的大致库存（依据从日本发出的数量和手动录入的实数）';

  @override
  String get virtualTitle => '海外仓库虚拟库存';

  @override
  String get virtualExplain =>
      '发往海外的商品已从实际库存中扣除。这里是根据日本发货和手动录入实数得出的虚拟数量，不用于预留或发货。';

  @override
  String get virtualNoWarehouse => '没有海外仓库';

  @override
  String get virtualNoWarehouseBody => '在仓库的“国家与角色”中设置国家后即会显示在这里。';

  @override
  String get virtualWarehouse => '仓库';

  @override
  String get virtualFromMonth => '起始月';

  @override
  String get virtualToMonth => '结束月';

  @override
  String virtualRangeTotal(String from, String to) {
    return '$from 至 $to 合计';
  }

  @override
  String get virtualByMonth => '按月';

  @override
  String get virtualByProduct => '按商品';

  @override
  String get virtualEmpty => '该期间没有记录';

  @override
  String get virtualOpening => '期初';

  @override
  String get virtualArrived => '来自日本';

  @override
  String get virtualAdjusted => '手动增减';

  @override
  String get virtualCountDiff => '与实数之差';

  @override
  String get virtualClosing => '期末';

  @override
  String get virtualMonth => '月';

  @override
  String virtualProductLine(int opening, int arrived, int change) {
    return '期初 $opening 、来自日本 +$arrived 、增减 $change';
  }

  @override
  String virtualLastCount(String date, int counted) {
    return '最近实数 $date：$counted';
  }

  @override
  String get virtualRecord => '录入实数或增减';

  @override
  String get virtualRecorded => '已记录';

  @override
  String get virtualHistory => '记录历史';

  @override
  String virtualBalanceThatDay(int balance) {
    return '当日数量 $balance';
  }

  @override
  String virtualEntryExport(int quantity, String number) {
    return '来自日本 +$quantity（$number）';
  }

  @override
  String virtualEntryCount(int counted) {
    return '实数 $counted';
  }

  @override
  String virtualEntryAdjust(String change) {
    return '增减 $change';
  }

  @override
  String get virtualTypeCount => '实数';

  @override
  String get virtualTypeAdjust => '增减';

  @override
  String get virtualTypeCountHint => '录入当天实际存在的数量，此后的数量将以此为基础计算。';

  @override
  String get virtualTypeAdjustHint => '录入已知的出库或入库。';

  @override
  String get virtualAdjustOut => '出库（减）';

  @override
  String get virtualAdjustIn => '入库（增）';

  @override
  String get virtualCountedQuantity => '实数';

  @override
  String get virtualAdjustQuantity => '数量';

  @override
  String get virtualDate => '日期';

  @override
  String get virtualNote => '备注（可选）';

  @override
  String get chartStockTitle => '商品库存构成';

  @override
  String get chartByWarehouse => '按仓库';

  @override
  String get chartByState => '按状态';

  @override
  String get chartShowTable => '以表格查看';

  @override
  String get chartShowChart => '以图表查看';

  @override
  String get chartEmpty => '尚无有库存的商品';

  @override
  String chartUnregisteredNote(int jans, String units) {
    return '未登记商品的 JAN $jans 个（共 $units 件）未计入图表';
  }

  @override
  String get chartUnregisteredAction => '去登记';

  @override
  String chartTopOf(int shown, int total) {
    return '库存最多的前 $shown 个商品（共 $total 个）';
  }

  @override
  String get chartFree => '空闲';

  @override
  String get chartReserved => '已预留';

  @override
  String get chartUnusable => '不可用（冻结、待检）';

  @override
  String get chartVirtualAbroad => '海外（虚拟）';

  @override
  String chartWarehouseVirtual(String name) {
    return '$name（虚拟）';
  }

  @override
  String get chartOther => '其他';

  @override
  String get chartProduct => '商品';

  @override
  String get chartTotal => '合计';

  @override
  String get recentPoTitle => '最近的采购单';

  @override
  String get recentPoEmpty => '尚无采购单';

  @override
  String recentPoDestination(String warehouse, String country) {
    return '收货仓库 $warehouse$country';
  }

  @override
  String recentPoExpected(String date) {
    return '交期 $date';
  }

  @override
  String recentPoReceived(String received, String ordered) {
    return '到货 $received / $ordered';
  }

  @override
  String get recentPoOpenAll => '查看全部采购单';

  @override
  String whTotalsCountry(String country) {
    return '合计（$country）';
  }

  @override
  String chartTopOfCountry(String country, int shown, int total) {
    return '$country：库存最多的前 $shown 个商品（共 $total 个）';
  }

  @override
  String dashOverviewCountry(String country) {
    return '概览（$country）';
  }

  @override
  String get heldStatusQcPending => '待检';

  @override
  String get heldStatusHold => '保留';

  @override
  String get heldStatusQuarantine => '隔离';

  @override
  String get heldStatusDamaged => '破损';

  @override
  String get heldStatusExpired => '过期';

  @override
  String get heldStatusBlocked => '停止出库';

  @override
  String get heldAwaitsInspection => '由检验决定合格与否';

  @override
  String get heldDispose => '处理';

  @override
  String dispTitle(String name) {
    return '处理 $name';
  }

  @override
  String get dispQuantity => '数量';

  @override
  String dispMax(int qty) {
    return '最多 $qty 件';
  }

  @override
  String get dispRelease => '恢复为良品';

  @override
  String get dispHold => '设为保留';

  @override
  String get dispQuarantine => '隔离';

  @override
  String get dispDamaged => '设为破损';

  @override
  String get dispScrap => '报废';

  @override
  String get dispReturn => '退回供应商';

  @override
  String get dispReason => '原因、退货单号等';

  @override
  String get dispReasonRequired => '报废或退货需要填写原因';

  @override
  String dispOverMax(int qty) {
    return '最多 $qty 件';
  }

  @override
  String get dispConfirm => '执行';

  @override
  String dispDone(int qty) {
    return '已处理 $qty 件';
  }

  @override
  String get mvScrap => '报废';

  @override
  String get mvReturnToSupplier => '退回供应商';

  @override
  String get bulkQcTitle => '批量检验';

  @override
  String get bulkQcGroupDate => '到货日期';

  @override
  String get bulkQcGroupPo => '采购单';

  @override
  String get bulkQcAllDates => '所有到货日期';

  @override
  String get bulkQcAllPos => '所有采购单';

  @override
  String get bulkQcNoPo => '无采购单';

  @override
  String bulkQcProductFilter(String name) {
    return '商品：$name';
  }

  @override
  String get bulkQcScanHint => '扫描JAN按商品筛选';

  @override
  String get bulkQcNoMatch => '该JAN没有待检商品';

  @override
  String get bulkQcSelectAll => '全选';

  @override
  String get bulkQcSelectNone => '取消选择';

  @override
  String bulkQcSummary(int lines, int units) {
    return '已选 $lines 行、共 $units 件';
  }

  @override
  String get bulkQcPass => '将所选作为良品完成检验';

  @override
  String get bulkQcConfirmTitle => '作为良品完成检验吗？';

  @override
  String bulkQcConfirmBody(int lines, int units) {
    return '将 $lines 行（共 $units 件）确定为良品，立即变为可出库库存。未选择的行仍保持待检。';
  }

  @override
  String bulkQcDone(int lines, int units) {
    return '已将 $lines 行（$units 件）确定为良品';
  }

  @override
  String get bulkQcEmpty => '没有待检行';

  @override
  String get bulkQcEmptyBody => '需要检验的商品入库后会列在这里。';

  @override
  String bulkQcArrived(String date) {
    return '到货 $date';
  }

  @override
  String get bulkQcRecordedBadge => '已记录';

  @override
  String get qcPassAll => '全部良品';

  @override
  String qcPassAllDone(int units) {
    return '已将 $units 件确定为良品';
  }

  @override
  String get qcFinalBadge => '已确定';

  @override
  String get qcScanHint => '扫描JAN检验对应行';

  @override
  String get qcScanNotInInspection => '此检验中没有该JAN';

  @override
  String qcScanPrompt(String name, int units) {
    return '$name：$units 件';
  }

  @override
  String get qcScanRecordEach => '单独记录';

  @override
  String receiptArrivedOn(String date) {
    return '到货日期 $date';
  }

  @override
  String get receiptArrivedOnEdit => '修改到货日期';

  @override
  String receiptArrivedOnSaved(String date) {
    return '到货日期已改为 $date';
  }

  @override
  String get featBulkInspection => '批量检验';

  @override
  String get featBulkInspectionDesc => '按到货日期、采购单或商品筛选，批量作为良品完成检验';

  @override
  String get qcCountMatch => '数量一致';

  @override
  String qcCountShort(int n) {
    return '不足 $n';
  }

  @override
  String qcCountOver(int n) {
    return '过多 $n';
  }

  @override
  String get qcCountNone => '未计数';

  @override
  String qcCountLine(int counted, int received) {
    return '检验数 $counted / 入库 $received';
  }

  @override
  String get qcEnterCount => '输入数量';

  @override
  String qcEnterCountTitle(String name) {
    return '$name 的检验数';
  }

  @override
  String qcScanCounted(String name, int counted, int received) {
    return '$name：$counted / $received';
  }

  @override
  String qcScanCountMatched(String name, int n) {
    return '$name 数量一致（$n 件）';
  }

  @override
  String get qcWrongItemTitle => '此次入库中没有该商品';

  @override
  String qcWrongItemBody(String jan) {
    return 'JAN $jan 不在本次入库中。要记录为错误商品吗？';
  }

  @override
  String get qcWrongItemRecord => '记录为错误商品';

  @override
  String get qcWrongItemDone => '已记录为错误商品';

  @override
  String qcMatchedSummary(int matched, int total) {
    return '数量一致 $matched / $total 行';
  }

  @override
  String get qcCompleteDefaultTitle => '有未检查的行';

  @override
  String qcCompleteDefaultBody(int n) {
    return '$n 个未检查的行将作为良品完成。已计数的行按计数确定。';
  }

  @override
  String get qcCompleteConfirm => '完成';

  @override
  String qcEffectCountShort(int n) {
    return '未能计数的 $n 件已转为保留';
  }

  @override
  String get qcScanPieceMode => '扫描一次计一件';

  @override
  String get qcScanPieceOn => '现在每次扫描计一件';

  @override
  String get qcScanPieceOff => '现在扫描选择商品并输入数量';

  @override
  String get qcReadNote => '读取送货单';

  @override
  String qcNoteApplied(int matched) {
    return '已将送货单的 $matched 行反映到检验';
  }

  @override
  String get qcNoteNone => '未能从送货单读取明细';

  @override
  String get qcNoteUnmatchedTitle => '未能匹配的送货单行';

  @override
  String get qcNoteUnmatchedBody => '以下行与本次入库商品不一致。若为错误商品，请记录为错误商品。';

  @override
  String qcNoteQuantity(int n) {
    return '送货单 $n';
  }

  @override
  String qcCountRemaining(int n) {
    return '剩余 $n';
  }

  @override
  String get qcCountModeAdd => '追加';

  @override
  String get qcCountModeSet => '修改合计';

  @override
  String qcCountSoFar(int counted, int received) {
    return '目前 $counted / 入库 $received';
  }

  @override
  String get qcCountAddHint => '本次计数（如一箱的数量）';

  @override
  String get qcCountSetHint => '计数合计';

  @override
  String get qcTick => '已确认商品和数量';

  @override
  String get partnerCountry => '国家';

  @override
  String get dashViewOverview => '概览';

  @override
  String get dashViewInspection => '验货';

  @override
  String get dashViewPurchasing => '采购';

  @override
  String get dashViewSales => '接单';

  @override
  String get dashAwaitingInspection => '待验货';

  @override
  String dashAwaitingBody(int inspections, int lines, int units) {
    return '$inspections单 · $lines行 · $units件';
  }

  @override
  String get dashAwaitingNone => '没有待验货';

  @override
  String get dashOpenInspections => '验货列表';

  @override
  String get dashBulkInspection => '批量验货';

  @override
  String get dashIncomingTitle => '待到货';

  @override
  String get dashIncomingEmpty => '没有待到货';

  @override
  String get dashDayToday => '今天';

  @override
  String get dashDayTomorrow => '明天';

  @override
  String get dashDayOverdue => '已逾期';

  @override
  String get dashDayNone => '日期未定';

  @override
  String get dashManualBadge => '手动';

  @override
  String dashPlanSummary(int lines, int units) {
    return '$lines种 · $units件';
  }

  @override
  String dashMoreLines(int count) {
    return '另有$count种';
  }

  @override
  String get dashUnplannedTitle => '没有发货单的采购单';

  @override
  String get dashUnplannedBody => '供应商未发来发货单的已批准采购单。可以手动创建到货清单。';

  @override
  String get dashCreateManualList => '手动创建到货清单';

  @override
  String get manualListTitle => '手动创建到货清单';

  @override
  String get manualListSupplier => '供应商（可选）';

  @override
  String get manualListExpected => '预计到货日';

  @override
  String get manualListNoDate => '未定';

  @override
  String get manualListScanHint => '扫描或输入JAN';

  @override
  String get manualListQuantity => '数量';

  @override
  String get manualListEmpty => '请扫描要到货商品的JAN';

  @override
  String get manualListSave => '创建清单';

  @override
  String manualListCreated(String number) {
    return '已创建到货清单 $number';
  }

  @override
  String get manualListNoWarehouse => '请先选择仓库';

  @override
  String get manualListBadJan => 'JAN为8位或13位数字';

  @override
  String get dashStockUsable => '良品';

  @override
  String get dashStockQcPending => '待验货';

  @override
  String get dashStockHeld => '冻结';

  @override
  String get dashStockReserved => '已分配';

  @override
  String get dashStockIncoming => '在途';

  @override
  String get dashStockShortfall => '缺口';

  @override
  String dashStockNext(String date) {
    return '下次 $date';
  }

  @override
  String get dashStockSearch => '按名称或JAN搜索';

  @override
  String get dashStockEmpty => '没有符合的商品';

  @override
  String dashStockProducts(int count) {
    return '$count种商品';
  }

  @override
  String get dashOpenDemand => '打开待采购';

  @override
  String dashSalesUnits(int months) {
    return '近$months个月接单数';
  }

  @override
  String dashSalesVsLastYear(String pct) {
    return '同比 $pct';
  }

  @override
  String get dashSalesNoCompare => '无去年数据';

  @override
  String get dashSalesOrders => '订单数';

  @override
  String get dashSalesMonthly => '每月接单数';

  @override
  String get dashSalesThisYear => '今年';

  @override
  String get dashSalesLastYear => '去年';

  @override
  String get dashSalesTop => '热门商品';

  @override
  String get dashSalesToPurchase => '待采购商品';

  @override
  String get dashSalesToPurchaseEmpty => '没有需要采购的商品';

  @override
  String get dashSalesAllCountries => '所有国家';

  @override
  String get dashSalesEmpty => '此期间没有订单';

  @override
  String get dashBackordered => '欠货';

  @override
  String dashUnitsCount(int count) {
    return '$count件';
  }

  @override
  String get productMaker => '制造商';

  @override
  String get productInspectionByWarehouse => '是否验货按仓库设置（仓库页面的“验货方式”）。';

  @override
  String get supplierNameJan => '供应商的JAN（可选）';

  @override
  String get supplierNameMaker => '供应商的制造商写法（可选）';

  @override
  String qcUnconvertedBlock(int count) {
    return '有$count行尚未转换为本公司商品，请逐行“转换为本公司商品”。';
  }

  @override
  String qcSampleDone(String name) {
    return '$name：抽检完成，此行已合格';
  }

  @override
  String qcSampleProgress(String name, int done, int target) {
    return '$name：抽检 $done/$target';
  }

  @override
  String qcConverted(String name) {
    return '已转换为“$name”';
  }

  @override
  String qcSamplingBadge(int percent, int min) {
    return '抽检（$percent%，至少$min件）';
  }

  @override
  String qcUnconvertedCount(int count) {
    return '未转换 $count行';
  }

  @override
  String qcOwnSku(String code) {
    return '货号 $code';
  }

  @override
  String qcSupplierNotation(String text) {
    return '供应商写法：$text';
  }

  @override
  String get qcUnconverted => '未转换';

  @override
  String qcSampleState(int done, int target) {
    return '抽检 $done/$target';
  }

  @override
  String get qcConvert => '转换为本公司商品';

  @override
  String get qcConvertChange => '更改商品';

  @override
  String get qcSampleAdd => '抽检 +1';

  @override
  String get qcConvertTitle => '转换为本公司商品';

  @override
  String get qcConvertSearch => '按本公司名称、JAN、货号、制造商搜索';

  @override
  String get qcConvertRemember => '记住此供应商的写法，下次自动转换';

  @override
  String get qcConvertNone => '没有符合的商品';

  @override
  String get qcErrorUnconverted => '未转换为本公司商品的行不能合格，请先转换。';

  @override
  String get qcErrorNotSampling => '此验货不是抽检';

  @override
  String get qcErrorNoJan => '所选商品没有JAN';

  @override
  String get qcErrorSerialConvert => '序列号管理的行不能转换，请取消入库后重新入库';

  @override
  String get whInspectionEdit => '验货方式';

  @override
  String get whInspectionFull => '全数验货';

  @override
  String whInspectionSampleShort(int percent, int min) {
    return '抽检 $percent%（至少$min）';
  }

  @override
  String get whInspectionNone => '无需验货（仅入库）';

  @override
  String get whInspectionSaved => '已保存验货方式';

  @override
  String whInspectionTitle(String name) {
    return '$name 的验货方式';
  }

  @override
  String get whInspectionFullBody => '来自供应商的到货全部待验货，验货完成前不能出货。';

  @override
  String get whInspectionSample => '抽检';

  @override
  String get whInspectionSampleBody => '到货待验货，但每行只检查一部分；抽检完成后该行合格。';

  @override
  String get whInspectionSamplePercent => '抽检比例';

  @override
  String get whInspectionSampleMin => '最少件数';

  @override
  String get whInspectionNoneBody => '适用于在本系统之外（如委托外部）验货的仓库。到货直接成为可用库存。';

  @override
  String get whInspectionApplies => '适用于供应商到货，不影响仓库间调拨。';

  @override
  String get productMakerRequired => '请输入制造商（商品必须有制造商）';

  @override
  String get productPickerTitle => '选择本公司商品';

  @override
  String get featNotationTraining => '表记预先学习';

  @override
  String get featNotationTrainingDesc => '从Excel、PDF、照片预先学习各商社的写法';

  @override
  String get ntTitle => '表记预先学习';

  @override
  String get ntTabTrain => '预先学习';

  @override
  String get ntTabDialects => '方言词典';

  @override
  String get ntTabColumns => '列标题';

  @override
  String get ntTabHistory => '历史、倾向';

  @override
  String get ntPartner => '商社（往来单位）';

  @override
  String get ntAllPartners => '全部（共通）';

  @override
  String get ntChoosePartner => '请选择商社';

  @override
  String get ntChooseFile => '请选择文件';

  @override
  String ntLearned(int learned, int added, int conflicts) {
    return '已学习$learned项（新增$added、冲突$conflicts）';
  }

  @override
  String get ntTrainIntro =>
      '读取商社的Excel、CSV、PDF、照片样本，以与实际入库相同的方式试读（AI读两次、拆分品名与货号、转换为本公司商品），不会登记任何内容。确认修正后点“学习”，即记住该商社的写法和列标题。';

  @override
  String get ntPickFile => '选择样本文件';

  @override
  String get ntRead => '读取试验';

  @override
  String get ntReread => '按修正的列重新读取';

  @override
  String get ntReading => '读取中（PDF、照片由AI读取两次）…';

  @override
  String ntLinesTitle(int count) {
    return '明细 $count行';
  }

  @override
  String get ntDiscard => '放弃';

  @override
  String ntLearn(int count) {
    return '学习$count行';
  }

  @override
  String ntSummaryLines(int count) {
    return '$count行';
  }

  @override
  String ntSummaryResolved(int done, int total) {
    return '已转换 $done/$total';
  }

  @override
  String ntSummaryReview(int count) {
    return '需确认 $count行';
  }

  @override
  String get ntReadTwice => 'AI读取两次已核对';

  @override
  String get ntReadOnce => '核对读取失败（仅一次）';

  @override
  String get ntReadSheet => '从表格读取（列也由AI确认）';

  @override
  String get ntErrorsTitle => '发现的问题';

  @override
  String get ntColumnsTitle => '列的读法';

  @override
  String get ntColumnsHint => '如有错误请修正后重新读取。学习后将记住为该商社的标题。';

  @override
  String get ntNoHeader => '（无标题）';

  @override
  String ntAiThinks(String field) {
    return 'AI判断：$field';
  }

  @override
  String get ntNotMatched => '未找到本公司商品';

  @override
  String get ntChooseProduct => '选择本公司商品';

  @override
  String get ntChangeProduct => '更改';

  @override
  String ntSplitFrom(String text) {
    return '拆分前：$text';
  }

  @override
  String ntOtherReading(String field, String value) {
    return '另一读法（$field）：$value';
  }

  @override
  String get ntDialectsIntro => '各商社的写法（方言）及其对应的本公司商品、制造商，各有ID（D-000000）。';

  @override
  String get ntAllFields => '全部';

  @override
  String get ntUnconfirmedOnly => '仅未确认';

  @override
  String get ntDialectSearch => '按写法、品名、JAN搜索';

  @override
  String get ntDialectsEmpty => '尚未学习写法';

  @override
  String ntSeen(int count) {
    return '$count次';
  }

  @override
  String get ntConfirm => '设为已确认';

  @override
  String get ntAddColumn => '添加标题';

  @override
  String get ntColumnHeader => '标题（按商社写法）';

  @override
  String get ntColumnsIntro => '列标题及其含义。将日语（汉字、假名）或英语标题对应到本公司项目。选择商社可显示其专用标题。';

  @override
  String get ntCommon => '共通';

  @override
  String get ntStatsTitle => '各商社的倾向';

  @override
  String get ntHistoryEmpty => '尚无预先学习记录';

  @override
  String get ntUnknownPartner => '未指定商社';

  @override
  String ntStatsLine(
      int runs, int lines, String rate, int dialects, int columns) {
    return '$runs次、$lines行、转换率$rate、方言$dialects项、标题$columns项';
  }

  @override
  String get ntRunsTitle => '读取历史';

  @override
  String get ntStatusLearned => '已学习';

  @override
  String get ntStatusDiscarded => '已放弃';

  @override
  String get ntStatusRead => '未学习';

  @override
  String get ntFieldJan => 'JAN';

  @override
  String get ntFieldMaker => '制造商';

  @override
  String get ntFieldName => '品名';

  @override
  String get ntFieldCode => '货号';

  @override
  String get ntFieldNameCode => '品名＋货号（一栏）';

  @override
  String get ntFieldQuantity => '数量';

  @override
  String get ntFieldCaseQuantity => '入数';

  @override
  String get ntFieldCases => '箱数';

  @override
  String get ntFieldUnitPrice => '单价';

  @override
  String get ntFieldAmount => '金额';

  @override
  String get ntFieldSpec => '规格';

  @override
  String get ntFieldTaxRate => '税率';

  @override
  String get ntFieldDate => '日期';

  @override
  String get ntFieldIgnore => '不使用';

  @override
  String get ntFieldUnknown => '不明';

  @override
  String get ntSourcePartner => '该商社已学习';

  @override
  String get ntSourceGlobal => '共通标题';

  @override
  String get ntSourceContains => '从标题部分推定';

  @override
  String get ntSourceValues => '从数值判定';

  @override
  String get ntSourceAi => 'AI判定';

  @override
  String get ntSourceOverride => '手动修正';

  @override
  String get ntSourceNone => '无法判定';

  @override
  String get ntFlagUnresolved => '无本公司商品';

  @override
  String get ntFlagJanCheck => 'JAN校验位错误';

  @override
  String get ntFlagNoJan => '无JAN';

  @override
  String get ntFlagNoMaker => '无制造商';

  @override
  String get ntFlagNoQuantity => '无数量';

  @override
  String get ntFlagAmount => '金额≠数量×单价';

  @override
  String get ntFlagAiDisagree => 'AI两次读取不一致';

  @override
  String ntFlagAiDisagreeOn(String field) {
    return 'AI读取不一致：$field';
  }

  @override
  String get ntFlagSplitDisagree => '品名货号拆分不一致';

  @override
  String get ntFlagSplitSingle => '已拆分品名货号（仅一种方法）';

  @override
  String get ntFlagSplitFailed => '无法拆分品名货号';

  @override
  String get ntFlagAdded => '核对时追加的行';

  @override
  String get ntFlagDropped => '核对时消失的行';

  @override
  String get ntFlagNotVerified => '无核对读取';

  @override
  String get ntFlagQtyFromCases => '数量＝入数×箱数';

  @override
  String get ntMatchJan => 'JAN一致';

  @override
  String get ntMatchDialect => '已学习方言一致';

  @override
  String get ntMatchSku => '本公司货号一致';

  @override
  String get ntMatchName => '本公司品名一致';

  @override
  String get ntMatchManual => '手动选择';

  @override
  String get ntMatchNone => '';

  @override
  String importSupplierWriting(String text) {
    return '对方写法：$text';
  }

  @override
  String importUnresolvedLines(int count) {
    return '$count行尚未转换为本公司商品。请选择，或先登记并在检品时转换。';
  }

  @override
  String get importColumnsRead => '列的识别方式';

  @override
  String get importNotVerified => 'AI复核读取失败（仅读取一次）。请仔细核对明细。';

  @override
  String get groupSupplyChain => '供应链';

  @override
  String get featScDashboard => '收益仪表板';

  @override
  String get featScDashboardDesc => '从采购到销售最终剩余多少';

  @override
  String get featScSuppliers => '供应商比较';

  @override
  String get featScSuppliersDesc => '按最终利润而非最低价比较';

  @override
  String get featScCosts => '成本结构';

  @override
  String get featScCostsDesc => '成本明细及成本、关税、汇率规则';

  @override
  String get featScRoutes => '物流路线';

  @override
  String get featScRoutesDesc => '海运、空运、卡车与清关路线及费用';

  @override
  String get featScSimulation => '利润模拟';

  @override
  String get featScSimulationDesc => '更改供应商、折扣率、运费、关税、汇率等进行试算';

  @override
  String get featScRisk => '风险分析';

  @override
  String get featScRiskDesc => '供应商、据点、路线的风险及原因';

  @override
  String get featScBottleneck => '瓶颈';

  @override
  String get featScBottleneckDesc => '容量紧张及停运影响';

  @override
  String get featScHistory => '情景历史';

  @override
  String get featScHistoryDesc => '已保存的情景及结果';

  @override
  String get scRevenue => '销售额';

  @override
  String get scPurchase => '采购成本';

  @override
  String get scFxImpact => '汇率影响';

  @override
  String get scLogistics => '物流费';

  @override
  String get scCustoms => '清关与关税';

  @override
  String get scWarehouse => '仓储费';

  @override
  String get scLabor => '人工费';

  @override
  String get scOther => '其他费用';

  @override
  String get scTotalCost => '总成本';

  @override
  String get scProfit => '毛利';

  @override
  String get scMargin => '利润率';

  @override
  String get scLeadTime => '平均交期';

  @override
  String get scSalesRelated => '销售相关费用';

  @override
  String get scRecoverable => '可抵扣/退还（不计入成本）';

  @override
  String get scLinePurchase => '采购';

  @override
  String get scLineFx => '汇率影响';

  @override
  String get scLineIntlFreight => '国际运费';

  @override
  String get scLineInsurance => '保险';

  @override
  String get scLineDuty => '关税';

  @override
  String get scLineImportTax => '进口税（不可抵扣）';

  @override
  String get scLineCustomsFee => '清关费';

  @override
  String get scLinePortFee => '港口/机场费';

  @override
  String get scLineDomesticFreight => '国内运费';

  @override
  String get scLineWarehouse => '仓储费';

  @override
  String get scLineReceiving => '入库作业';

  @override
  String get scLineInspection => '检品';

  @override
  String get scLinePacking => '包装';

  @override
  String get scLineLabor => '人工费';

  @override
  String get scLineOverhead => '公共费用';

  @override
  String get scLineOther => '其他';

  @override
  String get scLineRevenue => '销售额';

  @override
  String get scLandedCost => '到岸成本';

  @override
  String get scSalesPrice => '销售价格';

  @override
  String get scProfitPerUnit => '单件利润';

  @override
  String get scAnnualProfit => '年利润';

  @override
  String get scVolume => '年销量';

  @override
  String scDays(String days) {
    return '$days天';
  }

  @override
  String get scCurrent => '当前';

  @override
  String get scSimulated => '模拟';

  @override
  String get scDifference => '与当前差额';

  @override
  String get scCurrentValues => '当前值';

  @override
  String get scSimulatedValues => '模拟值（不会更改实际数据）';

  @override
  String get scDrivers => '变动原因';

  @override
  String get scNoData => '暂无可计算成本的商品';

  @override
  String get scNoDataBody =>
      '登记每个商品的采购条件（供应商、价格、折扣率）后即可计算成本和利润，也可从采购订单和送货单的单价导入。';

  @override
  String get scSeed => '从采购记录导入';

  @override
  String scSeeded(int po, int doc) {
    return '已从采购订单导入$po条，从送货单导入$doc条';
  }

  @override
  String get scSnapshot => '保存快照';

  @override
  String get scSnapshotSaved => '已保存当前状态';

  @override
  String get scAllWarehouses => '全部仓库';

  @override
  String get scAlerts => '需关注';

  @override
  String scAlertBottlenecks(int count) {
    return '超出容量/停运 $count处';
  }

  @override
  String scAlertRisks(int count) {
    return '高风险 $count项';
  }

  @override
  String scAlertNoSupply(int count) {
    return '无供应商商品 $count个';
  }

  @override
  String scAlertLoss(int count) {
    return '亏损商品 $count个';
  }

  @override
  String get scProductsTitle => '按商品利润';

  @override
  String get scCostBreakdown => '成本明细';

  @override
  String get scWaterfall => '从售价到利润（每件）';

  @override
  String get scChosen => '当前采购来源';

  @override
  String get scNoRoute => '未登记路线';

  @override
  String get scProduct => '商品';

  @override
  String get scChooseProduct => '请选择商品';

  @override
  String get scQuantity => '每次订货数量';

  @override
  String get scRates => '比较折扣率';

  @override
  String get scRatesHint => '例: 65,70,75';

  @override
  String get scDiscountRate => '折扣率';

  @override
  String get scUnitPrice => '采购单价';

  @override
  String get scListPrice => '定价';

  @override
  String get scCurrency => '货币';

  @override
  String get scMoq => 'MOQ';

  @override
  String get scOrderLot => '订货批量';

  @override
  String get scLeadTimeDays => '交期（天）';

  @override
  String get scPaymentTerms => '付款条件';

  @override
  String get scPrimary => '主要供应商';

  @override
  String get scDefaultRoute => '默认路线';

  @override
  String get scSupplyTerms => '采购条件';

  @override
  String get scAddTerm => '添加采购条件';

  @override
  String get scSupplier => '供应商';

  @override
  String get scSupplierStats => '供应商实绩';

  @override
  String scStatLine(int products, int sole, int orders) {
    return '$products个品目、独家供应$sole、订单$orders笔';
  }

  @override
  String get scLateRate => '延误率';

  @override
  String get scDefectRate => '不良率';

  @override
  String get scPurchased => '采购额';

  @override
  String get scProfile => '商品前提';

  @override
  String get scEditProfile => '编辑前提';

  @override
  String get scAnnualVolume => '年销量';

  @override
  String get scAnnualVolumeHint => '留空：过去12个月出货量';

  @override
  String get scSalesPriceHint => '留空：商品主数据价格';

  @override
  String get scWeight => '重量（kg/件）';

  @override
  String get scUnitsPerCarton => '每箱件数';

  @override
  String get scStorageDays => '保管天数';

  @override
  String get scHsCode => 'HS编码';

  @override
  String get scOriginCountry => '原产国';

  @override
  String get scCostRules => '成本规则';

  @override
  String get scTariffRules => '关税与进口税';

  @override
  String get scFxRates => '汇率';

  @override
  String get scByProduct => '按商品';

  @override
  String get scAddRule => '添加规则';

  @override
  String get scRuleName => '名称';

  @override
  String get scCategory => '类别';

  @override
  String get scBasis => '计费单位';

  @override
  String get scAmount => '金额/比率';

  @override
  String get scAmountPercentHint => '比率用小数（3% = 0.03）';

  @override
  String get scUnitsPerBasis => '基准数量';

  @override
  String get scUnitsPerBasisHint => '每小时处理量、每箱件数或月分摊数量';

  @override
  String get scExpensed => '计入成本（关闭：可抵扣）';

  @override
  String get scAll => '全部';

  @override
  String get scCatStorage => '保管';

  @override
  String get scCatReceiving => '入库作业';

  @override
  String get scCatInspection => '检品';

  @override
  String get scCatPacking => '包装';

  @override
  String get scCatPicking => '拣货';

  @override
  String get scCatShipping => '出货作业';

  @override
  String get scCatLabor => '人工费';

  @override
  String get scCatOverhead => '公共费用';

  @override
  String get scCatDomesticFreight => '国内配送';

  @override
  String get scCatSalesRelated => '销售相关';

  @override
  String get scCatOther => '其他';

  @override
  String get scBasisPerUnit => '每件';

  @override
  String get scBasisPerUnitMonth => '每件每月';

  @override
  String get scBasisPerCarton => '每箱';

  @override
  String get scBasisPerLine => '每行';

  @override
  String get scBasisPerOrder => '每单';

  @override
  String get scBasisPerHour => '每小时';

  @override
  String get scBasisPercentRevenue => '销售额比率';

  @override
  String get scBasisPercentPurchase => '采购额比率';

  @override
  String get scBasisFixedMonthly => '每月固定';

  @override
  String get scTariffRate => '关税率';

  @override
  String get scImportTaxRate => '进口税率';

  @override
  String get scImportTaxRecoverable => '进口税可抵扣/退还';

  @override
  String get scOtherRate => '其他进口税率';

  @override
  String get scValuation => '完税价格';

  @override
  String get scHsPrefix => 'HS编码（前缀匹配）';

  @override
  String get scDestinationCountry => '目的国';

  @override
  String get scAddTariff => '添加关税规则';

  @override
  String get scRateToBase => '换算汇率（每单位货币）';

  @override
  String get scAddFx => '添加货币';

  @override
  String get scRoutesTab => '路线';

  @override
  String get scNodesTab => '据点';

  @override
  String get scAddRoute => '添加路线';

  @override
  String get scAddNode => '添加据点';

  @override
  String get scRouteName => '路线名称';

  @override
  String get scLegs => '区间';

  @override
  String get scAddLeg => '添加区间';

  @override
  String get scFrom => '出发';

  @override
  String get scTo => '到达';

  @override
  String get scMode => '运输方式';

  @override
  String get scBaseCost => '基本费用（每批）';

  @override
  String get scCostPerKg => '每公斤';

  @override
  String get scCostPerUnit => '每件';

  @override
  String get scInsuranceRate => '保险费率';

  @override
  String get scCapacityKg => '容量（kg/月）';

  @override
  String get scCapacityUnits => '容量（件/月）';

  @override
  String get scCustomsClearance => '在此区间办理进口清关';

  @override
  String get scCustomsCost => '清关费（每批）';

  @override
  String get scRisk => '风险';

  @override
  String get scApplyRoute => '将此路线用于情景';

  @override
  String get scNoRoutes => '暂无路线';

  @override
  String get scNoRoutesBody => '登记从供应商到仓库的区间（海运、空运、卡车、清关）后，运费、关税和交期将计入计算。';

  @override
  String get scNodeName => '名称';

  @override
  String get scNodeKind => '类型';

  @override
  String get scCountry => '国家代码';

  @override
  String get scDwellDays => '滞留天数';

  @override
  String get scHandlingPerUnit => '装卸费（每件）';

  @override
  String get scKindSupplier => '供应商';

  @override
  String get scKindPort => '港口';

  @override
  String get scKindAirport => '机场';

  @override
  String get scKindCustoms => '海关';

  @override
  String get scKindWarehouse => '仓库';

  @override
  String get scKindDc => '配送中心';

  @override
  String get scKindCustomer => '客户';

  @override
  String get scKindHub => '中转据点';

  @override
  String get scModeSea => '海运';

  @override
  String get scModeAir => '空运';

  @override
  String get scModeTruck => '卡车';

  @override
  String get scModeRail => '铁路';

  @override
  String get scModeCourier => '快递';

  @override
  String get scModeInternal => '内部调拨';

  @override
  String get scRiskLow => '低';

  @override
  String get scRiskMedium => '中';

  @override
  String get scRiskHigh => '高';

  @override
  String get scRiskCritical => '严重';

  @override
  String get scScenario => '情景';

  @override
  String get scCurrentConditions => '当前条件';

  @override
  String get scScenarioName => '情景名称';

  @override
  String get scSuppliersUsed => '使用的供应商';

  @override
  String get scRouteChoice => '物流';

  @override
  String get scRouteCurrent => '当前路线';

  @override
  String get scRouteCheapest => '最便宜';

  @override
  String get scRouteFastest => '最快';

  @override
  String get scSupplierChoice => '供应商选择方式';

  @override
  String get scChoiceCurrent => '当前供应商';

  @override
  String get scChoiceCheapest => '利润最高';

  @override
  String get scChoiceFastest => '交期最短';

  @override
  String get scChanges => '变更条件（±%）';

  @override
  String get scChangeHint => '例：+10为上涨10%，-5为下降5%';

  @override
  String get scPriceChange => '采购价格';

  @override
  String get scFreightChange => '运费（全部）';

  @override
  String get scSeaChange => '海运运费';

  @override
  String get scAirChange => '空运运费';

  @override
  String get scTariffChange => '关税';

  @override
  String get scCustomsChange => '清关费';

  @override
  String get scWarehouseChange => '仓储费';

  @override
  String get scLaborChange => '人工费';

  @override
  String get scOverheadChange => '公共费用';

  @override
  String get scFxChange => '汇率（外币升值）';

  @override
  String get scSalesPriceChange => '销售价格';

  @override
  String get scVolumeChange => '销量';

  @override
  String get scRatesBySupplier => '折扣率变更';

  @override
  String scRateNow(String rate) {
    return '当前 $rate';
  }

  @override
  String get scAddSupplier => '添加供应商（试算）';

  @override
  String get scAddedSupplier => '要添加的供应商';

  @override
  String get scApplyRiskEvents => '反映已登记的风险';

  @override
  String get scRun => '运行模拟';

  @override
  String get scSaveScenario => '保存情景';

  @override
  String get scScenarioSaved => '情景已保存';

  @override
  String get scAddToCompare => '加入比较';

  @override
  String get scCompare => '比较（最多5个）';

  @override
  String get scRunCompare => '比较';

  @override
  String get scClearCompare => '清除';

  @override
  String get scCompareFull => '最多可比较5个情景';

  @override
  String scResultTitle(String name) {
    return '情景：$name';
  }

  @override
  String get scProductChanges => '按商品变化';

  @override
  String get scNotBest => '系统不会决定哪个最好，请综合利润、交期和风险自行判断。';

  @override
  String get scHighRisks => '高风险';

  @override
  String get scOverCapacity => '超出容量';

  @override
  String get scRiskTitle => '风险一览';

  @override
  String get scRiskRuleNote => '风险值基于可解释的规则计算：设定等级、登记风险、容量、独家供应、延误率和不良率。';

  @override
  String get scRiskEvents => '已登记的风险';

  @override
  String get scAddRiskEvent => '登记风险';

  @override
  String get scRiskEventTitle => '内容';

  @override
  String get scRiskKind => '类型';

  @override
  String get scSeverity => '严重程度';

  @override
  String get scStartsOn => '开始日期';

  @override
  String get scEndsOn => '结束日期';

  @override
  String get scPriceMultiplier => '价格倍率';

  @override
  String get scCostMultiplier => '费用倍率';

  @override
  String get scCapacityMultiplier => '容量倍率';

  @override
  String get scDelayDays => '延误天数';

  @override
  String get scTarget => '对象';

  @override
  String scReasonLevel(String level) {
    return '设定等级：$level';
  }

  @override
  String scReasonSole(String count) {
    return '独家供应 $count个品目';
  }

  @override
  String scReasonEvent(String kind) {
    return '登记风险：$kind';
  }

  @override
  String scReasonLate(String rate) {
    return '延误率 $rate%';
  }

  @override
  String scReasonDefect(String rate) {
    return '不良率 $rate%';
  }

  @override
  String get scReasonLoadExceeded => '超出容量';

  @override
  String get scReasonLoadBusy => '容量紧张';

  @override
  String get scReasonNoAlt => '无替代路径';

  @override
  String scReasonLongLead(String days) {
    return '交期较长 $days天';
  }

  @override
  String get scReasonCrossBorder => '跨境';

  @override
  String get scEvSupplierStop => '供应商停供';

  @override
  String get scEvSupplierPrice => '供应商涨价';

  @override
  String get scEvSupplierDelay => '供应商延迟交货';

  @override
  String get scEvRouteStop => '路线停运';

  @override
  String get scEvModeStop => '运输方式停运';

  @override
  String get scEvPortStop => '港口停运';

  @override
  String get scEvAirportStop => '机场停运';

  @override
  String get scEvCustomsDelay => '清关延误';

  @override
  String get scEvWarehouseCapacity => '仓库容量不足';

  @override
  String get scEvWarehouseStop => '仓库停运';

  @override
  String get scEvDomesticStop => '国内配送停运';

  @override
  String get scEvStaffShortage => '人手不足';

  @override
  String get scEvCostSpike => '成本激增';

  @override
  String get scRiskKindSupplier => '供应商';

  @override
  String get scRiskKindNode => '据点';

  @override
  String get scRiskKindRoute => '路线';

  @override
  String get scNoRisks => '暂无评估对象';

  @override
  String get scLoadsTitle => '容量与负荷';

  @override
  String get scStatusOk => '充裕';

  @override
  String get scStatusBusy => '紧张';

  @override
  String get scStatusExceeded => '超出容量';

  @override
  String get scStatusNoCapacity => '未设定容量';

  @override
  String get scStatusStopped => '停运';

  @override
  String get scAlternative => '有替代';

  @override
  String get scNoAlternative => '无替代';

  @override
  String scPerMonth(String units) {
    return '$units件/月';
  }

  @override
  String scLoadPercent(String percent) {
    return '负荷 $percent';
  }

  @override
  String get scDisruptionTitle => '故障模拟';

  @override
  String get scDisruptionTarget => '停运对象';

  @override
  String get scDisruptionDays => '天数';

  @override
  String get scDisruptionKind => '故障类型';

  @override
  String get scStop => '停运';

  @override
  String get scDelay => '延误';

  @override
  String get scRunDisruption => '计算影响';

  @override
  String get scImpact => '对利润的影响';

  @override
  String get scExtraCost => '追加费用';

  @override
  String get scLostProfit => '销售机会损失';

  @override
  String get scLostUnits => '缺货数量';

  @override
  String get scRerouted => '替代运输';

  @override
  String scCoverage(String days) {
    return '库存可覆盖$days天';
  }

  @override
  String get scNoAlternativeRoute => '无替代路线';

  @override
  String scAlternativeVia(String name) {
    return '替代：$name';
  }

  @override
  String get scNoLoads => '暂无物流，请登记路线和数量。';

  @override
  String get scSavedScenarios => '已保存的情景';

  @override
  String get scRunHistory => '运行历史';

  @override
  String get scRunAgain => '再次运行';

  @override
  String get scNoScenarios => '暂无已保存的情景';

  @override
  String get scNoRuns => '暂无运行记录';

  @override
  String get scRunKindBaseline => '当前';

  @override
  String get scRunKindScenario => '情景';

  @override
  String get scRunKindCompare => '比较';

  @override
  String get scRunKindDisruption => '故障';

  @override
  String get scRunKindProduct => '商品';

  @override
  String get scRunKindPurchaseCheck => '下单前检查';

  @override
  String get scProductCard => '成本与利润';

  @override
  String get scOpenComparison => '比较供应商';

  @override
  String get scNoTerms => '此商品暂无采购条件';

  @override
  String get scProfitWarning => '利润警告';

  @override
  String scProfitWarningBody(String before, String after) {
    return '按本次条件，利润率将从 $before 变为 $after。';
  }

  @override
  String get scWarnMarginLow => '利润率低于基准';

  @override
  String get scWarnMarginDrop => '利润率大幅下降';

  @override
  String get scWarnLoss => '亏损';

  @override
  String get scCauses => '原因';

  @override
  String get scContinueOrder => '继续下单';

  @override
  String get scBackToEdit => '返回';

  @override
  String get scNoteNoRoute => '未登记路线（不计物流费）';

  @override
  String get scNoteNoWeight => '未设定重量';

  @override
  String get scNoteNoVolume => '无数量（按1件计算）';

  @override
  String get scNoteNoPrice => '无采购价格';

  @override
  String get scNoteNoFx => '无汇率';

  @override
  String get scNoteNoTariff => '无关税规则';

  @override
  String get scNoteFixed => '固定费用无法分摊';

  @override
  String get scHypothetical => '试算';

  @override
  String get scManageOnly => '编辑需要 supply_chain.manage 权限';

  @override
  String get scRecalculate => '重新计算';

  @override
  String get scBlocked => '不可用';

  @override
  String get scErrorRouteLegs => '区间未衔接（每段必须从上一段的到达地出发）';

  @override
  String get scErrorNameRequired => '请输入名称';

  @override
  String get scNoChange => '无变化';

  @override
  String get aiFieldProduct => '本公司商品';

  @override
  String get aiBandAuto => '自动候选';

  @override
  String get aiBandReview => '建议确认';

  @override
  String get aiBandHuman => '需人工确认';

  @override
  String get aiSaved => '已保存阈值';

  @override
  String get featAiSettings => 'AI设置';

  @override
  String get featAiSettingsDesc => '读取置信度阈值';

  @override
  String get aiSettingsIntro =>
      '读取结果的每个项目都有置信度（根据AI两次读取是否一致、JAN校验码、品名与品番的拆分、数量×单价＝金额等计算）。按所在区间分为自动候选、建议确认、需人工确认。';

  @override
  String get aiAutoThreshold => '自动候选下限';

  @override
  String get aiReviewThreshold => '建议确认下限（低于此为需人工确认）';

  @override
  String get aiExample => '示例';

  @override
  String get featDocExceptions => '单据差异';

  @override
  String get featDocExceptionsDesc => '采购单、发票、送货与检品的不一致';

  @override
  String get docFlagNotOrdered => '采购单中没有';

  @override
  String get docFlagNotInvoiced => '发票中没有';

  @override
  String get docFlagInvoiceQty => '发票数量与采购不同';

  @override
  String get docFlagInvoicePrice => '发票单价与采购不同';

  @override
  String get docFlagShortDelivery => '收货少于发票';

  @override
  String get docFlagInspectShort => '检品数少于收货';

  @override
  String get docFlagDefective => '有不良';

  @override
  String get docInvoiceOpen => '未核对';

  @override
  String get docInvoiceMatched => '一致';

  @override
  String get docInvoiceMismatch => '有差异';

  @override
  String get docInvoiceApproved => '已批准';

  @override
  String get docInvoiceVoid => '作废';

  @override
  String get docMatchOk => '核对一致';

  @override
  String get docMatchMismatch => '有差异';

  @override
  String get docMatchPending => '等待发票';

  @override
  String get docMatchTitle => '单据核对';

  @override
  String get docAddInvoice => '登记发票';

  @override
  String get docTolerance => '允许差';

  @override
  String get docToleranceQty => '数量';

  @override
  String get docTolerancePrice => '单价';

  @override
  String get docOrder => '采购';

  @override
  String get docInvoice => '发票';

  @override
  String get docDelivery => '送货';

  @override
  String get docReceived => '收货';

  @override
  String get docInspection => '检品';

  @override
  String get docOrderAmount => '采购金额';

  @override
  String get docInvoiceAmount => '发票金额';

  @override
  String get docDifference => '差额';

  @override
  String docFailedShort(String n) {
    return '不良$n';
  }

  @override
  String get docUnitPrice => '单价';

  @override
  String docApproved(int n) {
    return '已批准（更新采购条件$n条）';
  }

  @override
  String get docInvoices => '发票';

  @override
  String get docNoInvoices => '暂无发票';

  @override
  String get docLinesSuffix => '行';

  @override
  String get docReadFromDocument => '从单据读取';

  @override
  String get docApprove => '批准';

  @override
  String get docVoid => '作废';

  @override
  String get docInvoiceNumberRequired => '请输入发票编号';

  @override
  String get docSaved => '已保存';

  @override
  String get docReadFromFile => '从发票（PDF、照片、Excel）读取';

  @override
  String get docInvoiceNumber => '发票编号';

  @override
  String get docInvoiceDate => '发票日期';

  @override
  String get docInvoiceTotal => '发票合计';

  @override
  String get docLines => '明细';

  @override
  String get docAddLine => '添加明细';

  @override
  String get docSaveAndMatch => '保存并核对';

  @override
  String get docExceptionsTitle => '单据差异';

  @override
  String get docNoExceptions => '没有差异';

  @override
  String docExceptionCount(int count) {
    return '需确认 $count项';
  }

  @override
  String docDeltaQty(String n) {
    return '数量 $n';
  }

  @override
  String docDeltaPrice(String n) {
    return '单价 $n';
  }

  @override
  String get poDocumentMatch => '单据核对';

  @override
  String get ntTabVersions => '版本';

  @override
  String get ntSnapshot => '保存当前版本';

  @override
  String get ntSnapshotNote => '备注（例：新格式）';

  @override
  String ntRestored(int version, int dialects, int aliases, int conflicts) {
    return '已恢复v$version（方言$dialects条、表头$aliases条、冲突$conflicts条）';
  }

  @override
  String get ntVersionTraining => '事前学习';

  @override
  String get ntVersionRestore => '恢复';

  @override
  String get ntVersionManual => '手动保存';

  @override
  String get ntVersionsIntro =>
      '按商社以编号保存词典（方言和表头）。每次学习自动保存，不会覆盖。恢复旧版本只补充当前缺少的内容；含义不同的写法不覆盖，作为冲突报告。';

  @override
  String get ntNoVersions => '暂无版本';

  @override
  String ntVersionCounts(int dialects, int aliases) {
    return '方言$dialects、表头$aliases';
  }

  @override
  String get ntVersionCurrent => '当前';

  @override
  String get ntRestore => '恢复';

  @override
  String syncSent(int count) {
    return '已发送$count条';
  }

  @override
  String syncOffline(int count) {
    return '离线 — 记录保存在设备上，恢复网络后发送（未发送 $count条）';
  }

  @override
  String syncPending(int count) {
    return '未发送记录 $count条';
  }

  @override
  String get syncNow => '立即发送';

  @override
  String syncRefused(String reason) {
    return '未能发送的记录：$reason';
  }

  @override
  String get syncDismiss => '关闭';

  @override
  String get errorOffline => '无法连接。请在网络恢复后确认（计数和检品记录保存在设备上）。';

  @override
  String get featProductLibrary => '商品图库';

  @override
  String get featProductLibraryDesc => '每个商品的照片，第一张显示在商品名前';

  @override
  String get plSearchHint => '按商品名、JAN、品番、厂家搜索';

  @override
  String get plWithoutImages => '仅无照片';

  @override
  String get plNoProducts => '没有符合的商品';

  @override
  String plImageCount(int count) {
    return '照片$count张';
  }

  @override
  String get plNoImages => '还没有照片';

  @override
  String get plAddPhoto => '添加照片';

  @override
  String get plFromCamera => '拍照';

  @override
  String get plFromGallery => '选择照片';

  @override
  String get plPutFirst => '放在最前（显示在商品名前）';

  @override
  String get plFace => '封面';

  @override
  String get plMakeFace => '设为第一张';

  @override
  String get plWithdraw => '撤下';

  @override
  String get plWithdrawConfirm => '撤下这张照片吗？（记录会保留）';

  @override
  String get plUploaded => '已添加照片';

  @override
  String get plReorderHint => '拖动可排序。第一张照片（封面）会显示在入库、检品、上架、拣货、出库、订单等画面的商品名前。';

  @override
  String get plFaceHint => '第一张照片（封面）会显示在各画面的商品名前。';

  @override
  String get plGalleryTitle => '商品照片';

  @override
  String get plOpenLibrary => '商品照片';

  @override
  String get plTabPhotos => '照片';

  @override
  String get plTabAttributes => '属性';

  @override
  String get plTabSuppliers => '供应商的叫法';

  @override
  String get plAttributesHint =>
      '本公司的值。各供应商的写法（例：カラー“BK”）列在“供应商的叫法”中，读取时换成本公司的值（色“黑”）。';

  @override
  String get plAttrNew => '添加属性';

  @override
  String get plAttrName => '属性名';

  @override
  String get plAttrUnit => '单位（可选）';

  @override
  String get plAttrValue => '值';

  @override
  String get plAttrHeading => '表头（例：カラー）';

  @override
  String get plSuppliersHint =>
      '各供应商对本商品的叫法——品名、品番、JAN、厂家和属性。事前学习、导入和检品确认后自动积累。';

  @override
  String get plNoSuppliers => '还没有供应商的叫法';

  @override
  String get plSupplierAdd => '添加供应商的叫法';

  @override
  String get plSupplier => '供应商';

  @override
  String get plSupplierSaved => '已保存';

  @override
  String get plWritings => '出现过的写法';

  @override
  String get plAdopt => '设为本公司的值';

  @override
  String plRemoveSupplierConfirm(String name) {
    return '移除 $name 对本商品的叫法和属性吗？（读取用词典保留）';
  }

  @override
  String get ntFieldAttr => '属性';

  @override
  String ntAttr(String name) {
    return '属性：$name';
  }

  @override
  String ntLearnedLibrary(int profiles, int attributes) {
    return '商品图库：供应商叫法$profiles条、属性$attributes条';
  }

  @override
  String get featNameFormats => '商品格式';

  @override
  String get featNameFormatsDesc => '商品名的组成方式，以及批量修改厂家名、颜色等叫法';

  @override
  String get nfTitle => '商品格式';

  @override
  String get nfTabFormats => '格式';

  @override
  String get nfTabMakers => '厂家';

  @override
  String get nfTabValues => '属性值';

  @override
  String get nfIntro =>
      '商品名由\"基本名\"与厂家、品番、尺寸、颜色等部件按所选格式组成。修改格式后，使用该格式的商品名会全部重新生成。手动输入的商品名保持不变。';

  @override
  String get nfDefault => '默认';

  @override
  String nfProducts(int count) {
    return '$count个商品';
  }

  @override
  String get nfNew => '添加格式';

  @override
  String get nfEdit => '编辑格式';

  @override
  String get nfName => '格式名称';

  @override
  String get nfTemplate => '组成方式';

  @override
  String get nfTemplateHint => '必须包含「基本名」';

  @override
  String get nfInsert => '插入项目（点击添加）';

  @override
  String get nfPartBase => '基本名';

  @override
  String get nfPartMaker => '厂家';

  @override
  String get nfPartCode => '品番';

  @override
  String get nfPartJan => 'JAN';

  @override
  String get nfPartUnit => '单位';

  @override
  String get nfSample => '示例';

  @override
  String get nfSampleBase => '圆珠笔';

  @override
  String get nfSampleMaker => '示例文具';

  @override
  String get nfSampleUnit => '支';

  @override
  String get nfSampleColor => '红';

  @override
  String get nfMakeDefault => '设为新商品的默认格式';

  @override
  String get nfPreview => '实际商品名的变化';

  @override
  String get nfPreviewRefresh => '确认';

  @override
  String get nfPreviewNone => '还没有使用此格式的商品';

  @override
  String get nfNeedsBase => '请在组成方式中加入「基本名」';

  @override
  String get nfNeedsName => '请输入格式名称';

  @override
  String nfSaved(int count) {
    return '已保存，重新生成了$count个商品名';
  }

  @override
  String get nfSearchMaker => '搜索厂家（其他写法也可）';

  @override
  String get nfMakersHint => '修改厂家名后，该厂家的商品名也会全部变更。旧名称今后仍识别为同一厂家。';

  @override
  String get nfRename => '修改厂家名';

  @override
  String get nfNewName => '新名称';

  @override
  String nfDialects(int count) {
    return '其他写法$count个';
  }

  @override
  String nfMakerRenamed(int count) {
    return '已应用到$count个商品';
  }

  @override
  String get nfValuesHint =>
      '批量修改属性值的叫法（例：颜色\"赤\"→\"レッド\"）。带有该值的商品名及供应商写法的对应也会随之变更。旧值今后仍识别为新值。';

  @override
  String get nfAttribute => '属性';

  @override
  String get nfFrom => '当前值';

  @override
  String get nfTo => '新值';

  @override
  String get nfRenameEverywhere => '批量修改';

  @override
  String nfValueRenamed(int count) {
    return '已修改$count个商品';
  }

  @override
  String get pnTitle => '商品名组成';

  @override
  String get pnBaseName => '基本名（不含尺寸、颜色）';

  @override
  String get pnUnit => '单位';

  @override
  String get pnListPrice => '定价';

  @override
  String get pnFormat => '格式';

  @override
  String pnFormatDefault(String name) {
    return '默认格式（$name）';
  }

  @override
  String get pnManual => '手动输入商品名（不使用格式）';

  @override
  String get pnName => '商品名';

  @override
  String get pnPreview => '商品名';

  @override
  String get pnLegacy => '此商品尚未分成部件。输入基本名后将按格式生成名称。';

  @override
  String get pnAttrsHint => '尺寸、颜色等在商品照片画面的\"属性\"标签中设置';

  @override
  String get pnNeedsBase => '请输入基本名';

  @override
  String get pnSaved => '已更新商品名';

  @override
  String rpOpen(int count) {
    return '按本公司格式登记未登记商品（$count）';
  }

  @override
  String get rpTitle => '按本公司格式登记商品';

  @override
  String get rpIntro => '已根据单据行生成按本公司格式整理的商品方案。请确认、修改后登记。登记时也会一并学习该供应商的写法。';

  @override
  String get rpNone => '没有可登记的新商品（不含无JAN的行和已登记的商品）';

  @override
  String get rpFromCode => '单据中没有商品名，暂以品番作为名称';

  @override
  String rpRegister(int count) {
    return '登记$count个';
  }

  @override
  String rpRegistered(int count) {
    return '已登记$count个商品';
  }

  @override
  String get rpNeedsMaker => '所选商品需要厂家和基本名';

  @override
  String get ntFieldListPrice => '定价';

  @override
  String get ntFieldDiscountRate => '折扣率';

  @override
  String get ntFieldUnit => '单位';

  @override
  String get ntFieldSupplierCode => '供应商商品代码';

  @override
  String get ntMatchRegistered => '按本公司格式新登记';

  @override
  String get featFieldLibrary => '项目库';

  @override
  String get featFieldLibraryDesc =>
      '汇总各交易方不同的标题（JAN、JANコード、ジャパンコード…），并决定系统显示的名称';

  @override
  String get flTitle => '项目库';

  @override
  String get flIntro =>
      '按单据列的含义（JAN、厂家、品番等）汇总各公司使用的标题。标题会在导入和预先学习时自动增加。点击铅笔可按语言设定本系统显示的名称（空白为标准名称）。';

  @override
  String flBuiltIn(String name) {
    return '标准名称：$name';
  }

  @override
  String get flEditNames => '设定显示名称';

  @override
  String flNamesHint(String name) {
    return '留空的语言保持标准名称\"$name\"。';
  }

  @override
  String get flLangJa => '日语';

  @override
  String get flLangEn => '英语';

  @override
  String get flLangZh => '中文';

  @override
  String get flSaved => '已保存显示名称';

  @override
  String flHeadings(int count) {
    return '各公司标题 $count个';
  }

  @override
  String get flAddHeading => '添加标题';

  @override
  String flAddHeadingTo(String name) {
    return '为\"$name\"添加标题';
  }

  @override
  String get flHeading => '标题（按单据原样）';

  @override
  String get flEveryone => '所有公司通用';

  @override
  String flOnlyFor(String name) {
    return '仅 $name';
  }

  @override
  String flHeadingAdded(String header) {
    return '已添加\"$header\"';
  }

  @override
  String get flAttributes => '商品属性';

  @override
  String get flAttributesHint => '颜色、尺寸等属性名称可在商品照片画面的\"属性\"标签中修改。';

  @override
  String get ntFieldUpstreamCode => '交易方的供应商代码';

  @override
  String get ntFieldCustomerCode => '客户代码（对方给本公司的代码）';

  @override
  String get ntFlagJanExponent => 'JAN被写成指数形式（如4.90E+12），位数已丢失';

  @override
  String get pcRulesTitle => '交易方代码编号规则';

  @override
  String get pcRulesHint => '新增交易方未输入代码时，按此规则编本公司代码。之后可逐个修改。';

  @override
  String get pcPrefix => '前缀';

  @override
  String get pcDigits => '位数';

  @override
  String get pcNext => '下一个编号';

  @override
  String pcNextCode(String code) {
    return '下一个代码：$code';
  }

  @override
  String get pcRulesSaved => '已保存编号规则';

  @override
  String get pcIssueMissing => '为未编号的交易方编号';

  @override
  String pcIssued(int count) {
    return '已为$count家公司编号';
  }

  @override
  String get pcOurCode => '本公司的交易方代码';

  @override
  String get pcAutoHint => '留空则按编号规则自动编号';

  @override
  String get pcTheirCode => '对方给本公司的代码（客户代码）';

  @override
  String get pcTheirCodeHint => '对方发票、报价单上的本公司编号，读取单据时也会自动填入';

  @override
  String pcOurCodeShort(String code) {
    return '本公司代码 $code';
  }

  @override
  String pcTheirCodeShort(String code) {
    return '对方给我方 $code';
  }

  @override
  String get pcVendorCodesTitle => '该交易方的供应商代码';

  @override
  String get pcVendorCodesHint => '交易方给其自身供应商（厂家等）的编号，并非本公司代码。';

  @override
  String get ntFlagJanDisplayExponent => 'JAN显示为指数形式（如4.90E+12），已按其中完整的13位读取';

  @override
  String get ntFlagJanRestored => 'JAN位数已丢失，已按品番对应的商品补全（前几位一致），请确认';

  @override
  String get ntFlagJanRestoreMismatch => 'JAN位数已丢失，且与品番对应商品的前几位不一致，未补全';

  @override
  String get ntFlagJanCodeMismatch => 'JAN与品番指向不同的商品';

  @override
  String get ntAltCodeProduct => '按品番查到的商品';

  @override
  String get ntMatchJanRestored => '按品番补全的JAN';

  @override
  String importJanWarnings(int count) {
    return '有$count行需要确认JAN（点击⚠可报告警告是否正确）';
  }

  @override
  String importJanDisplayExponent(int count) {
    return '有$count行JAN在文件中显示为指数形式（如4.90E+12），但已按完整位数正确读取。另存为CSV会丢失位数，请让对方直接发送Excel（.xlsx）文件';
  }

  @override
  String get wrTitle => '确认警告';

  @override
  String get wrQuestion => '这个警告正确吗？您的回答将用于调整警告规则。';

  @override
  String get wrNote => '备注（可选）';

  @override
  String get wrNoteHint => '例：箱装和单品使用同一品番';

  @override
  String get wrRight => '正确';

  @override
  String get wrWrong => '错误（没有问题）';

  @override
  String get wrThanks => '已报告，将用于调整警告';

  @override
  String get wrStatsTitle => '警告的准确度';

  @override
  String get wrStatsHint => '确认人员报告\"正确／错误\"的次数。错误多的警告将重新审视规则。';

  @override
  String get wrStatsEmpty => '尚无报告。点击行上的⚠即可报告';

  @override
  String wrRightCount(int count) {
    return '正确 $count';
  }

  @override
  String wrWrongCount(int count) {
    return '错误 $count';
  }

  @override
  String get ntFieldMulti => '多个项目（分隔读取）';

  @override
  String get ntFieldMultiPick => '多个项目（分隔读取）…';

  @override
  String ntMultiOf(String parts) {
    return '多项：$parts';
  }

  @override
  String get ntPartSkip => '不读取';

  @override
  String get ntSepAuto => '自动（有／或/则按其分隔，否则按空格）';

  @override
  String get ntSepSpace => '空格';

  @override
  String ntSepChar(String sep) {
    return '「$sep」';
  }

  @override
  String get ntSeparator => '分隔符';

  @override
  String ntPartsTitle(String header) {
    return '「$header」的分隔方法';
  }

  @override
  String get ntPartsHint => '请按从左到右的顺序点击此栏中的项目。最后一个项目会包含剩余全部内容（品番中有空格也不会被切断）。';

  @override
  String get ntPartsEmpty => '尚未选择';

  @override
  String get ntPartsAdd => '添加项目';

  @override
  String get ntFlagTotalMismatch => '明细合计与单据合计不一致';

  @override
  String get ntReadPdfText => '直接读取PDF中的文字';

  @override
  String get ntNotesTitle => '格式备注（给AI的指示）';

  @override
  String get ntNotesHint => '写在这里的内容会在每次读取该交易方的PDF或照片时告诉AI';

  @override
  String get ntNotesExample => '例：JAN在「备注」栏。品番前的「9A」「8E」等记号不读取。';

  @override
  String get ntNotesSaved => '已保存格式备注';

  @override
  String totalsOk(String sum) {
    return '明细合计 $sum 与单据合计一致';
  }

  @override
  String totalsMismatch(String sum, String expected) {
    return '明细合计 $sum 与单据合计 $expected 不一致，可能有数量或单价读错的行';
  }

  @override
  String totalsNotFound(String sum) {
    return '明细合计 $sum 与单据中任何合计都不一致';
  }

  @override
  String get totalsReport => '报告警告';

  @override
  String get wtSection => '重量';

  @override
  String get wtAdd => '输入重量';

  @override
  String get wtEdit => '修改重量';

  @override
  String get wtNone => '尚未输入重量，不会计入发货总重量';

  @override
  String wtPerUnit(String weight, String unit) {
    return '每$unit $weight';
  }

  @override
  String wtGramsLabel(String unit) {
    return '$unit的重量';
  }

  @override
  String get wtSourceManual => '手动输入';

  @override
  String get wtSourceMeasured => '实测';

  @override
  String get wtSourceWeb => '网上查到的值';

  @override
  String get wtUrl => '查询的网页（可选）';

  @override
  String get wtNote => '备注（可选）';

  @override
  String get wtClear => '清除重量';

  @override
  String get wtInvalid => '请输入0以上的数字';

  @override
  String get wtPackEdit => '修改单位与重量';

  @override
  String get wtPackageLabel => '箱子/外箱本身的重量（可选）';

  @override
  String get wtPackageHint => '加在内容物（入数 × 单个重量）上计算';

  @override
  String get wtGrossLabel => '整箱实测重量（可选）';

  @override
  String get wtGrossHint => '填写后优先于计算值';

  @override
  String get wtPackNoUnitWeight => '该商品尚无单个重量，除非填写整箱重量，否则无法计算外箱重量';

  @override
  String get swSection => '预计发货重量';

  @override
  String get swGoods => '商品';

  @override
  String swGoodsLine(String weight) {
    return '仅商品 $weight';
  }

  @override
  String swBoxes(int count) {
    return '纸箱 $count箱';
  }

  @override
  String get swMaterial => '包装材料';

  @override
  String get swTotal => '总重量（预计）';

  @override
  String get swMeasured => '实际称重';

  @override
  String swMissing(int count) {
    return '$count件商品没有重量，未计入合计';
  }

  @override
  String get swNoPlan => '尚未决定纸箱数量';

  @override
  String get swPlanned => '计划使用的纸箱';

  @override
  String swSuggest(String list) {
    return '按重量估算: $list';
  }

  @override
  String swSuggestOne(int count) {
    return '按重量约$count箱';
  }

  @override
  String swCarton(int no, String type) {
    return '第$no箱 $type';
  }

  @override
  String get swNoType => '（未设置类型）';

  @override
  String swEmpty(String weight) {
    return '箱 $weight';
  }

  @override
  String swMaterialOf(String weight) {
    return '包装材料 $weight';
  }

  @override
  String swEstimate(String weight) {
    return '预计 $weight';
  }

  @override
  String get swSetBox => '纸箱类型与重量';

  @override
  String get swPlanAction => '决定纸箱数量';

  @override
  String get swBoxType => '纸箱类型';

  @override
  String get ctTitle => '纸箱类型';

  @override
  String get ctAdd => '添加纸箱';

  @override
  String get ctEdit => '修改纸箱';

  @override
  String get ctHint => '发货用纸箱的尺寸与重量。预计总重量按此计算。不再使用的请关闭「使用」（历史发货仍引用其名称，因此不删除）。';

  @override
  String get ctName => '名称（例：100尺寸）';

  @override
  String get ctLength => '长';

  @override
  String get ctWidth => '宽';

  @override
  String get ctHeight => '高';

  @override
  String get ctEmptyWeight => '空纸箱重量';

  @override
  String get ctMaterial => '缓冲材等包装材料重量';

  @override
  String get ctMaxLoad => '每箱可装重量上限';

  @override
  String ctMaxLoadOf(String kg) {
    return '上限 $kg kg';
  }

  @override
  String get ctDefault => '常用纸箱';

  @override
  String get ctActive => '使用';

  @override
  String get ctInactive => '不使用';

  @override
  String get ctSaved => '已保存纸箱';

  @override
  String get groupProducts => '商品';

  @override
  String get planMenu => '更多操作';

  @override
  String get planDelete => '删除此计划';

  @override
  String planDeleteQ(String number) {
    return '删除「$number」吗？';
  }

  @override
  String get planDeleteBody => '计划明细也会一并删除。需要时可通过「导入计划」重新上传。已记录入库的计划无法删除。';

  @override
  String planDeleted(String number) {
    return '已删除「$number」';
  }

  @override
  String get productsListView => '列表';

  @override
  String get productsPhotoView => '照片';

  @override
  String get productNameEnTitle => '英文名称';

  @override
  String get productNameEnAdd => '添加英文名称';

  @override
  String get productNameEnLabel => '英文名称（英文与中文界面显示此名称）';

  @override
  String get uomPcs => '个';

  @override
  String get uomSet => '套';

  @override
  String get uomPack => '包';

  @override
  String get uomBox => '盒';

  @override
  String get uomCase => '箱';

  @override
  String get uomBag => '袋';

  @override
  String get uomRoll => '卷';

  @override
  String get uomSheet => '张';

  @override
  String get uomDozen => '打';

  @override
  String get uomPallet => '托盘';

  @override
  String get productNamesTitle => '各语言商品名';

  @override
  String get productNamesJa => '日语（商品名）';

  @override
  String get productNamesJaHint => '日语名称按商品格式生成，请通过“商品名组成”修改';

  @override
  String get productNamesEn => 'English（英文界面显示；无中文名时也显示）';

  @override
  String get productNamesZh => '中文（中文界面及选择中文的打印件显示）';

  @override
  String get featPrintLanguage => '打印语言';

  @override
  String get featPrintLanguageDesc => '送货单、装箱清单、箱标签的打印语言及用语';

  @override
  String get plLanguagesTitle => '打印的语言';

  @override
  String get plLanguagesHint =>
      '按点选顺序排列。第一种语言大字打印，其余在下方小字打印。商品名也按此顺序打印（有该语言名称时）。';

  @override
  String plPreview(String sample) {
    return '示例：$sample';
  }

  @override
  String get plSaved => '已保存';

  @override
  String get plWordsTitle => '单据与标签用语';

  @override
  String get plWordsHint => '点按可修改日语、英语、中文。';

  @override
  String get plWordNeedsAll => '请填写全部三种语言';

  @override
  String get productMenu => '操作';

  @override
  String get productActivate => '启用';

  @override
  String get productAddOne => '添加商品';

  @override
  String get productDeleteQ => '删除此商品？';

  @override
  String productDeleteBody(String name, String jan) {
    return '将删除 $name（JAN $jan），无法恢复。已用于库存或交易的商品无法删除，请改为停用。';
  }

  @override
  String get productDeleteAction => '删除';

  @override
  String productDeleted(String name) {
    return '已删除“$name”';
  }

  @override
  String get productDeleteInUseTitle => '此商品无法删除';

  @override
  String get productDeleteInUse => '它已用于库存、订单、入库、出库或发票。为保留历史记录，请停用而不是删除。';

  @override
  String get productDeleteNotReady =>
      '数据库尚未启用删除功能（0119 的 delete_product），请联系管理员。';

  @override
  String get quoteImportTitle => '从报价单批量登录';

  @override
  String get quoteImportIntro =>
      'AI 读取供应商的报价单（Excel、PDF 或照片）。尚未登录的商品按本公司格式登录，报价中的单价、定价、折扣率、入数作为该供应商的价格保存。同时学习其写法，下次读取更准确。';

  @override
  String get quoteSupplier => '供应商';

  @override
  String get quoteChooseSupplier => '请先选择供应商';

  @override
  String get quoteChooseFile => '选择报价单文件';

  @override
  String get quoteRead => '用 AI 读取';

  @override
  String get quoteReading => '读取中。PDF 或照片可能需要约一分钟。';

  @override
  String get quoteNothingRead => '未能读取商品行。请确认表格有标题（JAN、品名、单价等）。';

  @override
  String get quoteUnverified => 'AI 两次读取结果部分不一致，请核对数字';

  @override
  String quoteSummary(int total, int known, int fresh, int noJan) {
    return '$total 行：已登录 $known、新商品 $fresh、无 JAN $noJan';
  }

  @override
  String quoteRegister(int count) {
    return '登录新商品（$count 件）';
  }

  @override
  String quoteSave(int count) {
    return '保存价格（$count 件）';
  }

  @override
  String quoteSaved(int prices, int products) {
    return '已保存 $prices 个价格（商品 $products 件）';
  }

  @override
  String get quoteLineKnown => '已登录';

  @override
  String get quoteLineRegistered => '本次登录';

  @override
  String get quoteLineNew => '新商品';

  @override
  String get quoteLineNoJan => '无 JAN';

  @override
  String quoteTheirName(String name) {
    return '供应商写法：$name';
  }

  @override
  String quoteUnitPrice(String price) {
    return '单价 $price';
  }

  @override
  String quoteListPrice(String price) {
    return '定价 $price';
  }

  @override
  String quoteRate(String rate) {
    return '折扣率 $rate';
  }

  @override
  String quoteCase(String count) {
    return '入数 $count';
  }
}
