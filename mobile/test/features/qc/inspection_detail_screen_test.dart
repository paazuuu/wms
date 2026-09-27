// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/application/attachment_providers.dart';
import 'package:wms_mobile/features/qc/application/inspection_providers.dart';
import 'package:wms_mobile/features/qc/domain/attachment.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';
import 'package:wms_mobile/features/qc/presentation/inspection_detail_screen.dart';

import '../../support/harness.dart';

/// Text fields inside the finding sheet, not the scan field behind it (0099).
Finder _sheetField(int i) => find
    .descendant(of: find.byType(BottomSheet), matching: find.byType(TextField))
    .at(i);

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
  WidgetTester tester,
  FakeInspectionRepository repo, {
  FakeAttachmentRepository? attachments,
}) async {
  final container = ProviderContainer(overrides: [
    inspectionRepositoryProvider.overrideWithValue(repo),
    attachmentRepositoryProvider
        .overrideWithValue(attachments ?? FakeAttachmentRepository()),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(
      tester, container, const InspectionDetailScreen(inspectionId: 1));
  return container;
}

void main() {
  testWidgets('shows the stored discrepancy; unchecked lines complete as good after a confirm (0100)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeInspectionRepository(_pending());
    await _pump(tester, repo);

    // The line is unchecked, and the shortfall is displayed, not corrected.
    expect(find.text('未検品'), findsWidgets);
    expect(find.text('-50'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // expected
    expect(find.text('50'), findsOneWidget); // actual

    // Goods are good by default: completing asks once, then passes the line.
    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();
    expect(find.text('未チェックの 1 行は良品として完了します。数量を数えた行は、数えた数で確定します。'),
        findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.inspection.status, QcResult.pending);

    await tester.tap(find.text('検品を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qc-complete-default-confirm')));
    await tester.pumpAndSettle();
    expect(repo.inspection.status, QcResult.pass);
    expect(repo.inspection.items.single.passedQuantity, 50);

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

    await tester.enterText(_sheetField(0), '47');
    await tester.enterText(_sheetField(1), '3');
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

  group('attachments (§29, 0070)', () {
    Attachment photo({int id = 1, DateTime? withdrawnAt}) => Attachment(
          id: id,
          entityType: 'inspection',
          entityId: '1',
          storagePath: 'inspection/1/a.jpg',
          contentType: 'image/jpeg',
          kind: AttachmentKind.qcImage,
          caption: '外装の破れ',
          byteSize: 2048,
          withdrawnAt: withdrawnAt,
        );

    testWidgets('a photo says what kind of evidence it is, not just its size',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      final files = FakeAttachmentRepository(attachments: [photo()]);
      await _pump(tester, FakeInspectionRepository(_pending()),
          attachments: files);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('検品写真'), findsOneWidget);
      expect(find.textContaining('外装の破れ'), findsOneWidget);
      expect(find.textContaining('2 KB'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('a photo is withdrawn, never deleted', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      final files = FakeAttachmentRepository(attachments: [photo()]);
      await _pump(tester, FakeInspectionRepository(_pending()),
          attachments: files);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取り下げ').last);
      await tester.pumpAndSettle();

      // Confirmation first: the wording promises the record survives, which is
      // what 0070 actually does.
      expect(find.text('この添付を取り下げますか？'), findsOneWidget);
      expect(find.text('一覧からは外れますが、記録としては残ります。'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '取り下げ'));
      await tester.pumpAndSettle();

      expect(files.lastWithdrawnId, 1);
      expect(find.text('添付を取り下げました'), findsOneWidget);
      // Gone from the strip, but still there when asked for.
      final visible = await files.list('inspection', '1');
      visible.when(
        success: (rows) => expect(rows, isEmpty),
        failure: (f) => fail('expected success, got $f'),
      );
      final all =
          await files.list('inspection', '1', includeWithdrawn: true);
      all.when(
        success: (rows) => expect(rows.single.isWithdrawn, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('a completed inspection does not offer to withdraw its evidence',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      final files = FakeAttachmentRepository(attachments: [photo()]);
      await _pump(
          tester,
          FakeInspectionRepository(Inspection(
            id: 1,
            status: QcResult.pass,
            completedAt: DateTime(2026, 3, 1),
            items: _checked().items,
          )),
          attachments: files);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // The sheet still explains the file; only the action is gone.
      expect(find.text('検品写真'), findsOneWidget);
      expect(find.text('取り下げ'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('settling a line on its own (0099)', () {
    Inspection twoLines({bool firstFinal = false}) => Inspection(
          id: 1,
          status: QcResult.pending,
          items: [
            InspectionItem(
              id: 10, janCode: '4902505632037', productName: 'ペン',
              expectedQuantity: 5, actualQuantity: 5,
              passedQuantity: firstFinal ? 5 : 0, failedQuantity: 0, discrepancy: 0,
              result: firstFinal ? QcResult.pass : QcResult.pending,
              finalizedAt: firstFinal ? DateTime(2026, 9, 27) : null,
            ),
            InspectionItem(
              id: 11, janCode: '4900000000011', productName: 'ノート',
              expectedQuantity: 3, actualQuantity: 3,
              passedQuantity: 0, failedQuantity: 0, discrepancy: 0,
              result: QcResult.pending,
            ),
          ],
        );

    testWidgets('全数良品 passes just that line', (tester) async {
      final repo = FakeInspectionRepository(twoLines());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qc-pass-all-10')));
      await tester.pumpAndSettle();
      expect(repo.lastPassed, [10]);
      expect(find.text('5 点を良品として確定しました'), findsOneWidget);
    });

    testWidgets('a settled line is locked and marked', (tester) async {
      final repo = FakeInspectionRepository(twoLines(firstFinal: true));
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('確定済'), findsOneWidget);
      expect(find.byKey(const ValueKey('qc-pass-all-10')), findsNothing);
      expect(find.byKey(const ValueKey('qc-pass-all-11')), findsOneWidget);
    });

    testWidgets('each scan counts one piece, and the line says when it matches', (tester) async {
      final repo = FakeInspectionRepository(twoLines());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qc-count-state-11')), findsOneWidget);
      expect(find.text('未カウント'), findsNWidgets(2));

      for (var i = 0; i < 2; i++) {
        await tester.enterText(find.byType(TextField).first, '4900000000011');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }
      expect(find.text('ノート：2 / 3'), findsOneWidget);
      expect(find.text('不足 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '4900000000011');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('ノート の数量が一致しました（3 点）'), findsOneWidget);
      expect(find.text('数量一致'), findsOneWidget);
      expect(find.text('数量一致 1 / 2 行'), findsOneWidget);
      expect(repo.counts.every((c) => c.add && c.quantity == 1 && c.itemId == 11), isTrue);
    });

    testWidgets('the count can be typed instead', (tester) async {
      final repo = FakeInspectionRepository(twoLines());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qc-count-10')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('qc-count-field')), '6');
      await tester.tap(find.byKey(const ValueKey('qc-count-save')));
      await tester.pumpAndSettle();
      expect(repo.counts.last, (itemId: 10, quantity: 6, add: false));
      expect(find.text('過剰 1'), findsOneWidget);
    });

    testWidgets('a JAN not on the delivery can be recorded as a wrong item', (tester) async {
      final repo = FakeInspectionRepository(twoLines());
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1111');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('この入荷にない商品です'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qc-wrong-item-record')));
      await tester.pumpAndSettle();
      expect(repo.lastWrongItem?.jan, '1111');
      expect(find.text('誤品として記録しました'), findsOneWidget);
      expect(repo.lastPassed, isNull);
    });
  });
}
