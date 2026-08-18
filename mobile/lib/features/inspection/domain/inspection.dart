import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'inspection_item.dart';

enum InspectionStatus { pending, passed, failed }

InspectionStatus _parseStatus(String? value) => switch (value) {
      'passed' => InspectionStatus.passed,
      'failed' => InspectionStatus.failed,
      _ => InspectionStatus.pending,
    };

class Inspection extends Equatable {
  const Inspection({
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    this.note,
    this.purchaseOrderId,
    this.itemsCount,
    this.completedAt,
    this.items = const [],
    this.attachments = const [],
  });

  final int id;
  final String code;
  final String type;
  final InspectionStatus status;
  final String? note;
  final int? purchaseOrderId;
  final int? itemsCount;
  final DateTime? completedAt;
  final List<InspectionItem> items;
  final List<Attachment> attachments;

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? 'receiving',
      status: _parseStatus(json['status'] as String?),
      note: json['note'] as String?,
      purchaseOrderId: json['purchase_order_id'] as int?,
      itemsCount: json['items_count'] as int?,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => InspectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, code, status, items];
}
