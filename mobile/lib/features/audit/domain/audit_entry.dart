import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One append-only audit_log row (spec §33): who did what, to which record,
/// and when. Written by every mutating RPC in the system via `log_audit`;
/// this is purely the read side.
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.eventType,
    this.entityType,
    this.entityId,
    this.warehouseId,
    this.warehouseName,
    this.actorUserId,
    this.details = const {},
    this.createdAt,
  });

  final int id;
  final String eventType;
  final String? entityType;
  final String? entityId;
  final int? warehouseId;
  final String? warehouseName;
  final String? actorUserId;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: _asInt(json['id']),
        eventType: (json['event_type'] ?? '').toString(),
        entityType: json['entity_type'] as String?,
        entityId: json['entity_id'] as String?,
        warehouseId: json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        warehouseName: json['warehouse_name'] as String?,
        actorUserId: json['actor_user_id'] as String?,
        details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, eventType, entityType, entityId, createdAt];
}
