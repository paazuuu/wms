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
}
