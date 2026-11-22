import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/audit/application/audit_providers.dart';
import 'package:wms_mobile/features/audit/domain/audit_entry.dart';
import 'package:wms_mobile/features/audit/presentation/audit_log_screen.dart';

import 'package:wms_mobile/features/error_log/data/error_log_repository.dart';

import '../../support/fake_error_log_repository.dart';
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

    await tester.tap(find.widgetWithText(FilterChip, '倉庫間移動を承認'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(of: cards, matching: find.text('transfer.approved')),
        findsOneWidget);
    expect(
        find.descendant(of: cards, matching: find.text('transfer.created')),
        findsNothing);
  });

  testWidgets('an erased card says its name; エラーログ is the second tab (0227/0228)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeAuditRepository(
      [
        const AuditEntry(
            id: 3, eventType: 'partner.erase', entityType: 'partner', entityId: '40', details: {'name': 'テスト商事'}),
      ],
      types: const ['partner.erase'],
    );
    final errors = FakeErrorLogRepository([
      AppErrorEntry(
        id: 1,
        firstAt: DateTime.now(),
        lastAt: DateTime.now(),
        kind: 'api',
        status: 409,
        request: 'POST /rpc/partner_erase_check',
        message: '次の記録で使われているため削除できません: 発注書 2件',
      ),
      AppErrorEntry(id: 2, firstAt: DateTime.now(), lastAt: DateTime.now(), kind: 'api', status: 500, message: 'boom'),
    ]);
    await pumpApp(tester, const AuditLogScreen(), overrides: [
      auditRepositoryProvider.overrideWithValue(repo),
      errorLogRepositoryProvider.overrideWithValue(errors),
    ]);
    expect(find.text('取引先を完全に削除'), findsWidgets);
    expect(find.text('対象: partner #40（テスト商事）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('audit-tab-errors')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('el-list')), findsOneWidget);
    // A refusal is 操作できず, not a failed request.
    expect(find.text('操作できず'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('el-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('操作できず').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('el-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('el-2')), findsNothing);
  });
}
