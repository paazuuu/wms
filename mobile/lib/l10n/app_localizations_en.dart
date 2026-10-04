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
  String get errorPermissionDenied => 'You don\'t have permission to do that.';

  @override
  String get errorInspectionCompleted =>
      'This inspection is already completed. Reopen it to see the latest result.';

  @override
  String get errorReceiptInspected =>
      'A receipt whose inspection is completed cannot be cancelled. Use a stock adjustment to correct the stock.';

  @override
  String get errorInspectionClosedReceiveNew =>
      'This receipt\'s inspection is already closed. Receive the extra goods as a new receipt for the same delivery.';

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
  String get receiptEmpty => 'Nothing on this receipt';

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
  String get importLinesEmpty => 'No lines yet. Use \"Add line\" to enter one.';

  @override
  String get importAddLine => 'Add line';

  @override
  String get importEditLine => 'Edit line';

  @override
  String get importLineJan => 'JAN code';

  @override
  String get importLineProduct => 'Product name';

  @override
  String get importLineQuantity => 'Quantity';

  @override
  String get importSplitLine => 'Split line';

  @override
  String get importMergeDuplicates => 'Merge duplicate JANs';

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
  String get cartonStatusOpen => 'Packing';

  @override
  String get cartonStatusPacked => 'Packed';

  @override
  String get cartonStatusShipped => 'Shipped';

  @override
  String get cartonStatusCancelled => 'Cancelled';

  @override
  String get cartonMeasurementsAction => 'Edit size / weight';

  @override
  String get cartonMeasurementsSection => 'Size / weight';

  @override
  String get cartonTypeHint => 'Type (optional), e.g. size 60';

  @override
  String get cartonLength => 'Length';

  @override
  String get cartonWidth => 'Width';

  @override
  String get cartonHeight => 'Height';

  @override
  String cartonDimensionsCm(String length, String width, String height) {
    return '$length × $width × $height cm';
  }

  @override
  String get cartonClose => 'Close box';

  @override
  String get cartonCloseEmptyHint => 'An empty box cannot be closed';

  @override
  String get cartonClosed => 'Box closed';

  @override
  String get cartonReopen => 'Reopen box';

  @override
  String get cartonReopened => 'Box reopened';

  @override
  String get cartonMustReopenToEdit => 'Reopen the box to edit it';

  @override
  String get cartonAddParcel => 'Add';

  @override
  String get cartonPackQuantity => 'Quantity';

  @override
  String cartonUnpackedCount(int qty) {
    return '$qty left';
  }

  @override
  String get cartonLineDone => 'Fully packed';

  @override
  String get cartonRenameAction => 'Rename';

  @override
  String get cartonRenameTitle => 'Carton name';

  @override
  String get cartonSerialNumber => 'Serial number';

  @override
  String get cartonContentsSection => 'In this box';

  @override
  String get cartonContentsEmpty => 'Nothing packed yet';

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
  String get noRoleAssigned => 'No role assigned yet';

  @override
  String get noRoleAssignedBody =>
      'You are signed in, but no role has been assigned to your account yet, so there is nothing you can open. Ask an administrator to assign you one.';

  @override
  String get whNoAssignedWarehouse => 'No warehouse assigned to you';

  @override
  String get whNoAssignedWarehouseBody =>
      'Your account is not assigned to any warehouse yet, so there is nothing to view or work in. Ask an administrator to assign you one.';

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
  String get adjConfirmQ => 'Apply this adjustment?';

  @override
  String get adjConfirmIrreversible => 'This cannot be undone.';

  @override
  String get adjConfirmAction => 'Adjust';

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
  String get reasonInternalUse => 'Internal use';

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
  String get pickItemNoLot => 'No lot recorded';

  @override
  String get pickItemRemove => 'Undo this record';

  @override
  String pickItemUnattributed(int qty) {
    return '$qty unattributed';
  }

  @override
  String get pickLotCode => 'Lot code';

  @override
  String get pickLotCodeHint => 'Optional';

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
      'The products we handle: stock, orders, receipts and shipments hang off these';

  @override
  String get featUnlinkedJan => 'Unlinked JAN codes';

  @override
  String get featUnlinkedJanDesc =>
      'JAN codes in use with no product registered';

  @override
  String get unlinkedJanTitle => 'Unlinked JAN codes';

  @override
  String unlinkedJanCoverage(int linked, int rows) {
    return '$linked / $rows linked';
  }

  @override
  String get unlinkedJanReady => 'Every code is linked to a product';

  @override
  String get unlinkedJanEmpty => 'No unlinked JAN codes';

  @override
  String get unlinkedJanEmptyBody =>
      'Stock, receiving, and shipment records are all linked to a product.';

  @override
  String unlinkedJanRows(int qty) {
    return '$qty rows';
  }

  @override
  String get unlinkedJanSeenAsUnknown => 'Name unknown';

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
  String get featReports => 'Report builder';

  @override
  String get featReportsDesc =>
      'Pick a data source, filter it, save it for reuse';

  @override
  String get reportTitle => 'Report builder';

  @override
  String get reportSource => 'Data source';

  @override
  String get reportSourceStockMovements => 'Stock ledger';

  @override
  String get reportSourceInspections => 'Inspections';

  @override
  String get reportSourceTransfers => 'Transfers';

  @override
  String get reportSourceShipments => 'Shipments';

  @override
  String get reportSourcePurchaseOrders => 'Purchase orders';

  @override
  String get reportSourceSalesOrders => 'Sales orders';

  @override
  String get reportSourceWorkOrders => 'Work orders';

  @override
  String get reportSourceAuditLog => 'Audit log';

  @override
  String get reportSourceProducts => 'Product master';

  @override
  String get reportWarehouse => 'Warehouse';

  @override
  String get reportAllWarehouses => 'All warehouses';

  @override
  String get reportCountry => 'Country';

  @override
  String get reportAllCountries => 'All countries (each row shows its country)';

  @override
  String get reportFilterStatus => 'Status (optional)';

  @override
  String get reportFilterJan => 'JAN code (optional)';

  @override
  String get reportFilterCategory => 'Category (optional)';

  @override
  String get reportDateFrom => 'From';

  @override
  String get reportDateTo => 'To';

  @override
  String get reportRun => 'Run';

  @override
  String get reportSave => 'Save';

  @override
  String get reportSaveTitle => 'Save report';

  @override
  String get reportName => 'Report name';

  @override
  String get reportSaved => 'Report saved';

  @override
  String get reportEmpty => 'No matching data';

  @override
  String reportRowCount(int count) {
    return '$count rows';
  }

  @override
  String get reportSavedTitle => 'Saved reports';

  @override
  String get reportSavedEmpty => 'No saved reports yet';

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
  String get poCreateDeliveryPlan => 'Create delivery plan';

  @override
  String get poCreateDeliveryPlanQ =>
      'Create a delivery plan from this purchase order?';

  @override
  String poDeliveryPlanCreated(int lines) {
    return 'Delivery plan created ($lines lines)';
  }

  @override
  String get poOpenDeliveryPlan => 'Open delivery plan';

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
  String get productsShowInactive => 'Show dormant and discontinued too';

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
  String get productDeactivateQ => 'Make this product dormant?';

  @override
  String get productDeactivateBody =>
      'A dormant product cannot be chosen for receiving, shipping and the like. It can be made active again at any time.';

  @override
  String get productDeactivateAction => 'Make dormant';

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
  String aiReviewConfidence(String percent) {
    return 'Confidence $percent%';
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

  @override
  String get featPutaway => 'Put-away';

  @override
  String get featPutawayDesc => 'Assign received stock to shelf locations';

  @override
  String get nextStepPutaway => 'Put-away';

  @override
  String get nextStepPacking => 'Packing';

  @override
  String get nextStepInspection => 'Inspection';

  @override
  String get putawayTitle => 'Put-away';

  @override
  String get putawayNeedsWarehouse => 'Pick a warehouse first';

  @override
  String get putawayNeedsWarehouseBody =>
      'Put-away happens inside a single warehouse. Choose one with the warehouse switcher above.';

  @override
  String get putawayLocationsOff => 'This warehouse does not use locations';

  @override
  String get putawayLocationsOffBody =>
      'There is no put-away step without shelves. Enable location management in the warehouse settings and work will show up here.';

  @override
  String get putawayEmpty => 'Nothing awaits put-away';

  @override
  String get putawayEmptyBody =>
      'Every received item is already assigned to a location.';

  @override
  String putawayPendingCount(int count) {
    return '$count items';
  }

  @override
  String get putawayQueueHint =>
      'Received stock with no location yet. Tap an item and scan the shelf.';

  @override
  String get putawayPendingLabel => 'to put away';

  @override
  String get putawayNoSuggestion => 'No suggested location';

  @override
  String putawaySuggested(String code) {
    return 'Suggested: $code';
  }

  @override
  String get putawayScanLocation => 'Scan the location';

  @override
  String get putawayScanLocationHint => 'Scan the shelf barcode';

  @override
  String putawayBinNotFound(String code) {
    return 'No location \"$code\" in this warehouse';
  }

  @override
  String putawayBinInactive(String code) {
    return '$code is an inactive location';
  }

  @override
  String get putawayBinCurrent => 'Currently on this shelf';

  @override
  String get putawayBinEmpty => 'Empty';

  @override
  String get putawayThisTime => 'Quantity going in';

  @override
  String putawayOfPending(int pending) {
    return '/ $pending left';
  }

  @override
  String get putawayQuantityRequired => 'Enter a quantity of 1 or more';

  @override
  String putawayQuantityTooLarge(int max) {
    return 'Only $max awaits put-away';
  }

  @override
  String get putawayConfirm => 'Confirm put-away';

  @override
  String putawayConfirmed(int quantity, String bin, int pendingAfter) {
    return 'Put $quantity into $bin ($pendingAfter left)';
  }

  @override
  String get actionOk => 'OK';

  @override
  String scanWrongItem(String expected) {
    return 'Different item (expected $expected)';
  }

  @override
  String scanExpecting(String expected) {
    return 'Expecting $expected — line it up in the frame';
  }

  @override
  String get scanNothingYet => 'Nothing scanned yet';

  @override
  String scanAcceptedCount(int count) {
    return '$count scanned';
  }

  @override
  String get scanResultOk => 'OK';

  @override
  String get scanResultDuplicate => 'Duplicate (ignored)';

  @override
  String get scanResultNg => 'NG';

  @override
  String get scanManualEntry => 'Type it in';

  @override
  String get scanManualEntryHint => 'JAN / barcode';

  @override
  String get scanDone => 'Done';

  @override
  String get pickScanToConfirm => 'Scan this item\'s JAN to confirm a quantity';

  @override
  String get pickScanned => 'Scan confirmed';

  @override
  String get pickScanAction => 'Scan';

  @override
  String get taskInboundPlanned => 'Inbound due';

  @override
  String get actionEdit => 'Edit';

  @override
  String get autopackAction => 'Calculate cartons';

  @override
  String autopackTotal(int total) {
    return '$total units in total';
  }

  @override
  String get autopackPerCarton => 'Units per carton';

  @override
  String get autopackHint =>
      'Enter how many fit in one carton and the box count is worked out for you.';

  @override
  String autopackBoxes(int boxes) {
    return '$boxes cartons';
  }

  @override
  String autopackEven(int per) {
    return '$per per carton';
  }

  @override
  String autopackSplit(int full, int per, int last) {
    return '$full × $per plus $last in the last carton';
  }

  @override
  String get autopackConfirm => 'Create these cartons';

  @override
  String autopackDone(int boxes, int per) {
    return 'Created $boxes cartons ($per each)';
  }

  @override
  String get printCartonLabels => 'Print every carton label';

  @override
  String get printThisLabel => 'Label';

  @override
  String get shipmentParcelsAction => 'Lot history';

  @override
  String get shipmentParcelsTitle => 'Lot history';

  @override
  String get shipmentParcelsEmpty => 'Not shipped yet';

  @override
  String get shipmentParcelsEmptyBody =>
      'Once shipping is confirmed, the lots and serials that actually left will show up here.';

  @override
  String get shipmentParcelReversalTag => 'Reversed';

  @override
  String get shipLogisticsSection => 'Shipping details';

  @override
  String get shipLogisticsUnset => 'Not set';

  @override
  String get shipWeight => 'Weight';

  @override
  String shipWeightKg(double kg) {
    final intl.NumberFormat kgNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String kgString = kgNumberFormat.format(kg);

    return '$kgString kg';
  }

  @override
  String get shipWeightInvalid => 'Enter a weight of 0 or more';

  @override
  String get shipCarrier => 'Carrier';

  @override
  String get shipTracking => 'Tracking number';

  @override
  String get auditEventAiAnalysisCompleted => 'AI analysis completed';

  @override
  String get auditEventAiConfirmed => 'AI result confirmed';

  @override
  String get auditEventAiRejected => 'AI result rejected';

  @override
  String get auditEventAttachmentUploaded => 'Photo attached';

  @override
  String get auditEventCountCancelled => 'Cycle count cancelled';

  @override
  String get auditEventCountCompleted => 'Cycle count completed';

  @override
  String get auditEventCountStarted => 'Cycle count started';

  @override
  String get auditEventInspectionConfirmed => 'Inspection confirmed';

  @override
  String get auditEventInspectionStarted => 'Inspection started';

  @override
  String get auditEventInventoryAdjusted => 'Stock adjusted';

  @override
  String get auditEventPartnerCreated => 'Partner created';

  @override
  String get auditEventPartnerUpdated => 'Partner updated';

  @override
  String get auditEventPickListCancelled => 'Picking cancelled';

  @override
  String get auditEventPickListCompleted => 'Picking completed';

  @override
  String get auditEventPickListStarted => 'Picking started';

  @override
  String get auditEventProductCreated => 'Product created';

  @override
  String get auditEventProductUpdated => 'Product updated';

  @override
  String get auditEventPurchaseOrderApproved => 'Purchase order approved';

  @override
  String get auditEventPurchaseOrderCancelled => 'Purchase order cancelled';

  @override
  String get auditEventPurchaseOrderCompleted => 'Purchase order completed';

  @override
  String get auditEventPurchaseOrderCreated => 'Purchase order created';

  @override
  String get auditEventPurchaseOrderRejected => 'Purchase order rejected';

  @override
  String get auditEventPurchaseOrderSubmitted => 'Purchase order submitted';

  @override
  String get auditEventPutawayConfirmed => 'Put-away confirmed';

  @override
  String get auditEventReceivingCancelled => 'Receipt cancelled';

  @override
  String get auditEventReceivingConfirmed => 'Receipt confirmed';

  @override
  String get auditEventReportDeleted => 'Report deleted';

  @override
  String get auditEventReportSaved => 'Report saved';

  @override
  String get auditEventSalesOrderApproved => 'Sales order approved';

  @override
  String get auditEventSalesOrderCancelled => 'Sales order cancelled';

  @override
  String get auditEventSalesOrderCompleted => 'Sales order completed';

  @override
  String get auditEventSalesOrderCreated => 'Sales order created';

  @override
  String get auditEventSalesOrderRejected => 'Sales order rejected';

  @override
  String get auditEventSalesOrderSubmitted => 'Sales order submitted';

  @override
  String get auditEventShipmentAutopacked => 'Cartons auto-packed';

  @override
  String get auditEventShipmentCancelled => 'Shipment cancelled';

  @override
  String get auditEventShipmentCompleted => 'Shipment completed';

  @override
  String get auditEventShipmentLogisticsSet => 'Shipping details set';

  @override
  String get auditEventTransferApproved => 'Transfer approved';

  @override
  String get auditEventTransferCancelled => 'Transfer cancelled';

  @override
  String get auditEventTransferCreated => 'Transfer created';

  @override
  String get auditEventTransferPickingStarted => 'Transfer picking started';

  @override
  String get auditEventTransferReceived => 'Transfer received';

  @override
  String get auditEventTransferReceivingStarted => 'Transfer receiving started';

  @override
  String get auditEventTransferRejected => 'Transfer rejected';

  @override
  String get auditEventTransferShipped => 'Transfer shipped';

  @override
  String get auditEventTransferSubmitted => 'Transfer submitted';

  @override
  String get auditEventUserRoleAssigned => 'Role assigned';

  @override
  String get auditEventUserRoleRevoked => 'Role revoked';

  @override
  String get auditEventUserWarehouseAssigned => 'Warehouse access granted';

  @override
  String get auditEventUserWarehouseRevoked => 'Warehouse access revoked';

  @override
  String get auditEventWorkOrderCancelled => 'Work order cancelled';

  @override
  String get auditEventWorkOrderCompleted => 'Work order completed';

  @override
  String get auditEventWorkOrderCreated => 'Work order created';

  @override
  String get auditEventWorkOrderStarted => 'Work order started';

  @override
  String get dashNotificationsTitle => 'Notifications';

  @override
  String get dashNotificationsEmpty => 'Nothing needs attention right now';

  @override
  String notifCount(int count) {
    return '$count';
  }

  @override
  String get notifFailedInspection => 'Failed inspections';

  @override
  String get notifOutstandingPlans => 'Inbound outstanding';

  @override
  String get notifPutawayPending => 'Awaiting put-away';

  @override
  String get notifOpenPicking => 'Open picking';

  @override
  String get sidebarCollapse => 'Collapse menu';

  @override
  String get sidebarExpand => 'Expand menu';

  @override
  String get menuFilter => 'Filter menu';

  @override
  String get menuFilterNoMatch => 'No matching menu item';

  @override
  String get unknownLocation =>
      'That screen could not be found. Pick one from the menu instead.';

  @override
  String get close => 'Close';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutsHelp => 'Show keyboard shortcuts';

  @override
  String get shortcutFocusScan => 'Focus the scan box';

  @override
  String get shortcutToggleSidebar => 'Collapse or expand the menu';

  @override
  String get shortcutGlobalSearch => 'Open cross-entity search';

  @override
  String get shortcutSwitchTab => 'Switch to the Nth tab';

  @override
  String get shortcutShowHelp => 'Show this list';

  @override
  String get productSku => 'SKU';

  @override
  String get productSkuHint => 'Internal code (optional)';

  @override
  String get productTracking => 'Tracking';

  @override
  String get trackUntracked => 'Untracked';

  @override
  String get trackLot => 'Lot';

  @override
  String get trackSerial => 'Serial';

  @override
  String get trackLotAndSerial => 'Lot + serial';

  @override
  String get trackExpiry => 'Expiry';

  @override
  String get productBaseUnit => 'Base unit';

  @override
  String get productRequiresInspection => 'Require inspection on arrival';

  @override
  String get productRequiresInspectionHint =>
      'When on, goods of this product arrive held for QC (QC_PENDING) and cannot be picked or shipped until inspection is complete.';

  @override
  String get productPickingRule => 'Picking order';

  @override
  String get productPickingRuleHint =>
      'The default order stock is drawn from. A warehouse can override this separately.';

  @override
  String get pickRuleFifo => 'First in, first out (FIFO)';

  @override
  String get pickRuleFefo => 'Soonest expiry first (FEFO)';

  @override
  String get pickRuleLifo => 'Last in, first out (LIFO)';

  @override
  String get pickRuleManual => 'Chosen each time (MANUAL)';

  @override
  String productCodeCount(int count) {
    return '$count codes';
  }

  @override
  String productPackUnit(String code, String factor, String base) {
    return '$code = $factor $base';
  }

  @override
  String productScanAlreadyUsed(String name) {
    return 'This code already belongs to \"$name\"';
  }

  @override
  String get stockPositionTitle => 'Stock position';

  @override
  String get stockAvailable => 'Available';

  @override
  String get stockReserved => 'Reserved';

  @override
  String get stockAllocated => 'Allocated';

  @override
  String get stockUnavailable => 'Unavailable';

  @override
  String get stockOverPromised => 'More is promised than can ship';

  @override
  String get stockNotLinkedToProduct =>
      'This JAN is not in the product master yet';

  @override
  String stockPositionLot(String code) {
    return 'Lot $code';
  }

  @override
  String get stockPositionNoParcels => 'No parcels yet';

  @override
  String get productDetailTitle => 'Product';

  @override
  String get productEdit => 'Edit';

  @override
  String get productBarcodesSection => 'Barcodes';

  @override
  String get productBarcodeAdd => 'Add a code';

  @override
  String get productBarcodePrimary => 'Primary';

  @override
  String get productBarcodeType => 'Type';

  @override
  String get productBarcodeUnit => 'Unit (optional)';

  @override
  String productBarcodeQtyPerScan(String qty) {
    return '1 scan = $qty';
  }

  @override
  String get productBarcodeRemoveQ => 'Remove this code?';

  @override
  String get productBarcodeRemoveBody =>
      'Scanning this code will no longer find the product. The product itself stays.';

  @override
  String get productBarcodeEmpty => 'No codes yet';

  @override
  String get productUnitsSection => 'Units';

  @override
  String get productUnitAdd => 'Add a unit';

  @override
  String get productUnitFactor => 'Conversion';

  @override
  String get productUnitBase => 'Base';

  @override
  String get productUnitRemoveQ => 'Remove this unit?';

  @override
  String get productUnitRemoveBody =>
      'This pack size will no longer be selectable. The base unit, or a unit still named by a barcode, cannot be removed.';

  @override
  String get productLotsSection => 'Lots';

  @override
  String get productLotsEmpty => 'No lots recorded yet';

  @override
  String productLotExpiryOn(String date) {
    return 'Expires $date';
  }

  @override
  String productLotDaysLeft(int days) {
    return '$days days left';
  }

  @override
  String get productLotExpired => 'Expired';

  @override
  String productLotSerialCount(int count) {
    return '$count serials';
  }

  @override
  String get productSerialsSection => 'Serial numbers';

  @override
  String get productSerialsEmpty => 'No serial numbers recorded yet';

  @override
  String get productSerialFilterAll => 'All';

  @override
  String get serialInStock => 'In stock';

  @override
  String get serialShipped => 'Shipped';

  @override
  String get serialReturned => 'Returned';

  @override
  String get serialScrapped => 'Scrapped';

  @override
  String get serialHold => 'Hold';

  @override
  String get productSerialChangeStatus => 'Change status';

  @override
  String get productSerialStatus => 'Status';

  @override
  String get productSerialNote => 'Note (optional)';

  @override
  String get whpSection => 'In this warehouse';

  @override
  String get whpNone => 'No special handling in this warehouse';

  @override
  String get whpNoWarehouse => 'Pick a warehouse to set this';

  @override
  String get whpEdit => 'Set up';

  @override
  String get whpDefaultLocation => 'Default location';

  @override
  String get whpDefaultLocationHint => 'The code on the rack (empty to clear)';

  @override
  String get whpMinStock => 'Min stock';

  @override
  String get whpReorderPoint => 'Reorder point';

  @override
  String get whpMaxStock => 'Max stock';

  @override
  String get whpPickPriority => 'Pick priority';

  @override
  String get whpPutawayRule => 'Put-away rule';

  @override
  String get putawayManual => 'Manual';

  @override
  String get putawayFixed => 'Fixed location';

  @override
  String get putawayConsolidate => 'Consolidate';

  @override
  String get putawayNearestEmpty => 'Nearest empty';

  @override
  String get whpLeadTime => 'Lead time (days)';

  @override
  String get whpSupplier => 'Preferred supplier';

  @override
  String get whpClear => 'Remove these settings';

  @override
  String get whpClearQ => 'Remove this warehouse\'s settings?';

  @override
  String get whpClearBody =>
      'The default location and reorder point go, and it drops off the replenishment list.';

  @override
  String get whpNeedsReorder => 'Below the reorder point';

  @override
  String get featExpiringLots => 'Expiry watch';

  @override
  String get featExpiringLotsDesc =>
      'Lots that are expiring or already past their date';

  @override
  String get featReservations => 'Reservations';

  @override
  String get featReservationsDesc =>
      'Stock promised to orders, and which parcels will supply it';

  @override
  String get featLocations => 'Locations';

  @override
  String get featLocationsDesc =>
      'The zone / aisle / rack / shelf tree and what each is for';

  @override
  String get featReplenishment => 'Replenishment';

  @override
  String get featReplenishmentDesc =>
      'Products below their reorder point, and how much to order';

  @override
  String get featStockReconciliation => 'Stock reconciliation';

  @override
  String get featStockReconciliationDesc =>
      'Where stock levels and stock units disagree';

  @override
  String get expiryTitle => 'Expiry watch';

  @override
  String expiryHorizon(int days) {
    return 'Within $days days';
  }

  @override
  String get expiryEmpty => 'Nothing is expiring';

  @override
  String get expiryEmptyBody =>
      'No lot reaches its date in this window. Widen it to look further ahead.';

  @override
  String expiryExpiredCount(int count) {
    return '$count expired';
  }

  @override
  String expirySoonCount(int count) {
    return '$count expiring soon';
  }

  @override
  String get reservationsTitle => 'Reservations';

  @override
  String get reservationsEmpty => 'No reservations';

  @override
  String get reservationsEmptyBody =>
      'Stock promised to orders and shipments appears here.';

  @override
  String get reservationStatusActive => 'Active';

  @override
  String get reservationStatusFulfilled => 'Fulfilled';

  @override
  String get reservationStatusReleased => 'Released';

  @override
  String get reservationStatusAll => 'All';

  @override
  String get reservationLapsed => 'Lapsed';

  @override
  String reservationFor(String type, String id) {
    return '$type $id';
  }

  @override
  String get refSalesOrder => 'Sales order';

  @override
  String get refShipment => 'Shipment';

  @override
  String get refTransfer => 'Transfer';

  @override
  String get refWorkOrder => 'Work order';

  @override
  String get refManual => 'Manual';

  @override
  String reservationQuantity(String qty) {
    return 'Reserved $qty';
  }

  @override
  String reservationAllocated(String qty) {
    return 'Allocated $qty';
  }

  @override
  String reservationUnallocated(String qty) {
    return '$qty unallocated';
  }

  @override
  String reservationFulfilled(String qty) {
    return 'Shipped $qty';
  }

  @override
  String get reservationRelease => 'Release';

  @override
  String get reservationReleaseQ => 'Release this reservation?';

  @override
  String get reservationReleaseBody =>
      'The held stock becomes available again and its allocations are dropped. The record stays.';

  @override
  String get reservationFulfil => 'Mark as fulfilled';

  @override
  String get reservationFulfilTitle => 'Record it as fulfilled';

  @override
  String get reservationFulfilBody =>
      'This moves no stock. The shipment recorded that separately — this only records that the promise was kept.';

  @override
  String get reservationFulfilQuantity => 'Quantity';

  @override
  String get reservationAllocationsTitle => 'Allocated from';

  @override
  String get reservationNoAllocations => 'No parcels chosen yet';

  @override
  String get overAllocatedTitle => 'Over-allocated';

  @override
  String get overAllocatedBody =>
      'Stock fell below what was allocated — a shipment took it first. Release an allocation or replace the stock.';

  @override
  String overAllocatedRow(String quantity, String allocated, String over) {
    return '$quantity on hand / $allocated allocated ($over over)';
  }

  @override
  String get stockReconciliationTitle => 'Stock reconciliation';

  @override
  String get stockReconciliationEmpty => 'No discrepancies';

  @override
  String get stockReconciliationEmptyBody =>
      'Stock levels and stock units agree.';

  @override
  String get stockReconciliationReasonUnlinked => 'JAN not linked to a product';

  @override
  String get stockReconciliationReasonDrift => 'Quantity drift';

  @override
  String stockReconciliationLevels(int qty) {
    return 'Stock level $qty';
  }

  @override
  String stockReconciliationUnits(int qty) {
    return 'Stock units $qty';
  }

  @override
  String stockReconciliationDrift(String diff) {
    return 'Diff $diff';
  }

  @override
  String get locationsTitle => 'Locations';

  @override
  String get locationsEmpty => 'No locations yet';

  @override
  String get locationsEmptyBody =>
      'Zones and shelves appear here as a tree once they exist.';

  @override
  String get locationsNoWarehouse => 'Pick a warehouse to see its locations';

  @override
  String get locationAdd => 'Add a location';

  @override
  String get locationCode => 'Code';

  @override
  String get locationName => 'Name (optional)';

  @override
  String get locationType => 'Type';

  @override
  String get locationParent => 'Parent (optional)';

  @override
  String get locationBarcode => 'Label barcode (optional)';

  @override
  String get locationShowInactive => 'Show inactive';

  @override
  String get binStockAction => 'Stock by bin';

  @override
  String get binStockTitle => 'Stock by bin';

  @override
  String get binStockEmpty => 'This warehouse has no locations';

  @override
  String get binStockBinEmpty => 'Empty';

  @override
  String binStockTotalUnits(int qty) {
    return '$qty total';
  }

  @override
  String get locationPickable => 'Pickable';

  @override
  String get locationReceivable => 'Receivable';

  @override
  String get locationShipping => 'Shipping';

  @override
  String get locationQuarantine => 'Quarantine';

  @override
  String get locationVirtual => 'Virtual';

  @override
  String get locationInactive => 'Inactive';

  @override
  String locationOnHand(String qty) {
    return '$qty on hand';
  }

  @override
  String get locTypeStorage => 'Storage';

  @override
  String get locTypePicking => 'Picking';

  @override
  String get locTypeReceiving => 'Receiving';

  @override
  String get locTypeQc => 'QC';

  @override
  String get locTypePacking => 'Packing';

  @override
  String get locTypeShipping => 'Shipping';

  @override
  String get locTypeQuarantine => 'Quarantine';

  @override
  String get locTypeDamaged => 'Damaged';

  @override
  String get locTypeReturn => 'Return';

  @override
  String get locTypeTransit => 'Transit';

  @override
  String get locTypeVirtual => 'Virtual';

  @override
  String get replenishmentTitle => 'Replenishment';

  @override
  String get replenishmentEmpty => 'Nothing needs reordering';

  @override
  String get replenishmentEmptyBody =>
      'Every product with a reorder point is above it.';

  @override
  String replenishmentSuggest(String qty) {
    return 'Order $qty';
  }

  @override
  String replenishmentShortfall(String qty) {
    return '$qty below the line';
  }

  @override
  String replenishmentBlocked(String qty) {
    return '$qty of it blocked';
  }

  @override
  String replenishmentLeadTime(int days) {
    return '$days days lead time';
  }

  @override
  String get replenishmentNoWarehouse =>
      'Pick a warehouse to see its suggestions';

  @override
  String get exceptionsTitle => 'Exceptions';

  @override
  String get exceptionsEmpty => 'No open exceptions';

  @override
  String get exceptionsEmptyBody =>
      'Discrepancies found during receiving, QC or put-away appear here.';

  @override
  String get exceptionsNoWarehouse => 'Choose a warehouse to see this';

  @override
  String get exceptionsAllCategories => 'All stages';

  @override
  String get exceptionCategoryReceiving => 'Receiving';

  @override
  String get exceptionCategoryQc => 'QC';

  @override
  String get exceptionCategoryPutaway => 'Put-away';

  @override
  String get exceptionShowClosed => 'Show closed as well';

  @override
  String get exceptionSeverityBlocker => 'Blocker';

  @override
  String get exceptionSeverityWarning => 'Warning';

  @override
  String get exceptionSeverityInfo => 'Info';

  @override
  String get exceptionAcknowledge => 'Acknowledge';

  @override
  String get exceptionAcknowledged => 'Acknowledged';

  @override
  String get exceptionResolve => 'Record decision';

  @override
  String get exceptionResolved => 'Resolved';

  @override
  String get exceptionCancelled => 'Cancelled';

  @override
  String get exceptionResolveTitle => 'Record what was decided';

  @override
  String get exceptionResolutionLabel => 'Decision';

  @override
  String get exceptionResolutionAccepted => 'Accept as received';

  @override
  String get exceptionResolutionSupplierClaim => 'Raise with the supplier';

  @override
  String get exceptionResolutionReturned => 'Returned to supplier';

  @override
  String get exceptionResolutionScrapped => 'Scrapped';

  @override
  String get exceptionResolutionCorrected => 'Corrected the entry';

  @override
  String get exceptionResolutionRecounted => 'Recounted';

  @override
  String get exceptionResolutionNoAction => 'No action needed';

  @override
  String get exceptionNoteLabel => 'Note (optional)';

  @override
  String get exceptionNoteRequiredLabel => 'Note (required)';

  @override
  String get exceptionNoteHint => 'Say what was done';

  @override
  String get exceptionNoteRequired => 'This decision needs a note';

  @override
  String get exceptionStockNotMovedHint =>
      'This records the decision only. Moving stock is a separate adjustment.';

  @override
  String exceptionQuantity(int qty) {
    return 'Qty $qty';
  }

  @override
  String exceptionLot(String lot, String expiry) {
    return 'Lot $lot / expires $expiry';
  }

  @override
  String exceptionRaisedAt(String date) {
    return 'Raised $date';
  }

  @override
  String exceptionOpenCount(int count) {
    return '$count open';
  }

  @override
  String exceptionBlockerCount(int blockers, int open) {
    return '$blockers blocking, $open open in total';
  }

  @override
  String get exceptionRaise => 'Raise exception';

  @override
  String get exceptionRaiseTitle => 'Raise an exception';

  @override
  String get exceptionRaiseType => 'Type';

  @override
  String get exceptionRaiseJanCode => 'JAN code (optional)';

  @override
  String get exceptionRaiseQuantity => 'Quantity (optional)';

  @override
  String get exceptionRaiseNoTypes => 'No exception types to raise';

  @override
  String get exceptionCancel => 'Cancel it';

  @override
  String get exceptionCancelTitle => 'Cancel this exception?';

  @override
  String get exceptionCancelBody =>
      'For one raised by mistake. No resolution is recorded.';

  @override
  String get exceptionCancelReasonLabel => 'Reason (optional)';

  @override
  String get featExceptions => 'Exceptions';

  @override
  String get featExceptionsDesc =>
      'Work through discrepancies from receiving, QC and put-away';

  @override
  String get heldStockTitle => 'Stock that cannot ship';

  @override
  String get heldStockEmpty => 'Nothing is held';

  @override
  String get heldStockEmptyBody =>
      'Stock awaiting inspection, on hold, quarantined or damaged is listed here. It cannot ship.';

  @override
  String get heldStockNoWarehouse => 'Choose a warehouse to see this';

  @override
  String get qcEffectTitle => 'What moved';

  @override
  String get qcEffectNothingMoved =>
      'Nothing moved: what was judged was not sitting in QC-pending stock.';

  @override
  String get featHeldStock => 'Held for QC';

  @override
  String get featHeldStockDesc =>
      'See the stock that cannot ship until QC releases it';

  @override
  String heldStockTotal(int units, int parcels) {
    return '$units units in $parcels parcels cannot ship';
  }

  @override
  String heldStockQuantity(int qty) {
    return '$qty';
  }

  @override
  String heldStockLot(String lot) {
    return 'Lot $lot';
  }

  @override
  String heldStockExpiry(String date) {
    return 'Expires $date';
  }

  @override
  String heldStockDays(int days) {
    return 'held ${days}d';
  }

  @override
  String qcWillHold(int qty) {
    return 'Completing this moves $qty failed units out of shippable stock';
  }

  @override
  String qcEffectReleased(int qty) {
    return '$qty units released and now shippable';
  }

  @override
  String qcEffectHeld(int qty, String status) {
    return '$qty units held as $status';
  }

  @override
  String qcEffectNotHeld(int qty) {
    return '$qty of those were not held, so nothing moved for them';
  }

  @override
  String get putawayNoSuggestionBody => 'No bin in this warehouse can take it';

  @override
  String get putawayNoHeldBin =>
      'No bin here can hold stock that cannot ship (QC hold, damaged, …)';

  @override
  String putawayLot(String lot) {
    return 'Lot $lot';
  }

  @override
  String get parcelAddTitle => 'Record a parcel';

  @override
  String get parcelAdd => 'Add parcel';

  @override
  String get parcelRemove => 'Remove this parcel';

  @override
  String get parcelQuantity => 'Quantity';

  @override
  String get parcelQuantityRequired => 'Enter a quantity';

  @override
  String get parcelLot => 'Lot (optional)';

  @override
  String get parcelLotHint => 'The lot printed on the carton';

  @override
  String get parcelExpiry => 'Expiry (optional)';

  @override
  String get parcelExpiryNone => 'Not entered';

  @override
  String get parcelSerial => 'Serial (optional)';

  @override
  String get parcelSerialHelp => 'A serial is one unit';

  @override
  String get parcelSerialIsOne => 'A serial is recorded one unit at a time';

  @override
  String get parcelLocation => 'Location (optional)';

  @override
  String get parcelLocationHint => 'The code on the rack or area';

  @override
  String get parcelDamaged => 'Arrived damaged';

  @override
  String get parcelDamagedHelp => 'Recorded as damaged, and cannot ship.';

  @override
  String get parcelNote => 'Note (optional)';

  @override
  String get parcelNoneYet => 'No lot or serial recorded';

  @override
  String get parcelAllAttributed => 'All attributed';

  @override
  String parcelUnattributed(int qty) {
    return '$qty unattributed';
  }

  @override
  String parcelOverLine(int parcelled, int counted) {
    return 'Parcels total $parcelled, more than the $counted counted';
  }

  @override
  String parcelLotShort(String lot) {
    return 'L:$lot';
  }

  @override
  String get receiptAddParcelTooltip => 'Add a parcel';

  @override
  String get receiptDetailTitle => 'Receipt';

  @override
  String get receiptLineNoParcels => 'No lot or serial recorded';

  @override
  String get receiptParcelUnattributed => 'Unattributed';

  @override
  String get receiptUnlinkedTitle => 'Not on the order';

  @override
  String get receiptUnlinkedBody => 'Parcels that belong to no ordered line.';

  @override
  String receiptTotalUnits(int units) {
    return '$units units';
  }

  @override
  String receiptHeldUnits(int units) {
    return '$units of them cannot ship';
  }

  @override
  String receiptLinePlannedActual(int planned, int actual) {
    return '$planned planned / $actual received';
  }

  @override
  String receiptParcelLot(String lot) {
    return 'Lot $lot';
  }

  @override
  String receiptParcelExpiry(String date) {
    return 'exp $date';
  }

  @override
  String receiptParcelMovement(int id) {
    return 'ledger #$id';
  }

  @override
  String get attachmentKindPhoto => 'Photo';

  @override
  String get attachmentKindDeliveryNote => 'Delivery note';

  @override
  String get attachmentKindQcImage => 'QC photo';

  @override
  String get attachmentKindDamage => 'Damage photo';

  @override
  String get attachmentKindDocument => 'Document';

  @override
  String get attachmentKindLabel => 'Label';

  @override
  String get attachmentKindOther => 'Other';

  @override
  String get attachmentWithdraw => 'Withdraw';

  @override
  String get attachmentWithdrawQ => 'Withdraw this attachment?';

  @override
  String get attachmentWithdrawBody =>
      'It leaves the list but stays on the record.';

  @override
  String get attachmentWithdrawn => 'Attachment withdrawn';

  @override
  String get attachmentWithdrawnBadge => 'Withdrawn';

  @override
  String attachmentSize(int kb) {
    return '$kb KB';
  }

  @override
  String get attachmentNoCaption => 'No caption';

  @override
  String soApprovedWithReservations(int reserved) {
    return 'Sales order approved ($reserved reserved)';
  }

  @override
  String soApprovedWithSkips(int reserved, int skipped) {
    return 'Sales order approved ($reserved reserved, $skipped not reserved)';
  }

  @override
  String get soApprovalSkipDetail => 'Details';

  @override
  String get soSkippedLinesTitle => 'Lines not reserved';

  @override
  String get soSkipUnlinkedJan => 'No product is registered for this JAN';

  @override
  String soSkipInsufficientAvailable(int available, int requested) {
    return 'Not enough available ($available of $requested)';
  }

  @override
  String get soReservationsTitle => 'Reservations';

  @override
  String get soReservationFulfilled => 'Shipped';

  @override
  String get soCreateShipment => 'Create shipment';

  @override
  String get soCreateShipmentQ => 'Create a shipment from this sales order?';

  @override
  String soShipmentCreated(int lines) {
    return 'Shipment created ($lines lines)';
  }

  @override
  String get soOpenShipment => 'Open shipment';

  @override
  String get featWave => 'Wave picking';

  @override
  String get featWaveDesc => 'Group several shipments into one walk';

  @override
  String get waveListTitle => 'Wave picking';

  @override
  String get waveEmpty => 'No waves yet';

  @override
  String get waveEmptyBody =>
      'Group several shipments so they can be picked in one walk.';

  @override
  String get waveCreate => 'Create wave';

  @override
  String get waveChooseShipments => 'Choose shipments (multiple)';

  @override
  String get waveNoShipments => 'No shipments available';

  @override
  String get waveSelectAtLeastOne => 'Select at least one shipment';

  @override
  String waveCreated(String code, int lists) {
    return 'Wave $code created ($lists shipments)';
  }

  @override
  String waveCreatedWithSkips(String code, int lists, int skipped) {
    return 'Wave $code created ($lists joined, $skipped skipped)';
  }

  @override
  String get waveStatusOpen => 'Open';

  @override
  String get waveStatusPicking => 'In progress';

  @override
  String get waveStatusDone => 'Done';

  @override
  String get waveStatusCancelled => 'Cancelled';

  @override
  String waveListsProgress(int picked, int total) {
    return '$picked / $total lines';
  }

  @override
  String get waveUnassigned => 'Unassigned';

  @override
  String get waveAssignToMe => 'Take this wave';

  @override
  String get waveUnassign => 'Hand back';

  @override
  String get waveViewSheet => 'View pick sheet';

  @override
  String get waveSheetTitle => 'Pick sheet';

  @override
  String get waveSheetEmpty => 'Nothing pickable';

  @override
  String waveSheetTotalUnits(int total) {
    return '$total units total';
  }

  @override
  String waveSheetForOrders(int count) {
    return 'for $count shipments';
  }

  @override
  String get waveShortfallTitle => 'Shortfall';

  @override
  String waveShortfallUnits(int short) {
    return '$short short';
  }

  @override
  String get waveLists => 'Shipments in this wave';

  @override
  String get waveComplete => 'Complete wave';

  @override
  String get waveCompleteQ =>
      'Complete this wave? Every shipment in it will be closed out.';

  @override
  String waveCompleted(int count) {
    return 'Wave completed ($count)';
  }

  @override
  String get waveIncomplete => 'Some lines are still unpicked';

  @override
  String get waveCancelAction => 'Cancel wave';

  @override
  String get waveCancelQ =>
      'Cancel this wave? Its shipments are released; any picking already recorded stays.';

  @override
  String get waveCancelled => 'Wave cancelled';

  @override
  String get featDemand => 'Backorders & purchasing';

  @override
  String get featDemandDesc =>
      'Fill waiting orders from stock and buy what is short';

  @override
  String get demandTitle => 'Backorders & purchasing';

  @override
  String get demandEmpty => 'No orders are waiting';

  @override
  String get demandEmptyBody =>
      'Approved sales orders that stock could not cover gather here.';

  @override
  String get demandFillAll => 'Fill all from stock';

  @override
  String get demandFillAllQ =>
      'Free stock will be reserved for waiting orders, oldest approval first. Continue?';

  @override
  String get demandNothingToFill => 'There is no free stock to reserve';

  @override
  String demandFilled(int units) {
    return 'Reserved $units units';
  }

  @override
  String demandPoCreated(int links) {
    return 'Purchase order created (linked to $links order lines)';
  }

  @override
  String demandCreatePo(int count) {
    return 'Create purchase order ($count items)';
  }

  @override
  String get demandBackordered => 'Backordered';

  @override
  String get demandCanFillNow => 'Can fill now';

  @override
  String get demandIncoming => 'Incoming';

  @override
  String get demandToPurchase => 'To buy';

  @override
  String get demandAvailable => 'Free stock';

  @override
  String demandNeedsPurchase(int count) {
    return 'Buy $count';
  }

  @override
  String demandFillable(int count) {
    return 'Can fill $count';
  }

  @override
  String get demandCovered => 'Covered';

  @override
  String demandFillNow(int count) {
    return 'Fill from stock ($count)';
  }

  @override
  String demandWaitingOrders(int count) {
    return '$count waiting orders';
  }

  @override
  String demandLineStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return 'Ordered $ordered · reserved $promised · waiting $backordered · on order $onOrder';
  }

  @override
  String get demandLineFill => 'Reserve for this order';

  @override
  String get demandLineFillQuantity => 'Quantity to reserve';

  @override
  String demandLineFillMax(int max) {
    return 'Up to $max';
  }

  @override
  String get demandPoTitle => 'Purchase for backorders';

  @override
  String get demandPoHint =>
      'Quantities start at what is still to buy. Ordering less is fine — the rest can be supplied from elsewhere.';

  @override
  String demandPoLineHint(int backordered, int toPurchase) {
    return 'Backordered $backordered · to buy $toPurchase';
  }

  @override
  String get demandQuantity => 'Quantity';

  @override
  String get demandOrdered => 'Ordered';

  @override
  String get demandPromised => 'Reserved';

  @override
  String get demandShipped => 'Shipped';

  @override
  String soSkipPartial(int reserved, int backordered) {
    return 'Reserved $reserved · backordered $backordered';
  }

  @override
  String soCreateShipmentReadyQ(int units) {
    return 'The $units reserved units not yet shipped will go on the shipment. Continue?';
  }

  @override
  String get soShipRemaining => 'Ship the rest';

  @override
  String get soFillFromStock => 'Fill from stock';

  @override
  String get soMoreActions => 'More actions';

  @override
  String get soReadyToShip => 'Ready to ship';

  @override
  String get soShipments => 'Shipments';

  @override
  String get soShipmentShipped => 'Shipped';

  @override
  String get soShipmentOpen => 'In progress';

  @override
  String get soLineUnlinked =>
      'No product record for this JAN, so nothing can be reserved';

  @override
  String soLineOnOrder(int count) {
    return 'On order $count';
  }

  @override
  String get soFillLine => 'Reserve for this line';

  @override
  String get poCreateRemainingDeliveryPlan => 'Plan the rest of the delivery';

  @override
  String get poDeliveryPlans => 'Delivery plans';

  @override
  String get poPlanReceived => 'Received';

  @override
  String get poPlanOpen => 'Awaiting';

  @override
  String get poLinePlanned => 'Planned';

  @override
  String get poLineReceived => 'Received';

  @override
  String get poLineOutstanding => 'Outstanding';

  @override
  String get poLineForOrders => 'Bought for these orders';

  @override
  String get reconOpenPurchaseOrder => 'Open purchase order';

  @override
  String get reconLinkPurchaseOrder => 'Link to purchase order';

  @override
  String get reconNoPurchaseOrderToLink => 'There is no purchase order to link';

  @override
  String reconLinkedPurchaseOrder(String number) {
    return 'Linked to $number';
  }

  @override
  String reservationAllocatedShort(int allocated, int short) {
    return 'Allocated $allocated ($short could not be found)';
  }

  @override
  String reservationAllocatedDone(int allocated) {
    return 'Allocated $allocated';
  }

  @override
  String reservationManualNoProduct(String jan) {
    return 'No product with JAN $jan';
  }

  @override
  String get reservationManualCreated => 'Reservation created';

  @override
  String get reservationManualAdd => 'Reserve manually';

  @override
  String get reservationReleaseAllocation => 'Remove allocation';

  @override
  String get reservationAllocate => 'Allocate parcels';

  @override
  String get reservationManualNote => 'Purpose / note';

  @override
  String get reservationManualSubmit => 'Reserve';

  @override
  String get demandPoNeedSupplier => 'Enter a supplier';

  @override
  String demandPoOverLinked(int linked, int quantity) {
    return 'Linked $linked is more than the $quantity ordered';
  }

  @override
  String demandPoLineOverLinked(int backordered) {
    return 'More than the $backordered this order is waiting for';
  }

  @override
  String demandPoCreateN(int count) {
    return 'Create purchase orders ($count suppliers)';
  }

  @override
  String demandPoProductHint(int backordered, int toPurchase, int incoming) {
    return 'Backordered $backordered · to buy $toPurchase · incoming $incoming';
  }

  @override
  String demandPoProductTotal(int total) {
    return 'Total for this product $total';
  }

  @override
  String get demandPoSplitSupplier => 'Split to another supplier';

  @override
  String get demandPoRemoveRow => 'Remove this supplier';

  @override
  String get demandPoLinksTitle => 'Which orders this purchase is for';

  @override
  String get demandPoAutoLink => 'Split oldest first';

  @override
  String get demandPoNoWaiting =>
      'No order is waiting — all of it is bought ahead';

  @override
  String demandPoLineWaiting(int backordered, int onOrder) {
    return 'Waiting $backordered · on order $onOrder';
  }

  @override
  String demandPoRowSummary(int linked, int ahead) {
    return 'Linked $linked · bought ahead $ahead';
  }

  @override
  String demandPosCreated(int count) {
    return 'Created $count purchase orders';
  }

  @override
  String get demandAheadOnly => 'Bought ahead only';

  @override
  String demandIncomingBreakdown(int incoming) {
    return 'Incoming $incoming (by supplier)';
  }

  @override
  String demandIncomingBreakdownAhead(int incoming, int ahead) {
    return 'Incoming $incoming ($ahead bought ahead)';
  }

  @override
  String demandIncomingPo(int outstanding) {
    return '$outstanding to come';
  }

  @override
  String demandIncomingPoAhead(int outstanding, int ahead) {
    return '$outstanding to come ($ahead ahead)';
  }

  @override
  String get demandIncomingAhead => 'Bought ahead';

  @override
  String get poLinkEditTitle => 'Link to sales orders';

  @override
  String poLinkOverOrdered(int ordered) {
    return 'More than the $ordered this order asked for';
  }

  @override
  String poLinkSaved(int linked, int reserved, int released) {
    return 'Links saved (linked $linked, reserved from arrivals $reserved, released $released)';
  }

  @override
  String poLinkLineSummary(int quantity, int received) {
    return 'Ordered $quantity · received $received';
  }

  @override
  String get poLinkHint =>
      'Arrived goods are reserved to the linked orders automatically. Changing a link moves what this purchase reserved. Unlinked quantity is bought-ahead stock for whichever order comes next.';

  @override
  String get poLinkNoCandidates =>
      'No approved order is waiting for this product';

  @override
  String poLinkCandidateStatus(
      int ordered, int promised, int backordered, int onOrder) {
    return 'Ordered $ordered · reserved $promised · waiting $backordered · on order $onOrder';
  }

  @override
  String poLinkFilled(int filled) {
    return '$filled reserved from this purchase\'s arrivals';
  }

  @override
  String get poLinkQuantity => 'Linked';

  @override
  String poLinkReleaseWarning(int count) {
    return 'Saving releases $count already reserved for this order';
  }

  @override
  String get poLinkReleaseTitle => 'Release reserved stock?';

  @override
  String get poLinkReleaseBody =>
      'Goods that already arrived and were reserved will be taken off these orders. They go to the other linked orders, or back to free stock if there are none.';

  @override
  String poLinkReleaseLine(String order, int count) {
    return '$order: release $count';
  }

  @override
  String get poLinkReleaseConfirm => 'Release and save';

  @override
  String poLineLinkedAhead(int linked, int ahead) {
    return 'Linked to orders $linked · bought ahead $ahead';
  }

  @override
  String get poLinkEdit => 'Edit links';

  @override
  String poDemandFilled(int filled) {
    return '($filled reserved on arrival)';
  }

  @override
  String get transferStatusExported => 'Exported';

  @override
  String get transferExportBadge => 'Export';

  @override
  String transferCrossBorderExport(String country) {
    return 'This crosses into $country. The goods leave stock when they ship and are not received anywhere.';
  }

  @override
  String transferCrossBorderReceived(String country) {
    return 'The warehouse in $country is set to receive cross-border goods, so this is received like any transfer.';
  }

  @override
  String get transferExportNotice =>
      'Cross-border: the goods leave real stock when they ship and are not received. What was sent is added to the warehouse\'s virtual figure.';

  @override
  String get transferCrossBorderReceivedNotice =>
      'Cross-border: the destination receives cross-border goods, so this is received.';

  @override
  String transferCompletePickingExportBody(String warehouse) {
    return 'The goods leave $warehouse and are removed from stock as exported. This transfer closes without receiving.';
  }

  @override
  String get whRoleEdit => 'Country and role';

  @override
  String get whRoleSaved => 'Warehouse role saved';

  @override
  String get whRoleCountry => 'Country';

  @override
  String get whRoleCountryCode => 'Country code (2 letters)';

  @override
  String get whRoleReceivesCrossBorder =>
      'Receive cross-border transfers and hold the stock';

  @override
  String get whRoleReceivesCrossBorderHint =>
      'When off, a transfer here from another country leaves stock at the source. Turn on to ship to customers from this warehouse.';

  @override
  String get countryJP => 'Japan';

  @override
  String get countryCN => 'China';

  @override
  String get countryOther => 'Other';

  @override
  String get supplierNamesSection => 'Supplier names';

  @override
  String get supplierNamesHint =>
      'Record each supplier\'s name and code for this product to search by them and match their delivery notes. Downstream slips print our own name.';

  @override
  String get supplierNamesEmpty => 'None recorded yet';

  @override
  String get supplierNameAdd => 'Add supplier name';

  @override
  String get supplierNameEdit => 'Edit supplier name';

  @override
  String get supplierNameSaved => 'Supplier name saved';

  @override
  String get supplierNameNoSuppliers => 'Register a supplier first';

  @override
  String get supplierNameSupplier => 'Supplier';

  @override
  String get supplierNameName => 'Supplier\'s product name';

  @override
  String get supplierNameCode => 'Supplier\'s code (optional)';

  @override
  String get supplierNameNote => 'Note (optional)';

  @override
  String supplierNameCodeLabel(String code) {
    return 'Code $code';
  }

  @override
  String poLineSupplierName(String name) {
    return 'Supplier calls it: $name';
  }

  @override
  String get featVirtualStock => 'Stock abroad (virtual)';

  @override
  String get featVirtualStockDesc =>
      'A rough monthly figure for warehouses abroad, from what was sent and counts typed in';

  @override
  String get virtualTitle => 'Stock abroad (virtual)';

  @override
  String get virtualExplain =>
      'Goods sent abroad have left real stock. This is a virtual figure from what Japan sent and counts typed in; it is never reserved or shipped.';

  @override
  String get virtualNoWarehouse => 'No warehouse abroad';

  @override
  String get virtualNoWarehouseBody =>
      'Set a warehouse\'s country under 国・役割 and it appears here.';

  @override
  String get virtualWarehouse => 'Warehouse';

  @override
  String get virtualFromMonth => 'From month';

  @override
  String get virtualToMonth => 'To month';

  @override
  String virtualRangeTotal(String from, String to) {
    return 'Total $from – $to';
  }

  @override
  String get virtualByMonth => 'By month';

  @override
  String get virtualByProduct => 'By product';

  @override
  String get virtualEmpty => 'Nothing recorded in this range';

  @override
  String get virtualOpening => 'Opening';

  @override
  String get virtualArrived => 'From Japan';

  @override
  String get virtualAdjusted => 'Typed in';

  @override
  String get virtualCountDiff => 'Count gap';

  @override
  String get virtualClosing => 'Closing';

  @override
  String get virtualMonth => 'Month';

  @override
  String virtualProductLine(int opening, int arrived, int change) {
    return 'Opening $opening · from Japan +$arrived · change $change';
  }

  @override
  String virtualLastCount(String date, int counted) {
    return 'Last count $date: $counted';
  }

  @override
  String get virtualRecord => 'Enter count or change';

  @override
  String get virtualRecorded => 'Recorded';

  @override
  String get virtualHistory => 'History';

  @override
  String virtualBalanceThatDay(int balance) {
    return 'That day $balance';
  }

  @override
  String virtualEntryExport(int quantity, String number) {
    return 'From Japan +$quantity ($number)';
  }

  @override
  String virtualEntryCount(int counted) {
    return 'Counted $counted';
  }

  @override
  String virtualEntryAdjust(String change) {
    return 'Change $change';
  }

  @override
  String get virtualTypeCount => 'Count';

  @override
  String get virtualTypeAdjust => 'Change';

  @override
  String get virtualTypeCountHint =>
      'The number actually there on that day. The figure is counted on from it.';

  @override
  String get virtualTypeAdjustHint =>
      'A shipment out or in that you know about.';

  @override
  String get virtualAdjustOut => 'Out (−)';

  @override
  String get virtualAdjustIn => 'In (+)';

  @override
  String get virtualCountedQuantity => 'Counted';

  @override
  String get virtualAdjustQuantity => 'Quantity';

  @override
  String get virtualDate => 'Date';

  @override
  String get virtualNote => 'Note (optional)';

  @override
  String get chartStockTitle => 'Stock by product';

  @override
  String get chartByWarehouse => 'By warehouse';

  @override
  String get chartByState => 'By state';

  @override
  String get chartShowTable => 'Show as table';

  @override
  String get chartShowChart => 'Show as chart';

  @override
  String get chartEmpty => 'No product holds stock yet';

  @override
  String chartUnregisteredNote(int jans, String units) {
    return '$jans JANs with no product record ($units units) are not in the chart';
  }

  @override
  String get chartUnregisteredAction => 'Register';

  @override
  String chartTopOf(int shown, int total) {
    return 'Top $shown of $total products by stock';
  }

  @override
  String get chartFree => 'Free';

  @override
  String get chartReserved => 'Reserved';

  @override
  String get chartUnusable => 'Not usable (held / QC)';

  @override
  String get chartVirtualAbroad => 'Abroad (virtual)';

  @override
  String chartWarehouseVirtual(String name) {
    return '$name (virtual)';
  }

  @override
  String get chartOther => 'Other';

  @override
  String get chartProduct => 'Product';

  @override
  String get chartTotal => 'Total';

  @override
  String get recentPoTitle => 'Recent purchase orders';

  @override
  String get recentPoEmpty => 'No purchase orders yet';

  @override
  String recentPoDestination(String warehouse, String country) {
    return 'To $warehouse$country';
  }

  @override
  String recentPoExpected(String date) {
    return 'Due $date';
  }

  @override
  String recentPoReceived(String received, String ordered) {
    return 'Received $received / $ordered';
  }

  @override
  String get recentPoOpenAll => 'All purchase orders';

  @override
  String whTotalsCountry(String country) {
    return 'Total ($country)';
  }

  @override
  String chartTopOfCountry(String country, int shown, int total) {
    return '$country: top $shown of $total products by stock';
  }

  @override
  String dashOverviewCountry(String country) {
    return 'Overview ($country)';
  }

  @override
  String get heldStatusQcPending => 'Awaiting inspection';

  @override
  String get heldStatusHold => 'On hold';

  @override
  String get heldStatusQuarantine => 'Quarantined';

  @override
  String get heldStatusDamaged => 'Damaged';

  @override
  String get heldStatusExpired => 'Expired';

  @override
  String get heldStatusBlocked => 'Blocked';

  @override
  String get heldAwaitsInspection => 'Decided by its inspection';

  @override
  String get heldDispose => 'Resolve';

  @override
  String dispTitle(String name) {
    return 'Resolve $name';
  }

  @override
  String get dispQuantity => 'Quantity';

  @override
  String dispMax(int qty) {
    return 'Up to $qty';
  }

  @override
  String get dispRelease => 'Release as good';

  @override
  String get dispHold => 'Put on hold';

  @override
  String get dispQuarantine => 'Quarantine';

  @override
  String get dispDamaged => 'Mark damaged';

  @override
  String get dispScrap => 'Write off';

  @override
  String get dispReturn => 'Return to supplier';

  @override
  String get dispReason => 'Reason, return number…';

  @override
  String get dispReasonRequired =>
      'A reason is required to write off or return';

  @override
  String dispOverMax(int qty) {
    return 'No more than $qty';
  }

  @override
  String get dispConfirm => 'Apply';

  @override
  String dispDone(int qty) {
    return '$qty resolved';
  }

  @override
  String get mvScrap => 'Write-off';

  @override
  String get mvReturnToSupplier => 'Return to supplier';

  @override
  String get bulkQcTitle => 'Bulk inspection';

  @override
  String get bulkQcGroupDate => 'Arrival date';

  @override
  String get bulkQcGroupPo => 'Purchase order';

  @override
  String get bulkQcAllDates => 'All arrival dates';

  @override
  String get bulkQcAllPos => 'All purchase orders';

  @override
  String get bulkQcNoPo => 'No purchase order';

  @override
  String bulkQcProductFilter(String name) {
    return 'Product: $name';
  }

  @override
  String get bulkQcScanHint => 'Scan a JAN to narrow to one product';

  @override
  String get bulkQcNoMatch => 'Nothing awaits inspection for this JAN';

  @override
  String get bulkQcSelectAll => 'Select all';

  @override
  String get bulkQcSelectNone => 'Clear selection';

  @override
  String bulkQcSummary(int lines, int units) {
    return '$lines lines selected · $units units';
  }

  @override
  String get bulkQcPass => 'Pass the selection as good';

  @override
  String get bulkQcConfirmTitle => 'Pass these as good?';

  @override
  String bulkQcConfirmBody(int lines, int units) {
    return '$lines lines ($units units) will be settled as good and become shippable at once. Lines you did not select stay waiting for inspection.';
  }

  @override
  String bulkQcDone(int lines, int units) {
    return '$lines lines ($units units) passed as good';
  }

  @override
  String get bulkQcEmpty => 'Nothing is waiting for inspection';

  @override
  String get bulkQcEmptyBody =>
      'Goods that need inspection are listed here once received.';

  @override
  String bulkQcArrived(String date) {
    return 'Arrived $date';
  }

  @override
  String get bulkQcRecordedBadge => 'Finding recorded';

  @override
  String get qcPassAll => 'All good';

  @override
  String qcPassAllDone(int units) {
    return '$units passed as good';
  }

  @override
  String get qcFinalBadge => 'Settled';

  @override
  String get qcScanHint => 'Scan a JAN to inspect its line';

  @override
  String get qcScanNotInInspection => 'This JAN is not in this inspection';

  @override
  String qcScanPrompt(String name, int units) {
    return '$name: $units';
  }

  @override
  String get qcScanRecordEach => 'Record findings';

  @override
  String receiptArrivedOn(String date) {
    return 'Arrived $date';
  }

  @override
  String get receiptArrivedOnEdit => 'Change arrival date';

  @override
  String receiptArrivedOnSaved(String date) {
    return 'Arrival date set to $date';
  }

  @override
  String get featBulkInspection => 'Bulk inspection';

  @override
  String get featBulkInspectionDesc =>
      'Narrow by arrival date, PO or product and pass them as good in one go';

  @override
  String get qcCountMatch => 'Count matches';

  @override
  String qcCountShort(int n) {
    return 'Short $n';
  }

  @override
  String qcCountOver(int n) {
    return 'Over $n';
  }

  @override
  String get qcCountNone => 'Not counted';

  @override
  String qcCountLine(int counted, int received) {
    return 'Counted $counted / received $received';
  }

  @override
  String get qcEnterCount => 'Enter count';

  @override
  String qcEnterCountTitle(String name) {
    return 'Count for $name';
  }

  @override
  String qcScanCounted(String name, int counted, int received) {
    return '$name: $counted / $received';
  }

  @override
  String qcScanCountMatched(String name, int n) {
    return '$name matches ($n)';
  }

  @override
  String get qcWrongItemTitle => 'Not on this delivery';

  @override
  String qcWrongItemBody(String jan) {
    return 'JAN $jan is not on this delivery. Record it as a wrong item?';
  }

  @override
  String get qcWrongItemRecord => 'Record as wrong item';

  @override
  String get qcWrongItemDone => 'Recorded as a wrong item';

  @override
  String qcMatchedSummary(int matched, int total) {
    return '$matched of $total lines match';
  }

  @override
  String get qcCompleteDefaultTitle => 'Some lines are unchecked';

  @override
  String qcCompleteDefaultBody(int n) {
    return '$n unchecked lines will be completed as good. Counted lines settle at their count.';
  }

  @override
  String get qcCompleteConfirm => 'Complete';

  @override
  String qcEffectCountShort(int n) {
    return '$n that could not be counted went on hold';
  }

  @override
  String get qcScanPieceMode => 'Each scan counts one piece';

  @override
  String get qcScanPieceOn => 'Each scan now counts one piece';

  @override
  String get qcScanPieceOff =>
      'A scan now picks the line to enter its quantity';

  @override
  String get qcReadNote => 'Read delivery note';

  @override
  String qcNoteApplied(int matched) {
    return '$matched delivery-note lines applied';
  }

  @override
  String get qcNoteNone => 'No lines could be read from the delivery note';

  @override
  String get qcNoteUnmatchedTitle => 'Delivery-note lines with no match';

  @override
  String get qcNoteUnmatchedBody =>
      'These lines match nothing on this delivery. Record any wrong goods as a wrong item.';

  @override
  String qcNoteQuantity(int n) {
    return 'Note $n';
  }

  @override
  String qcCountRemaining(int n) {
    return '$n to go';
  }

  @override
  String get qcCountModeAdd => 'Add';

  @override
  String get qcCountModeSet => 'Set total';

  @override
  String qcCountSoFar(int counted, int received) {
    return 'So far $counted / received $received';
  }

  @override
  String get qcCountAddHint => 'Counted this time (e.g. one carton)';

  @override
  String get qcCountSetHint => 'Total counted';

  @override
  String get qcTick => 'Goods and count checked';

  @override
  String get partnerCountry => 'Country';

  @override
  String get dashViewOverview => 'Overview';

  @override
  String get dashViewInspection => 'Inspection';

  @override
  String get dashViewPurchasing => 'Purchasing';

  @override
  String get dashViewSales => 'Sales orders';

  @override
  String get dashAwaitingInspection => 'Awaiting inspection';

  @override
  String dashAwaitingBody(int inspections, int lines, int units) {
    return '$inspections inspections · $lines lines · $units units';
  }

  @override
  String get dashAwaitingNone => 'Nothing awaiting inspection';

  @override
  String get dashOpenInspections => 'Inspections';

  @override
  String get dashBulkInspection => 'Bulk inspection';

  @override
  String get dashIncomingTitle => 'Incoming';

  @override
  String get dashIncomingEmpty => 'Nothing is due in';

  @override
  String get dashDayToday => 'Today';

  @override
  String get dashDayTomorrow => 'Tomorrow';

  @override
  String get dashDayOverdue => 'Overdue';

  @override
  String get dashDayNone => 'No date yet';

  @override
  String get dashManualBadge => 'Manual';

  @override
  String dashPlanSummary(int lines, int units) {
    return '$lines items · $units units';
  }

  @override
  String dashMoreLines(int count) {
    return '$count more';
  }

  @override
  String get dashUnplannedTitle => 'Orders with no delivery list';

  @override
  String get dashUnplannedBody =>
      'Approved orders the supplier sent no delivery list for. You can write one by hand.';

  @override
  String get dashCreateManualList => 'Create an inbound list by hand';

  @override
  String get manualListTitle => 'New inbound list';

  @override
  String get manualListSupplier => 'Supplier (optional)';

  @override
  String get manualListExpected => 'Expected on';

  @override
  String get manualListNoDate => 'Not set';

  @override
  String get manualListScanHint => 'Scan or type a JAN';

  @override
  String get manualListQuantity => 'Quantity';

  @override
  String get manualListEmpty => 'Scan the JAN of each product that is coming';

  @override
  String get manualListSave => 'Create list';

  @override
  String manualListCreated(String number) {
    return 'Inbound list $number created';
  }

  @override
  String get manualListNoWarehouse => 'Pick a warehouse first';

  @override
  String get manualListBadJan => 'A JAN is 8 or 13 digits';

  @override
  String get dashStockUsable => 'Usable';

  @override
  String get dashStockQcPending => 'Awaiting QC';

  @override
  String get dashStockHeld => 'Held';

  @override
  String get dashStockReserved => 'Reserved';

  @override
  String get dashStockIncoming => 'Incoming';

  @override
  String get dashStockShortfall => 'Short';

  @override
  String dashStockNext(String date) {
    return 'Next $date';
  }

  @override
  String get dashStockSearch => 'Search by name or JAN';

  @override
  String get dashStockEmpty => 'No products match';

  @override
  String dashStockProducts(int count) {
    return '$count products';
  }

  @override
  String get dashOpenDemand => 'Open orders to purchase';

  @override
  String dashSalesUnits(int months) {
    return 'Units ordered, last $months months';
  }

  @override
  String dashSalesVsLastYear(String pct) {
    return '$pct vs last year';
  }

  @override
  String get dashSalesNoCompare => 'Nothing to compare with last year';

  @override
  String get dashSalesOrders => 'Orders';

  @override
  String get dashSalesMonthly => 'Units ordered by month';

  @override
  String get dashSalesThisYear => 'This year';

  @override
  String get dashSalesLastYear => 'Last year';

  @override
  String get dashSalesTop => 'Most ordered';

  @override
  String get dashSalesToPurchase => 'Still to purchase';

  @override
  String get dashSalesToPurchaseEmpty => 'Nothing left to purchase';

  @override
  String get dashSalesAllCountries => 'All countries';

  @override
  String get dashSalesEmpty => 'No orders in this period';

  @override
  String get dashBackordered => 'Backordered';

  @override
  String dashUnitsCount(int count) {
    return '$count units';
  }

  @override
  String get productMaker => 'Maker';

  @override
  String get productInspectionByWarehouse =>
      'Whether arrivals are inspected is set per warehouse (Warehouses → Inspection).';

  @override
  String get supplierNameJan => 'Supplier\'s JAN (optional)';

  @override
  String get supplierNameMaker => 'Supplier\'s maker name (optional)';

  @override
  String qcUnconvertedBlock(int count) {
    return '$count lines are not converted to your products yet. Use \"Convert to our product\" on each.';
  }

  @override
  String qcSampleDone(String name) {
    return '$name: sample done, the line passed';
  }

  @override
  String qcSampleProgress(String name, int done, int target) {
    return '$name: sample $done/$target';
  }

  @override
  String qcConverted(String name) {
    return 'Converted to \"$name\"';
  }

  @override
  String qcSamplingBadge(int percent, int min) {
    return 'Sampling ($percent%, at least $min)';
  }

  @override
  String qcUnconvertedCount(int count) {
    return '$count not converted';
  }

  @override
  String qcOwnSku(String code) {
    return 'Code $code';
  }

  @override
  String qcSupplierNotation(String text) {
    return 'Supplier wrote: $text';
  }

  @override
  String get qcUnconverted => 'Not converted';

  @override
  String qcSampleState(int done, int target) {
    return 'Sample $done/$target';
  }

  @override
  String get qcConvert => 'Convert to our product';

  @override
  String get qcConvertChange => 'Change product';

  @override
  String get qcSampleAdd => 'Sample +1';

  @override
  String get qcConvertTitle => 'Convert to our product';

  @override
  String get qcConvertSearch => 'Search our name, JAN, code or maker';

  @override
  String get qcConvertRemember =>
      'Remember this supplier\'s writing and convert it automatically next time';

  @override
  String get qcConvertNone => 'No products match';

  @override
  String get qcErrorUnconverted =>
      'A line not converted to one of your products cannot pass. Convert it first.';

  @override
  String get qcErrorNotSampling => 'This is not a sampling inspection';

  @override
  String get qcErrorNoJan => 'The chosen product has no JAN';

  @override
  String get qcErrorSerialConvert =>
      'A serial-numbered line cannot be converted; cancel the receipt and receive it again';

  @override
  String get whInspectionEdit => 'Inspection';

  @override
  String get whInspectionFull => 'Inspect everything';

  @override
  String whInspectionSampleShort(int percent, int min) {
    return 'Sample $percent% (min $min)';
  }

  @override
  String get whInspectionNone => 'No inspection (receive only)';

  @override
  String get whInspectionSaved => 'Inspection setting saved';

  @override
  String whInspectionTitle(String name) {
    return 'Inspection at $name';
  }

  @override
  String get whInspectionFullBody =>
      'Everything from suppliers waits for inspection and cannot ship until inspected.';

  @override
  String get whInspectionSample => 'Sampling';

  @override
  String get whInspectionSampleBody =>
      'Arrivals wait for inspection, but each line is checked on a sample; once the sample is done the line passes.';

  @override
  String get whInspectionSamplePercent => 'Sample rate';

  @override
  String get whInspectionSampleMin => 'At least';

  @override
  String get whInspectionNoneBody =>
      'For a warehouse that inspects outside this system (e.g. by another company). Arrivals go straight to usable stock.';

  @override
  String get whInspectionApplies =>
      'Applies to arrivals from suppliers, not transfers between warehouses.';

  @override
  String get productMakerRequired =>
      'Enter the maker (every product needs one)';

  @override
  String get productPickerTitle => 'Choose our product';

  @override
  String get featNotationTraining => 'Notation training';

  @override
  String get featNotationTrainingDesc =>
      'Teach each trading company\'s way of writing from sample files';

  @override
  String get ntTitle => 'Notation training';

  @override
  String get ntTabTrain => 'Train';

  @override
  String get ntTabDialects => 'Dialects';

  @override
  String get ntTabColumns => 'Column headings';

  @override
  String get ntTabHistory => 'History';

  @override
  String get ntPartner => 'Trading company';

  @override
  String get ntAllPartners => 'All (shared)';

  @override
  String get ntChoosePartner => 'Choose the trading company';

  @override
  String get ntChooseFile => 'Choose a file';

  @override
  String ntLearned(int learned, int added, int conflicts) {
    return 'Learned $learned (new $added, conflicts $conflicts)';
  }

  @override
  String get ntTrainIntro =>
      'Read a sample Excel, CSV, PDF or photo from a trading company exactly as a real import would (read twice by AI, name and code split, matched to our products) without booking anything. Check and correct it, then teach it.';

  @override
  String get ntPickFile => 'Choose a sample file';

  @override
  String get ntRead => 'Read and check';

  @override
  String get ntReread => 'Read again with the corrected columns';

  @override
  String get ntReading => 'Reading (a PDF or photo is read twice by the AI)…';

  @override
  String ntLinesTitle(int count) {
    return '$count lines';
  }

  @override
  String get ntDiscard => 'Discard';

  @override
  String ntLearn(int count) {
    return 'Teach $count lines';
  }

  @override
  String ntSummaryLines(int count) {
    return '$count lines';
  }

  @override
  String ntSummaryResolved(int done, int total) {
    return 'Matched $done/$total';
  }

  @override
  String ntSummaryReview(int count) {
    return '$count to check';
  }

  @override
  String get ntReadTwice => 'Read twice by the AI and compared';

  @override
  String get ntReadOnce => 'The check reading failed (read once)';

  @override
  String get ntReadSheet => 'Read from the sheet (columns checked by the AI)';

  @override
  String get ntErrorsTitle => 'Problems found';

  @override
  String get ntColumnsTitle => 'How the columns were read';

  @override
  String get ntColumnsHint =>
      'Correct any that are wrong and read again. Teaching remembers them as this company\'s headings.';

  @override
  String get ntNoHeader => '(no heading)';

  @override
  String ntAiThinks(String field) {
    return 'The AI thinks: $field';
  }

  @override
  String get ntNotMatched => 'No product of ours matched';

  @override
  String get ntChooseProduct => 'Choose ours';

  @override
  String get ntChangeProduct => 'Change';

  @override
  String ntSplitFrom(String text) {
    return 'Split from: $text';
  }

  @override
  String ntOtherReading(String field, String value) {
    return 'Other reading ($field): $value';
  }

  @override
  String get ntDialectsIntro =>
      'Each company\'s ways of writing and the product or maker of ours they mean, each with its own id (D-000000).';

  @override
  String get ntAllFields => 'All';

  @override
  String get ntUnconfirmedOnly => 'Unconfirmed only';

  @override
  String get ntDialectSearch => 'Search by writing, name or JAN';

  @override
  String get ntDialectsEmpty => 'Nothing learned yet';

  @override
  String ntSeen(int count) {
    return 'seen $count×';
  }

  @override
  String get ntConfirm => 'Confirm';

  @override
  String get ntAddColumn => 'Add heading';

  @override
  String get ntColumnHeader => 'Heading (as the company writes it)';

  @override
  String get ntColumnsIntro =>
      'Column headings and what they mean — Japanese (kanji, kana) or English, mapped to our fields. Choose a company to see its own.';

  @override
  String get ntCommon => 'Shared';

  @override
  String get ntStatsTitle => 'By trading company';

  @override
  String get ntHistoryEmpty => 'No training runs yet';

  @override
  String get ntUnknownPartner => 'No company';

  @override
  String ntStatsLine(
      int runs, int lines, String rate, int dialects, int columns) {
    return '$runs runs · $lines lines · $rate matched · $dialects dialects · $columns headings';
  }

  @override
  String get ntRunsTitle => 'Runs';

  @override
  String get ntStatusLearned => 'Learned';

  @override
  String get ntStatusDiscarded => 'Discarded';

  @override
  String get ntStatusRead => 'Not taught';

  @override
  String get ntFieldJan => 'JAN';

  @override
  String get ntFieldMaker => 'Maker';

  @override
  String get ntFieldName => 'Name';

  @override
  String get ntFieldCode => 'Code';

  @override
  String get ntFieldNameCode => 'Name + code (one cell)';

  @override
  String get ntFieldQuantity => 'Quantity';

  @override
  String get ntFieldCaseQuantity => 'Per case';

  @override
  String get ntFieldCases => 'Cases';

  @override
  String get ntFieldUnitPrice => 'Unit price';

  @override
  String get ntFieldAmount => 'Amount';

  @override
  String get ntFieldSpec => 'Spec';

  @override
  String get ntFieldTaxRate => 'Tax rate';

  @override
  String get ntFieldDate => 'Date';

  @override
  String get ntFieldIgnore => 'Ignore';

  @override
  String get ntFieldUnknown => 'Unknown';

  @override
  String get ntSourcePartner => 'Learned for this company';

  @override
  String get ntSourceGlobal => 'Shared heading';

  @override
  String get ntSourceContains => 'Guessed from part of the heading';

  @override
  String get ntSourceValues => 'Judged from the values';

  @override
  String get ntSourceAi => 'Judged by the AI';

  @override
  String get ntSourceOverride => 'Corrected by hand';

  @override
  String get ntSourceNone => 'Not recognised';

  @override
  String get ntFlagUnresolved => 'No product of ours';

  @override
  String get ntFlagJanCheck => 'JAN check digit wrong';

  @override
  String get ntFlagNoJan => 'No JAN';

  @override
  String get ntFlagNoMaker => 'No maker';

  @override
  String get ntFlagNoQuantity => 'No quantity';

  @override
  String get ntFlagAmount => 'Amount ≠ qty × price';

  @override
  String get ntFlagAiDisagree => 'The two AI readings differ';

  @override
  String ntFlagAiDisagreeOn(String field) {
    return 'AI readings differ: $field';
  }

  @override
  String get ntFlagSplitDisagree => 'Name/code split disagrees';

  @override
  String get ntFlagSplitSingle => 'Name/code split (one method only)';

  @override
  String get ntFlagSplitFailed => 'Could not split name/code';

  @override
  String get ntFlagAdded => 'Line added by the check';

  @override
  String get ntFlagDropped => 'Line dropped by the check';

  @override
  String get ntFlagNotVerified => 'Not checked';

  @override
  String get ntFlagQtyFromCases => 'Qty = per case × cases';

  @override
  String get ntMatchJan => 'Matched by JAN';

  @override
  String get ntMatchDialect => 'Matched by a learned dialect';

  @override
  String get ntMatchSku => 'Matched by our code';

  @override
  String get ntMatchName => 'Matched by our name';

  @override
  String get ntMatchManual => 'Chosen by hand';

  @override
  String get ntMatchNone => '';

  @override
  String importSupplierWriting(String text) {
    return 'Supplier wrote: $text';
  }

  @override
  String importUnresolvedLines(int count) {
    return '$count lines are not yet your products. Pick them, or register now and convert them at inspection.';
  }

  @override
  String get importColumnsRead => 'How the columns were read';

  @override
  String get importNotVerified =>
      'The AI\'s checking read failed (read once only). Check the lines carefully.';

  @override
  String get groupSupplyChain => 'Supply chain';

  @override
  String get featScDashboard => 'Profit dashboard';

  @override
  String get featScDashboardDesc =>
      'What is left after every cost from purchase to sale';

  @override
  String get featScSuppliers => 'Supplier comparison';

  @override
  String get featScSuppliersDesc =>
      'Compare by final profit, not the lowest price';

  @override
  String get featScCosts => 'Cost structure';

  @override
  String get featScCostsDesc =>
      'Cost breakdown and the cost, duty and FX rules';

  @override
  String get featScRoutes => 'Logistics routes';

  @override
  String get featScRoutesDesc =>
      'Sea, air, truck and customs legs and their costs';

  @override
  String get featScSimulation => 'Profit simulation';

  @override
  String get featScSimulationDesc =>
      'What if the supplier, rate, freight, duty or FX changes';

  @override
  String get featScRisk => 'Risk analysis';

  @override
  String get featScRiskDesc =>
      'Risk of suppliers, sites and routes, with reasons';

  @override
  String get featScBottleneck => 'Bottlenecks';

  @override
  String get featScBottleneckDesc =>
      'Capacity pressure and what a stoppage costs';

  @override
  String get featScHistory => 'Scenario history';

  @override
  String get featScHistoryDesc => 'Saved scenarios and their results';

  @override
  String get scRevenue => 'Revenue';

  @override
  String get scPurchase => 'Purchase cost';

  @override
  String get scFxImpact => 'FX impact';

  @override
  String get scLogistics => 'Logistics';

  @override
  String get scCustoms => 'Customs & duty';

  @override
  String get scWarehouse => 'Warehouse';

  @override
  String get scLabor => 'Labor';

  @override
  String get scOther => 'Other costs';

  @override
  String get scTotalCost => 'Total cost';

  @override
  String get scProfit => 'Gross profit';

  @override
  String get scMargin => 'Margin';

  @override
  String get scLeadTime => 'Avg lead time';

  @override
  String get scSalesRelated => 'Sales-related costs';

  @override
  String get scRecoverable => 'Recoverable (not in cost)';

  @override
  String get scLinePurchase => 'Purchase';

  @override
  String get scLineFx => 'FX impact';

  @override
  String get scLineIntlFreight => 'International freight';

  @override
  String get scLineInsurance => 'Insurance';

  @override
  String get scLineDuty => 'Duty';

  @override
  String get scLineImportTax => 'Import tax (not recoverable)';

  @override
  String get scLineCustomsFee => 'Customs fee';

  @override
  String get scLinePortFee => 'Port / airport';

  @override
  String get scLineDomesticFreight => 'Domestic freight';

  @override
  String get scLineWarehouse => 'Warehouse';

  @override
  String get scLineReceiving => 'Receiving';

  @override
  String get scLineInspection => 'Inspection';

  @override
  String get scLinePacking => 'Packing';

  @override
  String get scLineLabor => 'Labor';

  @override
  String get scLineOverhead => 'Overhead';

  @override
  String get scLineOther => 'Other';

  @override
  String get scLineRevenue => 'Revenue';

  @override
  String get scLandedCost => 'Landed cost';

  @override
  String get scSalesPrice => 'Sales price';

  @override
  String get scProfitPerUnit => 'Profit / unit';

  @override
  String get scAnnualProfit => 'Annual profit';

  @override
  String get scVolume => 'Annual volume';

  @override
  String scDays(String days) {
    return '$days d';
  }

  @override
  String get scCurrent => 'Current';

  @override
  String get scSimulated => 'Simulated';

  @override
  String get scDifference => 'Change vs current';

  @override
  String get scCurrentValues => 'Current values';

  @override
  String get scSimulatedValues => 'Simulated values (nothing real changes)';

  @override
  String get scDrivers => 'What changed it';

  @override
  String get scNoData => 'No products can be costed yet';

  @override
  String get scNoDataBody =>
      'Register each product\'s supply terms (supplier, price, rate) to see its cost and profit. They can also be taken from purchase orders and delivery notes.';

  @override
  String get scSeed => 'Take terms from purchase history';

  @override
  String scSeeded(int po, int doc) {
    return 'Took $po from purchase orders and $doc from delivery notes';
  }

  @override
  String get scSnapshot => 'Save snapshot';

  @override
  String get scSnapshotSaved => 'Current state saved';

  @override
  String get scAllWarehouses => 'All warehouses';

  @override
  String get scAlerts => 'Needs attention';

  @override
  String scAlertBottlenecks(int count) {
    return '$count over capacity or stopped';
  }

  @override
  String scAlertRisks(int count) {
    return '$count high risks';
  }

  @override
  String scAlertNoSupply(int count) {
    return '$count products without a supplier';
  }

  @override
  String scAlertLoss(int count) {
    return '$count products at a loss';
  }

  @override
  String get scProductsTitle => 'Profit by product';

  @override
  String get scCostBreakdown => 'Cost breakdown';

  @override
  String get scWaterfall => 'From sales price to profit (per unit)';

  @override
  String get scChosen => 'Current source';

  @override
  String get scNoRoute => 'No route';

  @override
  String get scProduct => 'Product';

  @override
  String get scChooseProduct => 'Choose a product';

  @override
  String get scQuantity => 'Quantity per order';

  @override
  String get scRates => 'Compare rates';

  @override
  String get scRatesHint => 'e.g. 65,70,75';

  @override
  String get scDiscountRate => 'Rate';

  @override
  String get scUnitPrice => 'Unit price';

  @override
  String get scListPrice => 'List price';

  @override
  String get scCurrency => 'Currency';

  @override
  String get scMoq => 'MOQ';

  @override
  String get scOrderLot => 'Order lot';

  @override
  String get scLeadTimeDays => 'Lead time (days)';

  @override
  String get scPaymentTerms => 'Payment terms';

  @override
  String get scPrimary => 'Primary';

  @override
  String get scDefaultRoute => 'Default route';

  @override
  String get scSupplyTerms => 'Supply terms';

  @override
  String get scAddTerm => 'Add supply term';

  @override
  String get scSupplier => 'Supplier';

  @override
  String get scSupplierStats => 'Supplier record';

  @override
  String scStatLine(int products, int sole, int orders) {
    return '$products items · $sole sole-sourced · $orders orders';
  }

  @override
  String get scLateRate => 'Late rate';

  @override
  String get scDefectRate => 'Defect rate';

  @override
  String get scPurchased => 'Purchased';

  @override
  String get scProfile => 'Product assumptions';

  @override
  String get scEditProfile => 'Edit assumptions';

  @override
  String get scAnnualVolume => 'Annual volume';

  @override
  String get scAnnualVolumeHint => 'Blank: last 12 months shipped';

  @override
  String get scSalesPriceHint => 'Blank: the product master price';

  @override
  String get scWeight => 'Weight (kg/unit)';

  @override
  String get scUnitsPerCarton => 'Units per carton';

  @override
  String get scStorageDays => 'Storage days';

  @override
  String get scHsCode => 'HS code';

  @override
  String get scOriginCountry => 'Origin country';

  @override
  String get scCostRules => 'Cost rules';

  @override
  String get scTariffRules => 'Duty & import tax';

  @override
  String get scFxRates => 'FX rates';

  @override
  String get scByProduct => 'By product';

  @override
  String get scAddRule => 'Add rule';

  @override
  String get scRuleName => 'Name';

  @override
  String get scCategory => 'Category';

  @override
  String get scBasis => 'Basis';

  @override
  String get scAmount => 'Amount / rate';

  @override
  String get scAmountPercentHint => 'Rates as decimals (3% = 0.03)';

  @override
  String get scUnitsPerBasis => 'Units per basis';

  @override
  String get scUnitsPerBasisHint =>
      'Units per hour, per carton, or the monthly volume to spread over';

  @override
  String get scExpensed => 'Count as cost (off: recoverable)';

  @override
  String get scAll => 'All';

  @override
  String get scCatStorage => 'Storage';

  @override
  String get scCatReceiving => 'Receiving';

  @override
  String get scCatInspection => 'Inspection';

  @override
  String get scCatPacking => 'Packing';

  @override
  String get scCatPicking => 'Picking';

  @override
  String get scCatShipping => 'Shipping';

  @override
  String get scCatLabor => 'Labor';

  @override
  String get scCatOverhead => 'Overhead';

  @override
  String get scCatDomesticFreight => 'Domestic freight';

  @override
  String get scCatSalesRelated => 'Sales-related';

  @override
  String get scCatOther => 'Other';

  @override
  String get scBasisPerUnit => 'Per unit';

  @override
  String get scBasisPerUnitMonth => 'Per unit per month';

  @override
  String get scBasisPerCarton => 'Per carton';

  @override
  String get scBasisPerLine => 'Per line';

  @override
  String get scBasisPerOrder => 'Per order';

  @override
  String get scBasisPerHour => 'Per hour';

  @override
  String get scBasisPercentRevenue => 'Rate of revenue';

  @override
  String get scBasisPercentPurchase => 'Rate of purchase';

  @override
  String get scBasisFixedMonthly => 'Fixed per month';

  @override
  String get scTariffRate => 'Duty rate';

  @override
  String get scImportTaxRate => 'Import tax rate';

  @override
  String get scImportTaxRecoverable => 'Import tax is recoverable';

  @override
  String get scOtherRate => 'Other import duty rate';

  @override
  String get scValuation => 'Valuation';

  @override
  String get scHsPrefix => 'HS code (prefix)';

  @override
  String get scDestinationCountry => 'Destination country';

  @override
  String get scAddTariff => 'Add duty rule';

  @override
  String get scRateToBase => 'Rate (per unit of currency)';

  @override
  String get scAddFx => 'Add currency';

  @override
  String get scRoutesTab => 'Routes';

  @override
  String get scNodesTab => 'Sites';

  @override
  String get scAddRoute => 'Add route';

  @override
  String get scAddNode => 'Add site';

  @override
  String get scRouteName => 'Route name';

  @override
  String get scLegs => 'Legs';

  @override
  String get scAddLeg => 'Add leg';

  @override
  String get scFrom => 'From';

  @override
  String get scTo => 'To';

  @override
  String get scMode => 'Mode';

  @override
  String get scBaseCost => 'Base cost (per shipment)';

  @override
  String get scCostPerKg => 'Per kg';

  @override
  String get scCostPerUnit => 'Per unit';

  @override
  String get scInsuranceRate => 'Insurance rate';

  @override
  String get scCapacityKg => 'Capacity (kg/month)';

  @override
  String get scCapacityUnits => 'Capacity (units/month)';

  @override
  String get scCustomsClearance => 'Clears import customs here';

  @override
  String get scCustomsCost => 'Customs fee (per shipment)';

  @override
  String get scRisk => 'Risk';

  @override
  String get scApplyRoute => 'Use this route in a scenario';

  @override
  String get scNoRoutes => 'No routes yet';

  @override
  String get scNoRoutesBody =>
      'Register the legs from a supplier to a warehouse (sea, air, truck, customs) to bring freight, duty and lead time into the numbers.';

  @override
  String get scNodeName => 'Name';

  @override
  String get scNodeKind => 'Kind';

  @override
  String get scCountry => 'Country code';

  @override
  String get scDwellDays => 'Dwell days';

  @override
  String get scHandlingPerUnit => 'Handling (per unit)';

  @override
  String get scKindSupplier => 'Supplier';

  @override
  String get scKindPort => 'Port';

  @override
  String get scKindAirport => 'Airport';

  @override
  String get scKindCustoms => 'Customs';

  @override
  String get scKindWarehouse => 'Warehouse';

  @override
  String get scKindDc => 'Distribution center';

  @override
  String get scKindCustomer => 'Customer';

  @override
  String get scKindHub => 'Hub';

  @override
  String get scModeSea => 'Sea';

  @override
  String get scModeAir => 'Air';

  @override
  String get scModeTruck => 'Truck';

  @override
  String get scModeRail => 'Rail';

  @override
  String get scModeCourier => 'Courier';

  @override
  String get scModeInternal => 'Internal transfer';

  @override
  String get scRiskLow => 'Low';

  @override
  String get scRiskMedium => 'Medium';

  @override
  String get scRiskHigh => 'High';

  @override
  String get scRiskCritical => 'Critical';

  @override
  String get scScenario => 'Scenario';

  @override
  String get scCurrentConditions => 'Current conditions';

  @override
  String get scScenarioName => 'Scenario name';

  @override
  String get scSuppliersUsed => 'Suppliers to use';

  @override
  String get scRouteChoice => 'Logistics';

  @override
  String get scRouteCurrent => 'Current route';

  @override
  String get scRouteCheapest => 'Cheapest';

  @override
  String get scRouteFastest => 'Fastest';

  @override
  String get scSupplierChoice => 'Which supplier';

  @override
  String get scChoiceCurrent => 'Current supplier';

  @override
  String get scChoiceCheapest => 'Most profit';

  @override
  String get scChoiceFastest => 'Shortest lead time';

  @override
  String get scChanges => 'What changes (±%)';

  @override
  String get scChangeHint => 'e.g. +10 is 10% more, -5 is 5% less';

  @override
  String get scPriceChange => 'Purchase price';

  @override
  String get scFreightChange => 'Freight (all)';

  @override
  String get scSeaChange => 'Sea freight';

  @override
  String get scAirChange => 'Air freight';

  @override
  String get scTariffChange => 'Duty';

  @override
  String get scCustomsChange => 'Customs fee';

  @override
  String get scWarehouseChange => 'Warehouse';

  @override
  String get scLaborChange => 'Labor';

  @override
  String get scOverheadChange => 'Overhead';

  @override
  String get scFxChange => 'FX (foreign currency up)';

  @override
  String get scSalesPriceChange => 'Sales price';

  @override
  String get scVolumeChange => 'Sales volume';

  @override
  String get scRatesBySupplier => 'Rate changes';

  @override
  String scRateNow(String rate) {
    return 'now $rate';
  }

  @override
  String get scAddSupplier => 'Add a supplier (what-if)';

  @override
  String get scAddedSupplier => 'Supplier to add';

  @override
  String get scApplyRiskEvents => 'Apply the registered risks';

  @override
  String get scRun => 'Run simulation';

  @override
  String get scSaveScenario => 'Save scenario';

  @override
  String get scScenarioSaved => 'Scenario saved';

  @override
  String get scAddToCompare => 'Add to comparison';

  @override
  String get scCompare => 'Comparison (up to 5)';

  @override
  String get scRunCompare => 'Compare';

  @override
  String get scClearCompare => 'Clear';

  @override
  String get scCompareFull => 'Up to 5 scenarios can be compared';

  @override
  String scResultTitle(String name) {
    return 'Scenario: $name';
  }

  @override
  String get scProductChanges => 'Changes by product';

  @override
  String get scNotBest =>
      'The system does not pick a winner: weigh profit, lead time and risk yourself.';

  @override
  String get scHighRisks => 'High risks';

  @override
  String get scOverCapacity => 'Over capacity';

  @override
  String get scRiskTitle => 'Risks';

  @override
  String get scRiskRuleNote =>
      'Risk scores come from explainable rules: set levels, registered risks, capacity, sole sourcing, late and defect rates.';

  @override
  String get scRiskEvents => 'Registered risks';

  @override
  String get scAddRiskEvent => 'Register a risk';

  @override
  String get scRiskEventTitle => 'Title';

  @override
  String get scRiskKind => 'Kind';

  @override
  String get scSeverity => 'Severity';

  @override
  String get scStartsOn => 'Starts';

  @override
  String get scEndsOn => 'Ends';

  @override
  String get scPriceMultiplier => 'Price multiplier';

  @override
  String get scCostMultiplier => 'Cost multiplier';

  @override
  String get scCapacityMultiplier => 'Capacity multiplier';

  @override
  String get scDelayDays => 'Delay (days)';

  @override
  String get scTarget => 'Target';

  @override
  String scReasonLevel(String level) {
    return 'Set level: $level';
  }

  @override
  String scReasonSole(String count) {
    return 'Sole source of $count items';
  }

  @override
  String scReasonEvent(String kind) {
    return 'Registered risk: $kind';
  }

  @override
  String scReasonLate(String rate) {
    return 'Late $rate%';
  }

  @override
  String scReasonDefect(String rate) {
    return 'Defects $rate%';
  }

  @override
  String get scReasonLoadExceeded => 'Over capacity';

  @override
  String get scReasonLoadBusy => 'Near capacity';

  @override
  String get scReasonNoAlt => 'No alternative';

  @override
  String scReasonLongLead(String days) {
    return 'Long lead time $days d';
  }

  @override
  String get scReasonCrossBorder => 'Crosses a border';

  @override
  String get scEvSupplierStop => 'Supplier stops';

  @override
  String get scEvSupplierPrice => 'Supplier price rise';

  @override
  String get scEvSupplierDelay => 'Supplier delay';

  @override
  String get scEvRouteStop => 'Route stops';

  @override
  String get scEvModeStop => 'Transport mode stops';

  @override
  String get scEvPortStop => 'Port closed';

  @override
  String get scEvAirportStop => 'Airport closed';

  @override
  String get scEvCustomsDelay => 'Customs delay';

  @override
  String get scEvWarehouseCapacity => 'Warehouse capacity short';

  @override
  String get scEvWarehouseStop => 'Warehouse stops';

  @override
  String get scEvDomesticStop => 'Domestic delivery stops';

  @override
  String get scEvStaffShortage => 'Staff shortage';

  @override
  String get scEvCostSpike => 'Cost spike';

  @override
  String get scRiskKindSupplier => 'Supplier';

  @override
  String get scRiskKindNode => 'Site';

  @override
  String get scRiskKindRoute => 'Route';

  @override
  String get scNoRisks => 'Nothing to assess yet';

  @override
  String get scLoadsTitle => 'Capacity and load';

  @override
  String get scStatusOk => 'OK';

  @override
  String get scStatusBusy => 'Near capacity';

  @override
  String get scStatusExceeded => 'Capacity exceeded';

  @override
  String get scStatusNoCapacity => 'No capacity set';

  @override
  String get scStatusStopped => 'Stopped';

  @override
  String get scAlternative => 'Has alternative';

  @override
  String get scNoAlternative => 'No alternative';

  @override
  String scPerMonth(String units) {
    return '$units units/month';
  }

  @override
  String scLoadPercent(String percent) {
    return 'Load $percent';
  }

  @override
  String get scDisruptionTitle => 'Disruption simulation';

  @override
  String get scDisruptionTarget => 'What stops';

  @override
  String get scDisruptionDays => 'Days';

  @override
  String get scDisruptionKind => 'Kind';

  @override
  String get scStop => 'Stop';

  @override
  String get scDelay => 'Delay';

  @override
  String get scRunDisruption => 'Work out the impact';

  @override
  String get scImpact => 'Impact on profit';

  @override
  String get scExtraCost => 'Extra cost';

  @override
  String get scLostProfit => 'Lost profit';

  @override
  String get scLostUnits => 'Units short';

  @override
  String get scRerouted => 'Rerouted';

  @override
  String scCoverage(String days) {
    return '$days days of stock';
  }

  @override
  String get scNoAlternativeRoute => 'No alternative route';

  @override
  String scAlternativeVia(String name) {
    return 'Via: $name';
  }

  @override
  String get scNoLoads => 'No flows yet: register routes and volumes.';

  @override
  String get scSavedScenarios => 'Saved scenarios';

  @override
  String get scRunHistory => 'Run history';

  @override
  String get scRunAgain => 'Run again';

  @override
  String get scNoScenarios => 'No saved scenarios';

  @override
  String get scNoRuns => 'No runs yet';

  @override
  String get scRunKindBaseline => 'Current';

  @override
  String get scRunKindScenario => 'Scenario';

  @override
  String get scRunKindCompare => 'Comparison';

  @override
  String get scRunKindDisruption => 'Disruption';

  @override
  String get scRunKindProduct => 'Product';

  @override
  String get scRunKindPurchaseCheck => 'Pre-order check';

  @override
  String get scProductCard => 'Cost & profit';

  @override
  String get scOpenComparison => 'Compare suppliers';

  @override
  String get scNoTerms => 'No supply terms for this product yet';

  @override
  String get scProfitWarning => 'Profit warning';

  @override
  String scProfitWarningBody(String before, String after) {
    return 'On these terms the margin goes from $before to $after.';
  }

  @override
  String get scWarnMarginLow => 'Margin below the threshold';

  @override
  String get scWarnMarginDrop => 'Margin drops sharply';

  @override
  String get scWarnLoss => 'Sold at a loss';

  @override
  String get scCauses => 'Causes';

  @override
  String get scContinueOrder => 'Place the order';

  @override
  String get scBackToEdit => 'Back';

  @override
  String get scNoteNoRoute => 'No route (no freight counted)';

  @override
  String get scNoteNoWeight => 'No weight set';

  @override
  String get scNoteNoVolume => 'No volume (costed per 1)';

  @override
  String get scNoteNoPrice => 'No purchase price';

  @override
  String get scNoteNoFx => 'No FX rate';

  @override
  String get scNoteNoTariff => 'No duty rule';

  @override
  String get scNoteFixed => 'Fixed cost not allocated';

  @override
  String get scHypothetical => 'What-if';

  @override
  String get scManageOnly => 'Editing needs supply_chain.manage';

  @override
  String get scRecalculate => 'Recalculate';

  @override
  String get scBlocked => 'Unavailable';

  @override
  String get scErrorRouteLegs =>
      'The legs don\'t join up (each must start where the last ended)';

  @override
  String get scErrorNameRequired => 'Enter a name';

  @override
  String get scNoChange => 'No change';

  @override
  String get aiFieldProduct => 'Our product';

  @override
  String get aiBandAuto => 'Auto candidate';

  @override
  String get aiBandReview => 'Check recommended';

  @override
  String get aiBandHuman => 'Human review';

  @override
  String get aiSaved => 'Thresholds saved';

  @override
  String get featAiSettings => 'AI settings';

  @override
  String get featAiSettingsDesc => 'Confidence thresholds for document reading';

  @override
  String get aiSettingsIntro =>
      'Each field of a reading has a confidence (from whether the AI\'s two reads agreed, the JAN check digit, the name/品番 split, and quantity × price = amount). Its band decides whether it is an automatic candidate, check recommended, or needs a person.';

  @override
  String get aiAutoThreshold => 'Automatic from';

  @override
  String get aiReviewThreshold =>
      'Check recommended from (below: human review)';

  @override
  String get aiExample => 'Examples';

  @override
  String get featDocExceptions => 'Document differences';

  @override
  String get featDocExceptionsDesc =>
      'Where order, invoice, delivery and inspection disagree';

  @override
  String get docFlagNotOrdered => 'Not on the order';

  @override
  String get docFlagNotInvoiced => 'Not invoiced';

  @override
  String get docFlagInvoiceQty => 'Invoiced quantity differs';

  @override
  String get docFlagInvoicePrice => 'Invoiced price differs';

  @override
  String get docFlagShortDelivery => 'Less received than invoiced';

  @override
  String get docFlagInspectShort => 'Less inspected than received';

  @override
  String get docFlagDefective => 'Defects found';

  @override
  String get docInvoiceOpen => 'Open';

  @override
  String get docInvoiceMatched => 'Matched';

  @override
  String get docInvoiceMismatch => 'Differences';

  @override
  String get docInvoiceApproved => 'Approved';

  @override
  String get docInvoiceVoid => 'Void';

  @override
  String get docMatchOk => 'All match';

  @override
  String get docMatchMismatch => 'Differences';

  @override
  String get docMatchPending => 'Awaiting invoice';

  @override
  String get docMatchTitle => 'Document match';

  @override
  String get docAddInvoice => 'Add invoice';

  @override
  String get docTolerance => 'Tolerance';

  @override
  String get docToleranceQty => 'Quantity';

  @override
  String get docTolerancePrice => 'Price';

  @override
  String get docOrder => 'Order';

  @override
  String get docInvoice => 'Invoice';

  @override
  String get docDelivery => 'Delivery';

  @override
  String get docReceived => 'Received';

  @override
  String get docInspection => 'Inspection';

  @override
  String get docOrderAmount => 'Ordered';

  @override
  String get docInvoiceAmount => 'Invoiced';

  @override
  String get docDifference => 'Difference';

  @override
  String docFailedShort(String n) {
    return '$n defective';
  }

  @override
  String get docUnitPrice => 'Unit price';

  @override
  String docApproved(int n) {
    return 'Approved ($n supply terms updated)';
  }

  @override
  String get docInvoices => 'Invoices';

  @override
  String get docNoInvoices => 'No invoices yet';

  @override
  String get docLinesSuffix => 'lines';

  @override
  String get docReadFromDocument => 'Read from document';

  @override
  String get docApprove => 'Approve';

  @override
  String get docVoid => 'Void';

  @override
  String get docInvoiceNumberRequired => 'Enter the invoice number';

  @override
  String get docSaved => 'Saved';

  @override
  String get docReadFromFile => 'Read from the invoice (PDF, photo, Excel)';

  @override
  String get docInvoiceNumber => 'Invoice number';

  @override
  String get docInvoiceDate => 'Invoice date';

  @override
  String get docInvoiceTotal => 'Invoice total';

  @override
  String get docLines => 'Lines';

  @override
  String get docAddLine => 'Add line';

  @override
  String get docSaveAndMatch => 'Save and match';

  @override
  String get docExceptionsTitle => 'Document differences';

  @override
  String get docNoExceptions => 'No differences';

  @override
  String docExceptionCount(int count) {
    return '$count to check';
  }

  @override
  String docDeltaQty(String n) {
    return 'qty $n';
  }

  @override
  String docDeltaPrice(String n) {
    return 'price $n';
  }

  @override
  String get poDocumentMatch => 'Document match';

  @override
  String get ntTabVersions => 'Versions';

  @override
  String get ntSnapshot => 'Save current version';

  @override
  String get ntSnapshotNote => 'Note (e.g. new layout)';

  @override
  String ntRestored(int version, int dialects, int aliases, int conflicts) {
    return 'Brought back v$version ($dialects writings, $aliases headings, $conflicts conflicts)';
  }

  @override
  String get ntVersionTraining => 'From training';

  @override
  String get ntVersionRestore => 'Restored';

  @override
  String get ntVersionManual => 'Saved by hand';

  @override
  String get ntVersionsIntro =>
      'Each company\'s dictionary (writings and headings) is kept as numbered versions — saved each time a sample is learned, never overwritten. Bringing an old version back only adds what is missing now; a writing that now means something else is reported, not overwritten.';

  @override
  String get ntNoVersions => 'No versions yet';

  @override
  String ntVersionCounts(int dialects, int aliases) {
    return '$dialects writings · $aliases headings';
  }

  @override
  String get ntVersionCurrent => 'Current';

  @override
  String get ntRestore => 'Bring back';

  @override
  String syncSent(int count) {
    return 'Sent $count';
  }

  @override
  String syncOffline(int count) {
    return 'Offline — records are kept on the device and sent when the network is back ($count waiting)';
  }

  @override
  String syncPending(int count) {
    return '$count records waiting to send';
  }

  @override
  String get syncNow => 'Send now';

  @override
  String syncRefused(String reason) {
    return 'Not accepted: $reason';
  }

  @override
  String get syncDismiss => 'Dismiss';

  @override
  String get errorOffline =>
      'No connection. Confirm once the network is back (counts and findings are kept on the device).';

  @override
  String get featProductLibrary => 'Product library';

  @override
  String get featProductLibraryDesc =>
      'Pictures of each product; the first is shown in front of its name';

  @override
  String get plSearchHint => 'Search name, JAN, code or maker';

  @override
  String get plWithoutImages => 'Without pictures only';

  @override
  String get plNoProducts => 'No matching products';

  @override
  String plImageCount(int count) {
    return '$count pictures';
  }

  @override
  String get plNoImages => 'No pictures yet';

  @override
  String get plAddPhoto => 'Add picture';

  @override
  String get plFromCamera => 'Take a photo';

  @override
  String get plFromGallery => 'Choose a picture';

  @override
  String get plPutFirst => 'Put first (shown in front of the name)';

  @override
  String get plFace => 'Face';

  @override
  String get plMakeFace => 'Make it first';

  @override
  String get plWithdraw => 'Take down';

  @override
  String get plWithdrawConfirm =>
      'Take this picture down? (It is kept on record.)';

  @override
  String get plUploaded => 'Picture added';

  @override
  String get plReorderHint =>
      'Drag to reorder. The first picture (the face) is shown in front of the product name on receiving, inspection, putaway, picking, shipping and order screens.';

  @override
  String get plFaceHint =>
      'The first picture (the face) is shown in front of the product name on every screen.';

  @override
  String get plGalleryTitle => 'Product pictures';

  @override
  String get plOpenLibrary => 'Product pictures';

  @override
  String get plTabPhotos => 'Pictures';

  @override
  String get plTabAttributes => 'Attributes';

  @override
  String get plTabSuppliers => 'Supplier names';

  @override
  String get plAttributesHint =>
      'Our values. Each supplier\'s way of writing them (e.g. カラー \'BK\') is listed under Supplier names and read as ours (色 \'黒\').';

  @override
  String get plAttrNew => 'Add attribute';

  @override
  String get plAttrName => 'Attribute name';

  @override
  String get plAttrUnit => 'Unit (optional)';

  @override
  String get plAttrValue => 'Value';

  @override
  String get plAttrHeading => 'Heading (e.g. Colour)';

  @override
  String get plSuppliersHint =>
      'How each supplier calls this product — name, code, JAN, maker and attributes. Filled automatically by pre-training, imports and inspection.';

  @override
  String get plNoSuppliers => 'No supplier names yet';

  @override
  String get plSupplierAdd => 'Add supplier name';

  @override
  String get plSupplier => 'Supplier';

  @override
  String get plSupplierSaved => 'Saved';

  @override
  String get plWritings => 'Spellings seen';

  @override
  String get plAdopt => 'Use as ours';

  @override
  String plRemoveSupplierConfirm(String name) {
    return 'Remove $name\'s names and attributes for this product? (The reading dictionary keeps them.)';
  }

  @override
  String get ntFieldAttr => 'Attribute';

  @override
  String ntAttr(String name) {
    return 'Attribute: $name';
  }

  @override
  String ntLearnedLibrary(int profiles, int attributes) {
    return 'Learned: $profiles supplier names, $attributes attributes';
  }

  @override
  String get featNameFormats => 'Product format';

  @override
  String get featNameFormatsDesc =>
      'How product names are built, and renaming a maker or a colour everywhere at once';

  @override
  String get nfTitle => 'Product format';

  @override
  String get nfTabFormats => 'Formats';

  @override
  String get nfTabMakers => 'Makers';

  @override
  String get nfTabValues => 'Attribute values';

  @override
  String get nfIntro =>
      'A product name is built from its parts — the base name, maker, code, size, colour and so on — by the chosen format. Change a format and every product using it is renamed. Names typed by hand are left alone.';

  @override
  String get nfDefault => 'Default';

  @override
  String nfProducts(int count) {
    return '$count products';
  }

  @override
  String get nfNew => 'Add format';

  @override
  String get nfEdit => 'Edit format';

  @override
  String get nfName => 'Format name';

  @override
  String get nfTemplate => 'Template';

  @override
  String get nfTemplateHint => 'The base name must be in it';

  @override
  String get nfInsert => 'Parts (tap to add)';

  @override
  String get nfPartBase => 'Base name';

  @override
  String get nfPartMaker => 'Maker';

  @override
  String get nfPartCode => 'Code';

  @override
  String get nfPartJan => 'JAN';

  @override
  String get nfPartUnit => 'Unit';

  @override
  String get nfSample => 'Example';

  @override
  String get nfSampleBase => 'Ballpoint pen';

  @override
  String get nfSampleMaker => 'Sample Stationery';

  @override
  String get nfSampleUnit => 'pc';

  @override
  String get nfSampleColor => 'red';

  @override
  String get nfMakeDefault => 'Default for new products';

  @override
  String get nfPreview => 'How real product names change';

  @override
  String get nfPreviewRefresh => 'Check';

  @override
  String get nfPreviewNone => 'No products use this format yet';

  @override
  String get nfNeedsBase => 'Put the base name in the template';

  @override
  String get nfNeedsName => 'Give the format a name';

  @override
  String nfSaved(int count) {
    return 'Saved. $count product names rebuilt';
  }

  @override
  String get nfSearchMaker => 'Search makers (any spelling)';

  @override
  String get nfMakersHint =>
      'Renaming a maker renames all its products. The old name keeps reading as the same maker.';

  @override
  String get nfRename => 'Rename maker';

  @override
  String get nfNewName => 'New name';

  @override
  String nfDialects(int count) {
    return '$count other spellings';
  }

  @override
  String nfMakerRenamed(int count) {
    return 'Applied to $count products';
  }

  @override
  String get nfValuesHint =>
      'Call an attribute value something else everywhere (e.g. colour 赤 → レッド). Product names with it and the suppliers’ words for it follow. The old value keeps reading as the new one.';

  @override
  String get nfAttribute => 'Attribute';

  @override
  String get nfFrom => 'Current value';

  @override
  String get nfTo => 'New value';

  @override
  String get nfRenameEverywhere => 'Rename everywhere';

  @override
  String nfValueRenamed(int count) {
    return '$count products changed';
  }

  @override
  String get pnTitle => 'Build the name';

  @override
  String get pnBaseName => 'Base name (without size or colour)';

  @override
  String get pnUnit => 'Unit';

  @override
  String get pnListPrice => 'List price';

  @override
  String get pnFormat => 'Format';

  @override
  String pnFormatDefault(String name) {
    return 'Default format ($name)';
  }

  @override
  String get pnManual => 'Type the name by hand (no format)';

  @override
  String get pnName => 'Product name';

  @override
  String get pnPreview => 'Product name';

  @override
  String get pnLegacy =>
      'This product has no parts yet. Enter a base name and the format will build its name.';

  @override
  String get pnAttrsHint =>
      'Size, colour and so on are set on the Attributes tab of the product pictures screen';

  @override
  String get pnNeedsBase => 'Enter a base name';

  @override
  String get pnSaved => 'Product name updated';

  @override
  String rpOpen(int count) {
    return 'Register new products in our format ($count)';
  }

  @override
  String get rpTitle => 'Register in our format';

  @override
  String get rpIntro =>
      'These are the document’s new lines as products in our format. Check and correct them, then register. Registering also learns this supplier’s way of writing them.';

  @override
  String get rpNone =>
      'Nothing new to register (lines without a JAN and products we have are left out)';

  @override
  String get rpFromCode =>
      'The document has no name for it; the code stands in for now';

  @override
  String rpRegister(int count) {
    return 'Register $count';
  }

  @override
  String rpRegistered(int count) {
    return '$count products registered';
  }

  @override
  String get rpNeedsMaker =>
      'Every chosen product needs a maker and a base name';

  @override
  String get ntFieldListPrice => 'List price';

  @override
  String get ntFieldDiscountRate => 'Rate';

  @override
  String get ntFieldUnit => 'Unit';

  @override
  String get ntFieldSupplierCode => 'Supplier’s own code';

  @override
  String get ntMatchRegistered => 'Registered in our format';

  @override
  String get featFieldLibrary => 'Field library';

  @override
  String get featFieldLibraryDesc =>
      'Every heading companies use (JAN, JANコード, ジャパンコード…) in one place, and the names this system shows';

  @override
  String get flTitle => 'Field library';

  @override
  String get flIntro =>
      'Each thing a document column can mean (JAN, maker, code…) with every heading companies use for it. Headings are added by imports and pre-training. Use the pencil to choose the name this system shows, per language (empty = the built-in name).';

  @override
  String flBuiltIn(String name) {
    return 'Built-in name: $name';
  }

  @override
  String get flEditNames => 'Choose the names shown';

  @override
  String flNamesHint(String name) {
    return 'A language left empty keeps the built-in name \"$name\".';
  }

  @override
  String get flLangJa => 'Japanese';

  @override
  String get flLangEn => 'English';

  @override
  String get flLangZh => 'Chinese';

  @override
  String get flSaved => 'Names saved';

  @override
  String flHeadings(int count) {
    return '$count headings';
  }

  @override
  String get flAddHeading => 'Add a heading';

  @override
  String flAddHeadingTo(String name) {
    return 'Add a heading for \"$name\"';
  }

  @override
  String get flHeading => 'Heading (as the document writes it)';

  @override
  String get flEveryone => 'Everyone';

  @override
  String flOnlyFor(String name) {
    return 'Only $name';
  }

  @override
  String flHeadingAdded(String header) {
    return 'Added \"$header\"';
  }

  @override
  String get flAttributes => 'Product attributes';

  @override
  String get flAttributesHint =>
      'Attribute names (colour, size…) are changed on the Attributes tab of the product pictures screen.';

  @override
  String get ntFieldUpstreamCode => 'The company’s supplier code';

  @override
  String get ntFieldCustomerCode => 'Their code for us';

  @override
  String get ntFlagJanExponent =>
      'The JAN lost its digits to exponent form (e.g. 4.90E+12)';

  @override
  String get pcRulesTitle => 'Numbering our partner codes';

  @override
  String get pcRulesHint =>
      'When a new company is added without a code, ours is numbered by this rule. Each company’s code can be changed later.';

  @override
  String get pcPrefix => 'Prefix';

  @override
  String get pcDigits => 'Digits';

  @override
  String get pcNext => 'Next number';

  @override
  String pcNextCode(String code) {
    return 'Next code: $code';
  }

  @override
  String get pcRulesSaved => 'Numbering saved';

  @override
  String get pcIssueMissing => 'Number those without a code';

  @override
  String pcIssued(int count) {
    return '$count companies numbered';
  }

  @override
  String get pcOurCode => 'Our code for this company';

  @override
  String get pcAutoHint => 'Left empty, it is numbered by our rule';

  @override
  String get pcTheirCode => 'Their code for us';

  @override
  String get pcTheirCodeHint =>
      'Our number on their invoices and quotes; filled from their documents when seen';

  @override
  String pcOurCodeShort(String code) {
    return 'Ours $code';
  }

  @override
  String pcTheirCodeShort(String code) {
    return 'Theirs for us $code';
  }

  @override
  String get pcVendorCodesTitle => 'This company’s supplier codes';

  @override
  String get pcVendorCodesHint =>
      'Numbers this company gives its own suppliers (makers). They are not our codes.';

  @override
  String get ntFlagJanDisplayExponent =>
      'The JAN is shown in exponent form (e.g. 4.90E+12); read from the full 13 digits it holds';

  @override
  String get ntFlagJanRestored =>
      'The JAN had lost its digits; taken from the product the 品番 names (its leading digits agree). Please check';

  @override
  String get ntFlagJanRestoreMismatch =>
      'The JAN lost its digits, and the 品番’s product does not match what is left, so nothing was filled in';

  @override
  String get ntFlagJanCodeMismatch =>
      'The JAN and the 品番 point to different products';

  @override
  String get ntAltCodeProduct => 'The product the 品番 names';

  @override
  String get ntMatchJanRestored => 'JAN taken from the 品番';

  @override
  String importJanWarnings(int count) {
    return '$count lines need their JAN checked (tap ⚠ to say whether the warning was right)';
  }

  @override
  String importJanDisplayExponent(int count) {
    return '$count JANs are shown in exponent form in the file (e.g. 4.90E+12) but were read right from their full digits. Saving the file as CSV would lose the digits, so ask for the Excel file as it is';
  }

  @override
  String get wrTitle => 'Check the warning';

  @override
  String get wrQuestion =>
      'Was this warning right? Your answer is used to tune the warning rules.';

  @override
  String get wrNote => 'Note (optional)';

  @override
  String get wrNoteHint => 'e.g. the case and the single item share a 品番';

  @override
  String get wrRight => 'It was right';

  @override
  String get wrWrong => 'Wrong (nothing was amiss)';

  @override
  String get wrThanks => 'Reported; it will be used to tune the warnings';

  @override
  String get wrStatsTitle => 'How right the warnings were';

  @override
  String get wrStatsHint =>
      'What the people checking reported. Warnings often wrong get their rules reviewed.';

  @override
  String get wrStatsEmpty => 'No reports yet. Tap ⚠ on a line to report';

  @override
  String wrRightCount(int count) {
    return 'Right $count';
  }

  @override
  String wrWrongCount(int count) {
    return 'Wrong $count';
  }

  @override
  String get ntFieldMulti => 'Several fields in one cell';

  @override
  String get ntFieldMultiPick => 'Several fields in one cell…';

  @override
  String ntMultiOf(String parts) {
    return 'Combined: $parts';
  }

  @override
  String get ntPartSkip => 'Skip';

  @override
  String get ntSepAuto => 'Automatic (／ or / when present, else spaces)';

  @override
  String get ntSepSpace => 'Spaces';

  @override
  String ntSepChar(String sep) {
    return '\"$sep\"';
  }

  @override
  String get ntSeparator => 'Separator';

  @override
  String ntPartsTitle(String header) {
    return 'How \"$header\" splits';
  }

  @override
  String get ntPartsHint =>
      'Tap the fields this cell holds, left to right. The last one takes whatever is left, so a 品番 with a space stays whole.';

  @override
  String get ntPartsEmpty => 'None chosen yet';

  @override
  String get ntPartsAdd => 'Add a field';

  @override
  String get ntFlagTotalMismatch =>
      'The lines do not add up to the document’s total';

  @override
  String get ntReadPdfText => 'Read from the PDF’s own text';

  @override
  String get ntNotesTitle => 'Reading notes (for the AI)';

  @override
  String get ntNotesHint =>
      'Written here, it is given to the AI with every PDF or photo from this company';

  @override
  String get ntNotesExample =>
      'e.g. The JAN is in the 備考 column. Skip the codes like 9A or 8E before the 品番.';

  @override
  String get ntNotesSaved => 'Reading notes saved';

  @override
  String totalsOk(String sum) {
    return 'The lines come to $sum, as the document says';
  }

  @override
  String totalsMismatch(String sum, String expected) {
    return 'The lines come to $sum but the document says $expected; a quantity or price may be misread';
  }

  @override
  String totalsNotFound(String sum) {
    return 'The lines come to $sum, which matches none of the document’s totals';
  }

  @override
  String get totalsReport => 'Report';

  @override
  String get wtSection => 'Weight';

  @override
  String get wtAdd => 'Enter weight';

  @override
  String get wtEdit => 'Change weight';

  @override
  String get wtNone => 'No weight yet; it is left out of shipping weights';

  @override
  String wtPerUnit(String weight, String unit) {
    return '$weight per $unit';
  }

  @override
  String wtGramsLabel(String unit) {
    return 'Weight of $unit';
  }

  @override
  String get wtSourceManual => 'Entered';

  @override
  String get wtSourceMeasured => 'Weighed here';

  @override
  String get wtSourceWeb => 'From the web';

  @override
  String get wtUrl => 'Page it came from (optional)';

  @override
  String get wtNote => 'Note (optional)';

  @override
  String get wtClear => 'Clear weight';

  @override
  String get wtInvalid => 'Enter a weight of 0 or more';

  @override
  String get wtPackEdit => 'Change pack and weight';

  @override
  String get wtPackageLabel => 'Weight of the empty box or case (optional)';

  @override
  String get wtPackageHint => 'Added to the pieces (count × unit weight)';

  @override
  String get wtGrossLabel => 'One whole pack, weighed (optional)';

  @override
  String get wtGrossHint => 'When given, it wins over the calculation';

  @override
  String get wtPackNoUnitWeight =>
      'This product has no unit weight yet, so a pack weighs nothing unless weighed whole';

  @override
  String get swSection => 'Expected shipping weight';

  @override
  String get swGoods => 'Goods';

  @override
  String swGoodsLine(String weight) {
    return '$weight of goods';
  }

  @override
  String swBoxes(int count) {
    return '$count boxes';
  }

  @override
  String get swMaterial => 'Packing material';

  @override
  String get swTotal => 'Total (expected)';

  @override
  String get swMeasured => 'Weighed';

  @override
  String swMissing(int count) {
    return '$count products have no weight and are left out';
  }

  @override
  String get swNoPlan => 'No boxes planned yet';

  @override
  String get swPlanned => 'Boxes planned';

  @override
  String swSuggest(String list) {
    return 'By weight: $list';
  }

  @override
  String swSuggestOne(int count) {
    return 'By weight: $count';
  }

  @override
  String swCarton(int no, String type) {
    return 'Box $no $type';
  }

  @override
  String get swNoType => '(no type)';

  @override
  String swEmpty(String weight) {
    return 'box $weight';
  }

  @override
  String swMaterialOf(String weight) {
    return 'packing $weight';
  }

  @override
  String swEstimate(String weight) {
    return 'about $weight';
  }

  @override
  String get swSetBox => 'Box type and weight';

  @override
  String get swPlanAction => 'Plan boxes';

  @override
  String get swBoxType => 'Box type';

  @override
  String get ctTitle => 'Box types';

  @override
  String get ctAdd => 'Add a box';

  @override
  String get ctEdit => 'Change box';

  @override
  String get ctHint =>
      'The boxes you ship in. Expected weights use these figures. Turn off \"In use\" for a box you no longer use; past shipments still name it.';

  @override
  String get ctName => 'Name (e.g. 100 size)';

  @override
  String get ctLength => 'Length';

  @override
  String get ctWidth => 'Width';

  @override
  String get ctHeight => 'Height';

  @override
  String get ctEmptyWeight => 'Empty box weight';

  @override
  String get ctMaterial => 'Packing material weight';

  @override
  String get ctMaxLoad => 'Most a box takes';

  @override
  String ctMaxLoadOf(String kg) {
    return 'up to $kg kg';
  }

  @override
  String get ctDefault => 'Usual box';

  @override
  String get ctActive => 'In use';

  @override
  String get ctInactive => 'Retired';

  @override
  String get ctSaved => 'Box saved';

  @override
  String get groupProducts => 'Products';

  @override
  String get planMenu => 'More';

  @override
  String get planDelete => 'Delete this plan';

  @override
  String planDeleteQ(String number) {
    return 'Delete \"$number\"?';
  }

  @override
  String get planDeleteBody =>
      'Its lines go with it. Upload it again with Import plan when it is needed. A plan with a recorded receipt cannot be deleted.';

  @override
  String planDeleted(String number) {
    return 'Deleted \"$number\"';
  }

  @override
  String get productsListView => 'List';

  @override
  String get productsPhotoView => 'Photos';

  @override
  String get productNameEnTitle => 'English name';

  @override
  String get productNameEnAdd => 'Add English name';

  @override
  String get productNameEnLabel =>
      'English name (shown on English and Chinese screens)';

  @override
  String get uomPcs => 'pc';

  @override
  String get uomSet => 'set';

  @override
  String get uomPack => 'pack';

  @override
  String get uomBox => 'box';

  @override
  String get uomCase => 'case';

  @override
  String get uomBag => 'bag';

  @override
  String get uomRoll => 'roll';

  @override
  String get uomSheet => 'sheet';

  @override
  String get uomDozen => 'dozen';

  @override
  String get uomPallet => 'pallet';

  @override
  String get productNamesTitle => 'Names by language';

  @override
  String get productNamesJa => 'Japanese (product name)';

  @override
  String get productNamesJaHint =>
      'The Japanese name is built in our name format; change it with \"Build the name\"';

  @override
  String get productNamesEn =>
      'English (shown on English screens, and when there is no Chinese name)';

  @override
  String get productNamesZh =>
      'Chinese (shown on Chinese screens and on prints in Chinese)';

  @override
  String get featPrintLanguage => 'Print languages';

  @override
  String get featPrintLanguageDesc =>
      'Which languages delivery notes, packing lists and carton labels print in, and their words';

  @override
  String get plLanguagesTitle => 'Languages to print';

  @override
  String get plLanguagesHint =>
      'In the order you tap them. The first prints large and the rest smaller beneath it. Product names print in the same order where the product has a name in that language.';

  @override
  String plPreview(String sample) {
    return 'e.g. $sample';
  }

  @override
  String get plSaved => 'Saved';

  @override
  String get plWordsTitle => 'Words on documents and labels';

  @override
  String get plWordsHint =>
      'Tap a word to change its Japanese, English and Chinese.';

  @override
  String get plWordNeedsAll => 'Fill in all three languages';

  @override
  String get productMenu => 'Actions';

  @override
  String get productActivate => 'Activate';

  @override
  String get productAddOne => 'Add a product';

  @override
  String get productDeleteQ => 'Delete this product?';

  @override
  String productDeleteBody(String name, String jan) {
    return '$name (JAN $jan) will be deleted. This cannot be undone. A product used in stock or a transaction cannot be deleted; deactivate it instead.';
  }

  @override
  String get productDeleteAction => 'Delete';

  @override
  String productDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get productDeleteInUseTitle => 'This product cannot be deleted';

  @override
  String get productDeleteInUse =>
      'It is used by stock, an order, a receipt, a shipment or an invoice. Deactivate it instead, so its history stays readable.';

  @override
  String get productDeleteNotReady =>
      'Deleting is not set up in the database yet (delete_product in 0119). Ask an administrator to apply it.';

  @override
  String get quoteImportTitle => 'Register from a file';

  @override
  String get quoteImportIntro =>
      'The AI reads any file listing products (Excel, PDF or a photo): a quotation, an invoice, a delivery note or our own catalogue. It sorts each line into maker, name, item code, JAN, spec and prices. Products we do not have yet can be registered in our format. Choosing the supplier is optional: the company named on the file is looked for.';

  @override
  String get quoteSupplier => 'Supplier';

  @override
  String get quoteChooseSupplier => 'Choose the supplier first';

  @override
  String get quoteChooseFile => 'Choose the quotation file';

  @override
  String get quoteRead => 'Read with AI';

  @override
  String get quoteReading => 'Reading. A PDF or photo can take about a minute.';

  @override
  String get quoteNothingRead =>
      'No product lines could be read. Check that the table has headings (JAN, name, price…).';

  @override
  String get quoteUnverified =>
      'The AI\'s two readings disagreed in places; check the figures';

  @override
  String quoteSummary(int total, int known, int fresh, int noJan) {
    return '$total lines: $known known, $fresh new, $noJan without a JAN';
  }

  @override
  String quoteRegister(int count) {
    return 'Register new products ($count)';
  }

  @override
  String quoteSave(int count) {
    return 'Save prices ($count)';
  }

  @override
  String quoteSaved(int prices, int products) {
    return 'Saved $prices prices ($products products)';
  }

  @override
  String get quoteLineKnown => 'Known';

  @override
  String get quoteLineRegistered => 'Registered now';

  @override
  String get quoteLineNew => 'New';

  @override
  String get quoteLineNoJan => 'No JAN';

  @override
  String quoteTheirName(String name) {
    return 'Their name: $name';
  }

  @override
  String quoteUnitPrice(String price) {
    return 'Unit $price';
  }

  @override
  String quoteListPrice(String price) {
    return 'List $price';
  }

  @override
  String quoteRate(String rate) {
    return 'Rate $rate';
  }

  @override
  String quoteCase(String count) {
    return 'Case $count';
  }

  @override
  String get lifecycleActive => 'Active';

  @override
  String get lifecycleDormant => 'Dormant';

  @override
  String get lifecycleDiscontinued => 'Discontinued';

  @override
  String get lifecycleArchived => 'Archived';

  @override
  String get lifecycleToActive => 'Make active';

  @override
  String get lifecycleToDormant => 'Make dormant';

  @override
  String get lifecycleToDiscontinued => 'Discontinue';

  @override
  String get lifecycleToArchived => 'Archive';

  @override
  String get lcSelect => 'Choose and change';

  @override
  String lcSelected(int count) {
    return '$count chosen';
  }

  @override
  String lcSelectAll(int count) {
    return 'Choose all shown ($count)';
  }

  @override
  String get lcClear => 'Clear';

  @override
  String get lcChange => 'Change state';

  @override
  String get lcHint =>
      'Tap a product to choose or exclude it. Narrow the list with the filters first to choose all of them at once.';

  @override
  String lcConfirm(int count, String state) {
    return 'Make $count products \"$state\"?';
  }

  @override
  String get lcActiveBody =>
      'They can be chosen again for receiving, shipping and orders.';

  @override
  String get lcDormantBody =>
      'Not handled for now: they cannot be chosen for receiving or shipping, and can be made active again at any time.';

  @override
  String get lcDiscontinuedBody =>
      'Ended by the maker or by us: they cannot be chosen for receiving or shipping. Their history and stock records stay.';

  @override
  String get lcArchivedBody =>
      'Kept out of the everyday list. Its data, history and stock records all stay, and it can be made active again at any time (choose \"Archived\" in the state filter to see it).';

  @override
  String get lcReason => 'Reason (optional), e.g. ended by the maker';

  @override
  String lcDone(int count, String state) {
    return '$count products are now \"$state\"';
  }

  @override
  String get pfLifecycle => 'State';

  @override
  String get pfMaker => 'Maker';

  @override
  String get pfSupplier => 'Supplier';

  @override
  String get pfCategory => 'Category';

  @override
  String get pfStock => 'Stock';

  @override
  String get pfStockAll => 'All';

  @override
  String get pfStockIn => 'In stock';

  @override
  String get pfStockOut => 'Out of stock';

  @override
  String get pfClear => 'Clear filters';

  @override
  String pfShowing(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get pfNoneMatch =>
      'No product matches the filters. Change them or clear them.';

  @override
  String get stockNone => 'No stock';

  @override
  String stockLine(int onHand) {
    return 'Stock $onHand';
  }

  @override
  String stockLineReserved(int onHand, int reserved, int available) {
    return 'Stock $onHand, reserved $reserved, available $available';
  }

  @override
  String get stockTitle => 'Stock by warehouse';

  @override
  String stockWarehouseRow(int onHand, int reserved, int available) {
    return 'On hand $onHand, reserved $reserved, available $available';
  }

  @override
  String get pdBasics => 'Details';

  @override
  String get pdMaker => 'Maker';

  @override
  String get pdBaseName => 'Product name';

  @override
  String get pdCode => 'Item code';

  @override
  String get pdJan => 'JAN';

  @override
  String get pdCategory => 'Category';

  @override
  String get pdUnit => 'Unit';

  @override
  String get pdListPrice => 'List price';

  @override
  String get pdPrice => 'Price';

  @override
  String get pdSuppliers => 'Suppliers';

  @override
  String get pdSpec => 'Spec';

  @override
  String get quoteSupplierOptional => 'Supplier (optional)';

  @override
  String get quoteSupplierNone => 'None (look on the file)';

  @override
  String get quoteSupplierHint =>
      'Choosing one reads the file in its way of writing, and lets its prices be saved';

  @override
  String get quoteSupplierDetected =>
      'Found from the company named on the file';

  @override
  String get quoteSaveNeedsSupplier =>
      'Choose the supplier to save prices (not needed to register products)';

  @override
  String get quoteOurProduct => 'Our product';

  @override
  String get quoteTheirCode => 'Their code';

  @override
  String get quoteCaseLabel => 'Case';

  @override
  String get quoteUnitPriceLabel => 'Unit price';

  @override
  String get quoteRateLabel => 'Rate';

  @override
  String get quoteLineArchived => 'Archived';

  @override
  String get quoteLineDormant => 'Dormant';

  @override
  String get quoteLineDiscontinued => 'Discontinued';

  @override
  String quoteInactiveNote(int count) {
    return '$count are registered but not active (archived, dormant or discontinued), so the library\'s list does not show them.';
  }

  @override
  String quoteRestore(int count) {
    return 'Make active ($count)';
  }

  @override
  String quoteRestored(int count) {
    return '$count made active';
  }

  @override
  String get pfNoneMatchTitle => 'No product matches the filters';

  @override
  String pfHiddenByState(String states) {
    return 'Some products are hidden by the state filter: $states';
  }

  @override
  String pfShowState(String state, int count) {
    return 'Show $count $state';
  }

  @override
  String get pfShowEverything => 'Show every product';

  @override
  String get quoteWakePolicy =>
      'Products on a file are taken to be ones we mean to handle, so by state: dormant → made active; archived → made active (administrator only); discontinued → left as it is (ended by the maker; tick its line to bring it back). Each line\'s tick changes it. Stock comes from receiving and does not change here.';

  @override
  String quoteWakeCount(int wake, int keep) {
    return 'Make active: $wake, leave as is: $keep';
  }

  @override
  String get quoteWakeLine => 'Make this product active';

  @override
  String get quoteWakeDiscontinued =>
      'This product is discontinued (e.g. ended by the maker). Tick to handle it again';

  @override
  String get quoteWakeNeedsAdmin =>
      'Bringing back archived or discontinued products needs the administrator';

  @override
  String quoteSaveAndWake(int count, int wake) {
    return 'Save prices ($count) and make active ($wake)';
  }

  @override
  String quoteRestoredSome(int changed, int skipped) {
    return '$changed made active ($skipped left: not permitted)';
  }

  @override
  String supTitle(int count) {
    return 'Suppliers ($count)';
  }

  @override
  String supCount(int count) {
    return '$count suppliers';
  }

  @override
  String supMore(int count) {
    return '+$count more';
  }

  @override
  String get supCheapest => 'Cheapest';

  @override
  String get supPrimary => 'Main';

  @override
  String supTheirName(String name) {
    return 'Their name: $name';
  }

  @override
  String supTheirCode(String code) {
    return 'Their code: $code';
  }

  @override
  String supUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get supNoPrice => 'No price yet';

  @override
  String get pdTabOurs => 'Ours';

  @override
  String pdSupplierTerms(String name) {
    return 'Terms with $name';
  }

  @override
  String get pdProductId => 'Product ID';

  @override
  String get featPriceBook => 'Price book';

  @override
  String get featPriceBookDesc =>
      'Each supplier\'s names, prices and rates for products, by branch and period — read from files and kept apart from the master';

  @override
  String get clTitle => 'Price book';

  @override
  String get clSearchHint =>
      'Search by name, maker, item code, JAN or a supplier\'s writing';

  @override
  String get clEmpty => 'The price book is empty';

  @override
  String get clEmptyBody =>
      'Use \"Import from a file\" to read a quotation, invoice or catalogue.';

  @override
  String get clInMaster => 'In the master';

  @override
  String get clNotInMaster => 'Not in the master';

  @override
  String get clToMaster => 'Add to the master';

  @override
  String clToMasterDone(int created, int linked, int skipped) {
    return 'Added to the master: $created new, $linked linked to existing, $skipped skipped (no JAN or maker)';
  }

  @override
  String get clDelete => 'Delete from the price book';

  @override
  String clDeleteQ(int count) {
    return 'Delete $count from the price book?';
  }

  @override
  String get clDeleteBody =>
      'The price book items and their price history by supplier are deleted, for good. The product master, stock, orders and receipts are not touched.';

  @override
  String clDeleted(int count) {
    return '$count deleted from the price book';
  }

  @override
  String get ciTitle => 'Import from a file';

  @override
  String get ciIntro =>
      'The AI reads a quotation, invoice, delivery note or catalogue (Excel, PDF or a photo), sorts each line into maker, name, item code, JAN, spec and prices, and puts it into the price book. An item with the same JAN is updated. The master and stock are not touched.';

  @override
  String get ciTermsFor => 'Prices (optional)';

  @override
  String get ciBranch => 'Supplier branch';

  @override
  String get ciBranchHint => 'e.g. Osaka branch (blank: all branches)';

  @override
  String ciValidFrom(String date) {
    return 'From $date';
  }

  @override
  String ciSummary(int total, int fresh, int known) {
    return '$total lines: $fresh new, $known updating items in the price book';
  }

  @override
  String get ciNoSupplierNote =>
      'Without a supplier only the products go in; their prices are not kept.';

  @override
  String ciImport(int count) {
    return 'Import into the price book ($count)';
  }

  @override
  String ciDone(int created, int updated, int terms) {
    return 'Imported: $created new, $updated updated, $terms prices';
  }

  @override
  String get ciLineNew => 'New';

  @override
  String get ciLineUpdate => 'Update';

  @override
  String get citOverview => 'Overview';

  @override
  String get citSourceFile => 'From file';

  @override
  String get citMaster => 'Master and stock';

  @override
  String get citFoundByJan =>
      'A master product with the same JAN (not linked yet)';

  @override
  String get citOpenMaster => 'Open in the master';

  @override
  String get citNotInMaster =>
      'Not in the master yet. Choose it in the list and add it to the master to use it for stock and orders.';

  @override
  String get citCurrentTerms => 'Current terms (by supplier and branch)';

  @override
  String get citNoTerms => 'No prices yet';

  @override
  String get citAddTerm => 'Add terms';

  @override
  String get citNewTerm => 'New terms';

  @override
  String get citAddBranch => 'Add terms for another branch';

  @override
  String get citAllBranches => 'All branches';

  @override
  String citSupplierHint(String name) {
    return 'The history of terms with $name. New terms end the earlier ones the day before, which stay here.';
  }

  @override
  String citFrom(String date) {
    return '$date –';
  }

  @override
  String citPeriod(String from, String to) {
    return '$from – $to';
  }

  @override
  String get citPast => 'Ended';

  @override
  String get citValidFromField => 'From (YYYY-MM-DD)';

  @override
  String get citRateField => 'Rate (60 or 0.6)';

  @override
  String get citTheirName => 'Their name';

  @override
  String get clOpenPriceBook => 'Open the price book';

  @override
  String get specSizeWeight => 'Size and weight';

  @override
  String get specWeight => 'Weight';

  @override
  String get specSize => 'Size';

  @override
  String specSizeValue(String w, String d, String h) {
    return 'W $w × D $d × H $h mm';
  }

  @override
  String get specNotEntered => 'Not entered';

  @override
  String get specSizeAdd => 'Enter the size';

  @override
  String get specSizeEdit => 'Change the size';

  @override
  String get specWidth => 'Width';

  @override
  String get specDepth => 'Depth';

  @override
  String get specHeight => 'Height';

  @override
  String get specSizeNote => 'Other notation (A4, φ10×140mm … optional)';

  @override
  String get specSizeHint =>
      'The product\'s own outer size, not its box, in millimetres.';

  @override
  String get specSizeInvalid => 'Enter the size as numbers of 0 or more';

  @override
  String get specSizeClear => 'Clear the size';

  @override
  String get specSourceFile => 'From a file';

  @override
  String get specWeightField => 'Weight (g)';

  @override
  String get clFromMaster => 'Bring in from the master';

  @override
  String get cfmTitle => 'Bring in from the master';

  @override
  String get cfmIntro =>
      'Master products not in the price book yet. The ones you choose are copied into the price book with their spec, pictures and each supplier\'s name and terms. The master is not changed, and the copy stays even if the master product is later removed.';

  @override
  String get cfmEmpty => 'Nothing to bring in';

  @override
  String get cfmEmptyBody =>
      'Every master product is already in the price book.';

  @override
  String cfmSelectAll(int count) {
    return 'Choose all ($count)';
  }

  @override
  String cfmImport(int count) {
    return 'Bring in $count';
  }

  @override
  String cfmDone(int created, int terms) {
    return '$created brought into the price book ($terms supplier terms)';
  }

  @override
  String cfmSuppliers(int count) {
    return '$count suppliers';
  }

  @override
  String get citEdit => 'Edit the item';

  @override
  String get citNameField => 'Name (as shown)';

  @override
  String get citSaved => 'Saved';

  @override
  String get citSpecFromPriceBook =>
      'The size, weight and pictures here are the price book\'s own record; changing the master does not change them.';

  @override
  String get citHowTheyCall => 'How this supplier calls it, and its terms now';

  @override
  String get citRateLabel => 'Rate';

  @override
  String get citTheirCodeLabel => 'Their item code';

  @override
  String get citWhere => 'Branch';

  @override
  String get citNoNaming => 'No name from this supplier yet';

  @override
  String get rmAction => 'Remove for good';

  @override
  String rmQ(int count) {
    return 'Remove $count from the master for good?';
  }

  @override
  String get rmBody =>
      'They leave the master for good, with their names, codes, units and picture records.\nProducts with stock, receipts, shipments or orders are not removed and stay as they are.\nThe price book keeps its items: only the link goes, and comes back by JAN if the product is added again.';

  @override
  String get rmConfirmLabel => 'Type 削除 to confirm';

  @override
  String get rmConfirmWord => '削除';

  @override
  String rmDone(int removed) {
    return '$removed removed for good';
  }

  @override
  String rmDoneInUse(int removed, int inUse) {
    return '$removed removed for good. $inUse have stock, receipt or shipment records and were kept (they can stay archived)';
  }

  @override
  String get ciTitleMaster => 'Register products from a file';

  @override
  String get ciIntroMaster =>
      'The AI reads a quotation, invoice, delivery note or catalogue (Excel, PDF or a photo), sorts each line into maker, name, item code and JAN, and registers it in the product master. A product whose JAN is already in the master is linked rather than made again. What was read — each supplier\'s names and prices — is also kept in the price book.';

  @override
  String get ciToMaster =>
      'Also register in the product master (to use for stock, receipts and shipments)';

  @override
  String get ciToMasterHint =>
      'Off: only the price book is updated; the master is not changed.';

  @override
  String ciMasterBlocked(int count) {
    return '$count lines have no JAN or maker, so they go into the price book only, not the master.';
  }

  @override
  String get ciLineNoMaster => 'Not for the master (no JAN or maker)';

  @override
  String ciImportMaster(int count) {
    return 'Import and register in the master ($count)';
  }

  @override
  String ciDoneMaster(int created, int linked, int skipped) {
    return 'Registered in the master: $created new, $linked linked to existing products, $skipped not registered (no JAN or maker). All lines are kept in the price book.';
  }

  @override
  String get pmImportFile => 'Register from a file';
}
