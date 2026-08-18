import 'package:flutter/material.dart';

import '../../../core/ui/status_pill.dart';
import '../domain/work_order.dart';

/// Single mapping from a work order's status to a [StatusTone] + icon + label,
/// so the list and detail screens render it identically.
class WorkOrderStatusUi {
  const WorkOrderStatusUi(this.tone, this.icon, this.label);

  final StatusTone tone;
  final IconData icon;
  final String label;

  static WorkOrderStatusUi of(WorkOrder order) => switch (order.status) {
        WorkOrderStatus.draft => const WorkOrderStatusUi(
            StatusTone.neutral, Icons.edit_note_outlined, 'Draft'),
        WorkOrderStatus.pending => const WorkOrderStatusUi(
            StatusTone.info, Icons.schedule_outlined, 'Pending'),
        WorkOrderStatus.inProgress => const WorkOrderStatusUi(
            StatusTone.warning, Icons.precision_manufacturing_outlined,
            'In progress'),
        WorkOrderStatus.completed => const WorkOrderStatusUi(
            StatusTone.success, Icons.check_circle_outline, 'Completed'),
        WorkOrderStatus.cancelled => const WorkOrderStatusUi(
            StatusTone.danger, Icons.cancel_outlined, 'Cancelled'),
      };
}
