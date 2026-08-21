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
}
