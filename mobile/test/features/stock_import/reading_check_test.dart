import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/presentation/reading_check_screen.dart';

import '../../support/harness.dart';

const _jan1 = '4909999000014';
const _jan2 = '4909999000021';

void main() {
  test('数量 × 単価 against 金額, a yen of rounding let pass', () {
    expect(amountMismatch('40', '307', '12280'), isFalse);
    expect(amountMismatch('40', '307', '12281'), isFalse);
    expect(amountMismatch('400', '307', '12280'), isTrue);
    expect(amountMismatch('1,000', '53.9', '53,900'), isFalse);
    // Without all three, nothing to say.
    expect(amountMismatch('40', '', '12280'), isFalse);
  });

  test('the cells a doubt points to', () {
    expect(doubtfulCells(const ReadRow(lineNo: 1, flags: ['jan_check', 'ai_disagree:planned_quantity'])), {'jan', 'quantity'});
    expect(doubtfulCells(const ReadRow(lineNo: 1, flags: ['split_disagree'])), {'name', 'code'});
    expect(doubtfulCells(const ReadRow(lineNo: 1, flags: ['unresolved'])), isEmpty);
  });

  test('checked by a person: not in doubt, and a row left out is not taken', () {
    final sheet = stockSheetFromRead(const [
      ReadRow(lineNo: 1, jan: _jan1, quantity: '10', flags: ['ai_disagree', 'human_checked']),
      ReadRow(lineNo: 2, jan: _jan2, quantity: '3', flags: ['human_checked', 'human_removed']),
    ]);
    expect(sheet.lines.single.janCode, _jan1);
    expect(sheet.lines.single.doubtful, isFalse);
    expect(sheet.problems, isEmpty);
    expect(sheet.read.length, 2);
    // Not checked, the same doubt still counts.
    expect(stockSheetFromRead(const [ReadRow(lineNo: 1, jan: _jan1, quantity: '10', flags: ['ai_disagree'])]).lines.single.doubtful,
        isTrue);
  });

  testWidgets('on a PC the original and the table side by side; only the columns the file had', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<ReadRow>? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
              builder: (_) => ReadingCheckScreen(
                fileName: '在庫.csv',
                bytes: Uint8List.fromList(utf8.encode('JAN,数量\n$_jan1,40\n')),
                rows: const [
                  ReadRow(lineNo: 2, jan: _jan1, name: 'テストペン', quantity: '40', ledger: LedgerFields(unitPrice: '307', amount: '12280')),
                ],
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('iv-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-2-unit_price')), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-2-order_number')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rc-all-columns')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rc-2-order_number')), findsOneWidget);

    // Right as it is: checked, nothing marked changed.
    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
    expect(result!.single.flags, ['human_checked']);
    expect(result!.single.corrected, isFalse);
    expect(result!.single.ledger.amount, '12280');
  });
}
