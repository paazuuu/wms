import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Lifecycle of a feature surfaced on the home menu.
enum FeatureStatus {
  /// Screen is implemented and navigable.
  ready,

  /// Backend API exists but the mobile screen is not built yet.
  comingSoon,
}

/// A single warehouse capability shown on the home dashboard.
///
/// Each entry maps 1:1 to an InventorOS backend capability. Label and
/// description are resolved from [AppLocalizations] by [id] so the whole menu
/// localizes with the app language.
@immutable
class FeatureEntry {
  const FeatureEntry({
    required this.id,
    required this.icon,
    this.status = FeatureStatus.comingSoon,
    this.builder,
  });

  final String id;
  final IconData icon;
  final FeatureStatus status;

  /// Navigation target when the feature is [FeatureStatus.ready].
  final WidgetBuilder? builder;

  bool get isReady => status == FeatureStatus.ready && builder != null;

  /// Localized menu label for this feature.
  String label(AppLocalizations l10n) {
    switch (id) {
      case 'inspection':
        return l10n.featInspection;
      case 'receiving':
        return l10n.featReceiving;
      case 'delivery':
        return l10n.featDelivery;
      case 'shipment':
        return l10n.featShipment;
      case 'stock_adjustment':
        return l10n.featStockAdjustment;
      case 'stock_count':
        return l10n.featStockCount;
      case 'picking':
        return l10n.featPicking;
      case 'product_lookup':
        return l10n.featProductLookup;
      case 'locations':
        return l10n.featLocations;
      case 'lots_serials':
        return l10n.featLotsSerials;
      case 'purchase_orders':
        return l10n.featPurchaseOrders;
      case 'sales_orders':
        return l10n.featSalesOrders;
      case 'suppliers':
        return l10n.featSuppliers;
      case 'warehouses':
        return l10n.featWarehouses;
      case 'work_orders':
        return l10n.featWorkOrders;
      case 'reports':
        return l10n.featReports;
      default:
        return id;
    }
  }

  /// Localized one-line description for this feature.
  String description(AppLocalizations l10n) {
    switch (id) {
      case 'inspection':
        return l10n.featInspectionDesc;
      case 'receiving':
        return l10n.featReceivingDesc;
      case 'delivery':
        return l10n.featDeliveryDesc;
      case 'shipment':
        return l10n.featShipmentDesc;
      case 'stock_adjustment':
        return l10n.featStockAdjustmentDesc;
      case 'stock_count':
        return l10n.featStockCountDesc;
      case 'picking':
        return l10n.featPickingDesc;
      case 'product_lookup':
        return l10n.featProductLookupDesc;
      case 'locations':
        return l10n.featLocationsDesc;
      case 'lots_serials':
        return l10n.featLotsSerialsDesc;
      case 'purchase_orders':
        return l10n.featPurchaseOrdersDesc;
      case 'sales_orders':
        return l10n.featSalesOrdersDesc;
      case 'suppliers':
        return l10n.featSuppliersDesc;
      case 'warehouses':
        return l10n.featWarehousesDesc;
      case 'work_orders':
        return l10n.featWorkOrdersDesc;
      case 'reports':
        return l10n.featReportsDesc;
      default:
        return '';
    }
  }
}

/// A titled cluster of related features (e.g. "Field Operations").
@immutable
class FeatureGroup {
  const FeatureGroup({required this.id, required this.entries});

  final String id;
  final List<FeatureEntry> entries;

  /// Localized group heading.
  String title(AppLocalizations l10n) {
    switch (id) {
      case 'field_operations':
        return l10n.groupFieldOperations;
      case 'lookup':
        return l10n.groupLookup;
      case 'management':
        return l10n.groupManagement;
      default:
        return id;
    }
  }
}
