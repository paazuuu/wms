import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/theme/app_theme.dart';
import 'package:wms_mobile/core/theme/app_theme_style.dart';
import 'package:wms_mobile/core/theme/appearance_controller.dart';
import 'package:wms_mobile/core/theme/theme_fonts.dart';
import 'package:wms_mobile/core/theme/theme_menu.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The app root as [WmsApp] builds it: the chosen design and brightness.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceControllerProvider);
    return MaterialApp(
      theme: AppTheme.light(look.style),
      darkTheme: AppTheme.dark(look.style),
      themeMode: look.mode,
      locale: const Locale('ja'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        appBar: AppBar(actions: const [ThemeMenuButton()]),
        body: Builder(
          builder: (context) => Text('${Theme.of(context).colorScheme.primary.toARGB32()}', key: const ValueKey('primary')),
        ),
      ),
    );
  }
}

void main() {
  group('designs (Astryx themes)', () {
    for (final style in AppThemeStyle.values) {
      for (final b in Brightness.values) {
        test('${style.name} ${b.name}: text and controls stay readable', () {
          final spec = AppThemeSpec.of(style);
          final s = spec.scheme(b);
          for (final bg in [s.surface, s.surfaceContainerLow, spec.card(b)]) {
            expect(_contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5), reason: 'text on $bg');
            expect(_contrast(s.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5), reason: 'secondary text on $bg');
          }
          expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5), reason: 'button label');
          expect(_contrast(s.error, s.surface), greaterThanOrEqualTo(4.5), reason: 'error text');
          expect(_contrast(s.outline, s.surface), greaterThanOrEqualTo(3), reason: 'control edge');
          // Builds without throwing.
          expect(b == Brightness.light ? AppTheme.light(style) : AppTheme.dark(style), isA<ThemeData>());
        });
      }
    }

    test('each design keeps its typefaces and corners', () {
      expect(AppTheme.light(AppThemeStyle.stone).textTheme.titleLarge?.fontFamily, 'Montserrat');
      expect(AppTheme.light(AppThemeStyle.stone).textTheme.bodyMedium?.fontFamily, 'Figtree');
      expect(AppTheme.light(AppThemeStyle.chocolate).textTheme.headlineSmall?.fontFamily, 'Fraunces');
      expect(AppTheme.light(AppThemeStyle.chocolate).cardTheme.color, const Color(0xFFEDE4D4));
      final y2kCard = AppTheme.light(AppThemeStyle.y2k).cardTheme.shape! as RoundedRectangleBorder;
      expect(y2kCard.borderRadius, BorderRadius.zero);
      // Same sizes in every design, so no screen moves.
      for (final s in AppThemeStyle.values) {
        expect(AppTheme.light(s).textTheme.bodyMedium?.fontSize, 14);
        expect(AppTheme.light(s).textTheme.titleLarge?.fontSize, 18);
      }
    });

    test('a design\'s fonts load from the bundle when chosen', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await expectLater(ThemeFonts.ensure(AppThemeStyle.chocolate), completes);
      await expectLater(ThemeFonts.ensure(AppThemeStyle.neutral), completes);
    });

    testWidgets('the palette menu switches the design and the brightness at once', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: _App()));
      await tester.pumpAndSettle();
      String primary() => tester.widget<Text>(find.byKey(const ValueKey('primary'))).data!;
      expect(primary(), '${AppThemeSpec.neutral.light.primary.toARGB32()}');

      await tester.tap(find.byKey(const ValueKey('theme-menu')));
      await tester.pumpAndSettle();
      expect(find.text('ナチュラル'), findsOneWidget);
      expect(find.text('あたたか'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('theme-style-matcha')));
      await tester.pumpAndSettle();
      expect(primary(), '${AppThemeSpec.matcha.light.primary.toARGB32()}');

      await tester.tap(find.byKey(const ValueKey('theme-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-mode-dark')));
      await tester.pumpAndSettle();
      expect(primary(), '${AppThemeSpec.matcha.dark.primary.toARGB32()}');

      // The chosen design is ticked.
      await tester.tap(find.byKey(const ValueKey('theme-menu')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(const ValueKey('theme-style-matcha')), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('theme-style-neutral')), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });
  });
}
