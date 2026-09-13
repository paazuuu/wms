// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WMS';

  @override
  String get search => 'Search';

  @override
  String get retry => 'Retry';

  @override
  String get signOut => 'Sign out';

  @override
  String get backToMenu => 'Back to menu';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get languageTooltip => 'Select language';

  @override
  String get textSizeMenu => 'Text size';

  @override
  String get textSizeNormal => 'Normal';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeXLarge => 'Extra large';

  @override
  String get textSizeXXLarge => 'Max';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get brandSubtitle => 'Warehouse';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get operatorName => 'Operator';

  @override
  String get scannerReady => 'Scanner ready';

  @override
  String get readyToScanTitle => 'Ready to scan';

  @override
  String get readyToScanBody =>
      'Fire a handheld scanner anywhere, or tap to search by barcode, SKU or name.';

  @override
  String get topbarScanHint => 'Scan or search a barcode / SKU';

  @override
  String get menu => 'Menu';

  @override
  String get cameraScan => 'Scan with camera';

  @override
  String get groupFieldOperations => 'Field Operations';

  @override
  String get groupManagement => 'Management';

  @override
  String get featInspection => 'Inspection';

  @override
  String get featInspectionDesc => 'Barcode & quantity checks, NG records';

  @override
  String get featStockAdjustment => 'Stock Adjustment';

  @override
  String get featStockAdjustmentDesc => 'Scan to add or remove with a reason';

  @override
  String get featStockCount => 'Stock Count';

  @override
  String get featStockCountDesc => 'Cycle count by location';

  @override
  String get featPicking => 'Picking';

  @override
  String get featPickingDesc => 'Fulfil sales orders by scan';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get comingSoonBody =>
      'The server API for this is ready — the mobile screen is next on the roadmap.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInSubtitle => 'Sign in to start inspecting';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get loading => 'Loading…';

  @override
  String lineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldContact => 'Contact';

  @override
  String get fieldSupplier => 'Supplier';

  @override
  String get actionComplete => 'Complete';

  @override
  String get actionContinue => 'Continue';

  @override
  String get filterAll => 'All';

  @override
  String get unknownSupplier => 'Unknown supplier';

  @override
  String get pickingEmpty => 'Nothing to pick.';

  @override
  String get noLinesToPick => 'No lines to pick.';

  @override
  String get unnamedProduct => 'Unnamed product';

  @override
  String get pickingEmptyBody =>
      'Open sales orders awaiting fulfilment appear here.';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total picked';
  }

  @override
  String get quantity => 'Quantity';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRecord => 'Record';

  @override
  String get working => 'Working…';

  @override
  String get adjustAdd => 'Add';

  @override
  String get adjustRemove => 'Remove';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get torchOn => 'Torch on';

  @override
  String get torchOff => 'Torch off';

  @override
  String get alignBarcode => 'Align the barcode within the frame';

  @override
  String get scanOrTypeBarcode => 'Scan or type a barcode';

  @override
  String get featDelivery => 'Delivery Check';

  @override
  String get featDeliveryDesc =>
      'Reconcile the delivery note against the Excel plan';

  @override
  String get deliveryStatusOpen => 'Not checked';

  @override
  String get deliveryStatusReconciling => 'Reconciling';

  @override
  String get deliveryStatusPartial => 'Partial';

  @override
  String get deliveryStatusCompleted => 'Reconciled';

  @override
  String get reconPending => 'Pending';

  @override
  String get reconMatched => 'Matched';

  @override
  String get reconShortfall => 'Short';

  @override
  String get reconOver => 'Over';

  @override
  String get reconUnexpected => 'Unexpected';

  @override
  String get deliveryPlansTitle => 'Delivery Check';

  @override
  String get deliveryPlansEmpty => 'No delivery plans.';

  @override
  String get deliveryPlansEmptyBody =>
      'Delivery plans imported from Excel on the back office appear here.';

  @override
  String get deliveryPlansHint => 'Scan or search by voucher no. or supplier';

  @override
  String get deliveryNoMatches => 'No matching delivery plans.';

  @override
  String get deliverySearchTip => 'Try a different voucher number or supplier.';

  @override
  String plannedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planned lines',
      one: '$count planned line',
    );
    return '$_temp0';
  }

  @override
  String get deliveryNumberLabel => 'Voucher no.';

  @override
  String get scanDeliveryHint => 'Scan the item JAN';

  @override
  String get ocrAssist => 'Scan note (OCR)';

  @override
  String ocrFound(int count) {
    return 'Detected $count JAN code(s) on the note';
  }

  @override
  String get ocrNoneFound => 'No JAN codes were found on the note.';

  @override
  String get ocrUnavailable => 'OCR is not available on this device.';

  @override
  String get reconSummaryTitle => 'Reconciliation';

  @override
  String get deliveryPlanned => 'Planned';

  @override
  String get reconReceivedPrev => 'Received';

  @override
  String get reconThisTime => 'This time';

  @override
  String get reconRemaining => 'Left';

  @override
  String get completeReconcile => 'Complete check';

  @override
  String get reconcileConfirmQ => 'Complete this reconciliation?';

  @override
  String get reconcileConfirmBody =>
      'Submit the current counts and close this reconciliation.';

  @override
  String get reconcileConfirmDiscrepancy =>
      'There are discrepancies (short, over or unexpected). Complete anyway?';

  @override
  String get reconcilePartialQ => 'Some items are still outstanding';

  @override
  String reconcilePartialBody(int count) {
    return '$count unit(s) are still outstanding. Save as a partial delivery and keep the rest on the outstanding list, or finalize now and treat the rest as short?';
  }

  @override
  String get reconcileKeepOpen => 'Save as partial';

  @override
  String get reconcileFinalizeShort => 'Finalize (rest short)';

  @override
  String get reconcilePartialSaved =>
      'Saved as partial — the outstanding items are kept';

  @override
  String get reconNoteReference => 'Note';

  @override
  String get reconAlreadyDoneQ => 'This plan is already reconciled';

  @override
  String get reconAlreadyDoneBody =>
      'Recording another receipt will add to stock again. To fix a mistake, cancel the receipt from the history instead.';

  @override
  String doubleScanWarning(String code) {
    return '$code exceeds the planned quantity — double scan?';
  }

  @override
  String get receiptHistoryTitle => 'Receipts / correct';

  @override
  String get receiptEmpty => 'No receipts yet.';

  @override
  String get receiptEmptyBody =>
      'Each time this plan is reconciled, the receipt is recorded here and can be cancelled.';

  @override
  String get receiptCancelAction => 'Cancel receipt';

  @override
  String get receiptCancelledBadge => 'Cancelled';

  @override
  String get receiptCancelQ => 'Cancel this receipt?';

  @override
  String get receiptCancelBody =>
      'The quantities and stock this receipt added will be reversed.';

  @override
  String get receiptCancelledDone => 'Receipt cancelled';

  @override
  String get showCompletedPlans => 'Show reconciled';

  @override
  String get hideCompletedPlans => 'Hide reconciled';

  @override
  String get reconcileDone => 'Reconciliation completed';

  @override
  String get reconcileEmptyCounts => 'Nothing counted yet. Scan to start.';

  @override
  String get unexpectedItem => 'Unexpected item';

  @override
  String enterQuantityFor(String code) {
    return 'Quantity for $code';
  }

  @override
  String get planImportTitle => 'Import plan';

  @override
  String get planImportHint =>
      'Pick an Excel / PDF / image to upload — it is parsed and registered as a plan automatically.';

  @override
  String get planImportChooseFirst =>
      'Choose a file and enter a voucher number.';

  @override
  String planImportedSummary(int count, int total) {
    return 'Imported $count items, $total units total';
  }

  @override
  String get planReadAction => 'Read note';

  @override
  String get planReading => 'Reading…';

  @override
  String get importFormatsHint => 'Excel / PDF / image';

  @override
  String get importChooseFile => 'Choose a file';

  @override
  String get changeFile => 'Change';

  @override
  String get importHeaderSection => 'Header';

  @override
  String get importLinesPreview => 'Line preview';

  @override
  String importMoreLines(int count) {
    return '+$count more';
  }

  @override
  String get planReviewTitle => 'Check the header';

  @override
  String get planReviewHint =>
      'Fields were auto-read from the note. Anything wrong or blank can be edited here before you register it.';

  @override
  String get planCommitAction => 'Register';

  @override
  String get planRegistering => 'Registering…';

  @override
  String planPreviewCount(int count, int total) {
    return '$count items · $total units';
  }

  @override
  String get fieldRegistrationNumber => 'Registration no. (T…)';

  @override
  String get fieldCustomerCode => 'Customer code';

  @override
  String get fieldDocNumber => 'Delivery-note no.';

  @override
  String get headerUnreadHint => 'Could not read — please enter';

  @override
  String get planNeedsReviewBadge => 'Needs check';

  @override
  String get planUnidentifiedNote =>
      'The company could not be read, so this was filed under the “UNKNOWN” series. Enter the supplier to reassign it.';

  @override
  String get referenceNoLabel => 'Ref. no.';

  @override
  String get companyCode => 'Company code';

  @override
  String get totalStockTitle => 'Total stock (by JAN)';

  @override
  String get sortMenu => 'Sort';

  @override
  String get sortByStock => 'By stock';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByJan => 'By JAN';

  @override
  String get stockOnHandUnit => 'on hand';

  @override
  String get stockEmpty => 'No stock yet.';

  @override
  String get stockEmptyBody =>
      'Completed reconciliations accumulate per-JAN stock here.';

  @override
  String get featShipment => 'Shipping';

  @override
  String get featShipmentDesc =>
      'Import a shipping list, pack into cartons, deduct stock';

  @override
  String get shipmentListTitle => 'Shipping';

  @override
  String get shipmentImportTitle => 'Import shipping list';

  @override
  String get shipmentEmpty => 'No shipments.';

  @override
  String get shipmentEmptyBody =>
      'Import a customer\'s Excel / PDF to start a shipment.';

  @override
  String get shipmentSearchHint => 'Search by shipment no. or customer';

  @override
  String get shipmentStatusOpen => 'To pack';

  @override
  String get shipmentStatusPacking => 'Packing';

  @override
  String get shipmentStatusShipped => 'Shipped';

  @override
  String get shipmentStatusCancelled => 'Cancelled';

  @override
  String cartonCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartons',
      one: '$count carton',
    );
    return '$_temp0';
  }

  @override
  String get shipmentLinesSection => 'Shipment list';

  @override
  String get cartonsSection => 'Cartons';

  @override
  String packProgress(int packed, int total) {
    return 'Packed $packed / $total';
  }

  @override
  String get addCarton => 'Add carton';

  @override
  String cartonNoLabel(int no) {
    return 'Carton #$no';
  }

  @override
  String get cartonLabelHint => 'Label (optional), e.g. A-1';

  @override
  String get cartonEditTitle => 'Carton contents';

  @override
  String get packRemaining => 'Unpacked';

  @override
  String get packThisCarton => 'This carton';

  @override
  String get overpackWarning => 'Packed more than the shipment quantity.';

  @override
  String get shipConfirmAction => 'Confirm shipment';

  @override
  String get shipConfirmQ => 'Confirm this shipment?';

  @override
  String get shipConfirmBody => 'The quantities will be deducted from stock.';

  @override
  String get shipShortWarning =>
      'Some items exceed stock on hand. Stock will not go below zero. Confirm anyway?';

  @override
  String get shipDone => 'Shipment confirmed';

  @override
  String get shipCancelAction => 'Undo shipment';

  @override
  String get shipCancelQ => 'Undo this shipment?';

  @override
  String get shipCancelBody =>
      'The deducted quantities will be added back to stock and the shipment reopened.';

  @override
  String get shipCancelledDone => 'Shipment reopened';

  @override
  String get printOverall => 'Print / PDF list';

  @override
  String get printAllCartons => 'Print / PDF cartons';

  @override
  String get printThisCarton => 'Print / PDF';

  @override
  String get printDeliverySlip => 'Print / PDF delivery slip';

  @override
  String get printMenu => 'Print / PDF';

  @override
  String get senderSettingsTitle => 'Sender (your company)';

  @override
  String get senderSettingsHint =>
      'Saved as the default sender. You can pick which fields to include each time you print.';

  @override
  String get senderPickTitle => 'Sender on this print';

  @override
  String get senderInclude => 'Print the sender block';

  @override
  String get senderNoneSet => 'No sender saved yet.';

  @override
  String get senderSaved => 'Sender saved';

  @override
  String get senderPreview => 'Print preview';

  @override
  String get fieldCompanyName => 'Company name';

  @override
  String get fieldPostalCode => 'Postal code';

  @override
  String get fieldFax => 'Fax';

  @override
  String get fieldNote => 'Note';

  @override
  String get deleteCartonQ => 'Delete this carton?';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get dashOverview => 'Overview';

  @override
  String get dashInboundToday => 'Received today';

  @override
  String get dashOutboundToday => 'Shipped today';

  @override
  String get dashOutstanding => 'Outstanding';

  @override
  String get dashTotalStock => 'Total stock';

  @override
  String get dashLowStock => 'Low stock';

  @override
  String get dashTrendTitle => 'Inbound / outbound (14 days)';

  @override
  String get dashInbound => 'In';

  @override
  String get dashOutbound => 'Out';

  @override
  String get dashOutstandingListTitle => 'Outstanding list';

  @override
  String get dashLowStockListTitle => 'Stock alerts';

  @override
  String get dashNoOutstanding => 'Nothing outstanding';

  @override
  String get dashNoAlerts => 'No stock alerts';

  @override
  String dashCount(int count) {
    return '$count entries';
  }

  @override
  String dashSkuCount(int count) {
    return '$count SKUs';
  }

  @override
  String dashThreshold(int count) {
    return 'Threshold $count';
  }

  @override
  String get whAllWarehouses => 'All warehouses';

  @override
  String get whSwitch => 'Switch warehouse';

  @override
  String get whAdd => 'Add warehouse';

  @override
  String get whAddTitle => 'Add warehouse';

  @override
  String get whManage => 'Manage warehouses';

  @override
  String get whOverviewTitle => 'Warehouses';

  @override
  String get whTotals => 'Total';

  @override
  String get whFieldCode => 'Warehouse code';

  @override
  String get whFieldName => 'Warehouse name';

  @override
  String get whFieldAddress => 'Address';

  @override
  String get whFieldPhone => 'Phone';

  @override
  String get whFieldTimezone => 'Timezone';

  @override
  String get whFieldActive => 'Active';

  @override
  String get whFieldDefaultBins => 'Create starter bins';

  @override
  String get whFieldDefaultBinsHelp =>
      'Creates staging, QC hold, shipping and a pickable bin.';

  @override
  String get whFieldReceivingBin => 'Default receiving area';

  @override
  String get whFieldShippingBin => 'Default shipping area';

  @override
  String get whCodeRequired => 'Enter a warehouse code';

  @override
  String get whNameRequired => 'Enter a warehouse name';

  @override
  String whCreated(String name) {
    return 'Added warehouse “$name”';
  }

  @override
  String get whInactive => 'Inactive';

  @override
  String get whStatInbound => 'Inbound';

  @override
  String get whStatOutbound => 'Outbound';

  @override
  String get whStatSku => 'SKU';

  @override
  String get whStatOnHand => 'On hand';

  @override
  String get whNoWarehouses => 'No warehouses yet';

  @override
  String get whBinsTitle => 'Bins';

  @override
  String get whBinStaging => 'Staging';

  @override
  String get whBinPickable => 'Pickable';

  @override
  String get whBinPickableStaging => 'Pickable staging';

  @override
  String get whBinQcHold => 'QC hold';

  @override
  String get whBinShipping => 'Shipping';

  @override
  String get whBinReturns => 'Returns';

  @override
  String get whBinDamaged => 'Damaged';

  @override
  String get whBinVirtual => 'Virtual';

  @override
  String get ledgerTitle => 'Stock history';

  @override
  String get ledgerSubtitle => 'Why this item\'s stock changed';

  @override
  String get ledgerEmpty => 'No stock movements yet';

  @override
  String get ledgerBeforeAfter => 'before → after';

  @override
  String get mvOpening => 'Opening';

  @override
  String get mvReceipt => 'Received';

  @override
  String get mvReceiptCancel => 'Receipt cancelled';

  @override
  String get mvPutaway => 'Put-away';

  @override
  String get mvPick => 'Picked';

  @override
  String get mvShip => 'Shipped';

  @override
  String get mvShipCancel => 'Shipment cancelled';

  @override
  String get mvAdjust => 'Adjustment';

  @override
  String get mvCount => 'Cycle count';

  @override
  String get mvTransferIn => 'Transfer in';

  @override
  String get mvTransferOut => 'Transfer out';

  @override
  String get qcTitle => 'Inspection';

  @override
  String get qcListEmpty => 'No inspections yet';

  @override
  String get qcListEmptyBody =>
      'Start one from a receipt in the receipt history.';

  @override
  String get qcStart => 'Start inspection';

  @override
  String get qcComplete => 'Complete inspection';

  @override
  String get qcResultPending => 'Unchecked';

  @override
  String get qcResultPass => 'Pass';

  @override
  String get qcResultFail => 'Fail';

  @override
  String get qcResultPartial => 'Partial';

  @override
  String get qcResultHold => 'Hold';

  @override
  String get qcPassed => 'Passed';

  @override
  String get qcFailed => 'Failed';

  @override
  String get qcExpected => 'Expected';

  @override
  String get qcActual => 'Actual';

  @override
  String get qcDiscrepancy => 'Discrepancy';

  @override
  String get qcLot => 'Lot';

  @override
  String get qcNote => 'Note';

  @override
  String get qcHold => 'Put on hold';

  @override
  String get qcRecord => 'Record';

  @override
  String qcUnchecked(int count) {
    return '$count unchecked';
  }

  @override
  String get qcCompleteBlocked => 'Cannot complete while lines are unchecked';

  @override
  String qcCompleted(String status) {
    return 'Inspection completed ($status)';
  }

  @override
  String qcFailedUnits(int count) {
    return '$count failed';
  }

  @override
  String get qcSplitHint =>
      'Enter passed and failed counts (they add up to the actual).';

  @override
  String get qcAttachmentsEmpty => 'No photos yet';

  @override
  String get qcAttachmentCamera => 'Take a photo';

  @override
  String get qcAttachmentGallery => 'Choose from gallery';

  @override
  String get whFieldUsesLocations => 'Manage stock by location';

  @override
  String get whFieldUsesLocationsHelp =>
      'Leave off to keep one balance per warehouse. Turn on only if you track stock by shelf — you can change this later.';

  @override
  String get whLocationsOn => 'Locations';

  @override
  String get adjTitle => 'Stock adjustment';

  @override
  String get adjNew => 'Adjust stock';

  @override
  String get adjEmpty => 'No adjustments yet';

  @override
  String get adjEmptyBody =>
      'Correct stock with a reason: damage, loss, found and so on.';

  @override
  String get adjJan => 'JAN code';

  @override
  String get adjQuantity => 'Quantity';

  @override
  String get adjReason => 'Reason';

  @override
  String get adjNote => 'Note';

  @override
  String get adjApply => 'Apply adjustment';

  @override
  String adjDone(String delta) {
    return 'Stock adjusted ($delta)';
  }

  @override
  String get adjNeedsWarehouse => 'Choose a warehouse first';

  @override
  String get adjJanRequired => 'Enter a JAN code';

  @override
  String get adjDeltaRequired => 'Enter a quantity of 1 or more';

  @override
  String get reasonDamage => 'Damage';

  @override
  String get reasonLoss => 'Loss';

  @override
  String get reasonFound => 'Found';

  @override
  String get reasonCorrection => 'Correction';

  @override
  String get reasonReturn => 'Return';

  @override
  String get reasonOther => 'Other';

  @override
  String get cntTitle => 'Stock count';

  @override
  String get cntEmpty => 'No counts yet';

  @override
  String get cntEmptyBody =>
      'Starting a count freezes the current balance into its lines.';

  @override
  String get cntStart => 'Start count';

  @override
  String get cntBlind => 'Blind count';

  @override
  String get cntBlindHelp =>
      'Hides the system quantity until the count is completed, so nobody anchors on it.';

  @override
  String get cntSystem => 'System';

  @override
  String get cntCounted => 'Counted';

  @override
  String get cntVariance => 'Variance';

  @override
  String get cntHidden => 'Hidden until completed';

  @override
  String get cntRecord => 'Enter counted quantity';

  @override
  String get cntComplete => 'Complete count';

  @override
  String get cntCancel => 'Cancel count';

  @override
  String get cntCompleteQ => 'Complete this count?';

  @override
  String get cntCompleteBody =>
      'Only lines with a variance are corrected, and each correction is recorded as a count movement.';

  @override
  String get cntCancelQ => 'Cancel this count?';

  @override
  String get cntCancelBody =>
      'Counted figures are discarded and stock is left unchanged.';

  @override
  String get cntCancelled => 'Count cancelled';

  @override
  String cntProgress(int counted, int total) {
    return '$counted/$total counted';
  }

  @override
  String cntCompleted(int lines, String net) {
    return 'Count completed ($lines lines adjusted, net $net)';
  }

  @override
  String cntUncountedWarn(int count) {
    return '$count uncounted lines are left as they are (not treated as zero)';
  }

  @override
  String get cntStatusCounting => 'Counting';

  @override
  String get cntStatusCompleted => 'Completed';

  @override
  String get cntStatusCancelled => 'Cancelled';

  @override
  String get pickListsTitle => 'Picking';

  @override
  String get pickStart => 'Start picking';

  @override
  String get pickChooseShipment => 'Choose a shipment';

  @override
  String get pickNoShipments => 'No shipments are waiting to be picked';

  @override
  String get pickStatusPicking => 'Picking';

  @override
  String get pickStatusPicked => 'Picked';

  @override
  String get pickStatusCancelled => 'Cancelled';

  @override
  String get pickTaskPending => 'Pending';

  @override
  String get pickTaskPicked => 'Done';

  @override
  String get pickTaskShort => 'Short';

  @override
  String get pickTaskOver => 'Over';

  @override
  String get pickPlanned => 'Planned';

  @override
  String get pickPickedQty => 'Picked';

  @override
  String get pickVariance => 'Variance';

  @override
  String get pickBin => 'Location';

  @override
  String get pickBinNone => 'None';

  @override
  String get pickRecord => 'Record pick';

  @override
  String get pickComplete => 'Complete picking';

  @override
  String get pickCompleteQ => 'Complete this pick list?';

  @override
  String get pickCompleteBody =>
      'The order moves on to packing. Shipping is confirmed separately afterward.';

  @override
  String get pickCancelAction => 'Cancel picking';

  @override
  String get pickCancelQ => 'Cancel this pick list?';

  @override
  String get pickCancelBody =>
      'Recorded quantities are discarded. Stock is left unchanged.';

  @override
  String get pickCancelled => 'Picking cancelled';

  @override
  String pickCompleted(int short, int over) {
    return 'Picking completed ($short short, $over over)';
  }

  @override
  String get pickCompleteBlocked =>
      'Cannot complete: some lines are still unpicked';

  @override
  String get transferTitle => 'Transfers';

  @override
  String get transferNew => 'New transfer';

  @override
  String get transferEmpty => 'No transfers yet';

  @override
  String get transferEmptyBody =>
      'Transfers between warehouses will appear here.';

  @override
  String get transferSource => 'From';

  @override
  String get transferDestination => 'To';

  @override
  String get transferNeedsTwoWarehouses => 'At least two warehouses are needed';

  @override
  String get transferLinesTitle => 'Items to move';

  @override
  String get transferAddLine => 'Add item';

  @override
  String get transferLineJan => 'JAN code';

  @override
  String get transferLineQuantity => 'Quantity';

  @override
  String get transferLineRequired => 'Add at least one item';

  @override
  String get transferNote => 'Note';

  @override
  String get transferCreate => 'Create transfer';

  @override
  String transferCreated(String number) {
    return 'Created transfer $number';
  }

  @override
  String get transferStatusDraft => 'Draft';

  @override
  String get transferStatusPendingApproval => 'Pending approval';

  @override
  String get transferStatusApproved => 'Approved';

  @override
  String get transferStatusPicking => 'Picking';

  @override
  String get transferStatusInTransit => 'In transit';

  @override
  String get transferStatusReceiving => 'Receiving';

  @override
  String get transferStatusCompleted => 'Completed';

  @override
  String get transferStatusRejected => 'Rejected';

  @override
  String get transferStatusCancelled => 'Cancelled';

  @override
  String get transferSubmit => 'Submit for approval';

  @override
  String get transferSubmitted => 'Submitted for approval';

  @override
  String get transferApprove => 'Approve';

  @override
  String get transferApproveQ => 'Approve this transfer?';

  @override
  String get transferApproved => 'Transfer approved';

  @override
  String get transferReject => 'Reject';

  @override
  String get transferRejectQ => 'Reject this transfer?';

  @override
  String get transferRejected => 'Transfer rejected';

  @override
  String get transferCancelAction => 'Cancel transfer';

  @override
  String get transferCancelBody =>
      'No stock has moved yet, so cancelling changes nothing.';

  @override
  String get transferCancelled => 'Transfer cancelled';

  @override
  String get transferStartPicking => 'Start picking';

  @override
  String get transferPickQty => 'Picked';

  @override
  String transferPickProgress(int picked, int total) {
    return '$picked / $total picked';
  }

  @override
  String get transferCompletePicking => 'Confirm shipment';

  @override
  String transferCompletePickingBody(String source) {
    return 'Deducts the picked quantities from $source and switches to in-transit.';
  }

  @override
  String get transferPickIncomplete =>
      'Cannot confirm shipment: some lines are still unpicked';

  @override
  String get transferStartReceiving => 'Start receiving';

  @override
  String get transferReceiveQty => 'Received';

  @override
  String transferReceiveProgress(int received, int total) {
    return '$received / $total received';
  }

  @override
  String get transferCompleteReceiving => 'Confirm receipt';

  @override
  String transferCompleteReceivingBody(String destination) {
    return 'Adds the received quantities to $destination and completes the transfer.';
  }

  @override
  String get transferReceiveIncomplete =>
      'Cannot confirm receipt: some lines are still unreceived';

  @override
  String transferCompleted(int loss) {
    return 'Transfer completed ($loss line(s) with a quantity variance)';
  }

  @override
  String get transferPlanned => 'Planned';

  @override
  String get transferLineProductName => 'Product name (optional)';

  @override
  String get featTransfer => 'Transfers';

  @override
  String get featTransferDesc => 'Move stock between warehouses';

  @override
  String get auditTitle => 'Audit log';

  @override
  String get auditEmpty => 'No audit entries yet';

  @override
  String get auditEmptyBody =>
      'Approvals, rejections and cancellations are recorded here.';

  @override
  String get auditExport => 'Export CSV';

  @override
  String get auditExported => 'Saved the CSV';

  @override
  String get auditExportFailed => 'Could not export the CSV';

  @override
  String get auditEntity => 'Entity';

  @override
  String get auditActor => 'Actor';

  @override
  String get auditActorSystem => 'System';

  @override
  String get csvExportTitle => 'Export CSV';

  @override
  String get featAuditLog => 'Audit log';

  @override
  String get featAuditLogDesc => 'Review operation history, export as CSV';

  @override
  String get featUserManagement => 'User management';

  @override
  String get featUserManagementDesc =>
      'Assign roles to teammates who have signed in';

  @override
  String get featConnectors => 'Connectors';

  @override
  String get featConnectorsDesc =>
      'External systems registered for future integration';

  @override
  String get featAiReview => 'AI review';

  @override
  String get featAiReviewDesc =>
      'Confirm or reject AI-extracted results before they count';

  @override
  String get featProducts => 'Product master';

  @override
  String get featProductsDesc =>
      'Name, category and price against each JAN code';

  @override
  String get featPurchaseOrders => 'Purchase orders';

  @override
  String get featPurchaseOrdersDesc =>
      'Create, approve and manage orders to suppliers';

  @override
  String get featSalesOrders => 'Sales orders';

  @override
  String get featSalesOrdersDesc =>
      'Create, approve and manage orders from customers';

  @override
  String get featPartners => 'Trading partners';

  @override
  String get featPartnersDesc =>
      'Contacts and terms for suppliers and customers';

  @override
  String get featWorkOrders => 'Work orders';

  @override
  String get featWorkOrdersDesc =>
      'Kitting/assembly: consume components, produce a finished item';

  @override
  String get woTitle => 'Work orders';

  @override
  String get woNew => 'New work order';

  @override
  String get woEmpty => 'No work orders yet';

  @override
  String get woEmptyBody => 'Create one with the button below.';

  @override
  String get woNeedsWarehouse => 'No warehouse exists';

  @override
  String get woWarehouse => 'Warehouse';

  @override
  String get woOutputTitle => 'Output';

  @override
  String get woOutputQuantity => 'Output quantity';

  @override
  String get woOutputRequired => 'Enter the output JAN code and quantity';

  @override
  String get woComponentsTitle => 'Components';

  @override
  String get woAddComponent => 'Add component';

  @override
  String get woComponentRequired => 'Add at least one component';

  @override
  String get woComponentQuantity => 'Required quantity';

  @override
  String woComponentCount(int count) {
    return '$count components';
  }

  @override
  String get woNote => 'Note';

  @override
  String get woCreate => 'Create';

  @override
  String get woLineJan => 'JAN code';

  @override
  String get woLineProductName => 'Product name';

  @override
  String get woStart => 'Start';

  @override
  String get woStarted => 'Work order started';

  @override
  String get woComplete => 'Mark complete';

  @override
  String get woCompleteQ =>
      'Complete this work order? Component stock will be consumed and output stock will increase.';

  @override
  String get woCompleted => 'Work order completed';

  @override
  String get woCancelAction => 'Cancel work order';

  @override
  String get woCancelBody => 'Cancel this work order?';

  @override
  String get woCancelled => 'Work order cancelled';

  @override
  String get woStatusDraft => 'Draft';

  @override
  String get woStatusInProgress => 'In progress';

  @override
  String get woStatusCompleted => 'Completed';

  @override
  String get woStatusCancelled => 'Cancelled';

  @override
  String get partnersTitle => 'Trading partners';

  @override
  String get partnersSearchHint => 'Search by name or code';

  @override
  String get partnersEmpty => 'No trading partners yet';

  @override
  String get partnersEmptyBody => 'Add one with the + button.';

  @override
  String get partnerKindAll => 'All';

  @override
  String get partnerKindSupplier => 'Supplier';

  @override
  String get partnerKindCustomer => 'Customer';

  @override
  String get partnerKindBoth => 'Supplier/Customer';

  @override
  String get partnerNewTitle => 'New trading partner';

  @override
  String get partnerEditTitle => 'Edit trading partner';

  @override
  String get partnerName => 'Name';

  @override
  String get partnerCode => 'Code';

  @override
  String get partnerContactName => 'Contact name';

  @override
  String get partnerPhone => 'Phone';

  @override
  String get partnerEmail => 'Email';

  @override
  String get partnerAddress => 'Address';

  @override
  String get partnerPaymentTerms => 'Payment terms';

  @override
  String get partnerNotes => 'Notes';

  @override
  String get partnerSave => 'Save';

  @override
  String get partnerValidationRequired => 'Enter a name';

  @override
  String get soTitle => 'Sales orders';

  @override
  String get soNew => 'New sales order';

  @override
  String get soEmpty => 'No sales orders yet';

  @override
  String get soEmptyBody => 'Create one with the button below.';

  @override
  String get soNeedsWarehouse => 'No warehouse exists';

  @override
  String get soCustomerName => 'Customer name';

  @override
  String get soWarehouse => 'Source warehouse';

  @override
  String get soRequestedShipDate => 'Requested ship date';

  @override
  String get soLinesTitle => 'Lines';

  @override
  String get soAddLine => 'Add line';

  @override
  String get soNote => 'Note';

  @override
  String get soCustomerRequired => 'Enter a customer name';

  @override
  String get soLineRequired => 'Add at least one line';

  @override
  String get soCreate => 'Create';

  @override
  String get soLineJan => 'JAN code';

  @override
  String get soLineProductName => 'Product name';

  @override
  String get soLineQuantity => 'Quantity';

  @override
  String get soLineUnitPrice => 'Unit price';

  @override
  String get soTotalAmount => 'Amount';

  @override
  String get soSubmit => 'Submit';

  @override
  String get soSubmitted => 'Sales order submitted';

  @override
  String get soApprove => 'Approve';

  @override
  String get soApproveQ => 'Approve this sales order?';

  @override
  String get soApproved => 'Sales order approved';

  @override
  String get soReject => 'Reject';

  @override
  String get soRejectQ => 'Reject this sales order?';

  @override
  String get soRejected => 'Sales order rejected';

  @override
  String get soCancelAction => 'Cancel order';

  @override
  String get soCancelBody => 'Cancel this sales order?';

  @override
  String get soCancelled => 'Sales order cancelled';

  @override
  String get soComplete => 'Mark complete';

  @override
  String get soCompleteQ =>
      'Mark this sales order complete? Stock does not move.';

  @override
  String get soCompleted => 'Sales order completed';

  @override
  String get soStatusDraft => 'Draft';

  @override
  String get soStatusSubmitted => 'Submitted';

  @override
  String get soStatusApproved => 'Approved';

  @override
  String get soStatusRejected => 'Rejected';

  @override
  String get soStatusCancelled => 'Cancelled';

  @override
  String get soStatusCompleted => 'Completed';

  @override
  String get poTitle => 'Purchase orders';

  @override
  String get poNew => 'New purchase order';

  @override
  String get poEmpty => 'No purchase orders yet';

  @override
  String get poEmptyBody => 'Create one with the button below.';

  @override
  String get poNeedsWarehouse => 'No warehouse exists';

  @override
  String get poSupplierName => 'Supplier name';

  @override
  String get poWarehouse => 'Destination warehouse';

  @override
  String get poExpectedDate => 'Expected date';

  @override
  String get poLinesTitle => 'Lines';

  @override
  String get poAddLine => 'Add line';

  @override
  String get poNote => 'Note';

  @override
  String get poSupplierRequired => 'Enter a supplier name';

  @override
  String get poLineRequired => 'Add at least one line';

  @override
  String get poCreate => 'Create';

  @override
  String get poLineJan => 'JAN code';

  @override
  String get poLineProductName => 'Product name';

  @override
  String get poLineQuantity => 'Quantity';

  @override
  String get poLineUnitPrice => 'Unit price';

  @override
  String get poTotalAmount => 'Amount';

  @override
  String get poSubmit => 'Submit';

  @override
  String get poSubmitted => 'Purchase order submitted';

  @override
  String get poApprove => 'Approve';

  @override
  String get poApproveQ => 'Approve this purchase order?';

  @override
  String get poApproved => 'Purchase order approved';

  @override
  String get poReject => 'Reject';

  @override
  String get poRejectQ => 'Reject this purchase order?';

  @override
  String get poRejected => 'Purchase order rejected';

  @override
  String get poCancelAction => 'Cancel order';

  @override
  String get poCancelBody => 'Cancel this purchase order?';

  @override
  String get poCancelled => 'Purchase order cancelled';

  @override
  String get poComplete => 'Mark complete';

  @override
  String get poCompleteQ =>
      'Mark this purchase order complete? Stock does not move.';

  @override
  String get poCompleted => 'Purchase order completed';

  @override
  String get poStatusDraft => 'Draft';

  @override
  String get poStatusSubmitted => 'Submitted';

  @override
  String get poStatusApproved => 'Approved';

  @override
  String get poStatusRejected => 'Rejected';

  @override
  String get poStatusCancelled => 'Cancelled';

  @override
  String get poStatusCompleted => 'Completed';

  @override
  String get productsTitle => 'Product master';

  @override
  String get productsShowInactive => 'Show inactive products';

  @override
  String get productsSearchHint => 'Search by name or JAN code';

  @override
  String get productsEmpty => 'No products yet';

  @override
  String get productsEmptyBody => 'Add one with the + button.';

  @override
  String get productActive => 'Active';

  @override
  String get productInactive => 'Inactive';

  @override
  String get productNewTitle => 'New product';

  @override
  String get productEditTitle => 'Edit product';

  @override
  String get productJanCode => 'JAN code';

  @override
  String get productName => 'Name';

  @override
  String get productCategory => 'Category';

  @override
  String get productPrice => 'Price';

  @override
  String get productSave => 'Save';

  @override
  String get productValidationRequired => 'Enter a JAN code and a name';

  @override
  String get dashTodayTasks => 'Today\'s work';

  @override
  String get taskPackingWait => 'To pack';

  @override
  String get taskShippingWait => 'To ship';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search by JAN, document number, or party name';

  @override
  String get searchNoQuery =>
      'Search across deliveries, shipments, transfers and products.';

  @override
  String get searchEmpty => 'No matches';

  @override
  String get searchEmptyBody => 'Try a different keyword.';

  @override
  String get searchKindStock => 'Product';

  @override
  String get searchKindDelivery => 'Delivery';

  @override
  String get searchKindShipment => 'Shipment';

  @override
  String get searchKindPickList => 'Picking';

  @override
  String get searchKindTransfer => 'Transfer';

  @override
  String get userMgmtTitle => 'User Management';

  @override
  String get userMgmtEmpty => 'No users yet';

  @override
  String get userMgmtEmptyBody =>
      'Users appear here once they sign in for the first time.';

  @override
  String get userMgmtAddRole => 'Add role';

  @override
  String get userMgmtNoRoles => 'No role assigned';

  @override
  String get userMgmtAllRolesHeld => 'This user already holds every role.';

  @override
  String get userMgmtRemoveRoleTitle => 'Remove role?';

  @override
  String userMgmtRemoveRoleBody(String role, String name) {
    return 'Remove $role from $name?';
  }

  @override
  String get userMgmtRemoveRoleAction => 'Remove';

  @override
  String get userMgmtWarehousesLabel => 'Warehouse access';

  @override
  String get userMgmtAddWarehouse => 'Add warehouse';

  @override
  String get userMgmtNoWarehouses =>
      'No warehouse assigned (admins still see every warehouse; anyone else sees none)';

  @override
  String get userMgmtAllWarehousesHeld =>
      'This user already has every warehouse.';

  @override
  String get userMgmtRemoveWarehouseTitle => 'Remove warehouse access?';

  @override
  String userMgmtRemoveWarehouseBody(String warehouse, String name) {
    return 'Remove $warehouse from $name?';
  }

  @override
  String get userMgmtRemoveWarehouseAction => 'Remove';

  @override
  String get connectorsTitle => 'Connectors';

  @override
  String get connectorsEmpty => 'No connectors registered';

  @override
  String get connectorsEmptyBody =>
      'External systems will appear here once registered.';

  @override
  String get connectorNoAdapterYet =>
      'No adapter implemented yet — this only registers the connection, nothing syncs.';

  @override
  String get connectorEnabled => 'Enabled';

  @override
  String get connectorDisabled => 'Disabled';

  @override
  String get connectorNeverRun => 'Never run';

  @override
  String get aiReviewTitle => 'AI Review';

  @override
  String get aiReviewEmpty => 'Nothing waiting for review';

  @override
  String get aiReviewEmptyBody =>
      'AI-extracted results appear here until a person confirms or rejects them.';

  @override
  String aiReviewLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines extracted',
      one: '$count line extracted',
    );
    return '$_temp0';
  }

  @override
  String get aiReviewConfirm => 'Confirm';

  @override
  String get aiReviewReject => 'Reject';

  @override
  String get aiReviewRejectTitle => 'Reject this result?';

  @override
  String get aiReviewRejectHint => 'Reason (optional)';

  @override
  String get aiReviewConfirmed => 'Confirmed';

  @override
  String get aiReviewRejected => 'Rejected';
}
