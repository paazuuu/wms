import 'package:flutter/material.dart';

import '../../admin/presentation/user_management_screen.dart';
import '../../ai_review/presentation/ai_review_list_screen.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../connectors/presentation/connector_list_screen.dart';
import '../../delivery/presentation/delivery_plan_list_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import '../../qc/presentation/inspection_list_screen.dart';
import '../../picking_ops/presentation/pick_list_index_screen.dart';
import '../../partners/presentation/trading_partner_list_screen.dart';
import '../../product/presentation/product_list_screen.dart';
import '../../putaway/presentation/putaway_queue_screen.dart';
import '../../purchasing/presentation/purchase_order_list_screen.dart';
import '../../reports/presentation/report_builder_screen.dart';
import '../../sales/presentation/sales_order_list_screen.dart';
import '../../stock_ops/presentation/stock_adjustment_screen.dart';
import '../../stock_ops/presentation/stock_count_screen.dart';
import '../../transfers/presentation/transfer_list_screen.dart';
import '../../work_orders/presentation/work_order_list_screen.dart';
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
          // Sits directly after 受入/検品 because that is the order the work
          // happens in: stock lands in the warehouse, then someone says which
          // shelf it went to (UI spec §13/§55).
          FeatureEntry(
            id: 'putaway',
            icon: Icons.move_to_inbox_outlined,
            status: FeatureStatus.ready,
            builder: _putaway,
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
          FeatureEntry(
            id: 'purchase_orders',
            icon: Icons.add_shopping_cart_outlined,
            status: FeatureStatus.ready,
            builder: _purchaseOrders,
          ),
          FeatureEntry(
            id: 'sales_orders',
            icon: Icons.point_of_sale_outlined,
            status: FeatureStatus.ready,
            builder: _salesOrders,
          ),
          FeatureEntry(
            id: 'work_orders',
            icon: Icons.precision_manufacturing_outlined,
            status: FeatureStatus.ready,
            builder: _workOrders,
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
          FeatureEntry(
            id: 'ai_review',
            icon: Icons.fact_check_outlined,
            status: FeatureStatus.ready,
            builder: _aiReview,
          ),
          FeatureEntry(
            id: 'products',
            icon: Icons.inventory_2_outlined,
            status: FeatureStatus.ready,
            builder: _products,
          ),
          FeatureEntry(
            id: 'partners',
            icon: Icons.handshake_outlined,
            status: FeatureStatus.ready,
            builder: _partners,
          ),
          FeatureEntry(
            id: 'reports',
            icon: Icons.table_chart_outlined,
            status: FeatureStatus.ready,
            builder: _reports,
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

/// Top-level (const-referenceable) builder for the AI Review feature.
Widget _aiReview(BuildContext _) => const AiReviewListScreen();

/// Top-level (const-referenceable) builder for the Product Master feature.
Widget _products(BuildContext _) => const ProductListScreen();

/// Top-level (const-referenceable) builder for the Trading Partners feature.
Widget _partners(BuildContext _) => const TradingPartnerListScreen();

/// Top-level (const-referenceable) builder for the Report Builder feature.
Widget _reports(BuildContext _) => const ReportBuilderScreen();

/// Top-level (const-referenceable) builder for the Put-away feature.
Widget _putaway(BuildContext _) => const PutawayQueueScreen();

/// Top-level (const-referenceable) builder for the Picking feature.
Widget _picking(BuildContext _) => const PickListIndexScreen();

/// Top-level (const-referenceable) builder for the Transfer feature.
Widget _transfer(BuildContext _) => const TransferListScreen();

/// Top-level (const-referenceable) builder for the Purchase Orders feature.
Widget _purchaseOrders(BuildContext _) => const PurchaseOrderListScreen();

/// Top-level (const-referenceable) builder for the Sales Orders feature.
Widget _salesOrders(BuildContext _) => const SalesOrderListScreen();

/// Top-level (const-referenceable) builder for the Work Orders feature.
Widget _workOrders(BuildContext _) => const WorkOrderListScreen();
