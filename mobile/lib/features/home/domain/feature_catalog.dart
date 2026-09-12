import 'package:flutter/material.dart';

import '../../admin/presentation/user_management_screen.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../connectors/presentation/connector_list_screen.dart';
import '../../delivery/presentation/delivery_plan_list_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import '../../qc/presentation/inspection_list_screen.dart';
import '../../picking_ops/presentation/pick_list_index_screen.dart';
import '../../stock_ops/presentation/stock_adjustment_screen.dart';
import '../../stock_ops/presentation/stock_count_screen.dart';
import '../../transfers/presentation/transfer_list_screen.dart';
import 'feature_entry.dart';

/// The app's full feature menu, grouped for the home dashboard.
///
/// This is the single source of truth for navigation: adding a screen means
/// flipping an entry to [FeatureStatus.ready] and pointing [FeatureEntry.builder]
/// at it. Every entry is backed by this app's own Supabase project — the
/// InventorOS-backed screens this catalog used to also list (product lookup,
/// locations, lot/serial tracking, purchase/sales orders, suppliers,
/// warehouse management, work orders, reports, receiving) were removed: that
/// backend was never actually reachable, and building on it was abandoned.
List<FeatureGroup> buildFeatureCatalog() => const [
      FeatureGroup(
        id: 'field_operations',
        entries: [
          FeatureEntry(
            id: 'inspection',
            icon: Icons.fact_check_outlined,
            status: FeatureStatus.ready,
            builder: _inspectionList,
          ),
          FeatureEntry(
            id: 'delivery',
            icon: Icons.rule_folder_outlined,
            status: FeatureStatus.ready,
            builder: _delivery,
          ),
          FeatureEntry(
            id: 'shipment',
            icon: Icons.outbox_outlined,
            status: FeatureStatus.ready,
            builder: _shipment,
          ),
          FeatureEntry(
            id: 'stock_adjustment',
            icon: Icons.tune_outlined,
            status: FeatureStatus.ready,
            builder: _stockAdjustment,
          ),
          FeatureEntry(
            id: 'stock_count',
            icon: Icons.checklist_outlined,
            status: FeatureStatus.ready,
            builder: _stockCount,
          ),
          FeatureEntry(
            id: 'picking',
            icon: Icons.shopping_cart_checkout_outlined,
            status: FeatureStatus.ready,
            builder: _picking,
          ),
          FeatureEntry(
            id: 'transfer',
            icon: Icons.compare_arrows,
            status: FeatureStatus.ready,
            builder: _transfer,
          ),
        ],
      ),
      FeatureGroup(
        id: 'management',
        entries: [
          FeatureEntry(
            id: 'audit_log',
            icon: Icons.history_outlined,
            status: FeatureStatus.ready,
            builder: _auditLog,
          ),
          FeatureEntry(
            id: 'user_management',
            icon: Icons.manage_accounts_outlined,
            status: FeatureStatus.ready,
            builder: _userManagement,
          ),
          FeatureEntry(
            id: 'connectors',
            icon: Icons.hub_outlined,
            status: FeatureStatus.ready,
            builder: _connectors,
          ),
        ],
      ),
    ];

/// Top-level (const-referenceable) builder for the Inspection feature.
/// Points at the Supabase-backed inbound inspection (検品), not the legacy
/// InventorOS screen, so the entry actually works against the live backend.
Widget _inspectionList(BuildContext _) => const QcInspectionListScreen();

/// Top-level (const-referenceable) builder for the Delivery Check feature.
Widget _delivery(BuildContext _) => const DeliveryPlanListScreen();

/// Top-level (const-referenceable) builder for the Shipping (出庫) feature.
Widget _shipment(BuildContext _) => const ShipmentListScreen();

/// Top-level (const-referenceable) builder for the Stock Adjustment feature.
Widget _stockAdjustment(BuildContext _) => const StockAdjustmentScreen();

/// Top-level (const-referenceable) builder for the Stock Count feature.
Widget _stockCount(BuildContext _) => const StockCountScreen();

/// Top-level (const-referenceable) builder for the Audit Log feature.
Widget _auditLog(BuildContext _) => const AuditLogScreen();

/// Top-level (const-referenceable) builder for the User Management feature.
Widget _userManagement(BuildContext _) => const UserManagementScreen();

/// Top-level (const-referenceable) builder for the Connectors feature.
Widget _connectors(BuildContext _) => const ConnectorListScreen();

/// Top-level (const-referenceable) builder for the Picking feature.
Widget _picking(BuildContext _) => const PickListIndexScreen();

/// Top-level (const-referenceable) builder for the Transfer feature.
Widget _transfer(BuildContext _) => const TransferListScreen();
