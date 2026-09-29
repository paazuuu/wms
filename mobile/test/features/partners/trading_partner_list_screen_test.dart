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

  testWidgets('our code and their code for us are shown and can be set (0112)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeTradingPartnerRepository(partners: const [
      TradingPartner(id: 1, name: 'ウエダ商事', code: 'S00001', theirCodeForUs: '5001033', vendorCodes: 2),
    ])
      ..vendors = {
        1: const [
          PartnerVendorCode(id: 1, code: '724', makerName: '三菱鉛筆', rawMaker: 'ミツビシ'),
          PartnerVendorCode(id: 2, code: '50', rawMaker: 'ゼブラ'),
        ],
      };
    await _pump(tester, repo);
    expect(find.text('自社コード S00001 · 先方での当社 5001033'), findsOneWidget);

    await tester.tap(find.text('ウエダ商事'));
    await tester.pumpAndSettle();
    // The wholesaler's codes for its own suppliers: not ours.
    expect(find.byKey(const ValueKey('partner-vendor-724')), findsOneWidget);
    expect(find.text('三菱鉛筆'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('partner-code')), 'UEDA');
    await tester.enterText(find.byKey(const ValueKey('partner-their-code')), '5001034');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.lastCodes, (id: 1, code: 'UEDA', theirCodeForUs: '5001034'));
  });

  testWidgets('a new company without a code keeps the field empty for our rule, and its code for us is saved',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeTradingPartnerRepository();
    await _pump(tester, repo);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('空欄なら採番の規則で自動的に振ります'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '取引先名'), 'ウエダ商事');
    await tester.enterText(find.byKey(const ValueKey('partner-their-code')), '5001033');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.lastCodes?.theirCodeForUs, '5001033');
    expect(repo.lastCodes?.code, isNull);
  });

  testWidgets('the numbering rule is set per kind with a preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeTradingPartnerRepository()..issued = 3;
    await _pump(tester, repo);
    await tester.tap(find.byKey(const ValueKey('partner-code-rules')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('pc-preview-supplier'))).data, '次に振るコード：S00001');
    await tester.enterText(find.byKey(const ValueKey('pc-prefix-supplier')), 'SUP-');
    await tester.enterText(find.byKey(const ValueKey('pc-digits-supplier')), '4');
    await tester.enterText(find.byKey(const ValueKey('pc-next-supplier')), '50');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('pc-preview-supplier'))).data, '次に振るコード：SUP-0050');
    await tester.tap(find.byKey(const ValueKey('pc-save')));
    await tester.pumpAndSettle();
    expect(repo.savedFormats.single, (PartnerKind.supplier, 'SUP-', 4, 50));
    expect(find.text('採番の規則を保存しました'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pc-issue')));
    await tester.pumpAndSettle();
    expect(find.text('3社にコードを振りました'), findsOneWidget);
  });
}
