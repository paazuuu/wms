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
      'Name, category and price against each JAN code';

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
  String get productDeactivateQ => 'Deactivate this product?';

  @override
  String get productDeactivateBody =>
      'Once inactive, it can no longer be selected for receiving, shipping, or other operations.';

  @override
  String get productDeactivateAction => 'Deactivate';

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
  String get heldStockTitle => 'Held for QC';

  @override
  String get heldStockEmpty => 'Nothing is held for QC';

  @override
  String get heldStockEmptyBody =>
      'Goods that need inspecting on arrival wait here until QC releases them. They cannot ship.';

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
}
