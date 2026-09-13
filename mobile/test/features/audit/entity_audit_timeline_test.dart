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

    // Humanized labels (§29), not the raw event codes.
    expect(find.text('倉庫間移動を作成'), findsOneWidget);
    expect(find.text('倉庫間移動を承認'), findsOneWidget);
  });

  testWidgets('shows who did it, or "system" when no actor was logged',
      (tester) async {
    final repo = FakeAuditRepository(const [
      AuditEntry(
        id: 1,
        eventType: 'transfer.approved',
        entityType: 'transfer_order',
        entityId: '7',
        actorName: 'テスト太郎',
      ),
      AuditEntry(
        id: 2,
        eventType: 'transfer.created',
        entityType: 'transfer_order',
        entityId: '7',
      ),
    ]);

    await pumpApp(
      tester,
      const Scaffold(
        body: EntityAuditTimeline(entityType: 'transfer_order', entityId: '7'),
      ),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.textContaining('テスト太郎'), findsOneWidget);
    expect(find.textContaining('システム'), findsOneWidget);
  });

  testWidgets('falls back to email when there is no resolved name',
      (tester) async {
    final repo = FakeAuditRepository(const [
      AuditEntry(
        id: 1,
        eventType: 'transfer.approved',
        entityType: 'transfer_order',
        entityId: '7',
        actorEmail: 'no-name@example.com',
      ),
    ]);

    await pumpApp(
      tester,
      const Scaffold(
        body: EntityAuditTimeline(entityType: 'transfer_order', entityId: '7'),
      ),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.textContaining('no-name@example.com'), findsOneWidget);
  });

  testWidgets('an unmapped event code still renders instead of disappearing',
      (tester) async {
    final repo = FakeAuditRepository(const [
      AuditEntry(
        id: 1,
        eventType: 'brand_new.thing_happened',
        entityType: 'transfer_order',
        entityId: '7',
      ),
    ]);

    await pumpApp(
      tester,
      const Scaffold(
        body: EntityAuditTimeline(entityType: 'transfer_order', entityId: '7'),
      ),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('brand new thing happened'), findsOneWidget);
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
