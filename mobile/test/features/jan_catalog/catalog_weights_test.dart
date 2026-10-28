import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/jan_catalog/data/jan_catalog_repository.dart';
import 'package:wms_mobile/features/jan_catalog/data/pdf_catalog_import.dart';
import 'package:wms_mobile/features/jan_catalog/data/pdf_text.dart';
import 'package:wms_mobile/features/jan_catalog/presentation/jan_catalog_screen.dart';
import 'package:wms_mobile/features/product/data/spec_lookup.dart';
import 'package:wms_mobile/features/product/presentation/product_labels.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/features/stock_import/presentation/reading_check_screen.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

import '../../support/fake_jan_catalog_repository.dart';
import '../../support/harness.dart';

// Synthetic JANs (good check digits).
const _j1 = '4909999000014';
const _j2 = '4909999000021';
const _j3 = '4909999000038';
const _j4 = '4909999000045';

class _Spec implements SpecLookupRepository {
  _Spec(this.answer);

  final SpecLookupResult Function(SpecLookupRequest) answer;
  final asked = <List<SpecLookupRequest>>[];

  @override
  Future<ApiResult<SpecLookupResult>> lookup(SpecLookupRequest item) async => ApiSuccess(answer(item));

  @override
  Future<ApiResult<SpecLookupBatch>> lookupMany(List<SpecLookupRequest> items) async {
    asked.add(items);
    return ApiSuccess((results: [for (final i in items) answer(i)], searchUnavailable: false));
  }
}

class _Reader implements PdfTextReader {
  _Reader(this.pages);

  final int pages;
  bool closed = false;

  @override
  Future<int> open(Uint8List bytes) async => pages;

  @override
  Future<List<List<Object>>> page(int n) async => n == 3
      ? const []
      : [
          [100.0, 100.0, 60.0, 'TP-$n'],
          [200.0, 100.0, 75.0, _j1],
        ];

  @override
  Future<String> sha256(Uint8List bytes) async => 'ab' * 32;

  @override
  Future<void> close() async => closed = true;
}

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  test('a weight from a catalog is said so', () {
    expect(weightSourceLabel(ja, 'catalog'), 'カタログ');
    expect(weightSourceLabel(ja, 'web'), isNot('カタログ'));
  });

  test('the AI asked a few at a time, what it found kept apart; a guess kept as a guess', () async {
    final repo = FakeJanCatalogRepository();
    final spec = _Spec((r) => switch (r.jan) {
          _j1 => const SpecLookupResult(weightG: 12, confidence: 0.9, sourceUrl: 'https://example.invalid/a'),
          _j2 => const SpecLookupResult(weightG: 30, estimated: true),
          _ => const SpecLookupResult(),
        });
    final asks = [
      for (final j in [_j1, _j2, _j3, _j4, _j1, _j2, _j3]) (jan: j, maker: 'テスト', name: 'ペン', code: 'TP-1'),
    ];
    final r = await findWeightsWithAi(spec, repo, asks);
    expect(spec.asked.map((b) => b.length), [5, 2]);
    expect(spec.asked.first.first.jan, _j1);
    expect(r.stopped, isFalse);
    expect(r.found.map((f) => [f.jan, f.weightG, f.estimated]), [
      [_j1, 12.0, false],
      [_j2, 30.0, true],
      [_j1, 12.0, false],
      [_j2, 30.0, true],
    ]);
    expect(repo.savedWeights.length, 4);
    expect(repo.savedWeights.first.sourceUrl, 'https://example.invalid/a');
  });

  test('the AI out of its daily limit: stopped, the rest not asked', () async {
    final spec = _Spec((r) => const SpecLookupResult(errorKind: 'limit'));
    final asks = [for (var i = 0; i < 12; i++) (jan: _j1, maker: null, name: 'ペン', code: null)];
    final r = await findWeightsWithAi(spec, FakeJanCatalogRepository(), asks);
    expect(r.stopped, isTrue);
    expect(spec.asked.length, 1);
  });

  test('a PDF read a page at a time, sent ten pages at once, an empty page skipped', () async {
    final repo = FakeJanCatalogRepository();
    final reader = _Reader(23);
    final seen = <int>[];
    final r = await importPdfCatalog(
      repo: repo,
      reader: reader,
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'テスト総合カタログ.pdf',
      onProgress: (p) => seen.add(p.page),
    );
    expect(r, isA<ApiSuccess<JanCatalog>>());
    expect(repo.pdfStarts.single.name, 'テスト総合カタログ');
    expect(repo.pdfStarts.single.sha256, 'ab' * 32);
    expect(repo.pdfSent.map((b) => b.length), [10, 10, 2]);
    expect(repo.pdfSent.expand((b) => b).any((p) => p.index == 3), isFalse);
    expect(seen.last, 23);
    expect((r as ApiSuccess<JanCatalog>).data.entryCount, 22);
    expect(reader.closed, isTrue);
  });

  testWidgets('a PDF chosen on the catalog screen: read, listed as a PDF', (tester) async {
    final repo = FakeJanCatalogRepository();
    await pumpApp(tester, const JanCatalogScreen(), overrides: [
      janCatalogRepositoryProvider.overrideWithValue(repo),
      pdfTextReaderProvider.overrideWithValue(_Reader(4)),
      pdfCatalogPickerProvider.overrideWithValue(() async => (name: 'テスト.pdf', bytes: Uint8List.fromList([1]))),
    ]);
    await tester.enterText(find.byKey(const ValueKey('jc-pdf-maker')), 'テスト株式会社');
    await tester.tap(find.byKey(const ValueKey('jc-pdf-pick')));
    await tester.pumpAndSettle();
    expect(repo.pdfStarts.single.maker, 'テスト株式会社');
    expect(find.byKey(const ValueKey('jc-pdf-91')), findsOneWidget);
    expect(find.text('JAN 3件（うち重量 1件）を読み込みました'), findsOneWidget);
    // A PDF is read again by choosing it again.
    expect(find.byKey(const ValueKey('jc-resync-91')), findsNothing);
  });

  testWidgets('no pdf.js (phone, desktop): said to use a PC browser', (tester) async {
    await pumpApp(tester, const JanCatalogScreen(), overrides: [pdfTextReaderProvider.overrideWithValue(null)]);
    expect(find.byKey(const ValueKey('jc-pdf-browser')), findsOneWidget);
    expect(find.byKey(const ValueKey('jc-pdf-pick')), findsNothing);
  });

  testWidgets('weights in the check table: the catalog’s, a person’s, and the AI’s for the rest', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final asked = <List<WeightAsk>>[];
    final hits = {
      _j1: const JanCatalogHit(
          jan: _j1,
          found: true,
          covered: true,
          weightG: 11.5,
          weightSource: 'catalog',
          weightText: '●重量：11.5g／パック',
          weightBasis: 'pack'),
      _j2: const JanCatalogHit(jan: _j2, found: false, covered: false, weightG: 20, weightSource: 'manual'),
      _j3: const JanCatalogHit(jan: _j3, found: false, covered: false),
      _j4: const JanCatalogHit(jan: _j4, found: false, covered: false),
    };
    await pumpApp(
      tester,
      ReadingCheckScreen(
        rows: const [
          ReadRow(lineNo: 1, jan: _j1, quantity: '1'),
          ReadRow(lineNo: 2, jan: _j2, quantity: '1'),
          ReadRow(lineNo: 3, jan: _j3, maker: 'テスト', name: 'テストペン', code: 'TP-07', quantity: '1'),
          ReadRow(lineNo: 4, jan: _j4, quantity: '1'),
        ],
        catalogLookup: (jans) async => {for (final j in jans) j: hits[j]!},
        weightLookup: (asks) async {
          asked.add(asks);
          return (
            found: [const AiWeight(jan: _j3, weightG: 8, confidence: 0.8, sourceUrl: 'https://example.invalid/p')],
            stopped: false
          );
        },
      ),
    );
    expect(find.text('重量'), findsOneWidget);
    Finder cell(int n, String text) =>
        find.descendant(of: find.byKey(ValueKey('rc-$n-weight')), matching: find.text(text));
    expect(cell(1, '11.5 g'), findsOneWidget);
    expect(cell(1, 'カタログ'), findsOneWidget);
    expect(cell(2, '20 g'), findsOneWidget);
    expect(cell(2, '登録済み'), findsOneWidget);
    // Only those with no weight were asked, with what the row says of them.
    expect(asked.single.map((a) => a.jan), [_j3, _j4]);
    expect([asked.single.first.maker, asked.single.first.name, asked.single.first.code], ['テスト', 'テストペン', 'TP-07']);
    expect(cell(3, '8 g'), findsOneWidget);
    expect(cell(3, 'AI'), findsOneWidget);
    expect(cell(4, '見つかりませんでした'), findsOneWidget);
  });

  testWidgets('looked back at: the weights known, the AI not asked', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var asked = 0;
    await pumpApp(
      tester,
      ReadingCheckScreen(
        readOnly: true,
        rows: const [ReadRow(lineNo: 1, jan: _j3, quantity: '1')],
        catalogLookup: (jans) async => {_j3: const JanCatalogHit(jan: _j3, found: false, covered: false)},
        weightLookup: (asks) async {
          asked++;
          return (found: const <AiWeight>[], stopped: false);
        },
      ),
    );
    expect(asked, 0);
    expect(find.descendant(of: find.byKey(const ValueKey('rc-1-weight')), matching: find.text('—')), findsOneWidget);
  });
}
