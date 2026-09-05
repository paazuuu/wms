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
  String get language => 'Language';

  @override
  String get languageTooltip => 'Select language';

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
  String get groupLookup => 'Lookup';

  @override
  String get groupManagement => 'Management';

  @override
  String get featInspection => 'Inspection';

  @override
  String get featInspectionDesc => 'Barcode & quantity checks, NG records';

  @override
  String get featReceiving => 'Receiving';

  @override
  String get featReceivingDesc => 'Receive POs, auto-start inspection';

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
  String get featProductLookup => 'Product Lookup';

  @override
  String get featProductLookupDesc => 'Scan a barcode to view product & stock';

  @override
  String get featLocations => 'Locations';

  @override
  String get featLocationsDesc => 'Bins, zones and transfers';

  @override
  String get featLotsSerials => 'Lots & Serials';

  @override
  String get featLotsSerialsDesc => 'Batch and serial tracking';

  @override
  String get featPurchaseOrders => 'Purchase Orders';

  @override
  String get featPurchaseOrdersDesc => 'Create and manage POs';

  @override
  String get featSalesOrders => 'Sales Orders';

  @override
  String get featSalesOrdersDesc => 'View and edit orders';

  @override
  String get featSuppliers => 'Suppliers';

  @override
  String get featSuppliersDesc => 'Supplier directory';

  @override
  String get featWarehouses => 'Warehouses';

  @override
  String get featWarehousesDesc => 'Warehouse master data';

  @override
  String get featWorkOrders => 'Work Orders';

  @override
  String get featWorkOrdersDesc => 'Assembly & kitting';

  @override
  String get featReports => 'Reports';

  @override
  String get featReportsDesc => 'Saved reports & exports';

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
  String get searching => 'Searching…';

  @override
  String get scanTypeHint => 'Scan or type barcode, SKU, or name';

  @override
  String get scanTypeMessage => 'Scan or type a barcode, SKU, or name.';

  @override
  String noMatchesFor(String query) {
    return 'No matches for \"$query\".';
  }

  @override
  String get tryDifferentScan => 'Try a different barcode, SKU, or name.';

  @override
  String get inStock => 'in stock';

  @override
  String get productLookupEmpty => 'No products yet.';

  @override
  String get findProductToAdjust => 'Find a product to adjust.';

  @override
  String get findProductToTrace => 'Find a product to trace.';

  @override
  String get loading => 'Loading…';

  @override
  String get emptyLocations => 'No locations yet.';

  @override
  String get emptyWarehouses => 'No warehouses yet.';

  @override
  String get emptySuppliers => 'No suppliers yet.';

  @override
  String get emptySalesOrders => 'No sales orders yet.';

  @override
  String get emptyPurchaseOrders => 'No purchase orders yet.';

  @override
  String get emptyWorkOrders => 'No work orders yet.';

  @override
  String get tryDifferentNameCode => 'Try a different name or code.';

  @override
  String get tryDifferentOrder => 'Try a different order number or customer.';

  @override
  String get tryDifferentPo => 'Try a different PO number or supplier.';

  @override
  String get tryDifferentWo => 'Try a different WO number, product, or SKU.';

  @override
  String get hintLocations => 'Scan or search by name or code';

  @override
  String get hintWarehouses => 'Scan or search by name, code or city';

  @override
  String get hintSuppliers => 'Scan or search by name, code, contact or email';

  @override
  String get hintSalesOrders => 'Scan or search by order #, customer or email';

  @override
  String get hintPurchaseOrders => 'Scan or search by PO number or supplier';

  @override
  String get hintWorkOrders => 'Scan or search by WO number, product, or SKU';

  @override
  String get warehouseDefault => 'Default';

  @override
  String get noCustomer => 'No customer';

  @override
  String get noSupplier => 'No supplier';

  @override
  String get noProduct => 'No product';

  @override
  String qtyLabel(int quantity) {
    return 'Qty $quantity';
  }

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
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusPending => 'Pending';

  @override
  String get salesProcessing => 'Processing';

  @override
  String get salesShipped => 'Shipped';

  @override
  String get salesDelivered => 'Delivered';

  @override
  String get poSent => 'Sent';

  @override
  String get poPartiallyReceived => 'Partially received';

  @override
  String get poReceived => 'Received';

  @override
  String get stockIn => 'In stock';

  @override
  String get stockLow => 'Low stock';

  @override
  String get stockOut => 'Out of stock';

  @override
  String get inspectionPassed => 'Passed';

  @override
  String get inspectionFailed => 'Failed';

  @override
  String get matchOk => 'OK';

  @override
  String get matchNg => 'NG';

  @override
  String get typeReceiving => 'Receiving';

  @override
  String get typeShipping => 'Shipping';

  @override
  String get typeOther => 'Other';

  @override
  String get titleProduct => 'Product';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldStatus => 'Status';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldBarcode => 'Barcode';

  @override
  String get fieldSku => 'SKU';

  @override
  String get fieldPrice => 'Price';

  @override
  String get fieldSellingPrice => 'Selling price';

  @override
  String get fieldMinStock => 'Min stock';

  @override
  String get fieldOnHand => 'On hand';

  @override
  String get fieldLocation => 'Location';

  @override
  String get fieldHasVariants => 'Has variants';

  @override
  String get fieldManager => 'Manager';

  @override
  String get fieldTimezone => 'Timezone';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldUsers => 'Users';

  @override
  String get fieldLocations => 'Locations';

  @override
  String get fieldContact => 'Contact';

  @override
  String get fieldWebsite => 'Website';

  @override
  String get fieldPaymentTerms => 'Payment terms';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldProducts => 'Products';

  @override
  String get fieldAisle => 'Aisle';

  @override
  String get fieldShelf => 'Shelf';

  @override
  String get fieldBin => 'Bin';

  @override
  String get fieldCode => 'Code';

  @override
  String get fieldFullLocation => 'Full location';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String productCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '$count product',
    );
    return '$_temp0';
  }

  @override
  String binCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bins',
      one: '$count bin',
    );
    return '$_temp0';
  }

  @override
  String get fieldCustomer => 'Customer';

  @override
  String get lineItems => 'Line items';

  @override
  String get noLineItems => 'No line items.';

  @override
  String get fieldOrderDate => 'Order date';

  @override
  String get fieldSubtotal => 'Subtotal';

  @override
  String get fieldTax => 'Tax';

  @override
  String get fieldShipping => 'Shipping';

  @override
  String get fieldTotal => 'Total';

  @override
  String get fieldSupplier => 'Supplier';

  @override
  String get fieldExpected => 'Expected';

  @override
  String get fieldOrdered => 'Ordered';

  @override
  String get fieldReceived => 'Received';

  @override
  String get fieldRemaining => 'Remaining';

  @override
  String get actionComplete => 'Complete';

  @override
  String get actionContinue => 'Continue';

  @override
  String get fieldAssemblyProduct => 'Assembly product';

  @override
  String get fieldComponents => 'Components';

  @override
  String get noComponents => 'No components.';

  @override
  String get fieldConsumed => 'Consumed';

  @override
  String get fieldProduced => 'Produced';

  @override
  String get fieldRequired => 'Required';

  @override
  String get fieldTarget => 'Target';

  @override
  String get fieldStarted => 'Started';

  @override
  String productNumber(int id) {
    return 'Product #$id';
  }

  @override
  String get fieldCountedLines => 'Counted lines';

  @override
  String get noCountedLines => 'No counted lines.';

  @override
  String get fieldCounted => 'Counted';

  @override
  String get fieldUncounted => 'Uncounted';

  @override
  String get fieldDiscrepancy => 'Discrepancy';

  @override
  String get fieldMatch => 'Match';

  @override
  String get fieldSystem => 'System';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldType => 'Type';

  @override
  String get filterAll => 'All';

  @override
  String remainingLeft(int count) {
    return '$count left';
  }

  @override
  String remainingAmount(String amount) {
    return '$amount left';
  }

  @override
  String get unknownSupplier => 'Unknown supplier';

  @override
  String get receivingEmpty => 'Nothing to receive.';

  @override
  String get receivingEmptyBody =>
      'Purchase orders that are sent or partially received will appear here.';

  @override
  String get receivingDone => 'Nothing left to receive.';

  @override
  String get fieldQtyToReceive => 'Quantity to receive';

  @override
  String get receiveStock => 'Receive stock';

  @override
  String get actionReceive => 'Receive';

  @override
  String get receivingInProgress => 'Receiving…';

  @override
  String get emptyInspections => 'No inspections yet.';

  @override
  String get inspectionsEmptyBody =>
      'Pull down to refresh, or start one from a purchase order receipt.';

  @override
  String get pickingEmpty => 'Nothing to pick.';

  @override
  String get noLinesToPick => 'No lines to pick.';

  @override
  String get orderNoLineItems => 'This order has no line items.';

  @override
  String get unnamedProduct => 'Unnamed product';

  @override
  String get pickListTitle => 'Pick List';

  @override
  String get customReport => 'Custom report';

  @override
  String get emptyReports => 'No saved reports yet.';

  @override
  String get reportsEmptyBody =>
      'Reports saved on the back office appear here.';

  @override
  String get reportShared => 'Shared';

  @override
  String columnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columns',
      one: '$count column',
    );
    return '$_temp0';
  }

  @override
  String get allLocations => 'All locations';

  @override
  String get emptyStockCounts => 'No stock counts yet.';

  @override
  String get pickingEmptyBody =>
      'Open sales orders awaiting fulfilment appear here.';

  @override
  String get stockCountsEmptyBody =>
      'Cycle counts created on the back office appear here.';

  @override
  String get receivingDoneBody =>
      'Every line on this purchase order is fully received.';

  @override
  String receiveInvalidQty(String product) {
    return 'Enter a valid quantity for $product.';
  }

  @override
  String receiveExceedsRemaining(String product, int remaining) {
    return '$product: cannot receive more than $remaining remaining.';
  }

  @override
  String get receiveEnterAtLeastOne =>
      'Enter a quantity on at least one line to receive.';

  @override
  String get receiveSuccess =>
      'Stock received. An inspection was started automatically.';

  @override
  String pickedProgress(int picked, int total) {
    return '$picked / $total picked';
  }

  @override
  String get attachFiles => 'Attach files';

  @override
  String get cameraLabel => 'Camera';

  @override
  String get scanToRecord => 'Scan item barcode to record';

  @override
  String get scanToRecordQty1 => 'Scan to record (qty 1)';

  @override
  String get fastModeOnTooltip => 'Fast mode: records quantity 1 per scan';

  @override
  String get fastModeOffTooltip => 'Prompt for a quantity on each scan';

  @override
  String get fastQtyOneLabel => 'Qty 1';

  @override
  String get actualQuantity => 'Actual quantity';

  @override
  String scannedCode(String code) {
    return 'Scanned: $code';
  }

  @override
  String get quantity => 'Quantity';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRecord => 'Record';

  @override
  String get itemRecorded => 'Item recorded';

  @override
  String get offlineItemQueued => 'Offline — item queued for sync';

  @override
  String filesUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files uploaded',
      one: '$count file uploaded',
    );
    return '$_temp0';
  }

  @override
  String offlineFilesQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return 'Offline — $_temp0 queued for sync';
  }

  @override
  String get completeInspectionQ => 'Complete inspection?';

  @override
  String get completeInspectionBody =>
      'Mark this inspection as complete. You can still view it afterward.';

  @override
  String get inspectionCompleted => 'Inspection completed';

  @override
  String get offlineCompletionQueued => 'Offline — completion queued for sync';

  @override
  String get sectionItems => 'Items';

  @override
  String get sectionAttachments => 'Attachments';

  @override
  String get noItemsYet => 'No items yet. Tap Scan to record one.';

  @override
  String get noAttachments =>
      'No attachments. Use the paperclip to add photos or files.';

  @override
  String get completeInspection => 'Complete inspection';

  @override
  String completedOn(String date) {
    return 'Completed $date';
  }

  @override
  String get actualLabel => 'Actual';

  @override
  String itemNumber(int id) {
    return 'Item $id';
  }

  @override
  String get working => 'Working…';

  @override
  String get adjustAdd => 'Add';

  @override
  String get adjustRemove => 'Remove';

  @override
  String get reasonType => 'Reason type';

  @override
  String get reasonOptional => 'Reason (optional)';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get onHandAfter => 'On hand after';

  @override
  String get saving => 'Saving…';

  @override
  String get addStock => 'Add stock';

  @override
  String get removeStock => 'Remove stock';

  @override
  String onHandCount(int count) {
    return '$count on hand';
  }

  @override
  String get enterQtyPositive => 'Enter a quantity greater than zero.';

  @override
  String cannotRemoveOnly(int qty, int current) {
    return 'Cannot remove $qty; only $current on hand.';
  }

  @override
  String stockUpdatedTo(int count) {
    return 'Stock updated — now $count on hand.';
  }

  @override
  String get adjustTypeManual => 'Manual';

  @override
  String get adjustTypeCount => 'Count';

  @override
  String get adjustTypeDamage => 'Damage';

  @override
  String get adjustTypeReturn => 'Return';

  @override
  String get adjustTypeTransfer => 'Transfer';

  @override
  String get sectionBatches => 'Batches';

  @override
  String get sectionSerials => 'Serials';

  @override
  String get noBatches => 'No batches for this product.';

  @override
  String get noSerials => 'No serials for this product.';

  @override
  String get loadingBatches => 'Loading batches…';

  @override
  String get loadingSerials => 'Loading serials…';

  @override
  String get batchExpired => 'Expired';

  @override
  String get batchValid => 'Valid';

  @override
  String get fieldExpiry => 'Expiry';

  @override
  String get report => 'Report';

  @override
  String get runningReport => 'Running report…';

  @override
  String get noData => 'No data.';

  @override
  String get reportNoRows => 'This report returned no rows.';

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '$count row',
    );
    return '$_temp0';
  }

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
  String get deliveryDateLabel => 'Delivery date';

  @override
  String get scanDeliveryHint => 'Scan the item JAN';

  @override
  String get ocrAssist => 'Scan note (OCR)';

  @override
  String get ocrScanning => 'Reading the note…';

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
  String get diffLabel => 'Diff';

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
  String get noteImageAttached => 'Delivery note attached';

  @override
  String get planImportTitle => 'Import plan';

  @override
  String get planImportHint =>
      'Pick an Excel / PDF / image to upload — it is parsed and registered as a plan automatically.';

  @override
  String get pickFile => 'Choose file';

  @override
  String planImportSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get planImportAction => 'Import';

  @override
  String get planImporting => 'Importing…';

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
  String get fieldDocDate => 'Date';

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
  String get orderDateLabel => 'Order date';

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
  String get shipmentNumberLabel => 'Shipment no.';

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
  String get cartonEmpty => 'Nothing packed in this carton yet.';

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
  String get shipAlreadyDone => 'Already shipped';

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
  String get senderOpenSettings => 'Set up sender';

  @override
  String get senderSaved => 'Sender saved';

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
}
