import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Lifecycle of a feature surfaced on the home menu.
enum FeatureStatus {
  /// Screen is implemented and navigable.
  ready,

  /// Backend API exists but the mobile screen is not built yet.
  comingSoon,
}

/// A single warehouse capability shown on the home dashboard, backed by this
/// app's own Supabase project. Label and description are resolved from
/// [AppLocalizations] by [id] so the whole menu localizes with the app
/// language.
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
      case 'transfer':
        return l10n.featTransfer;
      case 'audit_log':
        return l10n.featAuditLog;
      case 'user_management':
        return l10n.featUserManagement;
      case 'connectors':
        return l10n.featConnectors;
      case 'ai_review':
        return l10n.featAiReview;
      case 'products':
        return l10n.featProducts;
      case 'purchase_orders':
        return l10n.featPurchaseOrders;
      case 'sales_orders':
        return l10n.featSalesOrders;
      case 'partners':
        return l10n.featPartners;
      default:
        return id;
    }
  }

  /// Localized one-line description for this feature.
  String description(AppLocalizations l10n) {
    switch (id) {
      case 'inspection':
        return l10n.featInspectionDesc;
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
      case 'transfer':
        return l10n.featTransferDesc;
      case 'audit_log':
        return l10n.featAuditLogDesc;
      case 'user_management':
        return l10n.featUserManagementDesc;
      case 'connectors':
        return l10n.featConnectorsDesc;
      case 'ai_review':
        return l10n.featAiReviewDesc;
      case 'products':
        return l10n.featProductsDesc;
      case 'purchase_orders':
        return l10n.featPurchaseOrdersDesc;
      case 'sales_orders':
        return l10n.featSalesOrdersDesc;
      case 'partners':
        return l10n.featPartnersDesc;
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
      case 'management':
        return l10n.groupManagement;
      default:
        return id;
    }
  }
}
