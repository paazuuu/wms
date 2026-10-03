import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
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
  Future<ApiResult<QuoteRead>> read({required int partnerId, required MultipartFile file}) async {
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
        productNamingRepositoryProvider.overrideWithValue(naming),
        tradingPartnerRepositoryProvider.overrideWithValue(FakeTradingPartnerRepository(partners: const [
          TradingPartner(id: 4, name: '新東光通商', kind: PartnerKind.supplier),
          TradingPartner(id: 5, name: 'お客様商店', kind: PartnerKind.customer),
        ])),
      ],
    );

    // Reading waits for a supplier and a file.
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
    expect(find.text('仕入先の表記: ユニボール エア 0.5 クロ'), findsOneWidget);
    expect(find.textContaining('単価 ¥132'), findsOneWidget);
    expect(find.textContaining('掛率 55%'), findsOneWidget);

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
}
