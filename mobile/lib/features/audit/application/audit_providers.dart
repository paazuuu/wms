import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/audit_repository.dart';
import '../domain/audit_entry.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepositoryImpl(
      ref.watch(deliveryDioProvider), ref.watch(restDioProvider));
});

/// The event type filter chip row; null means "every event".
final auditEventTypeFilterProvider = StateProvider<String?>((_) => null);

final auditEventTypesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final result = await ref.watch(auditRepositoryProvider).eventTypes();
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// The audit trail for the active warehouse (or every warehouse, when none is
/// active), newest first, filtered by the selected event type.
final auditListProvider = FutureProvider.autoDispose<List<AuditEntry>>((ref) async {
  final warehouseId = ref.watch(activeWarehouseIdProvider);
  final eventType = ref.watch(auditEventTypeFilterProvider);
  final result = await ref
      .watch(auditRepositoryProvider)
      .list(warehouseId: warehouseId, eventType: eventType, limit: 200);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// Everything logged against one specific record (spec §40's per-document
/// timeline). Keyed by (entityType, entityId).
final entityAuditProvider = FutureProvider.autoDispose
    .family<List<AuditEntry>, (String, String)>((ref, key) async {
  final (entityType, entityId) = key;
  final result = await ref
      .watch(auditRepositoryProvider)
      .forEntity(entityType, entityId, limit: 50);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});
