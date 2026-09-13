import '../../../l10n/app_localizations.dart';

/// Human phrasing for an `audit_log.event_type` code (UI spec §29: "誰が・
/// いつ・何をしたか表示する" — raw codes like `purchase_order.approved` are the
/// "what" a machine wants, not what an operator reads at a glance).
///
/// The mapping is a closed, finite set — every `log_audit(...)` call site in
/// the schema is enumerated here (55 as of 0040) — so it can be complete
/// rather than a guess. A code this map doesn't recognise (a future event
/// type added to a migration without updating this list) still renders: it
/// falls back to the raw code with separators turned into spaces, so nothing
/// silently disappears while the gap gets fixed.
class AuditEventLabels {
  const AuditEventLabels._();

  static String of(AppLocalizations l10n, String eventType) {
    return switch (eventType) {
      'ai.analysis_completed' => l10n.auditEventAiAnalysisCompleted,
      'ai.confirmed' => l10n.auditEventAiConfirmed,
      'ai.rejected' => l10n.auditEventAiRejected,
      'attachment.uploaded' => l10n.auditEventAttachmentUploaded,
      'count.cancelled' => l10n.auditEventCountCancelled,
      'count.completed' => l10n.auditEventCountCompleted,
      'count.started' => l10n.auditEventCountStarted,
      'inspection.confirmed' => l10n.auditEventInspectionConfirmed,
      'inspection.started' => l10n.auditEventInspectionStarted,
      'inventory.adjusted' => l10n.auditEventInventoryAdjusted,
      'partner.created' => l10n.auditEventPartnerCreated,
      'partner.updated' => l10n.auditEventPartnerUpdated,
      'pick_list.cancelled' => l10n.auditEventPickListCancelled,
      'pick_list.completed' => l10n.auditEventPickListCompleted,
      'pick_list.started' => l10n.auditEventPickListStarted,
      'product.created' => l10n.auditEventProductCreated,
      'product.updated' => l10n.auditEventProductUpdated,
      'purchase_order.approved' => l10n.auditEventPurchaseOrderApproved,
      'purchase_order.cancelled' => l10n.auditEventPurchaseOrderCancelled,
      'purchase_order.completed' => l10n.auditEventPurchaseOrderCompleted,
      'purchase_order.created' => l10n.auditEventPurchaseOrderCreated,
      'purchase_order.rejected' => l10n.auditEventPurchaseOrderRejected,
      'purchase_order.submitted' => l10n.auditEventPurchaseOrderSubmitted,
      'putaway.confirmed' => l10n.auditEventPutawayConfirmed,
      'receiving.cancelled' => l10n.auditEventReceivingCancelled,
      'receiving.confirmed' => l10n.auditEventReceivingConfirmed,
      'report.deleted' => l10n.auditEventReportDeleted,
      'report.saved' => l10n.auditEventReportSaved,
      'sales_order.approved' => l10n.auditEventSalesOrderApproved,
      'sales_order.cancelled' => l10n.auditEventSalesOrderCancelled,
      'sales_order.completed' => l10n.auditEventSalesOrderCompleted,
      'sales_order.created' => l10n.auditEventSalesOrderCreated,
      'sales_order.rejected' => l10n.auditEventSalesOrderRejected,
      'sales_order.submitted' => l10n.auditEventSalesOrderSubmitted,
      'shipment.autopacked' => l10n.auditEventShipmentAutopacked,
      'shipment.cancelled' => l10n.auditEventShipmentCancelled,
      'shipment.completed' => l10n.auditEventShipmentCompleted,
      'shipment.logistics_set' => l10n.auditEventShipmentLogisticsSet,
      'transfer.approved' => l10n.auditEventTransferApproved,
      'transfer.cancelled' => l10n.auditEventTransferCancelled,
      'transfer.created' => l10n.auditEventTransferCreated,
      'transfer.picking_started' => l10n.auditEventTransferPickingStarted,
      'transfer.received' => l10n.auditEventTransferReceived,
      'transfer.receiving_started' => l10n.auditEventTransferReceivingStarted,
      'transfer.rejected' => l10n.auditEventTransferRejected,
      'transfer.shipped' => l10n.auditEventTransferShipped,
      'transfer.submitted' => l10n.auditEventTransferSubmitted,
      'user.role_assigned' => l10n.auditEventUserRoleAssigned,
      'user.role_revoked' => l10n.auditEventUserRoleRevoked,
      'user.warehouse_assigned' => l10n.auditEventUserWarehouseAssigned,
      'user.warehouse_revoked' => l10n.auditEventUserWarehouseRevoked,
      'work_order.cancelled' => l10n.auditEventWorkOrderCancelled,
      'work_order.completed' => l10n.auditEventWorkOrderCompleted,
      'work_order.created' => l10n.auditEventWorkOrderCreated,
      'work_order.started' => l10n.auditEventWorkOrderStarted,
      _ => _fallback(eventType),
    };
  }

  /// `purchase_order.approved` → `purchase order approved`. Never crashes,
  /// never hides the event — just less polished than a mapped one.
  static String _fallback(String eventType) =>
      eventType.replaceAll(RegExp(r'[._]'), ' ').trim();
}
