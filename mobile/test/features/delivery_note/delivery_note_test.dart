import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery_note/delivery_note.dart';
import 'package:wms_mobile/features/delivery_note/delivery_note_view_screen.dart';
import 'package:wms_mobile/features/master_import/data/master_import_repository.dart';
import 'package:wms_mobile/features/master_import/domain/master_import.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/data/web_photos.dart';
import 'package:wms_mobile/features/product/domain/product.dart';

import '../../support/fake_web_photo_repository.dart';
import '../../support/harness.dart';

const _known = '4909999000014';
const _unknown = '4909999000021';

void main() {
  test('a note line reads its JAN as a number and its count', () {
    final l = NoteLine.of(const MasterLine(
        lineNo: 3, janCode: '4909999-000014', supplierName: 'ﾃｽﾄﾍﾟﾝ', quantity: '1,200', maker: 'テスト', productCode: 'TP-1'));
    expect((l.jan, l.quantity, l.name, l.code), (_known, 1200, 'ﾃｽﾄﾍﾟﾝ', 'TP-1'));
    expect(NoteLine.of(const MasterLine(lineNo: 1, quantity: '')).quantity, isNull);
  });

  testWidgets('納品書を写して見る: each line with its picture, name, JAN and count; one with none is shown without', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = FakeMasterImportRepository(
      readResult: const MasterRead(lines: [
        MasterLine(lineNo: 1, janCode: _known, supplierName: 'ﾃｽﾄﾍﾟﾝ ｱｵ', quantity: '20', maker: 'テスト', productCode: 'TP-1'),
        MasterLine(lineNo: 2, janCode: _unknown, supplierName: 'スタンプノリ', quantity: '200'),
      ]),
    );
    final asked = <bool>[];
    await pumpApp(tester, const DeliveryNoteViewScreen(), overrides: [
      masterImportRepositoryProvider.overrideWithValue(reader),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
        Product(id: 7, janCode: _known, name: 'テストペン 青', baseName: 'テストペン 青', maker: 'テスト', sku: 'TP-1', imageCount: 1),
      ])),
      deliveryNotePickerProvider.overrideWithValue(({required camera}) async {
        asked.add(camera);
        return (name: '納品書.jpg', bytes: Uint8List.fromList([1, 2, 3]));
      }),
    ]);
    await tester.tap(find.byKey(const ValueKey('dn-take')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dn-pick-camera')));
    await tester.pumpAndSettle();
    expect(asked, [true]);
    // Kept as a delivery note photographed, each row on its own.
    expect((reader.readPurpose, reader.readKeptRows), ('ocr', true));
    expect(find.text('テストペン 青'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('dn-qty-1'))).data, '20');
    expect(tester.widget<Text>(find.byKey(const ValueKey('dn-jan-2'))).data, 'JAN $_unknown');
    expect(find.byKey(const ValueKey('dn-nophoto-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('dn-nophoto-1')), findsNothing);
    expect(find.text('2行・合計 220個（確認 0行）'), findsOneWidget);
    // Seen, by a tap.
    await tester.tap(find.byKey(const ValueKey('dn-line-2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('dn-seen-2')), findsOneWidget);
    expect(find.text('2行・合計 220個（確認 1行）'), findsOneWidget);
  });

  testWidgets('a good not in the library shows the picture kept for its JAN, asked from the database first (0179)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photos = FakeWebPhotoRepository(kept: {_unknown: 'https://example.test/jan/$_unknown.jpg'});
    await pumpApp(tester, const DeliveryNoteViewScreen(lines: [
      NoteLine(lineNo: 1, jan: _known, name: 'ﾃｽﾄﾍﾟﾝ', quantity: 20),
      NoteLine(lineNo: 2, jan: _unknown, name: 'スタンプノリ', quantity: 200),
      NoteLine(lineNo: 3, jan: '4909999000038', name: '写真なし', quantity: 1),
    ], fileName: '納品書.jpg'), overrides: [
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
        Product(id: 7, janCode: _known, name: 'テストペン 青', baseName: 'テストペン 青', imageCount: 1),
      ])),
      webPhotoRepositoryProvider.overrideWithValue(photos),
    ]);
    await tester.pumpAndSettle();
    // Only the goods the library does not have are asked for, looked up once if never tried.
    expect(photos.janCalls.single.jans, [_unknown, '4909999000038']);
    expect(photos.janCalls.single.look, isTrue);
    expect(find.byKey(const ValueKey('dn-webphoto-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('dn-nophoto-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('dn-webphoto-1')), findsNothing);
  });
}
