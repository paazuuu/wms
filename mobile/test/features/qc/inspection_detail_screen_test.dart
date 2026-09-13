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
}
