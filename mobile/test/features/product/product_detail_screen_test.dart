// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/supplier_product_name.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/domain/product_lot.dart';
import 'package:wms_mobile/features/product/domain/warehouse_product.dart';
import 'package:wms_mobile/features/product/presentation/product_detail_screen.dart';
import 'package:wms_mobile/features/warehouse_context/application/warehouse_providers.dart';

import '../../support/harness.dart';

const _lotTracked = Product(
  id: 1,
  janCode: '4902505632037',
  name: 'ボールペン',
  sku: 'PEN-001',
  trackingMode: TrackingMode.lot,
  baseUom: Uom(code: 'PCS', name: '個'),
  uoms: [
    ProductUom(code: 'PCS', name: '個', conversionFactor: 1, isBase: true),
    ProductUom(code: 'BOX', name: '箱', conversionFactor: 12, isBase: false),
  ],
  barcodes: [
    ProductBarcode(
      id: 11,
      barcode: '4902505632037',
      barcodeType: 'JAN',
      isPrimary: true,
      quantityPerScan: 1,
    ),
    ProductBarcode(
      id: 12,
      barcode: '14902505632034',
      barcodeType: 'CASE',
      isPrimary: false,
      quantityPerScan: 12,
      uom: 'BOX',
    ),
  ],
);

const _untracked =
    Product(id: 2, janCode: '4909999999999', name: '追跡なし品');

const _serialTracked = Product(
  id: 3,
  janCode: '4908888888888',
  name: 'シリアル品',
  trackingMode: TrackingMode.serial,
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeProductRepository repo, {
  int productId = 1,
  int? warehouseId,
  List<TradingPartner> partners = const [],
}) async {
  final container = ProviderContainer(overrides: [
    productRepositoryProvider.overrideWithValue(repo),
    tradingPartnerRepositoryProvider
        .overrideWithValue(FakeTradingPartnerRepository(partners: partners)),
  ]);
  addTearDown(container.dispose);
  if (warehouseId != null) {
    container.read(activeWarehouseIdProvider.notifier).state = warehouseId;
  }
  await pumpAppWith(
      tester, container, ProductDetailScreen(productId: productId));
  return container;
}

void main() {
  testWidgets('shows every code with what one scan of it means', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('4902505632037'), findsWidgets);
    expect(find.text('14902505632034'), findsOneWidget);
    // The primary code cannot be removed, so it shows a badge instead of a bin.
    expect(find.text('主コード'), findsOneWidget);
    // A case code carries its unit and its multiplier (0059).
    expect(find.textContaining('1スキャン = 12 BOX'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows the base unit and each pack size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    expect(find.text('PCS — 個'), findsOneWidget);
    expect(find.text('基本'), findsOneWidget);
    expect(find.text('BOX — 箱'), findsOneWidget);
    expect(find.text('12 個'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a lot-tracked product lists its lots with time left',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked])
      ..lotsByProduct = {
        1: [
          ProductLot(
            id: 5,
            lotCode: 'A-2024/05',
            expiryDate: DateTime(2027, 3, 31),
            daysToExpiry: 20,
            supplierName: '文具商事',
            serialCount: 0,
          ),
          ProductLot(
            id: 6,
            lotCode: 'OLD-1',
            expiryDate: DateTime(2026, 1, 31),
            daysToExpiry: -40,
          ),
        ],
      };
    await _pump(tester, repo);

    // Twice on purpose: the header's tracking-mode chip and the section title.
    expect(find.text('ロット'), findsNWidgets(2));
    expect(find.text('A-2024/05'), findsOneWidget);
    expect(find.textContaining('期限 2027-03-31'), findsOneWidget);
    expect(find.textContaining('文具商事'), findsOneWidget);
    // Expiring soon is a warning; already expired is a decision, so the two do
    // not share a pill.
    expect(find.text('あと20日'), findsOneWidget);
    expect(find.text('期限切れ'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('an untracked product shows no lot or serial section',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_untracked]);
    await _pump(tester, repo, productId: 2);

    // The tracking mode says these cannot exist, so an empty card inviting
    // someone to add one would be a lie.
    expect(find.text('ロット'), findsNothing);
    expect(find.text('シリアル'), findsNothing);
    // The codes and units are always there.
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('単位'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the serial filter goes to the server, not to a client-side list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_serialTracked])
      ..serialsByProduct = {
        3: [
          ProductSerial(id: 1, serialNumber: 'SN-0001', status: 'IN_STOCK'),
          ProductSerial(id: 2, serialNumber: 'SN-0002', status: 'SHIPPED'),
        ],
      };
    final container = await _pump(tester, repo, productId: 3);

    expect(find.text('SN-0001'), findsOneWidget);
    expect(find.text('SN-0002'), findsOneWidget);
    expect(find.text('在庫あり'), findsOneWidget);
    expect(find.text('出荷済'), findsWidgets);

    container.read(serialStatusFilterProvider.notifier).state = 'IN_STOCK';
    await tester.pumpAndSettle();

    expect(repo.lastSerialStatus, 'IN_STOCK');
    expect(find.text('SN-0002'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'changing a serial to HOLD goes through set_serial_status and the list reflects it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_serialTracked])
      ..serialsByProduct = {
        3: [ProductSerial(id: 1, serialNumber: 'SN-0001', status: 'IN_STOCK')],
      };
    await _pump(tester, repo, productId: 3);

    expect(find.text('在庫あり'), findsOneWidget);

    await tester.tap(find.byTooltip('ステータスを変更'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastSerialStatusChange,
        (serialId: 1, status: 'HOLD', note: null));
    // Not just the RPC call — the list on screen shows the new status too.
    expect(find.text('保留'), findsOneWidget);
    expect(find.text('在庫あり'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'a permission-denied status change shows the friendly message, not the raw RPC text (§34)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_serialTracked])
      ..serialsByProduct = {
        3: [ProductSerial(id: 1, serialNumber: 'SN-0001', status: 'IN_STOCK')],
      }
      ..failSerialStatusWith = 'not permitted: inventory.adjust required';
    await _pump(tester, repo, productId: 3);

    await tester.tap(find.byTooltip('ステータスを変更'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('inventory.adjust'), findsNothing);
    // The status on screen never changed.
    expect(find.text('在庫あり'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('with no active warehouse the settings section says so',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    // §22's settings are per warehouse, so without one there is nothing to show
    // and nothing to set.
    expect(find.text('倉庫を選ぶと設定できます'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a product with no warehouse row says there is no special handling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo, warehouseId: 1);

    expect(find.text('この倉庫には専用の設定がありません'), findsOneWidget);
    expect(find.text('設定する'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the warehouse settings show the policy beside the live numbers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    final repo = FakeProductRepository(products: const [_lotTracked])
      ..warehouseProducts = {
        (1, 1): WarehouseProduct(
          warehouseId: 1,
          productId: 1,
          defaultLocationCode: 'Z1-A-01',
          minStock: 20,
          reorderPoint: 50,
          maxStock: 200,
          pickPriority: 10,
          putawayRule: 'FIXED',
          preferredSupplierName: '文具商事',
          leadTimeDays: 7,
          onHand: 100,
          available: 10,
        ),
      };
    await _pump(tester, repo, warehouseId: 1);

    expect(find.text('Z1-A-01'), findsOneWidget);
    expect(find.text('固定ロケーション'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('文具商事'), findsOneWidget);
    // available 10 < reorder point 50, so the card says the quiet part out loud.
    expect(find.text('発注点を下回っています'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('saving the warehouse settings posts them for this warehouse',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo, warehouseId: 2);

    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '既定ロケーション'), 'Z9-B-02');
    await tester.enterText(find.widgetWithText(TextField, '発注点'), '40');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastWarehouseProduct?.warehouseId, 2);
    expect(repo.lastWarehouseProduct?.productId, 1);
    expect(repo.lastWarehouseProduct?.locationCode, 'Z9-B-02');
    expect(repo.lastWarehouseProduct?.reorderPoint, 40);
    // Now shown on the card, read back from the saved row.
    expect(find.text('Z9-B-02'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused settings save keeps the sheet open with the reason',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    final repo = FakeProductRepository(products: const [_lotTracked])
      ..failWarehouseProductWith =
          'new row for relation "warehouse_products" violates check constraint '
              '"warehouse_products_levels_check"';
    await _pump(tester, repo, warehouseId: 1);

    await tester.tap(find.text('設定する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '最小在庫'), '100');
    await tester.enterText(find.widgetWithText(TextField, '最大在庫'), '50');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('levels_check'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('adding a barcode can name a unit the product actually has',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    await tester.tap(find.text('コードを追加'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'スキャンまたはバーコードを入力'),
        '24902505632031');
    // Only this product's own units are offered: naming any other is refused by
    // the derive trigger (0059), so the form does not present the choice.
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.text('BOX').hitTestable(), findsWidgets);
    await tester.tap(find.text('BOX').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.addedBarcodes.single.barcode, '24902505632031');
    expect(repo.addedBarcodes.single.uomCode, 'BOX');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('removing a non-primary code asks first', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('このコードを削除しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    // By id, which is what `remove_product_barcode` takes.
    expect(repo.removedBarcodeIds, [12]);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('defining a pack size posts the factor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    await tester.tap(find.text('単位を追加'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASE — ケース').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '換算数'), '144');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.setUoms.single.uomCode, 'CASE');
    expect(repo.setUoms.single.factor, 144);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('removing a pack size asks first, and never offers it for the base unit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked]);
    await _pump(tester, repo);

    // Only BOX (the pack size) gets a delete button; PCS is the base unit.
    // The barcode section has its own delete icon too, so this is the one
    // after it in the unit list — not `.first`.
    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();

    expect(find.text('この単位を削除しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(repo.removedUoms.single, (productId: 1, uomCode: 'BOX'));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a refused unit removal shows the reason, not a swallowed failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    final repo = FakeProductRepository(products: const [_lotTracked])
      ..failRemoveUomWith = 'a barcode still uses unit BOX; remove the barcode first';
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.textContaining('remove the barcode first'), findsOneWidget);
    expect(repo.removedUoms, isEmpty);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('each supplier\'s name and code for the product can be recorded (0087)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    final repo = FakeProductRepository(products: const [_untracked])
      ..supplierNameList = [
        SupplierProductName(
            id: 5, supplierId: 1, supplierDisplayName: '新東光通商', productId: 2,
            supplierName: '追跡なし品（大）', supplierCode: 'SK-100'),
      ];
    await _pump(tester, repo, productId: 2, partners: [
      TradingPartner(id: 1, name: '新東光通商', kind: PartnerKind.supplier),
      TradingPartner(id: 2, name: '別の商会', kind: PartnerKind.both),
      TradingPartner(id: 3, name: 'お客様', kind: PartnerKind.customer),
    ]);

    expect(find.text('仕入先ごとの呼び名'), findsOneWidget);
    expect(find.text('追跡なし品（大）'), findsOneWidget);
    expect(find.text('新東光通商 · 品番 SK-100'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('呼び名を追加'), 200);
    await tester.tap(find.text('呼び名を追加'));
    await tester.pumpAndSettle();
    // Customers are not suppliers.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    expect(find.text('お客様'), findsNothing);
    await tester.tap(find.text('別の商会').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('supplier-name')), 'ケシゴムS');
    await tester.enterText(find.byKey(const ValueKey('supplier-code')), 'B-7');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(repo.lastSupplierName, (supplierId: 2, productId: 2, name: 'ケシゴムS', code: 'B-7'));
    expect(find.text('呼び名を保存しました'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
