import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/ai_review/application/ai_review_providers.dart';
import 'package:wms_mobile/features/ai_review/domain/ai_analysis_entry.dart';
import 'package:wms_mobile/features/ai_review/presentation/ai_review_list_screen.dart';

import '../../support/harness.dart';

void main() {
  AiAnalysisEntry pendingEntry({int id = 1}) => AiAnalysisEntry(
        id: id,
        taskType: 'ocr_delivery_note',
        provider: 'gemini',
        model: 'gemini-3.8-flash',
        status: 'PENDING_REVIEW',
        createdAt: DateTime(2026, 1, 1, 12, 30),
        lines: const [
          AiOcrLine(janCode: '4901234567894', productName: 'ボールペン', quantity: 10),
        ],
      );

  testWidgets('lists pending results with their extracted lines', (tester) async {
    final repo = FakeAiReviewRepository([pendingEntry()]);

    await pumpApp(
      tester,
      const AiReviewListScreen(),
      overrides: [aiReviewRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('ocr_delivery_note'), findsOneWidget);
    expect(find.textContaining('gemini'), findsOneWidget);
    expect(find.textContaining('4901234567894'), findsOneWidget);
    expect(find.textContaining('ボールペン'), findsOneWidget);
  });

  testWidgets('an empty queue explains itself rather than showing nothing',
      (tester) async {
    final repo = FakeAiReviewRepository(const []);

    await pumpApp(
      tester,
      const AiReviewListScreen(),
      overrides: [aiReviewRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('レビュー待ちはありません'), findsOneWidget);
  });

  testWidgets('confirming removes the entry from the pending list', (tester) async {
    final repo = FakeAiReviewRepository([pendingEntry()]);

    await pumpApp(
      tester,
      const AiReviewListScreen(),
      overrides: [aiReviewRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('承認'));
    await tester.pumpAndSettle();

    expect(find.text('レビュー待ちはありません'), findsOneWidget);
  });

  testWidgets('rejecting asks for a reason, then removes the entry', (tester) async {
    final repo = FakeAiReviewRepository([pendingEntry()]);

    await pumpApp(
      tester,
      const AiReviewListScreen(),
      overrides: [aiReviewRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('却下'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'wrong JAN read');
    await tester.tap(find.widgetWithText(FilledButton, '却下'));
    await tester.pumpAndSettle();

    expect(repo.lastRejectedId, 1);
    expect(repo.lastRejectReason, 'wrong JAN read');
    expect(find.text('レビュー待ちはありません'), findsOneWidget);
  });
}
