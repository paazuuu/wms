import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/audit/application/audit_providers.dart';
import 'package:wms_mobile/features/audit/domain/audit_entry.dart';
import 'package:wms_mobile/features/audit/presentation/entity_audit_timeline.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('shows only entries logged against this exact entity',
      (tester) async {
    final repo = FakeAuditRepository(const [
      AuditEntry(
          id: 1, eventType: 'transfer.created', entityType: 'transfer_order', entityId: '7'),
      AuditEntry(
          id: 2, eventType: 'transfer.approved', entityType: 'transfer_order', entityId: '7'),
      // A different transfer's history must not leak in.
      AuditEntry(
          id: 3, eventType: 'transfer.created', entityType: 'transfer_order', entityId: '8'),
    ]);

    await pumpApp(
      tester,
      const Scaffold(
        body: EntityAuditTimeline(entityType: 'transfer_order', entityId: '7'),
      ),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('transfer.created'), findsOneWidget);
    expect(find.text('transfer.approved'), findsOneWidget);
  });

  testWidgets('renders nothing when the entity has no history', (tester) async {
    final repo = FakeAuditRepository(const []);

    await pumpApp(
      tester,
      const Scaffold(
        body: EntityAuditTimeline(entityType: 'transfer_order', entityId: '7'),
      ),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.byType(Card), findsNothing);
  });
}
