import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/stock_ops/application/stock_ops_providers.dart';
import 'package:wms_mobile/features/stock_ops/domain/stock_ops.dart';
import 'package:wms_mobile/features/stock_ops/presentation/stock_count_detail_screen.dart';

import '../../support/harness.dart';

StockCount _openCount({required bool blind}) => StockCount(
      id: 7,
      status: CountStatus.counting,
      warehouseId: 1,
      isBlind: blind,
      lines: const [
        StockCountLine(
          id: 11,
          janCode: '4901234567894',
          productName: 'ボールペン',
          systemQuantity: 40,
        ),
        StockCountLine(
          id: 12,
          janCode: '4901234567895',
          productName: 'ノート',
          systemQuantity: 12,
        ),
      ],
    );

void main() {
  testWidgets('a blind count hides the system quantity while it is open',
      (tester) async {
    final repo = FakeStockOpsRepository(count: _openCount(blind: true));

    await pumpApp(
      tester,
      const StockCountDetailScreen(countId: 7),
      overrides: [stockOpsRepositoryProvider.overrideWithValue(repo)],
    );

    // The theoretical figures must not reach the counter's eyes.
    expect(find.text('40'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('確定まで非表示'), findsWidgets);
  });

  testWidgets('a non-blind count shows the system quantity', (tester) async {
    final repo = FakeStockOpsRepository(count: _openCount(blind: false));

    await pumpApp(
      tester,
      const StockCountDetailScreen(countId: 7),
      overrides: [stockOpsRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('40'), findsOneWidget);
    expect(find.text('確定まで非表示'), findsNothing);
  });

  testWidgets('completing with uncounted lines warns that they are left alone',
      (tester) async {
    final repo = FakeStockOpsRepository(count: _openCount(blind: false));

    await pumpApp(
      tester,
      const StockCountDetailScreen(countId: 7),
      overrides: [stockOpsRepositoryProvider.overrideWithValue(repo)],
    );

    // Count one of the two lines, leave the other untouched.
    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '38');
    await tester.tap(find.text('実査数を入力'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '棚卸を確定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('未実査 1 行'), findsOneWidget);
  });

  testWidgets('an uncounted line is not treated as zero', (tester) async {
    final repo = FakeStockOpsRepository(count: _openCount(blind: false));

    await pumpApp(
      tester,
      const StockCountDetailScreen(countId: 7),
      overrides: [stockOpsRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '38');
    await tester.tap(find.text('実査数を入力'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '棚卸を確定'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '棚卸を確定'),
    ));
    await tester.pumpAndSettle();

    // Only the counted line moved (-2); the uncounted one contributed nothing,
    // rather than being corrected down to zero.
    expect(find.text('棚卸を確定しました（1行を補正・純増減 -2）'), findsOneWidget);
  });
}
