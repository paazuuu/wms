import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/application/product_naming_providers.dart';
import 'package:wms_mobile/features/product_library/data/quote_repository.dart';
import 'package:wms_mobile/features/product_library/domain/product_naming.dart';
import 'package:wms_mobile/features/product_library/domain/supplier_quote.dart';
import 'package:wms_mobile/features/product_library/presentation/quote_import_screen.dart';

import '../../support/harness.dart';

class _FakeQuoteRepository implements QuoteRepository {
  _FakeQuoteRepository(this.read_);

  final QuoteRead read_;
  int? readPartner;
  String? readFile;
  int? savePartner;
  List<Map<String, dynamic>>? saved;
  String? savedNote;

  @override
  Future<ApiResult<QuoteRead>> read({int? partnerId, required MultipartFile file}) async {
    readPartner = partnerId;
    readFile = file.filename;
    return ApiSuccess(read_);
  }

  @override
  Future<ApiResult<QuoteSaved>> save({required int partnerId, required List<Map<String, dynamic>> lines, String? note}) async {
    savePartner = partnerId;
    saved = lines;
    savedNote = note;
    return ApiSuccess(QuoteSaved(prices: lines.length, products: lines.length));
  }
}

const _quote = QuoteRead(partnerId: 4, source: 'gemini', lines: [
  {
    'jan_code': '4902778198940',
    'product_name': 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5 ｸﾛ',
    'maker': '三菱鉛筆',
    'product_code': 'UBA20105.24',
    'unit_price': 132,
    'list_price': 220,
    'discount_rate': 0.6,
    'case_quantity': 10,
    'product_id': 9,
    'product': {'id': 9, 'jan_code': '4902778198940', 'name': 'ユニボール エア 0.5 黒', 'maker': '三菱鉛筆'},
  },
  {
    'jan_code': '4902505000001',
    'product_name': 'ｻﾗｻ ﾄﾞﾗｲ 0.5 ｱｵ',
    'maker': 'ゼブラ',
    'list_price': 165,
    'discount_rate': 0.55,
    'product_id': null,
    'flags': ['unresolved'],
  },
  {'jan_code': '', 'product_name': '消しゴム', 'unit_price': 50, 'product_id': null, 'flags': ['unresolved']},
]);

PlatformFile _file() => PlatformFile(name: 'mitsumori.pdf', size: 3, bytes: Uint8List.fromList([1, 2, 3]));

void main() {
  test('a line reads its price from the unit price, else list price × rate', () {
    expect(QuoteLine.price(_quote.lines[0]), 132);
    expect(QuoteLine.price(_quote.lines[1]), closeTo(90.75, 0.001));
    expect(QuoteLine.hasJan(_quote.lines[2]), isFalse);
    expect(QuoteLine.toSaveJson(_quote.lines[0])['product_id'], 9);
    expect(QuoteSaved.fromJson(const {'prices': 2, 'products': 3, 'skipped': 1}).skipped, 1);
  });

  testWidgets('a quotation is read for its supplier, new products registered and prices saved', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final quotes = _FakeQuoteRepository(_quote);
    final naming = FakeProductNamingRepository(proposals: const [
      ProductProposal(row: 1, janCode: '4902505000001', maker: 'ゼブラ', baseName: 'サラサドライ', attributes: {'size': '0.5'}),
    ]);
    await pumpApp(
      tester,
      QuoteImportScreen(pickFile: () async => _file()),
      overrides: [
        quoteRepositoryProvider.overrideWithValue(quotes),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
          Product(id: 9, janCode: '4902778198940', name: 'ユニボール エア 0.5 黒'),
        ])),
        productNamingRepositoryProvider.overrideWithValue(naming),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
          TradingPartner(id: 5, name: 'お客様商店', kind: PartnerKind.customer),
        ])),
      ],
    );

    // Reading waits for a file only.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('quote-read'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('quote-partner')));
    await tester.pumpAndSettle();
    // Only suppliers are offered.
    expect(find.text('お客様商店'), findsNothing);
    await tester.tap(find.text('新東光通商').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-read')));
    await tester.pumpAndSettle();

    expect(quotes.readPartner, 4);
    expect(quotes.readFile, 'mitsumori.pdf');
    expect(find.text('3行：登録済み 1・新しい商品 1・JANなし 1'), findsOneWidget);
    // Our name, with theirs beneath, widened from half-width kana.
    expect(find.text('ユニボール エア 0.5 黒'), findsOneWidget);
    // Each line sorted into its parts, under their names.
    expect(find.text('品名 ユニボール エア 0.5 クロ', findRichText: true), findsOneWidget);
    expect(find.text('品番 UBA20105.24', findRichText: true), findsOneWidget);
    expect(find.text('メーカー 三菱鉛筆', findRichText: true), findsOneWidget);
    expect(find.text('単価 ¥132', findRichText: true), findsOneWidget);
    expect(find.text('掛率 55%', findRichText: true), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quote-register')));
    await tester.pumpAndSettle();
    expect(naming.lastProposePartner, 4);
    expect(naming.lastProposeLines!.single['jan_code'], '4902505000001');
    await tester.tap(find.byKey(const ValueKey('rp-register')));
    await tester.pumpAndSettle();
    expect(find.text('3行：登録済み 2・新しい商品 0・JANなし 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quote-save')));
    await tester.pumpAndSettle();
    expect(quotes.savePartner, 4);
    expect([for (final l in quotes.saved!) l['product_id']], [9, 500]);
    expect(quotes.savedNote, 'mitsumori.pdf');
  });

  testWidgets('a file is read with no supplier chosen; the company on it is used, else prices wait', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final quotes = _FakeQuoteRepository(const QuoteRead(partnerId: null, lines: [
      {'jan_code': '4902778198940', 'product_name': 'エア', 'unit_price': 100, 'product_id': 9,
       'product': {'id': 9, 'name': 'ユニボール エア'}},
    ]));
    await pumpApp(
      tester,
      QuoteImportScreen(pickFile: () async => _file()),
      overrides: [
        quoteRepositoryProvider.overrideWithValue(quotes),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
          Product(id: 9, janCode: '4902778198940', name: 'ユニボール エア 0.5 黒'),
        ])),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
        ])),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('quote-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-read')));
    await tester.pumpAndSettle();

    expect(quotes.readPartner, isNull);
    expect(find.text('ユニボール エア'), findsOneWidget);
    // Nothing named the company: prices wait for one to be chosen.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('quote-save'))).onPressed, isNull);
    expect(find.textContaining('価格を保存するには仕入先を選んでください'), findsOneWidget);
  });

  testWidgets('the company named on the file is chosen for the person', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final quotes = _FakeQuoteRepository(_quote);
    await pumpApp(
      tester,
      QuoteImportScreen(pickFile: () async => _file()),
      overrides: [
        quoteRepositoryProvider.overrideWithValue(quotes),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
          Product(id: 9, janCode: '4902778198940', name: 'ユニボール エア 0.5 黒'),
        ])),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
        ])),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('quote-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-read')));
    await tester.pumpAndSettle();
    expect(find.text('ファイルに書かれた会社から判断しました'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quote-save')));
    await tester.pumpAndSettle();
    expect(quotes.savePartner, 4);
  });

  Future<FakeProductRepository> pumpWith(WidgetTester tester, _FakeQuoteRepository quotes, List<Product> products,
      {bool admin = true}) async {
    await tester.binding.setSurfaceSize(const Size(900, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeProductRepository(products: products)..mayLift = admin;
    await pumpApp(
      tester,
      QuoteImportScreen(pickFile: () async => _file()),
      overrides: [
        quoteRepositoryProvider.overrideWithValue(quotes),
        productRepositoryProvider.overrideWithValue(repo),
        productCanLifecycleProvider.overrideWithValue(admin),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
        ])),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('quote-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quote-read')));
    await tester.pumpAndSettle();
    return repo;
  }

  QuoteRead threeLines() => const QuoteRead(partnerId: 4, lines: [
        {'jan_code': '4900000000001', 'product_name': 'A', 'unit_price': 10, 'product_id': 1, 'product': {'id': 1, 'name': 'A'}},
        {'jan_code': '4900000000002', 'product_name': 'B', 'unit_price': 20, 'product_id': 2, 'product': {'id': 2, 'name': 'B'}},
        {'jan_code': '4900000000003', 'product_name': 'C', 'unit_price': 30, 'product_id': 3, 'product': {'id': 3, 'name': 'C'}},
      ]);

  const asleep = Product(id: 1, janCode: '4900000000001', name: 'A', status: 'inactive', lifecycleCode: 'dormant');
  const archived = Product(id: 2, janCode: '4900000000002', name: 'B', status: 'inactive', lifecycleCode: 'archived');
  const ended = Product(id: 3, janCode: '4900000000003', name: 'C', status: 'inactive', lifecycleCode: 'discontinued');

  testWidgets('by state: dormant and archived come back, discontinued stays, as prices are saved', (tester) async {
    final quotes = _FakeQuoteRepository(threeLines());
    final repo = await pumpWith(tester, quotes, const [asleep, archived, ended]);

    expect(find.text('休眠中'), findsOneWidget);
    expect(find.text('アーカイブ中'), findsOneWidget);
    expect(find.text('提供終了'), findsOneWidget);
    expect(find.text('取扱中に戻す 2件・そのまま 1件'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-1'))).value, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-2'))).value, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-3'))).value, isFalse);
    expect(find.textContaining('提供終了の商品です'), findsOneWidget);

    // The person keeps the archived one where it is.
    await tester.tap(find.byKey(const ValueKey('quote-wake-2')));
    await tester.pump();
    expect(find.text('取扱中に戻す 1件・そのまま 2件'), findsOneWidget);
    expect(find.text('価格を保存（3件）＋取扱中に戻す（1件）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quote-save')));
    await tester.pumpAndSettle();
    expect(repo.reactivateCalls.single, [1]);
    expect(quotes.saved!.length, 3);
    expect(find.text('休眠中'), findsNothing);
    expect(find.text('アーカイブ中'), findsOneWidget);
  });

  testWidgets('without the administrator only dormant products come back', (tester) async {
    final quotes = _FakeQuoteRepository(threeLines());
    final repo = await pumpWith(tester, quotes, const [asleep, archived, ended], admin: false);

    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-1'))).value, isTrue);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-2'))).onChanged, isNull);
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('quote-wake-3'))).onChanged, isNull);
    expect(find.textContaining('管理者の権限が必要です'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('quote-restore')));
    await tester.pumpAndSettle();
    expect(repo.reactivateCalls.single, [1]);
  });
}
