import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/presentation/plan_import_screen.dart';
import 'package:wms_mobile/features/notation/application/notation_providers.dart';
import 'package:wms_mobile/features/notation/domain/notation.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/features/product_library/application/product_naming_providers.dart';
import 'package:wms_mobile/features/product_library/domain/product_naming.dart';

import '../../support/harness.dart';

PlatformFile _fakeFile() => PlatformFile(
      name: 'note.jpg',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

ImportPreview _previewWith(List<Map<String, dynamic>> lines) => ImportPreview(
      source: 'gemini',
      lineCount: lines.length,
      totalQuantity: lines.fold(0, (s, l) => s + (l['planned_quantity'] as int)),
      lines: lines,
      deliveryNumber: 'ABC-123',
    );

Future<void> _openReview(
  WidgetTester tester,
  FakeDeliveryRepository repo,
) async {
  // The review step stacks header fields above the line-items section in a
  // plain ListView, which only builds what fits the surface (sliver lazy
  // building) — a tall surface keeps the lines section reachable by
  // find.text() without a manual scroll.
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await pumpApp(
    tester,
    PlanImportScreen(pickFile: () async => _fakeFile()),
    overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
  );

  await tester.tap(find.text('ファイルを選ぶ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('読み取る'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reads a file and shows the extracted lines editable',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('×10'), findsOneWidget);
  });

  testWidgets('an empty read shows an explicit empty state, not nothing',
      (tester) async {
    final repo = FakeDeliveryRepository(const [], preview: _previewWith([]));

    await _openReview(tester, repo);

    expect(find.text('明細はまだありません。「行を追加」から入力できます。'), findsOneWidget);
  });

  testWidgets('editing a line changes what gets committed (§31 修正)',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '数量'), '7');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('×7'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines.single['planned_quantity'], 7);
  });

  testWidgets('deleting a line removes it from what gets committed',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
        {'jan_code': '4901234567895', 'product_name': 'ノート', 'planned_quantity': 5},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('ボールペン'), findsNothing);
    expect(find.text('ノート'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines, hasLength(1));
    expect(repo.lastCommit!.lines.single['jan_code'], '4901234567895');
  });

  testWidgets('adding a line includes it in what gets committed',
      (tester) async {
    final repo = FakeDeliveryRepository(const [], preview: _previewWith([]));

    await _openReview(tester, repo);

    await tester.tap(find.text('行を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4901234567896');
    await tester.enterText(find.widgetWithText(TextField, '商品名'), '消しゴム');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '行を追加').last);
    await tester.pumpAndSettle();

    expect(find.text('消しゴム'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines.single['jan_code'], '4901234567896');
  });

  testWidgets('splitting a line produces two rows that still sum to the original',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.byIcon(Icons.call_split));
    await tester.pumpAndSettle();

    expect(find.text('ボールペン'), findsNWidgets(2));
    expect(find.text('×5'), findsNWidgets(2));

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    final lines = repo.lastCommit!.lines;
    expect(lines, hasLength(2));
    expect(
      lines.fold<int>(0, (s, l) => s + (l['planned_quantity'] as int)),
      10,
    );
  });

  testWidgets('merging duplicate JANs combines their quantities',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 4},
        {'jan_code': '4901234567894', 'product_name': '', 'planned_quantity': 6},
      ]),
    );

    await _openReview(tester, repo);

    expect(find.text('同じJANをまとめる'), findsOneWidget);
    await tester.tap(find.text('同じJANをまとめる'));
    await tester.pumpAndSettle();

    expect(find.text('×10'), findsOneWidget);
    expect(find.text('同じJANをまとめる'), findsNothing);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines, hasLength(1));
    expect(repo.lastCommit!.lines.single['planned_quantity'], 10);
  });

  testWidgets(
      'a permission-denied register shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    )..failWith = 'not permitted: receiving.confirm required';

    await _openReview(tester, repo);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit, isNull);
    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('receiving.confirm'), findsNothing);
  });

  testWidgets(
      'a line shows our product with the company writing faded, an unmatched one can be tied, '
      'and the columns go back on commit (0105)', (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: const ImportPreview(
        source: 'xlsx',
        lineCount: 2,
        totalQuantity: 15,
        deliveryNumber: 'ABC-123',
        columns: [
          ReadColumn(index: 0, header: '商品コード', field: ColumnField.jan, source: 'global'),
          ReadColumn(index: 1, header: 'Item', field: ColumnField.productName, source: 'ai'),
        ],
        lines: [
          {
            'jan_code': '4901234567894',
            'raw_jan_code': '4901234-567894',
            'maker': 'TEST BUNGU',
            'product_name': 'BALL PEN BLK',
            'planned_quantity': 10,
            'product_id': 1,
            'product': {'id': 1, 'jan_code': '4901234567894', 'name': 'ボールペン', 'maker': 'テスト文具', 'sku': 'PEN-001'},
            'matched_by': 'dialect_jan',
            'flags': <String>[],
          },
          {
            'jan_code': '',
            'maker': 'テスト',
            'product_name': 'けしごむ',
            'product_code': 'ER-9',
            'planned_quantity': 5,
            'product_id': null,
            'product': null,
            'flags': ['unresolved', 'no_jan', 'ai_disagree:product_name'],
          },
        ],
      ),
    );
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      PlanImportScreen(pickFile: () async => _fakeFile()),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
        productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
          Product(id: 1, janCode: '4901234567894', name: 'ボールペン', maker: 'テスト文具'),
          Product(id: 2, janCode: '4900000000019', name: '消しゴム', maker: 'テスト文具', sku: 'ER-9'),
        ])),
      ],
    );
    await tester.tap(find.text('ファイルを選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();

    // Ours first, the company's writing under it for checking.
    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('4901234567894 · テスト文具 · PEN-001'), findsOneWidget);
    expect(find.textContaining('先方の表記：4901234-567894 · TEST BUNGU · BALL PEN BLK'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-unresolved')), findsOneWidget);
    expect(find.textContaining('AIの読みが不一致：品名'), findsOneWidget);
    // A missing JAN alone is no problem when the 品番 places it.
    expect(find.textContaining('JANなし'), findsNothing);
    expect(find.text('商品コード → JAN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-pick-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-picker-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-unresolved')), findsNothing);
    expect(find.text('消しゴム'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();
    final sent = repo.lastCommit!;
    expect(sent.lines[1]['product_id'], 2);
    expect(sent.lines[1]['matched_by'], 'manual');
    // The company's own writing still travels, to be learned.
    expect(sent.lines[1]['product_name'], 'けしごむ');
    expect(sent.toJson()['columns'], [
      {'index': 0, 'header': '商品コード', 'field': 'jan'},
      {'index': 1, 'header': 'Item', 'field': 'product_name'},
    ]);
  });

  testWidgets('new products on the note are registered in our format and its lines tied to them (0111)',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: const ImportPreview(
        source: 'xlsx',
        lineCount: 2,
        totalQuantity: 12,
        deliveryNumber: 'Q-1',
        partnerId: 4,
        lines: [
          {
            'jan_code': '4902505000001',
            'maker': 'ﾐﾂﾋﾞｼ',
            'product_name': 'ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ',
            'unit': 'ﾎﾝ',
            'list_price': 200,
            'planned_quantity': 10,
            'flags': ['unresolved'],
          },
          {'jan_code': '', 'product_name': 'けしごむ', 'planned_quantity': 2, 'flags': ['unresolved']},
        ],
      ),
    );
    final naming = FakeProductNamingRepository(proposals: const [
      ProductProposal(row: 0, janCode: '4902505000001', maker: '三菱鉛筆', baseName: 'ユニボール エア', attributes: {'size': '0.5mm'}),
    ]);
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      PlanImportScreen(pickFile: () async => _fakeFile()),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
        productLibraryCanManageProvider.overrideWithValue(true),
        productNamingRepositoryProvider.overrideWithValue(naming),
      ],
    );
    await tester.tap(find.text('ファイルを選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-register-products')));
    await tester.pumpAndSettle();
    expect(naming.lastProposePartner, 4);
    expect(naming.lastProposeLines?.single['row'], 0);
    await tester.tap(find.byKey(const ValueKey('rp-register')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-register-products')), findsNothing);

    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();
    final sent = repo.lastCommit!.lines;
    expect(sent.first['product_id'], 500);
    expect(sent.first['flags'], isEmpty);
    expect(sent.last['product_id'], isNull);
  });

  testWidgets('JAN warnings are counted at the top, and each can be said to be right or wrong (0113)',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: const ImportPreview(
        source: 'xlsx',
        lineCount: 2,
        totalQuantity: 70,
        deliveryNumber: 'Q-2',
        partnerId: 4,
        lines: [
          {
            'jan_code': '4901480344041',
            'raw_jan_code': '4901480344041',
            'product_name': 'バインダー',
            'planned_quantity': 60,
            'flags': ['jan_display_exponent'],
          },
          {
            'jan_code': '4902778198940',
            'raw_jan_code': '4.90278E+12',
            'product_code': 'UBA20105.15',
            'planned_quantity': 10,
            'product_id': 9,
            'product': {'id': 9, 'jan_code': '4902778198940', 'name': 'ユニボール エア'},
            'flags': ['jan_restored'],
            'alternatives': {'code_product': 'ユニボール エア (4902778198940)'},
          },
        ],
      ),
    );
    final notation = FakeNotationRepository();
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      PlanImportScreen(pickFile: () async => _fakeFile()),
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
        notationRepositoryProvider.overrideWithValue(notation),
      ],
    );
    await tester.tap(find.text('ファイルを選ぶ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-jan-warnings')), findsOneWidget);
    expect(find.textContaining('JANの確認が必要な行が1行'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-jan-display')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-code-product')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-warning-jan_restored')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wr-note')), '品番の読み違い');
    await tester.tap(find.byKey(const ValueKey('wr-wrong')));
    await tester.pumpAndSettle();
    final r = notation.reports.single;
    expect(r.flag, 'jan_restored');
    expect(r.right, isFalse);
    expect(r.partnerId, 4);
    expect(r.note, '品番の読み違い');
    expect(r.line?['raw_jan_code'], '4.90278E+12');
    expect(find.text('報告しました。警告の見直しに使います'), findsOneWidget);
  });
}
