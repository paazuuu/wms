import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/notation/application/notation_providers.dart';
import 'package:wms_mobile/features/notation/domain/notation.dart';
import 'package:wms_mobile/features/notation/presentation/notation_training_screen.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';

import '../../support/harness.dart';

PlatformFile _sample() => PlatformFile(
      name: 'a-shosha.xlsx',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

const _read = TrainingRead(
  trainingId: 7,
  partnerId: 1,
  source: 'xlsx',
  columns: [
    ReadColumn(index: 0, header: 'JAN CODE', field: ColumnField.jan, source: 'global'),
    ReadColumn(index: 1, header: '品名・品番', field: ColumnField.nameCode, source: 'ai'),
    ReadColumn(index: 2, header: 'ｽｳﾘｮｳ', field: ColumnField.quantity, source: 'contains'),
  ],
  lines: [
    ReadLineResult(
      row: 2,
      rawJanCode: '4901234-567894',
      janCode: '4901234567894',
      maker: 'TEST BUNGU',
      productName: 'ボールペン黒',
      productCode: 'BP-01',
      rawNameCode: 'ボールペン黒 BP-01',
      quantity: 10,
      flags: ['split_single'],
      product: ResolvedProduct(id: 1, janCode: '4901234567894', name: 'ボールペン', maker: 'テスト文具'),
      matchedBy: 'dialect_jan',
    ),
    ReadLineResult(
      row: 3,
      maker: 'テスト',
      productName: 'けしごむ',
      productCode: 'ER-9',
      quantity: 5,
      flags: ['unresolved', 'no_jan', 'ai_disagree:product_name'],
      alternatives: {'product_name': 'けしゴム'},
    ),
  ],
);

Future<FakeNotationRepository> _pump(
  WidgetTester tester, {
  FakeNotationRepository? repo,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final notation = repo ?? FakeNotationRepository(read: _read);
  await pumpApp(
    tester,
    NotationTrainingScreen(pickFile: () async => _sample()),
    overrides: [
      notationRepositoryProvider.overrideWithValue(notation),
      tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(
          partners: const [TradingPartner(id: 1, name: 'A商社')])),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
        Product(id: 1, janCode: '4901234567894', name: 'ボールペン', maker: 'テスト文具'),
        Product(id: 2, janCode: '4900000000019', name: '消しゴム', maker: 'テスト文具', sku: 'ER-9'),
      ])),
    ],
  );
  return notation;
}

Future<void> _choosePartnerAndRead(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nt-partner-train')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('A商社').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nt-pick')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nt-read')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a sample is read, and what went wrong is shown line by line',
      (tester) async {
    final repo = await _pump(tester);
    await _choosePartnerAndRead(tester);

    expect(repo.lastRead?.partnerId, 1);
    expect(repo.lastRead?.fileName, 'a-shosha.xlsx');
    // The summary: 2 lines, 1 of 2 converted, and problems counted.
    expect(find.byKey(const ValueKey('nt-summary-resolved')), findsOneWidget);
    expect(find.text('自社商品に変換 1/2'), findsOneWidget);
    expect(find.text('見つかった問題'), findsOneWidget);
    // Columns as understood, in the company's own headings.
    expect(find.text('品名・品番'), findsOneWidget);
    expect(find.text('ｽｳﾘｮｳ'), findsOneWidget);
    // Line 2: ours, with the split and the company's writing faded.
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('分解前：ボールペン黒 BP-01'), findsOneWidget);
    expect(find.textContaining('4901234-567894'), findsOneWidget);
    // Line 3: nothing matched yet, and the AI's two readings disagreed.
    expect(find.text('自社商品が見つかりません'), findsOneWidget);
    expect(find.text('AIの読みが不一致：品名'), findsOneWidget);
    expect(find.text('もう一方の読み（品名）：けしゴム'), findsOneWidget);
  });

  testWidgets('a line is tied to our product, then the checked sample is learned',
      (tester) async {
    final repo = await _pump(tester);
    await _choosePartnerAndRead(tester);

    expect(find.text('1行を学習する'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nt-pick-product-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-picker-2')));
    await tester.pumpAndSettle();

    expect(find.text('消しゴム'), findsOneWidget);
    expect(find.text('2行を学習する'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nt-learn')));
    await tester.pumpAndSettle();

    final learned = repo.lastLearn!;
    expect(learned.partnerId, 1);
    expect(learned.trainingId, 7);
    expect(learned.lines.last.product?.id, 2);
    expect(learned.lines.last.matchedBy, 'manual');
    // The company's writing is what gets taught, not ours.
    expect(learned.lines.last.productName, 'けしごむ');
    expect(learned.columns.map((c) => c.header), ['JAN CODE', '品名・品番', 'ｽｳﾘｮｳ']);
    expect(find.textContaining('2件を学習しました'), findsOneWidget);
  });

  testWidgets('a corrected column is sent back when read again', (tester) async {
    final repo = await _pump(tester);
    await _choosePartnerAndRead(tester);

    await tester.tap(find.byKey(const ValueKey('nt-col-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ケース数').last);
    await tester.pumpAndSettle();
    expect(find.text('直した列で読み直す'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nt-read')));
    await tester.pumpAndSettle();
    expect(repo.lastRead?.overrides, {2: ColumnField.cases});
  });

  testWidgets('a read can be discarded without learning anything', (tester) async {
    final repo = await _pump(tester);
    await _choosePartnerAndRead(tester);

    await tester.tap(find.byKey(const ValueKey('nt-discard')));
    await tester.pumpAndSettle();

    expect(repo.discarded, [7]);
    expect(repo.lastLearn, isNull);
    expect(find.byKey(const ValueKey('nt-learn')), findsNothing);
  });

  testWidgets('reading needs a company first', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('nt-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nt-read')));
    await tester.pumpAndSettle();

    expect(find.text('商社を選んでください'), findsOneWidget);
    expect(repo.lastRead, isNull);
  });

  testWidgets('the dictionary lists each writing with its id and can confirm it',
      (tester) async {
    final repo = await _pump(
      tester,
      repo: FakeNotationRepository(dialectRows: const [
        NotationDialect(
          id: 12,
          code: 'D-000012',
          field: 'jan',
          rawValue: '4901234-567894',
          rawValues: ['4901234-567894', '4901234 567894'],
          partnerId: 1,
          partnerName: 'A商社',
          productId: 1,
          productJan: '4901234567894',
          productName: 'ボールペン',
          seenCount: 3,
        ),
        NotationDialect(
          id: 13,
          code: 'D-000013',
          field: 'maker',
          rawValue: 'TEST BUNGU',
          partnerId: 1,
          partnerName: 'A商社',
          makerName: 'テスト文具',
          confirmed: true,
        ),
      ]),
    );
    await tester.tap(find.byKey(const ValueKey('nt-tab-dialects')));
    await tester.pumpAndSettle();

    expect(find.text('4901234-567894 / 4901234 567894'), findsOneWidget);
    expect(find.textContaining('D-000012'), findsOneWidget);
    expect(find.textContaining('→ ボールペン · 4901234567894'), findsOneWidget);
    expect(find.textContaining('→ テスト文具'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('nt-dialect-12')),
        matching: find.byIcon(Icons.check_circle_outline)));
    await tester.pumpAndSettle();
    expect(repo.confirmed.single.id, 12);

    await tester.tap(find.byKey(const ValueKey('nt-dialect-field-maker')));
    await tester.pumpAndSettle();
    expect(repo.lastDialectQuery?.field, 'maker');
    expect(find.byKey(const ValueKey('nt-dialect-12')), findsNothing);
    expect(find.byKey(const ValueKey('nt-dialect-13')), findsOneWidget);
  });

  testWidgets('a column heading can be taught by hand', (tester) async {
    final repo = await _pump(
      tester,
      repo: FakeNotationRepository(aliases: const [
        ColumnAlias(id: 1, header: 'JANコード', field: ColumnField.jan, source: 'seed'),
      ]),
    );
    await tester.tap(find.byKey(const ValueKey('nt-tab-columns')));
    await tester.pumpAndSettle();
    expect(find.text('JANコード'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nt-add-column')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nt-column-header')), 'ｼｮｳﾋﾝﾒｲ');
    await tester.tap(find.byKey(const ValueKey('nt-column-save')));
    await tester.pumpAndSettle();

    expect(repo.lastAlias?.header, 'ｼｮｳﾋﾝﾒｲ');
    expect(repo.lastAlias?.field, ColumnField.productName);
    expect(find.text('ｼｮｳﾋﾝﾒｲ'), findsOneWidget);
  });

  testWidgets('history shows each company and what its documents get wrong',
      (tester) async {
    await _pump(
      tester,
      repo: FakeNotationRepository(
        stats: const [
          PartnerTrainingStats(
            partnerId: 1,
            partnerName: 'A商社',
            runs: 2,
            lines: 20,
            resolved: 15,
            dialects: 8,
            columns: 3,
            flags: {'jan_check': 4, 'split_disagree': 1},
          ),
        ],
        runs: const [
          TrainingRun(id: 5, partnerName: 'A商社', fileName: 'a-shosha.xlsx', lineCount: 10, resolvedCount: 9, status: 'learned'),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('nt-tab-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nt-stats-1')), findsOneWidget);
    expect(find.text('2回・20行・変換率75%・方言8件・見出し3件'), findsOneWidget);
    expect(find.text('JANのチェック数字が不正 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('nt-run-5')), findsOneWidget);
    expect(find.text('学習済み'), findsOneWidget);
  });
}
