import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/audit/application/audit_providers.dart';
import 'package:wms_mobile/features/audit/domain/audit_entry.dart';
import 'package:wms_mobile/features/audit/presentation/audit_log_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('renders entries newest first with their event type', (tester) async {
    final repo = FakeAuditRepository(
      [
        const AuditEntry(
          id: 2,
          eventType: 'transfer.approved',
          entityType: 'transfer_order',
          entityId: '7',
        ),
        const AuditEntry(
          id: 1,
          eventType: 'transfer.created',
          entityType: 'transfer_order',
          entityId: '7',
        ),
      ],
      types: const ['transfer.approved', 'transfer.created'],
    );

    await pumpApp(
      tester,
      const AuditLogScreen(),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    final cards = find.byType(Card);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.approved')),
        findsOneWidget);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.created')),
        findsOneWidget);
    // The CSV export action is always offered, even with data on screen.
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
  });

  testWidgets('an empty audit log explains itself rather than showing nothing',
      (tester) async {
    final repo = FakeAuditRepository(const []);

    await pumpApp(
      tester,
      const AuditLogScreen(),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('監査ログはまだありません'), findsOneWidget);
  });

  testWidgets('selecting an event type filters the list', (tester) async {
    final repo = FakeAuditRepository(
      [
        const AuditEntry(id: 2, eventType: 'transfer.approved'),
        const AuditEntry(id: 1, eventType: 'transfer.created'),
      ],
      types: const ['transfer.approved', 'transfer.created'],
    );

    await pumpApp(
      tester,
      const AuditLogScreen(),
      overrides: [auditRepositoryProvider.overrideWithValue(repo)],
    );

    final cards = find.byType(Card);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.approved')),
        findsOneWidget);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.created')),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'transfer.approved'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(of: cards, matching: find.text('transfer.approved')),
        findsOneWidget);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.created')),
        findsNothing);
  });
}
