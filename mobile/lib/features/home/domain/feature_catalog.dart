import 'package:flutter/material.dart';

import '../../../core/ai/ai_settings_screen.dart';
import '../../admin/presentation/user_management_screen.dart';
import '../../ai_review/presentation/ai_review_list_screen.dart';
import '../../audit/presentation/audit_log_screen.dart';
import '../../connectors/presentation/connector_list_screen.dart';
import '../../delivery/presentation/delivery_plan_list_screen.dart';
import '../../demand/presentation/open_demand_screen.dart';
import '../../documents/presentation/document_exceptions_screen.dart';
import '../../exceptions/presentation/exception_list_screen.dart';
import '../../notation/presentation/notation_training_screen.dart';
import '../../qc/presentation/held_stock_screen.dart';
import '../../inventory/presentation/expiring_lots_screen.dart';
import '../../inventory/presentation/replenishment_screen.dart';
import '../../inventory/presentation/reservations_screen.dart';
import '../../inventory/presentation/stock_reconciliation_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import '../../qc/presentation/bulk_inspection_screen.dart';
import '../../qc/presentation/inspection_list_screen.dart';
import '../../picking_ops/presentation/pick_list_index_screen.dart';
import '../../wave/presentation/pick_wave_list_screen.dart';
import '../../partners/presentation/trading_partner_list_screen.dart';
import '../../product/presentation/product_list_screen.dart';
import '../../product/presentation/unlinked_jan_screen.dart';
import '../../putaway/presentation/putaway_queue_screen.dart';
import '../../purchasing/presentation/purchase_order_list_screen.dart';
import '../../warehouse_context/presentation/location_tree_screen.dart';
import '../../reports/presentation/report_builder_screen.dart';
import '../../sales/presentation/sales_order_list_screen.dart';
import '../../supply_chain/presentation/sc_bottleneck_screen.dart';
import '../../supply_chain/presentation/sc_cost_structure_screen.dart';
import '../../supply_chain/presentation/sc_dashboard_screen.dart';
import '../../supply_chain/presentation/sc_history_screen.dart';
import '../../supply_chain/presentation/sc_risk_screen.dart';
import '../../supply_chain/presentation/sc_routes_screen.dart';
import '../../supply_chain/presentation/sc_simulation_screen.dart';
import '../../supply_chain/presentation/sc_supplier_comparison_screen.dart';
import '../../stock_ops/presentation/stock_adjustment_screen.dart';
import '../../stock_ops/presentation/stock_count_screen.dart';
import '../../transfers/presentation/transfer_list_screen.dart';
import '../../virtual_stock/presentation/virtual_stock_screen.dart';
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
            requiredAnyOf: ['inspection.view', 'inspection.confirm'],
          ),
          // Most deliveries are fine: settle them as good in one go (0099).
          FeatureEntry(
            id: 'bulk_inspection',
            icon: Icons.done_all,
            status: FeatureStatus.ready,
            builder: _bulkInspection,
            requiredAnyOf: ['inspection.confirm'],
          ),
          FeatureEntry(
            id: 'delivery',
            icon: Icons.rule_folder_outlined,
            status: FeatureStatus.ready,
            builder: _delivery,
            requiredAnyOf: ['receiving.view', 'receiving.confirm'],
          ),
          // Sits directly after 受入/検品 because that is the order the work
          // happens in: stock lands in the warehouse, then someone says which
          // shelf it went to (UI spec §13/§55).
          FeatureEntry(
            id: 'putaway',
            icon: Icons.move_to_inbox_outlined,
            status: FeatureStatus.ready,
            builder: _putaway,
            requiredAnyOf: ['putaway.confirm'],
          ),
          FeatureEntry(
            id: 'shipment',
            icon: Icons.outbox_outlined,
            status: FeatureStatus.ready,
            builder: _shipment,
            requiredAnyOf: ['pack.complete', 'ship.complete'],
          ),
          FeatureEntry(
            id: 'stock_adjustment',
            icon: Icons.tune_outlined,
            status: FeatureStatus.ready,
            builder: _stockAdjustment,
            requiredAnyOf: ['inventory.adjust'],
          ),
          FeatureEntry(
            id: 'expiring_lots',
            icon: Icons.event_busy_outlined,
            status: FeatureStatus.ready,
            builder: _expiringLots,
            requiredAnyOf: ['inventory.view'],
          ),
          // Next to QC, because it is the queue QC works from: everything
          // here is waiting for an inspection to release it.
          FeatureEntry(
            id: 'held_stock',
            icon: Icons.pan_tool_outlined,
            status: FeatureStatus.ready,
            builder: _heldStock,
            requiredAnyOf: ['inspection.view', 'inventory.view'],
          ),
          // Beside the floor tasks, not with the reports: an open blocker is
          // work, and the person who has to clear it is on the dock.
          FeatureEntry(
            id: 'exceptions',
            icon: Icons.report_problem_outlined,
            status: FeatureStatus.ready,
            builder: _exceptions,
            requiredAnyOf: ['receiving.view', 'inspection.view', 'inventory.view'],
          ),
          FeatureEntry(
            id: 'stock_count',
            icon: Icons.checklist_outlined,
            status: FeatureStatus.ready,
            builder: _stockCount,
            requiredAnyOf: ['count.perform', 'count.approve'],
          ),
          FeatureEntry(
            id: 'picking',
            icon: Icons.shopping_cart_checkout_outlined,
            status: FeatureStatus.ready,
            builder: _picking,
            requiredAnyOf: ['pick.confirm'],
          ),
          FeatureEntry(
            id: 'wave',
            icon: Icons.route_outlined,
            status: FeatureStatus.ready,
            builder: _wave,
            requiredAnyOf: ['pick.confirm'],
          ),
          FeatureEntry(
            id: 'transfer',
            icon: Icons.compare_arrows,
            status: FeatureStatus.ready,
            builder: _transfer,
            requiredAnyOf: ['transfer.create', 'transfer.approve', 'transfer.receive'],
          ),
          FeatureEntry(
            id: 'replenishment',
            icon: Icons.trending_down_outlined,
            status: FeatureStatus.ready,
            builder: _replenishment,
            requiredAnyOf: ['inventory.view'],
          ),
          // Beside replenishment: both answer "how much is where", this one
          // for the warehouses abroad whose stock left the system (0088).
          FeatureEntry(
            id: 'virtual_stock',
            icon: Icons.public,
            status: FeatureStatus.ready,
            builder: _virtualStock,
            requiredAnyOf: ['inventory.view'],
          ),
          FeatureEntry(
            id: 'purchase_orders',
            icon: Icons.add_shopping_cart_outlined,
            status: FeatureStatus.ready,
            builder: _purchaseOrders,
            requiredAnyOf: ['purchase_order.view', 'purchase_order.manage', 'purchase_order.approve'],
          ),
          // Order, invoice, delivery and inspection that do not agree (0108):
          // only the differences, so matching lines pass without a look.
          FeatureEntry(
            id: 'document_exceptions',
            icon: Icons.difference_outlined,
            status: FeatureStatus.ready,
            builder: _documentExceptions,
            requiredAnyOf: ['purchase_order.view', 'purchase_order.manage', 'purchase_order.approve', 'receiving.view', 'inspection.view'],
          ),
          FeatureEntry(
            id: 'sales_orders',
            icon: Icons.point_of_sale_outlined,
            status: FeatureStatus.ready,
            builder: _salesOrders,
            requiredAnyOf: ['sales_order.view', 'sales_order.manage', 'sales_order.approve'],
          ),
          // Between the two kinds of order on purpose: this is where the
          // orders taken downstream turn into the purchases made upstream.
          FeatureEntry(
            id: 'demand',
            icon: Icons.assignment_late_outlined,
            status: FeatureStatus.ready,
            builder: _demand,
            requiredAnyOf: ['sales_order.view', 'purchase_order.view', 'inventory.view'],
          ),
          FeatureEntry(
            id: 'work_orders',
            icon: Icons.precision_manufacturing_outlined,
            status: FeatureStatus.ready,
            builder: _workOrders,
            requiredAnyOf: ['work_order.view', 'work_order.manage'],
          ),
        ],
      ),
      // Supply chain profit & risk (0107, spec §1): an analysis layer over
      // the operations above, not a replacement for any of them. What-ifs
      // never change stock or orders.
      FeatureGroup(
        id: 'supply_chain',
        entries: [
          FeatureEntry(
            id: 'sc_dashboard',
            icon: Icons.stacked_line_chart,
            status: FeatureStatus.ready,
            builder: _scDashboard,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_suppliers',
            icon: Icons.compare_arrows,
            status: FeatureStatus.ready,
            builder: _scSuppliers,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_costs',
            icon: Icons.receipt_long_outlined,
            status: FeatureStatus.ready,
            builder: _scCosts,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_routes',
            icon: Icons.alt_route,
            status: FeatureStatus.ready,
            builder: _scRoutes,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_simulation',
            icon: Icons.science_outlined,
            status: FeatureStatus.ready,
            builder: _scSimulation,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_risk',
            icon: Icons.shield_outlined,
            status: FeatureStatus.ready,
            builder: _scRisk,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_bottleneck',
            icon: Icons.traffic_outlined,
            status: FeatureStatus.ready,
            builder: _scBottleneck,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
          ),
          FeatureEntry(
            id: 'sc_history',
            icon: Icons.history_edu_outlined,
            status: FeatureStatus.ready,
            builder: _scHistory,
            requiredAnyOf: ['supply_chain.view', 'supply_chain.manage'],
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
            requiredAnyOf: ['audit.view'],
          ),
          FeatureEntry(
            id: 'user_management',
            icon: Icons.manage_accounts_outlined,
            status: FeatureStatus.ready,
            builder: _userManagement,
            requiredAnyOf: ['user.manage'],
          ),
          FeatureEntry(
            id: 'connectors',
            icon: Icons.hub_outlined,
            status: FeatureStatus.ready,
            builder: _connectors,
            requiredAnyOf: ['connector.manage'],
          ),
          FeatureEntry(
            id: 'ai_review',
            icon: Icons.fact_check_outlined,
            status: FeatureStatus.ready,
            builder: _aiReview,
            requiredAnyOf: ['ai.review'],
          ),
          FeatureEntry(
            id: 'ai_settings',
            icon: Icons.tune_outlined,
            status: FeatureStatus.ready,
            builder: _aiSettings,
            requiredAnyOf: ['ai.review', 'user.manage'],
          ),
          FeatureEntry(
            id: 'products',
            icon: Icons.inventory_2_outlined,
            status: FeatureStatus.ready,
            builder: _products,
            requiredAnyOf: ['product.view', 'product.manage'],
          ),
          // The registration worklist behind that master data: a code the
          // system has seen but no product yet accounts for.
          FeatureEntry(
            id: 'unlinked_jan',
            icon: Icons.link_off_outlined,
            status: FeatureStatus.ready,
            builder: _unlinkedJan,
            requiredAnyOf: ['product.view', 'inventory.view'],
          ),
          FeatureEntry(
            id: 'partners',
            icon: Icons.handshake_outlined,
            status: FeatureStatus.ready,
            builder: _partners,
            requiredAnyOf: ['partner.view', 'partner.manage'],
          ),
          FeatureEntry(
            id: 'locations',
            icon: Icons.account_tree_outlined,
            status: FeatureStatus.ready,
            builder: _locations,
            requiredAnyOf: ['warehouse.view', 'warehouse.manage'],
          ),
          FeatureEntry(
            id: 'reservations',
            icon: Icons.bookmark_border,
            status: FeatureStatus.ready,
            builder: _reservations,
            requiredAnyOf: ['inventory.view'],
          ),
          // A diagnostic, not a routine list — beside reservations because
          // both live off the same inventory.view read, not because either
          // one is normally worth looking at.
          FeatureEntry(
            id: 'stock_reconciliation',
            icon: Icons.fact_check_outlined,
            status: FeatureStatus.ready,
            builder: _stockReconciliation,
            requiredAnyOf: ['inventory.view'],
          ),
          FeatureEntry(
            id: 'reports',
            icon: Icons.table_chart_outlined,
            status: FeatureStatus.ready,
            builder: _reports,
            requiredAnyOf: ['report.view', 'report.manage'],
          ),
          // Teaching each trading company's way of writing before its goods
          // arrive (0105/0106): sample files read, checked and learned.
          FeatureEntry(
            id: 'notation_training',
            icon: Icons.school_outlined,
            status: FeatureStatus.ready,
            builder: _notationTraining,
            requiredAnyOf: ['product.manage', 'receiving.confirm'],
          ),
        ],
      ),
    ];

/// Top-level (const-referenceable) builder for the Inspection feature.
/// Points at the Supabase-backed inbound inspection (検品), not the legacy
/// InventorOS screen, so the entry actually works against the live backend.
Widget _inspectionList(BuildContext _) => const QcInspectionListScreen();
Widget _bulkInspection(BuildContext _) => const BulkInspectionScreen();

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
Widget _aiSettings(BuildContext _) => const AiSettingsScreen();
Widget _documentExceptions(BuildContext _) => const DocumentExceptionsScreen();

/// Top-level (const-referenceable) builder for the Product Master feature.
Widget _products(BuildContext _) => const ProductListScreen();

/// Top-level (const-referenceable) builder for the Unlinked JAN Codes feature.
Widget _unlinkedJan(BuildContext _) => const UnlinkedJanScreen();

/// Top-level (const-referenceable) builder for the Trading Partners feature.
Widget _partners(BuildContext _) => const TradingPartnerListScreen();

/// Top-level (const-referenceable) builder for the Report Builder feature.
Widget _reports(BuildContext _) => const ReportBuilderScreen();
Widget _notationTraining(BuildContext _) => const NotationTrainingScreen();

/// Top-level (const-referenceable) builder for the Put-away feature.
Widget _putaway(BuildContext _) => const PutawayQueueScreen();

/// Top-level (const-referenceable) builder for the Picking feature.
Widget _picking(BuildContext _) => const PickListIndexScreen();
Widget _wave(BuildContext _) => const PickWaveListScreen();

/// Top-level (const-referenceable) builder for the Transfer feature.
Widget _transfer(BuildContext _) => const TransferListScreen();

/// Top-level (const-referenceable) builder for the Purchase Orders feature.
Widget _purchaseOrders(BuildContext _) => const PurchaseOrderListScreen();

/// Top-level (const-referenceable) builder for the Sales Orders feature.
Widget _salesOrders(BuildContext _) => const SalesOrderListScreen();

Widget _demand(BuildContext _) => const OpenDemandScreen();

Widget _virtualStock(BuildContext _) => const VirtualStockScreen();

/// Top-level (const-referenceable) builder for the Work Orders feature.
Widget _workOrders(BuildContext _) => const WorkOrderListScreen();

/// Top-level (const-referenceable) builder for the Expiry Watch feature.
Widget _expiringLots(BuildContext _) => const ExpiringLotsScreen();

/// Top-level (const-referenceable) builder for the Reservations feature.
Widget _reservations(BuildContext _) => const ReservationsScreen();

/// Top-level (const-referenceable) builder for the Stock Reconciliation
/// feature.
Widget _stockReconciliation(BuildContext _) =>
    const StockReconciliationScreen();
Widget _exceptions(BuildContext _) => const ExceptionListScreen();
Widget _heldStock(BuildContext _) => const HeldStockScreen();

/// Top-level (const-referenceable) builder for the Replenishment feature.
Widget _replenishment(BuildContext _) => const ReplenishmentScreen();

/// Top-level (const-referenceable) builder for the Locations feature.
Widget _locations(BuildContext _) => const LocationTreeScreen();

/// The supply chain screens (0107).
Widget _scDashboard(BuildContext _) => const ScDashboardScreen();
Widget _scSuppliers(BuildContext _) => const ScSupplierComparisonScreen();
Widget _scCosts(BuildContext _) => const ScCostStructureScreen();
Widget _scRoutes(BuildContext _) => const ScRoutesScreen();
Widget _scSimulation(BuildContext _) => const ScSimulationScreen();
Widget _scRisk(BuildContext _) => const ScRiskScreen();
Widget _scBottleneck(BuildContext _) => const ScBottleneckScreen();
Widget _scHistory(BuildContext _) => const ScHistoryScreen();
