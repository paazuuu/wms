// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/partners/presentation/trading_partner_list_screen.dart';

import '../../support/harness.dart';

Future<ProviderContainer> _pump(
    WidgetTester tester, FakeTradingPartnerRepository repo) async {
  final container = ProviderContainer(overrides: [
    tradingPartnerRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  await pumpAppWith(tester, container, const TradingPartnerListScreen());
  return container;
}

void main() {
  testWidgets('lists trading partners with name, kind and contact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeTradingPartnerRepository(partners: const [
      TradingPartner(
        id: 1,
        name: 'テスト商事株式会社',
        kind: PartnerKind.both,
        code: 'TST01',
        contactName: '山田太郎',
        phone: '03-1234-5678',
      ),
    ]);
    await _pump(tester, repo);

    expect(find.text('テスト商事株式会社'), findsOneWidget);
    expect(find.text('山田太郎'), findsOneWidget);
    expect(find.text('03-1234-5678'), findsOneWidget);
    // "仕入先/顧客" also labels the kind filter chip, so scope to the card.
    expect(
        find.descendant(of: find.byType(Card), matching: find.text('仕入先/顧客')),
        findsOneWidget);
    expect(find.text('有効'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the empty state explains how to add the first partner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeTradingPartnerRepository();
    await _pump(tester, repo);

    expect(find.text('取引先がまだありません'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('adding a partner via the form appears in the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeTradingPartnerRepository();
    await _pump(tester, repo);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '取引先名'), 'テスト顧客商事');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('テスト顧客商事'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'tapping the status pill deactivates a partner (shown once inactive ones are visible)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeTradingPartnerRepository(partners: const [
      TradingPartner(id: 1, name: 'テスト商事株式会社'),
    ]);
    await _pump(tester, repo);

    // Reveal inactive partners too, so the row survives its own deactivation
    // (the default list is active-only).
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.text('有効'), findsOneWidget);
    await tester.tap(find.text('有効'));
    await tester.pumpAndSettle();

    expect(find.text('無効'), findsOneWidget);
  });

  testWidgets('filtering by kind shows only matching partners', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    final repo = FakeTradingPartnerRepository(partners: const [
      TradingPartner(id: 1, name: 'サプライヤーA', kind: PartnerKind.supplier),
      TradingPartner(id: 2, name: '顧客B', kind: PartnerKind.customer),
    ]);
    await _pump(tester, repo);

    expect(find.text('サプライヤーA'), findsOneWidget);
    expect(find.text('顧客B'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '顧客'));
    await tester.pumpAndSettle();

    expect(find.text('サプライヤーA'), findsNothing);
    expect(find.text('顧客B'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
