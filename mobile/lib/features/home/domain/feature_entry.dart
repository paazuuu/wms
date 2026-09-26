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
    this.requiredAnyOf = const [],
  });

  final String id;
  final IconData icon;
  final FeatureStatus status;

  /// Navigation target when the feature is [FeatureStatus.ready].
  final WidgetBuilder? builder;

  /// Permission codes gating this entry (UI spec §37): held if the signed-in
  /// user has *any* one of them, matching how the same screen's own actions
  /// are usually a view/manage pair. Empty means every signed-in user may
  /// open it — the menu doesn't hide a screen it never restricted.
  final List<String> requiredAnyOf;

  bool get isReady => status == FeatureStatus.ready && builder != null;

  /// This feature's URL path, derived from [id] so the catalog stays the one
  /// place a feature is declared: adding an entry gives it a route for free,
  /// and an id and its URL can never drift apart. Underscores become hyphens
  /// because `/stock-adjustment` is the conventional shape for a URL segment.
  String get path => '/${id.replaceAll('_', '-')}';

  /// Whether [permissions] unlock this entry. Server-side RLS/RPC checks are
  /// the actual boundary (§37) — this only decides what the menu *offers*, so
  /// tapping a hidden entry was never the only thing standing between an
  /// operator and data they shouldn't see.
  bool visibleFor(Iterable<String> permissions) =>
      requiredAnyOf.isEmpty || requiredAnyOf.any(permissions.contains);

  /// Whether this entry should survive a sidebar filter of [query].
  ///
  /// Matches the label *and* the one-line description, because the
  /// description is where the vocabulary an operator actually thinks in tends
  /// to live: someone hunting for approvals types "approve" and means
  /// purchase and sales orders, whose labels say neither. Substring rather
  /// than fuzzy matching, so the result of a keystroke is always predictable.
  ///
  /// Lower-casing is a no-op for Japanese and Chinese, which is correct —
  /// those labels match on the substring alone.
  bool matchesQuery(AppLocalizations l10n, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label(l10n).toLowerCase().contains(q) ||
        description(l10n).toLowerCase().contains(q);
  }

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
      case 'wave':
        return l10n.featWave;
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
      case 'unlinked_jan':
        return l10n.featUnlinkedJan;
      case 'purchase_orders':
        return l10n.featPurchaseOrders;
      case 'sales_orders':
        return l10n.featSalesOrders;
      case 'demand':
        return l10n.featDemand;
      case 'partners':
        return l10n.featPartners;
      case 'work_orders':
        return l10n.featWorkOrders;
      case 'reports':
        return l10n.featReports;
      case 'putaway':
        return l10n.featPutaway;
      case 'expiring_lots':
        return l10n.featExpiringLots;
      case 'exceptions':
        return l10n.featExceptions;
      case 'held_stock':
        return l10n.featHeldStock;
      case 'reservations':
        return l10n.featReservations;
      case 'stock_reconciliation':
        return l10n.featStockReconciliation;
      case 'locations':
        return l10n.featLocations;
      case 'replenishment':
        return l10n.featReplenishment;
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
      case 'wave':
        return l10n.featWaveDesc;
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
      case 'unlinked_jan':
        return l10n.featUnlinkedJanDesc;
      case 'purchase_orders':
        return l10n.featPurchaseOrdersDesc;
      case 'sales_orders':
        return l10n.featSalesOrdersDesc;
      case 'demand':
        return l10n.featDemandDesc;
      case 'partners':
        return l10n.featPartnersDesc;
      case 'work_orders':
        return l10n.featWorkOrdersDesc;
      case 'reports':
        return l10n.featReportsDesc;
      case 'putaway':
        return l10n.featPutawayDesc;
      case 'expiring_lots':
        return l10n.featExpiringLotsDesc;
      case 'exceptions':
        return l10n.featExceptionsDesc;
      case 'held_stock':
        return l10n.featHeldStockDesc;
      case 'reservations':
        return l10n.featReservationsDesc;
      case 'stock_reconciliation':
        return l10n.featStockReconciliationDesc;
      case 'locations':
        return l10n.featLocationsDesc;
      case 'replenishment':
        return l10n.featReplenishmentDesc;
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

  /// Entries in this group [permissions] unlock. A group that comes back
  /// empty (every entry gated on something this user lacks) is meant to be
  /// dropped entirely by the caller, not shown as an empty heading.
  List<FeatureEntry> visibleEntries(Iterable<String> permissions) =>
      entries.where((e) => e.visibleFor(permissions)).toList();

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
