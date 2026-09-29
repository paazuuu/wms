import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/notation/application/notation_providers.dart';
import 'package:wms_mobile/features/notation/domain/notation.dart';
import 'package:wms_mobile/features/notation/presentation/field_library_screen.dart';
import 'package:wms_mobile/features/notation/presentation/notation_labels.dart';
import 'package:wms_mobile/features/partners/application/trading_partner_providers.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';
import 'package:wms_mobile/features/product_library/application/product_library_providers.dart';
import 'package:wms_mobile/l10n/app_localizations_ja.dart';

import '../../support/harness.dart';

Future<FakeNotationRepository> _pump(WidgetTester tester, {bool manage = true}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakeNotationRepository();
  await pumpApp(tester, const FieldLibraryScreen(), overrides: [
    notationRepositoryProvider.overrideWithValue(repo),
    productLibraryCanManageProvider.overrideWithValue(manage),
    tradingPartnerRepositoryProvider.overrideWithValue(
        FakeTradingPartnerRepository(partners: const [TradingPartner(id: 1, name: 'A商社')])),
  ]);
  return repo;
}

void main() {
  test('a field is shown by the name chosen for it, else the built-in one (0112)', () {
    final l10n = AppLocalizationsJa();
    expect(columnFieldLabel(l10n, ColumnField.jan), 'JAN');
    expect(columnFieldLabel(l10n, ColumnField.jan, const {'jan': 'JANコード'}), 'JANコード');
    expect(columnFieldLabel(l10n, ColumnField.maker, const {'jan': 'JANコード'}), l10n.ntFieldMaker);
    expect(dialectFieldLabel(l10n, 'code', const {'product_code': 'メーカー品番'}), 'メーカー品番');
    expect(columnFieldLabel(l10n, ColumnField.upstreamCode), '取引先の仕入先コード');
    expect(flagLabel(l10n, 'jan_exponent'), l10n.ntFlagJanExponent);
    expect(NotationFlag.isProblem('jan_exponent'), isTrue);
    // Shown in exponent form but read whole: a warning, not a problem (0113).
    expect(NotationFlag.isProblem('jan_display_exponent'), isFalse);
    expect(NotationFlag.isWarning('jan_display_exponent'), isTrue);
    expect(NotationFlag.isProblem('jan_code_mismatch'), isTrue);
    expect(flagLabel(l10n, 'jan_restored'), l10n.ntFlagJanRestored);
  });

  test('the chosen names are served per language', () async {
    final repo = FakeNotationRepository()
      ..labels = {
        'jan': {'ja': 'JANコード', 'en': 'Barcode'},
      };
    final c = ProviderContainer(overrides: [notationRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    await c.read(fieldLabelsProvider.future);
    expect(c.read(customFieldLabelsProvider('ja')), {'jan': 'JANコード'});
    expect(c.read(customFieldLabelsProvider('en')), {'jan': 'Barcode'});
    expect(c.read(customFieldLabelsProvider('zh')), isEmpty);
  });

  test('a line carries the company\'s supplier code and its code for us (0112)', () {
    final l = ReadLineResult.fromJson(const {'row': 1, 'upstream_code': '724', 'customer_code': '5001033'});
    expect(l.upstreamCode, '724');
    expect(l.customerCode, '5001033');
    expect(l.toLearnJson()['upstream_code'], '724');
    expect(l.withProduct(const ResolvedProduct(id: 1, janCode: '4902778198940', name: 'x')).upstreamCode, '724');
    expect(ColumnField.parse('customer_code'), ColumnField.customerCode);
  });

  testWidgets('every heading companies use is gathered under its field', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('fl-field-jan')), findsOneWidget);
    expect(find.text('ジャパンコード'), findsOneWidget);
    expect(find.text('Jan（A商社）'), findsOneWidget);
    expect(find.text('各社の見出し 3件'), findsOneWidget);
    expect(find.byKey(const ValueKey('fl-attr-color')), findsOneWidget);
    expect(find.text('カラー'), findsOneWidget);
  });

  testWidgets('the name the system shows is ours to choose, per language', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('fl-edit-jan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fl-label-ja')), 'JANコード');
    await tester.enterText(find.byKey(const ValueKey('fl-label-en')), 'JAN code');
    await tester.tap(find.byKey(const ValueKey('fl-save')));
    await tester.pumpAndSettle();
    expect(repo.lastLabels?.key, 'jan');
    expect(repo.lastLabels?.labels, {'ja': 'JANコード', 'en': 'JAN code'});
    expect(tester.widget<Text>(find.byKey(const ValueKey('fl-name-jan'))).data, 'JANコード');
    expect(find.text('標準の名前：JAN'), findsOneWidget);
    expect(find.text('表示名を保存しました'), findsOneWidget);
  });

  testWidgets('a heading is taught for one company, and one for an attribute', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('fl-add-jan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fl-heading')), 'ＪＡＮ　ＣＤ');
    await tester.tap(find.byKey(const ValueKey('fl-heading-partner')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A商社').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fl-heading-save')));
    await tester.pumpAndSettle();
    expect(repo.lastHeading?.partnerId, 1);
    expect(repo.lastHeading?.choice, const ColumnChoice(ColumnField.jan));

    await tester.tap(find.byKey(const ValueKey('fl-add-attr-color')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fl-heading')), 'カラー名');
    await tester.tap(find.byKey(const ValueKey('fl-heading-save')));
    await tester.pumpAndSettle();
    expect(repo.lastHeading?.partnerId, isNull);
    expect(repo.lastHeading?.choice, const ColumnChoice.attr('color'));
  });

  testWidgets('without product.manage the library is read-only', (tester) async {
    await _pump(tester, manage: false);
    expect(find.byKey(const ValueKey('fl-edit-jan')), findsNothing);
    expect(find.byKey(const ValueKey('fl-add-jan')), findsNothing);
  });
}
