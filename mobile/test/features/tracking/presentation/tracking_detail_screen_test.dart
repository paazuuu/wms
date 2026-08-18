import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/products/domain/product.dart';
import 'package:wms_mobile/features/tracking/application/tracking_providers.dart';
import 'package:wms_mobile/features/tracking/data/tracking_repository.dart';
import 'package:wms_mobile/features/tracking/domain/product_batch.dart';
import 'package:wms_mobile/features/tracking/domain/product_serial.dart';
import 'package:wms_mobile/features/tracking/presentation/tracking_detail_screen.dart';

/// In-memory fake so the tracing detail renders without a network.
class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({this.batchList = const [], this.serialList = const []});

  final List<ProductBatch> batchList;
  final List<ProductSerial> serialList;

  @override
  Future<ApiResult<List<ProductBatch>>> batches(int productId) async =>
      ApiSuccess(batchList);

  @override
  Future<ApiResult<List<ProductSerial>>> serials(int productId) async =>
      ApiSuccess(serialList);
}

const _product = Product(id: 3, sku: 'SKU-3', name: 'Widget');

Widget _wrap(TrackingRepository repo) => ProviderScope(
      overrides: [
        trackingRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TrackingDetailScreen(product: _product)),
    );

void main() {
  testWidgets('renders batches and serials for the product', (tester) async {
    final repo = _FakeTrackingRepository(
      batchList: const [
        ProductBatch(
          id: 1,
          productId: 3,
          batchNumber: 'LOT-A',
          quantity: 10,
          expiryDate: '2027-01-01',
        ),
      ],
      serialList: const [
        ProductSerial(
          id: 2,
          productId: 3,
          serialNumber: 'SN-9',
          status: 'available',
        ),
      ],
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Widget'), findsOneWidget);
    expect(find.text('LOT-A'), findsOneWidget);
    expect(find.text('SN-9'), findsOneWidget);
    expect(find.text('available'), findsOneWidget);
    expect(find.text('Batches'), findsOneWidget);
    expect(find.text('Serials'), findsOneWidget);
  });

  testWidgets('shows empty messages when there is no tracking data',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeTrackingRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No batches for this product.'), findsOneWidget);
    expect(find.text('No serials for this product.'), findsOneWidget);
  });
}
