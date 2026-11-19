import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/presentation/reading_check_screen.dart';

import '../../support/harness.dart';

const _jan1 = '4909999000014';
const _jan2 = '4909999000021';
const _jan3 = '4909999000038';

void main() {
  test('識別コード: a short letter code, or one beside a date; nothing else', () {
    expect(classCodeOf(' hl '), 'HL');
    expect(classCodeOf('ＢＬ'), 'BL');
    expect(classCodeOf('20261027 HL'), 'HL');
    expect(classCodeOf('11月5日 BL'), 'BL');
    expect(classCodeOf('BL 11/5'), 'BL');
    expect(classCodeOf('2026/10/27'), isNull);
    expect(classCodeOf('12345'), isNull);
    expect(classCodeOf('ボールペン'), isNull);
    expect(codeBesideDate('HL 9E'), isNull, reason: 'an order number is not a date');
  });

  test('a sheet: the 識別コード heading, or a column of codes no heading named', () {
    final named = parseStockRows([
      ['JAN', '数量', '識別コード'],
      [_jan1, '5', 'hl'],
      [_jan2, '3', 'BL'],
    ]);
    expect([for (final l in named.lines) l.classCode], ['HL', 'BL']);
    expect(named.lines.first.toJson()['class_code'], 'HL');

    final guessed = parseStockRows([
      ['JAN', '数量', '備考'],
      [_jan1, '5', 'HL'],
      [_jan2, '3', 'BL'],
      [_jan3, '1', 'HL'],
    ]);
    expect([for (final l in guessed.lines) l.classCode], ['HL', 'BL', 'HL']);

    // One code throughout, or words: not taken for codes.
    final words = parseStockRows([
      ['JAN', '数量', '備考'],
      [_jan1, '5', '至急'],
      [_jan2, '3', '至急'],
    ]);
    expect(words.lines.every((l) => l.classCode == null), isTrue);
    expect(words.lines.first.toJson().containsKey('class_code'), isFalse);
  });

  test('read by the AI: the code goes with the line, the same JAN twice keeps the first', () {
    final sheet = stockSheetFromRead(const [
      ReadRow(lineNo: 1, jan: _jan1, quantity: '10', ledger: LedgerFields(classCode: 'HL')),
      ReadRow(lineNo: 2, jan: _jan1, quantity: '5', ledger: LedgerFields(classCode: 'BL')),
      ReadRow(lineNo: 3, jan: _jan2, quantity: '2'),
    ]);
    expect(sheet.lines.map((l) => (l.janCode, l.quantity, l.classCode)), [(_jan1, 15, 'HL'), (_jan2, 2, null)]);
    expect(const LedgerFields(classCode: 'HL').toJson(), {'class_code': 'HL'});
    expect(LedgerFields.fromJson(const {'class_code': 'bl'}).classCode, 'BL');
  });

  testWidgets('識別コードをまとめて入力: the empty lines get the code, the read ones keep theirs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<ReadRow>? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.of(context).push<List<ReadRow>>(MaterialPageRoute(
              builder: (_) => const ReadingCheckScreen(rows: [
                ReadRow(lineNo: 1, jan: _jan1, name: 'テストペン', quantity: '10', ledger: LedgerFields(classCode: 'HL')),
                ReadRow(lineNo: 2, jan: _jan2, name: 'テスト替芯', quantity: '4'),
                ReadRow(lineNo: 3, jan: _jan3, name: 'テスト消しゴム', quantity: '6'),
              ]),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Always a column, so a code not read can be typed in.
    expect(find.byKey(const ValueKey('rc-2-class_code')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rc-class-code')));
    await tester.pumpAndSettle();
    // The lines with no code are ticked at first.
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('cc-row-1'))).value, isFalse);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('cc-row-2'))).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('cc-row-3')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('cc-code')), 'bl');
    await tester.pump();
    expect(find.text('1行に入れる'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cc-apply')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('rc-ok')));
    await tester.pumpAndSettle();
    expect([for (final r in result!) r.ledger.classCode], ['HL', 'BL', '']);
    expect(result![1].flags, contains('human_corrected'));
  });
}
