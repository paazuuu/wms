import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/requirements/requirements_repository.dart';
import 'package:wms_mobile/features/requirements/requirements_screen.dart';

import '../../support/fake_requirements_repository.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('each step and what it needs; the system administrator relaxes a rule after a confirm', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeRequirementsRepository(canEdit: true);
    await pumpApp(tester, const RequirementsScreen(),
        overrides: [requirementsRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('入荷（仕入先のファイル・発注の取込）'), findsOneWidget);
    expect(find.text('出庫（出庫済みにする）'), findsOneWidget);
    expect(find.text('各行の仕入単価'), findsOneWidget);
    expect(find.text('固定'), findsWidgets);
    expect(find.byKey(const ValueKey('rq-read-only')), findsNothing);

    const sw = ValueKey('rq-switch-receipt.unit_price-入荷（仕入先のファイル・発注の取込）');
    expect(tester.widget<Switch>(find.byKey(sw)).value, isTrue);
    // Turning it off is asked first; cancelled, nothing changes.
    await tester.tap(find.byKey(sw));
    await tester.pumpAndSettle();
    expect(find.text('「各行の仕入単価」を必須から外しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('popconfirm-cancel')));
    await tester.pumpAndSettle();
    expect(repo.sets, isEmpty);

    await tester.tap(find.byKey(sw));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rq-relax-ok')));
    await tester.pumpAndSettle();
    expect(repo.sets, [(Req.receiptPrice, false)]);
    expect(tester.widget<Switch>(find.byKey(sw)).value, isFalse);
    expect(find.text('任意'), findsOneWidget);

    // Back on, without a question.
    await tester.tap(find.byKey(sw));
    await tester.pumpAndSettle();
    expect(repo.sets.last, (Req.receiptPrice, true));
  });

  testWidgets('anyone else sees the same list, without switches to use', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const RequirementsScreen());
    expect(find.byKey(const ValueKey('rq-read-only')), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, isNotEmpty);
    expect(switches.every((s) => s.onChanged == null), isTrue);
  });
}
