import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/product_name.dart';
import 'package:wms_mobile/features/product/presentation/product_list_screen.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

import '../../support/harness.dart';

Widget _in(String lang) => MaterialApp(
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
      ],
      home: const Scaffold(
        body: ProductNameText(name: 'サラサドライ 0.5 青', nameEn: 'Zebra Sarasa Dry 0.5 Blue'),
      ),
    );

void main() {
  test('half-width kana is widened, voiced marks joined', () {
    expect(widenKana('C_2穴ﾊﾞｲﾝﾀﾞｰA4ﾗｲﾄﾌﾞﾙ'), 'C_2穴バインダーA4ライトブル');
    expect(widenKana('ﾎﾟﾝ ｺｸﾖ'), 'ポン コクヨ');
    expect(widenKana('JAN 4901'), 'JAN 4901');
  });

  testWidgets('Japanese screens show the English name under the Japanese one', (tester) async {
    await tester.pumpWidget(_in('ja'));
    expect(find.text('サラサドライ 0.5 青'), findsOneWidget);
    expect(find.text('Zebra Sarasa Dry 0.5 Blue'), findsOneWidget);
  });

  testWidgets('Chinese and English screens show the English name only', (tester) async {
    for (final lang in ['zh', 'en']) {
      await tester.pumpWidget(_in(lang));
      expect(find.text('Zebra Sarasa Dry 0.5 Blue'), findsOneWidget);
      expect(find.text('サラサドライ 0.5 青'), findsNothing);
    }
  });

  testWidgets('the product library switches between the list and the photos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const ProductListScreen());
    expect(find.text('商品ライブラリー'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    // The same list, drawn as pictures, with the same filters.
    expect(find.byKey(const ValueKey('pf-without-images')), findsOneWidget);
    expect(find.byKey(const ValueKey('pf-maker')), findsOneWidget);
  });
}
