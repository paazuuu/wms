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
    expect(doubtfulCells(const ReadRow(lineNo: 1, flags: ['split_disagree'])), {'maker_name', 'code'});
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

  test('メーカー（品名） as one text, and back into its two', () {
    expect(makerAndName('パイロット', ''), 'パイロット');
    expect(makerAndName('三菱鉛筆', 'ジェットストリーム 0.7'), '三菱鉛筆（ジェットストリーム 0.7）');
    expect(splitMakerAndName('三菱鉛筆（ジェットストリーム 0.7）'), ('三菱鉛筆', 'ジェットストリーム 0.7'));
    expect(splitMakerAndName('ゼブラ (サラサ)'), ('ゼブラ', 'サラサ'));
    expect(splitMakerAndName('コクヨ'), ('コクヨ', ''));
    expect(splitMakerAndName('（ノート）'), ('', 'ノート'));
  });

  testWidgets('maker and name share a column; edited there, both are kept', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<ReadRow>? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
              builder: (_) => const ReadingCheckScreen(rows: [
                ReadRow(lineNo: 1, jan: _jan1, maker: 'パイロット', code: 'BIL80EFSULB', quantity: '100'),
              ]),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('メーカー（品名）'), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-1-name')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('rc-1-maker_name')), 'パイロット（テストペン 黒）');
    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
    expect([result!.single.maker, result!.single.name], ['パイロット', 'テストペン 黒']);
    expect(result!.single.flags, containsAll(['human_checked', 'human_corrected']));
  });

  testWidgets('looked back at, the table is as it was left: nothing to change, the corrections in blue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      const ReadingCheckScreen(
        readOnly: true,
        rows: [
          ReadRow(lineNo: 1, jan: _jan1, maker: 'コクヨ', quantity: '10', aiQuantity: '100', flags: ['ai_disagree', 'human_checked', 'human_corrected']),
          ReadRow(lineNo: 2, jan: _jan2, quantity: '3', flags: ['human_checked', 'human_removed']),
        ],
      ),
    );
    expect(find.text('読み取り結果（表）'), findsOneWidget);
    expect(find.byKey(const ValueKey('rc-ok')), findsNothing);
    expect(find.byKey(const ValueKey('rc-add')), findsNothing);
    expect(find.byKey(const ValueKey('rc-remove-1')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rc-1-quantity'))).readOnly, isTrue);
    // The row left out stays struck through.
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rc-2-quantity'))).enabled, isFalse);
  });

  testWidgets('金額 follows 数量 × 単価, whichever is changed; the table scrolls sideways with its bar shown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<ReadRow>? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
              builder: (_) => const ReadingCheckScreen(rows: [
                ReadRow(lineNo: 1, jan: _jan1, maker: 'コクヨ', code: 'フ-CE755P', quantity: '111',
                    ledger: LedgerFields(unitPrice: '322', amount: '16100', deliveryDate: '8月27日', serial: '1')),
              ]),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rc-mismatch')), findsOneWidget);
    expect(tester.widget<Scrollbar>(find.byKey(const ValueKey('rc-across'))).thumbVisibility, isTrue);

    await tester.enterText(find.byKey(const ValueKey('rc-1-quantity')), '50');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rc-1-amount'))).controller!.text, '16100');
    expect(find.byKey(const ValueKey('rc-mismatch')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('rc-1-unit_price')), '322.5');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rc-1-amount'))).controller!.text, '16125');
    expect(find.text('1行・数量合計 50・金額合計 16,125'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
    expect([result!.single.quantity, result!.single.ledger.unitPrice, result!.single.ledger.amount], ['50', '322.5', '16125']);
  });
}
