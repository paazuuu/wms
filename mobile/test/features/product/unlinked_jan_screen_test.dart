import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/data_quality.dart';
import 'package:wms_mobile/features/product/presentation/unlinked_jan_screen.dart';

import '../../support/harness.dart';

void main() {
  group('UnlinkedJanScreen', () {
    testWidgets('shows the coverage summary and each unlinked code',
        (tester) async {
      final repo = FakeProductRepository()
        ..unlinkedJans = const [
          UnlinkedJan(
            janCode: '4900000000099',
            totalRows: 12,
            seenAs: '謎のペン',
            sources: {'stock_levels': 3, 'delivery_plan_lines': 9},
          ),
        ]
        ..coverage = const ProductIdCoverage(
            rows: 100, linked: 88, unlinked: 12, readyToSwitch: false);

      await pumpApp(
        tester,
        const UnlinkedJanScreen(),
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('88 / 100 件が紐付け済み'), findsOneWidget);
      expect(find.text('4900000000099'), findsOneWidget);
      expect(find.text('謎のペン'), findsOneWidget);
      expect(find.text('12 件'), findsOneWidget);
      expect(find.text('stock_levels: 3'), findsOneWidget);
      expect(find.text('delivery_plan_lines: 9'), findsOneWidget);
    });

    testWidgets('a code seen with no name reads as unknown, not blank',
        (tester) async {
      final repo = FakeProductRepository()
        ..unlinkedJans = const [
          UnlinkedJan(janCode: '4900000000001', totalRows: 1),
        ];

      await pumpApp(
        tester,
        const UnlinkedJanScreen(),
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('名称不明'), findsOneWidget);
    });

    testWidgets('nothing unlinked shows the healthy empty state',
        (tester) async {
      final repo = FakeProductRepository();

      await pumpApp(
        tester,
        const UnlinkedJanScreen(),
        overrides: [productRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text('未紐付けのJANコードはありません'), findsOneWidget);
    });
  });
}
