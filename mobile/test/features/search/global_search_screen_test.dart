import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/presentation/reconciliation_screen.dart';
import 'package:wms_mobile/features/delivery/presentation/stock_ledger_screen.dart';
import 'package:wms_mobile/features/picking_ops/presentation/pick_list_detail_screen.dart';
import 'package:wms_mobile/features/search/application/search_providers.dart';
import 'package:wms_mobile/features/search/domain/search_result.dart';
import 'package:wms_mobile/features/search/presentation/global_search_screen.dart';
import 'package:wms_mobile/features/shipment/presentation/shipment_detail_screen.dart';
import 'package:wms_mobile/features/transfers/presentation/transfer_detail_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('an empty query explains what can be searched, not nothing',
      (tester) async {
    final repo = FakeSearchRepository(const []);
    await pumpApp(
      tester,
      const GlobalSearchScreen(),
      overrides: [searchRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('入荷・出荷・移動の番号や商品名で横断検索できます。'), findsOneWidget);
  });

  testWidgets('typing shows results with their kind and subtitle',
      (tester) async {
    final repo = FakeSearchRepository(const [
      SearchResult(
        kind: SearchResultKind.delivery,
        id: '1',
        title: '0901',
        subtitle: '新東光通商株式会社 · open',
      ),
    ]);
    await pumpApp(
      tester,
      const GlobalSearchScreen(),
      overrides: [searchRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField), '0901');
    await tester.pumpAndSettle();

    expect(repo.lastQuery, '0901');
    expect(
        find.descendant(of: find.byType(Card), matching: find.text('0901')),
        findsOneWidget);
    expect(find.textContaining('新東光通商株式会社'), findsOneWidget);
  });

  testWidgets('no matches explains itself rather than showing nothing',
      (tester) async {
    final repo = FakeSearchRepository(const []);
    await pumpApp(
      tester,
      const GlobalSearchScreen(),
      overrides: [searchRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField), 'nomatch');
    await tester.pumpAndSettle();

    expect(find.text('一致する結果がありません'), findsOneWidget);
  });

  Future<void> expectOpensScreen<T>(
    WidgetTester tester,
    SearchResult result,
  ) async {
    final repo = FakeSearchRepository([result]);
    await pumpApp(
      tester,
      const GlobalSearchScreen(),
      overrides: [searchRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pumpAndSettle();

    await tester.tap(find.text(result.title));
    // A couple of frames for the push transition to land, short of
    // pumpAndSettle — the destination screen's own (unfaked) data load
    // never resolves, so settling would hang.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(T), findsOneWidget);
  }

  testWidgets('a stock result opens its ledger', (tester) async {
    await expectOpensScreen<StockLedgerScreen>(
      tester,
      const SearchResult(
        kind: SearchResultKind.stock,
        id: '4901234567894',
        title: 'ボールペン',
        janCode: '4901234567894',
      ),
    );
  });

  testWidgets('a delivery result opens its reconciliation screen', (tester) async {
    await expectOpensScreen<ReconciliationScreen>(
      tester,
      const SearchResult(kind: SearchResultKind.delivery, id: '1', title: '0901'),
    );
  });

  testWidgets('a shipment result opens its detail screen', (tester) async {
    await expectOpensScreen<ShipmentDetailScreen>(
      tester,
      const SearchResult(
          kind: SearchResultKind.shipment, id: '1', title: 'SHIP-0001'),
    );
  });

  testWidgets('a pick list result opens its detail screen', (tester) async {
    await expectOpensScreen<PickListDetailScreen>(
      tester,
      const SearchResult(
          kind: SearchResultKind.pickList, id: '1', title: 'SHIP-0001'),
    );
  });

  testWidgets('a transfer result opens its detail screen', (tester) async {
    await expectOpensScreen<TransferDetailScreen>(
      tester,
      const SearchResult(
          kind: SearchResultKind.transfer, id: '1', title: 'TR-000001'),
    );
  });
}
