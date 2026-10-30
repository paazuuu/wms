import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/export/xlsx.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/tax_files/data/tax_files_repository.dart';
import 'package:wms_mobile/features/tax_files/data/tax_workbook.dart';
import 'package:wms_mobile/features/tax_files/domain/tax_purchases.dart';
import 'package:wms_mobile/features/tax_files/presentation/tax_files_screen.dart';

import '../../support/harness.dart';

Map<String, dynamic> _import(int id, String day, List<Map<String, dynamic>> lines,
        {String? reg = 'T3122001027817', String supplier = '新東光通商株式会社', Map<String, dynamic>? totals, bool paid = false}) =>
    {
      'id': id, 'day': day, 'document_date': day, 'created_at': '2026-10-29T04:13:00Z', 'status': 'stock_done',
      'original_name': '請求書$id.pdf', 'original_path': 'imports/$id/original.pdf', 'paid': paid,
      'read_lines': lines,
      'document': {
        'id': id + 100, 'supplier_name': supplier, 'registration_number': reg, 'doc_number': 'INV-$id',
        'storage_path': '2026/10/$id.pdf', 'file_name': '請求書$id.pdf', 'sha256': 'abc$id', 'totals': totals,
      },
    };

Map<String, dynamic> _line(int no, String qty, String unit, String amount, {String? rate, String? unitTax, List<String> flags = const []}) => {
      'line_no': no, 'jan': '4909999000014', 'name': 'テストペン', 'code': 'TP-$no', 'maker': 'テスト', 'quantity': qty,
      if (unit.isNotEmpty) 'unit_price': unit, if (amount.isNotEmpty) 'amount': amount,
      if (rate != null) 'tax_rate': rate, if (unitTax != null) 'unit_price_tax': unitTax, 'flags': flags,
    };

void main() {
  test('the same invoice taken in twice: the later one is marked, the first is not', () {
    final first = _import(19, '2026-08-19', [_line(1, '500', '63.6', '31800')], supplier: 'アケボノ');
    final again = _import(20, '2026-08-19', [_line(1, '500', '63.6', '31800')], supplier: 'アケボノ');
    (again['document'] as Map)['sha256'] = 'abc19';
    final other = _import(21, '2026-08-20', [_line(1, '1', '100', '100')]);
    final month = TaxMonth.group([TaxPurchase.fromJson(again), TaxPurchase.fromJson(first), TaxPurchase.fromJson(other)]).single;
    final by = {for (final p in month.purchases) p.importId: p};
    expect(by[19]!.doubts, isNot(contains('duplicate')));
    expect(by[20]!.sameAs, 19);
    expect(by[20]!.doubts, contains('duplicate'));
    expect(by[21]!.sameAs, isNull);
    expect(month.doubtful, greaterThanOrEqualTo(1));
    // Without the file's fingerprint: the same supplier, number, date and total.
    final a = _import(30, '2026-08-19', [_line(1, '2', '50', '100')]);
    final b = _import(31, '2026-08-19', [_line(1, '2', '50', '100')]);
    for (final j in [a, b]) {
      (j['document'] as Map)
        ..['sha256'] = null
        ..['doc_number'] = 'INV-1';
    }
    final m2 = TaxMonth.group([TaxPurchase.fromJson(a), TaxPurchase.fromJson(b)]).single;
    expect(m2.purchases.firstWhere((p) => p.importId == 31).sameAs, 30);
  });

  test('税抜 from the lines, tax once per invoice and rate (切り捨て), 税込; a left-out row does not count', () {
    final p = TaxPurchase.fromJson(_import(18, '2026-09-01', [
      _line(1, '100', '440', '44000'),
      _line(2, '3000', '49', '147000'),
      _line(3, '10', '100', '1000', flags: ['human_removed']),
      _line(4, '3', '33', '99', rate: '8%'),
    ], totals: {'doc_total': 210012}));
    expect(p.byRate[10]!.net, 191000);
    expect(p.byRate[10]!.tax, 19100);
    expect(p.byRate[8]!.net, 99);
    expect(p.byRate[8]!.tax, 7); // 7.92 → 7
    expect(p.gross, 210206);
    expect(p.agrees, isFalse); // the document says otherwise
    expect(p.qualified, isTrue);
    expect(p.doubts, ['totals']);
  });

  test('a row priced only 税込 is worked back to 税抜; rates as printed', () {
    expect(TaxLine.rateOf(''), 10);
    expect(TaxLine.rateOf('10%'), 10);
    expect(TaxLine.rateOf('8%'), 8);
    expect(TaxLine.rateOf('軽減'), 8);
    expect(TaxLine.rateOf('0.08'), 8);
    expect(TaxLine.rateOf('非課税'), 0);
    final p = TaxPurchase.fromJson(_import(5, '2026-08-19', [_line(1, '2', '', '', unitTax: '110')], reg: null));
    expect(p.taxLines.single.net, closeTo(200, 0.001));
    expect(p.tax, 20);
    expect(p.doubts, contains('no_registration'));
  });

  test('one rate and the tax printed: the document’s tax is the invoice’s', () {
    final p = TaxPurchase.fromJson(_import(9, '2026-09-02', [_line(1, '3', '333', '999')], totals: {'doc_tax': 100, 'doc_total': 1099}));
    expect(p.tax, 100);
    expect(p.agrees, isTrue);
  });

  test('the month’s workbook: invoices with 税抜・消費税 by rate and 税込, evidence names, totals; the ZIP holds the originals',
      () {
    final m = TaxMonth.group([
      TaxPurchase.fromJson(_import(18, '2026-09-01', [_line(1, '100', '440', '44000')], paid: true)),
      TaxPurchase.fromJson(_import(20, '2026-09-15', [_line(1, '10', '100', '1000')], reg: null, supplier: 'B社')),
    ]).single;
    expect(m.month, DateTime(2026, 9));
    expect(m.keptTill, DateTime(2033, 9, 29));
    final book = buildTaxWorkbook(m, now: DateTime(2026, 10, 29, 9));
    final rows = readXlsx(book);
    expect(rows[0][0], '2026年9月分 仕入一覧');
    final head = rows[2];
    expect(head.take(5), ['日付', '仕入先', '登録番号', '適格請求書', '請求書番号']);
    final first = rows[3];
    expect(first[0], '2026/09/01');
    expect(first[1], '新東光通商株式会社');
    expect(first[head.indexOf('10%対象 税抜')], '44000');
    expect(first[head.indexOf('10% 消費税')], '4400');
    expect(first[head.indexOf('税込合計')], '48400');
    expect(first[head.indexOf('支払')], '振込済');
    expect(first[head.indexOf('証拠ファイル')], '20260901_新東光通商株式会社_取込18.pdf');
    expect(rows[4][head.indexOf('備考・要確認')], contains('登録番号なし'));
    expect(rows.last[0], '合計（2件）');
    expect(rows.last[head.indexOf('税込合計')], '49500');

    final zip = ZipDecoder().decodeBytes(buildTaxZip(m, book, {18: Uint8List.fromList([1, 2, 3])}));
    final names = zip.files.map((f) => f.name).toList();
    expect(names, containsAll(['2026-09_仕入一覧.xlsx', '証拠/20260901_新東光通商株式会社_取込18.pdf', '不足.txt']));
  });

  testWidgets('税理士用ファイル: a month with its totals and invoices; its Excel downloaded (0168)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <String>[];
    await pumpApp(tester, const TaxFilesScreen(initialYear: 2026), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u1', email: 'a@b.test', name: '経理', permissions: ['report.view']))),
      taxFilesRepositoryProvider.overrideWithValue(_Repo([
        TaxPurchase.fromJson(_import(18, '2026-09-01', [_line(1, '100', '440', '44000')])),
        TaxPurchase.fromJson(_import(19, '2026-08-19', [_line(1, '10', '100', '1000')], reg: null, supplier: 'アケボノ')),
      ])),
      taxFileSaverProvider.overrideWithValue((name, bytes) async => saved.add(name)),
    ]);
    expect(find.byKey(const ValueKey('tx-month-2026-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('tx-month-2026-8')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('tx-totals-2026-9'))).data,
        '1件　税抜 ¥44,000　消費税 ¥4,400　税込 ¥48,400');
    expect(find.byKey(const ValueKey('tx-doubt-2026-8')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tx-excel-2026-9')));
    await tester.pumpAndSettle();
    expect(saved, ['2026-09_仕入一覧.xlsx']);
    await tester.tap(find.byKey(const ValueKey('tx-zip-2026-8')));
    await tester.pumpAndSettle();
    expect(saved.last, '2026-08_仕入一覧_証拠.zip');
  });

  testWidgets('without the right the books are not shown', (tester) async {
    await pumpApp(tester, const TaxFilesScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['product.view']))),
    ]);
    expect(find.byKey(const ValueKey('tx-no-permission')), findsOneWidget);
  });
}

class _Repo implements TaxFilesRepository {
  _Repo(this.all);
  final List<TaxPurchase> all;

  @override
  Future<ApiResult<List<TaxPurchase>>> purchases(DateTime from, DateTime to) async =>
      ApiSuccess([for (final p in all) if (!p.day.isBefore(from) && !p.day.isAfter(to)) p]);

  @override
  Future<ApiResult<Uint8List>> original(TaxPurchase p) async => ApiSuccess(Uint8List.fromList([p.importId]));
}
