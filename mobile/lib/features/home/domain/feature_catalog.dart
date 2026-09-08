import 'package:flutter/material.dart';

import '../../delivery/presentation/delivery_plan_list_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import '../../inspection/presentation/inspection_list_screen.dart';
import '../../locations/presentation/location_list_screen.dart';
import '../../picking/presentation/picking_list_screen.dart';
import '../../products/presentation/product_lookup_screen.dart';
import '../../purchase_orders/presentation/purchase_order_list_screen.dart';
import '../../receiving/presentation/receiving_list_screen.dart';
import '../../reports/presentation/report_list_screen.dart';
import '../../sales_orders/presentation/sales_order_list_screen.dart';
import '../../stock_adjustment/presentation/stock_adjustment_search_screen.dart';
import '../../stock_count/presentation/stock_count_list_screen.dart';
import '../../suppliers/presentation/supplier_list_screen.dart';
import '../../tracking/presentation/tracking_search_screen.dart';
import '../../warehouses/presentation/warehouse_list_screen.dart';
import '../../work_orders/presentation/work_order_list_screen.dart';
import 'feature_entry.dart';

/// The app's full feature menu, grouped for the home dashboard.
///
/// This is the single source of truth for navigation: adding a screen means
/// flipping an entry to [FeatureStatus.ready] and pointing [FeatureEntry.builder]
/// at it. Every entry corresponds to a live InventorOS backend endpoint.
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
            id: 'receiving',
            icon: Icons.move_to_inbox_outlined,
            status: FeatureStatus.ready,
            builder: _receiving,
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
        ],
      ),
      FeatureGroup(
        id: 'lookup',
        entries: [
          FeatureEntry(
            id: 'product_lookup',
            icon: Icons.qr_code_scanner_outlined,
            status: FeatureStatus.ready,
            builder: _productLookup,
          ),
          FeatureEntry(
            id: 'locations',
            icon: Icons.place_outlined,
            status: FeatureStatus.ready,
            builder: _locations,
          ),
          FeatureEntry(
            id: 'lots_serials',
            icon: Icons.tag_outlined,
            status: FeatureStatus.ready,
            builder: _lotsSerials,
          ),
        ],
      ),
      FeatureGroup(
        id: 'management',
        entries: [
          FeatureEntry(
            id: 'purchase_orders',
            icon: Icons.receipt_long_outlined,
            status: FeatureStatus.ready,
            builder: _purchaseOrders,
          ),
          FeatureEntry(
            id: 'sales_orders',
            icon: Icons.list_alt_outlined,
            status: FeatureStatus.ready,
            builder: _salesOrders,
          ),
          FeatureEntry(
            id: 'suppliers',
            icon: Icons.local_shipping_outlined,
            status: FeatureStatus.ready,
            builder: _suppliers,
          ),
          FeatureEntry(
            id: 'warehouses',
            icon: Icons.warehouse_outlined,
            status: FeatureStatus.ready,
            builder: _warehouses,
          ),
          FeatureEntry(
            id: 'work_orders',
            icon: Icons.precision_manufacturing_outlined,
            status: FeatureStatus.ready,
            builder: _workOrders,
          ),
          FeatureEntry(
            id: 'reports',
            icon: Icons.assessment_outlined,
            status: FeatureStatus.ready,
            builder: _reports,
          ),
        ],
      ),
    ];

/// Top-level (const-referenceable) builder for the Inspection feature.
Widget _inspectionList(BuildContext _) => const InspectionListScreen();

/// Top-level (const-referenceable) builder for the Product Lookup feature.
Widget _productLookup(BuildContext _) => const ProductLookupScreen();

/// Top-level (const-referenceable) builder for the Receiving feature.
Widget _receiving(BuildContext _) => const ReceivingListScreen();

/// Top-level (const-referenceable) builder for the Delivery Check feature.
Widget _delivery(BuildContext _) => const DeliveryPlanListScreen();

/// Top-level (const-referenceable) builder for the Shipping (出庫) feature.
Widget _shipment(BuildContext _) => const ShipmentListScreen();

/// Top-level (const-referenceable) builder for the Stock Adjustment feature.
Widget _stockAdjustment(BuildContext _) =>
    const StockAdjustmentSearchScreen();

/// Top-level (const-referenceable) builder for the Stock Count feature.
Widget _stockCount(BuildContext _) => const StockCountListScreen();

/// Top-level (const-referenceable) builder for the Locations feature.
Widget _locations(BuildContext _) => const LocationListScreen();

/// Top-level (const-referenceable) builder for the Suppliers feature.
Widget _suppliers(BuildContext _) => const SupplierListScreen();

/// Top-level (const-referenceable) builder for the Warehouses feature.
Widget _warehouses(BuildContext _) => const WarehouseListScreen();

/// Top-level (const-referenceable) builder for the Sales Orders feature.
Widget _salesOrders(BuildContext _) => const SalesOrderListScreen();

/// Top-level (const-referenceable) builder for the Purchase Orders feature.
Widget _purchaseOrders(BuildContext _) => const PurchaseOrderListScreen();

/// Top-level (const-referenceable) builder for the Lots & Serials feature.
Widget _lotsSerials(BuildContext _) => const TrackingSearchScreen();

/// Top-level (const-referenceable) builder for the Work Orders feature.
Widget _workOrders(BuildContext _) => const WorkOrderListScreen();

/// Top-level (const-referenceable) builder for the Reports feature.
Widget _reports(BuildContext _) => const ReportListScreen();

/// Top-level (const-referenceable) builder for the Picking feature.
Widget _picking(BuildContext _) => const PickingListScreen();
