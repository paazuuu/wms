// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/application/attachment_providers.dart';
import 'package:wms_mobile/features/qc/application/inspection_providers.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/qc/presentation/inspection_detail_screen.dart';

import '../../support/harness.dart';

/// Spec §38 Scenario B: 50 received against a plan of 100, 47 pass / 3 fail.
Inspection _pending() => Inspection(
      id: 1,
      status: QcResult.pending,
      deliveryNumber: '0901',
      supplierName: '新東光通商株式会社',
      items: [
        InspectionItem(
          id: 10,
          janCode: '4902505632037',
          productName: 'ペン',
          expectedQuantity: 100,
          actualQuantity: 50,
          passedQuantity: 0,
          failedQuantity: 0,
          discrepancy: -50,
          result: QcResult.pending,
        ),
      ],
    );

/// Fully checked, so _complete() reaches the repository instead of being
/// refused locally for unchecked items.
Inspection _checked() => Inspection(
      id: 1,
      status: QcResult.pending,
      deliveryNumber: '0901',
      supplierName: '新東光通商株式会社',
      items: [
        InspectionItem(
          id: 10,
          janCode: '4902505632037',
          productName: 'ペン',
          expectedQuantity: 100,
          actualQuantity: 100,
          passedQuantity: 100,
          failedQuantity: 0,
          discrepancy: 0,
          result: QcResult.pass,
        ),
      ],
    );

Future<ProviderContainer> _pump(
    WidgetTester tester, FakeInspectionRepository repo) async {
  final container = ProviderContainer(overrides: [
    inspectionRepositoryProvider.overrideWithValue(repo),
    attachmentRepositoryProvider.overrideWithValue(FakeAttachmentRepository()),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
      tester, container, const InspectionDetailScreen(inspectionId: 1));
  return container;
}

void main() {
  testWidgets('shows the stored discrepancy and blocks completing while unchecked',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeInspectionRepository(_pending());
    await _pump(tester, repo);

    // The line is unchecked, and the shortfall is displayed, not corrected.
    expect(find.text('未検品'), findsWidgets);
    expect(find.text('-50'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // expected
    expect(find.text('50'), findsOneWidget); // actual

    // Completing is refused locally, before any request goes out.
    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();
    expect(find.text('未検品の明細があるため確定できません'), findsOneWidget);
    expect(repo.refusedIncomplete, isFalse);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('recording 47 pass / 3 fail yields PARTIAL and then completes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeInspectionRepository(_pending());
    await _pump(tester, repo);

    // Open the finding sheet for the line.
    await tester.tap(find.text('ペン'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '47');
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.tap(find.text('記録'));
    await tester.pumpAndSettle();

    // The split drives the line result.
    expect(repo.inspection.items.single.result, QcResult.partial);
    expect(find.text('一部合格'), findsWidgets);

    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();

    expect(repo.inspection.status, QcResult.partial);
    expect(find.textContaining('検品を確定しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'completing offers put-away as the next step instead of just refreshing (§35)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeInspectionRepository(_checked());
    await _pump(tester, repo);

    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();

    // The next task is one tap away, but the screen the operator just
    // finished on is still what's shown — no automatic navigation.
    expect(find.widgetWithText(SnackBarAction, '棚入れへ'), findsOneWidget);
    expect(find.byType(InspectionDetailScreen), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a permission-denied completion shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeInspectionRepository(_checked())
      ..failWith = 'not permitted: inspection.confirm required';
    await _pump(tester, repo);

    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('inspection.confirm'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  group('the QC gate, made visible (§13, 0068)', () {
    /// Checked with a real failure: 28 pass, 10 fail. The case that moves stock.
    Inspection partlyFailed() => Inspection(
          id: 1,
          status: QcResult.pending,
          deliveryNumber: '0901',
          supplierName: '新東光通商株式会社',
          items: [
            InspectionItem(
              id: 10,
              janCode: '4902505632037',
              productName: 'ペン',
              expectedQuantity: 40,
              actualQuantity: 38,
              passedQuantity: 28,
              failedQuantity: 10,
              discrepancy: -2,
              result: QcResult.partial,
            ),
          ],
        );

    testWidgets('warns what completing will do before the operator taps it',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      final repo = FakeInspectionRepository(partlyFailed());
      await _pump(tester, repo);

      // Since 0068 a failure is not a note on a document — it moves the goods
      // out of shippable. The operator learns that before, not after.
      expect(
          find.text('確定すると不合格 10 点は出荷できない在庫に移ります'),
          findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('reports what actually moved, which a status word cannot',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      final repo = FakeInspectionRepository(partlyFailed());
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(FilledButton, '検品を確定'));
      await tester.pumpAndSettle();

      expect(find.text('在庫への反映'), findsOneWidget);
      // The answer to "are the 28 I passed sellable now".
      expect(find.text('合格 28 点を出荷可能にしました'), findsOneWidget);
      expect(find.text('不合格 10 点を DAMAGED に移しました'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('an all-pass inspection reports the release and holds nothing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      final repo = FakeInspectionRepository(_checked());
      await _pump(tester, repo);

      // Nothing to warn about before: there are no failures.
      expect(find.textContaining('出荷できない在庫に移ります'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, '検品を確定'));
      await tester.pumpAndSettle();

      expect(find.text('合格 100 点を出荷可能にしました'), findsOneWidget);
      expect(find.textContaining('に移しました'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('judging goods that were never held says so instead of lying',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      final repo = FakeInspectionRepository(_checked())
        // What the server returns when the product did not require inspection:
        // the inspection is valid, and nothing was gated to release.
        ..stockEffect = InspectionStockEffect(
          releasedToOk: 0,
          failedQuantity: 0,
          notInQcPending: 100,
        );
      await _pump(tester, repo);

      await tester.tap(find.widgetWithText(FilledButton, '検品を確定'));
      await tester.pumpAndSettle();

      expect(find.text('うち 100 点は検品待ち在庫に無く、在庫は動いていません'),
          findsOneWidget);
      expect(
          find.text('検品対象が検品待ち在庫になかったため、在庫は動いていません。'),
          findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
