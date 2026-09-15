import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wms_mobile/core/router/app_router.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/home/presentation/breadcrumbs.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// Resolves a real [AppLocalizations] so the trail is asserted against the
/// same strings the sidebar renders, not test doubles that could drift.
Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  test('the dashboard is a single, unlinked crumb', () async {
    final l10n = await _l10n();
    final crumbs = crumbsFor(l10n, 'dashboard');

    expect(crumbs.map((c) => c.label), ['Dashboard']);
    // A lone crumb linking to the page you are already on is a button that
    // does nothing.
    expect(crumbs.single.isLink, isFalse);
  });

  test('a feature reads dashboard > section > screen', () async {
    final l10n = await _l10n();
    final crumbs = crumbsFor(l10n, 'picking');

    expect(crumbs.map((c) => c.label),
        ['Dashboard', 'Field Operations', 'Picking']);
    expect(crumbs[0].path, AppRoutes.dashboard);
    // The section groups screens without being one, so it names context
    // rather than offering a dead click.
    expect(crumbs[1].isLink, isFalse);
    expect(crumbs[2].isLink, isFalse);
  });

  test('a management feature picks up its own section', () async {
    final l10n = await _l10n();
    // The second group, to prove the trail reads the containing group rather
    // than hardcoding the first one.
    expect(crumbsFor(l10n, 'reports').map((c) => c.label),
        ['Dashboard', 'Management', 'Report builder']);
  });

  test('search and a scanned lookup hang directly off the dashboard',
      () async {
    final l10n = await _l10n();
    // Neither is a catalog entry, so neither has a sidebar section to sit
    // under — a fabricated middle step would be worse than none.
    expect(crumbsFor(l10n, 'search').map((c) => c.label).toList(),
        ['Dashboard', 'Search']);
    expect(crumbsFor(l10n, 'stock_lookup').length, 2);
  });

  test('every catalog feature produces a full three-step trail', () async {
    final l10n = await _l10n();
    for (final group in buildFeatureCatalog()) {
      for (final entry in group.entries) {
        final crumbs = crumbsFor(l10n, entry.id);
        expect(crumbs, hasLength(3), reason: entry.id);
        expect(crumbs.last.label, entry.label(l10n), reason: entry.id);
        expect(crumbs[1].label, group.title(l10n), reason: entry.id);
      }
    }
  });

  test('an unknown id falls back to the dashboard rather than an empty bar',
      () async {
    final l10n = await _l10n();
    expect(crumbsFor(l10n, 'not_a_feature').map((c) => c.label), ['Dashboard']);
  });

  testWidgets('renders the trail and navigates on an ancestor tap',
      (tester) async {
    // A real (if tiny) router, because Breadcrumbs navigates with context.go
    // and the tap is the behaviour under test — a stubbed callback would
    // verify the test's own wiring instead of the widget's.
    final router = GoRouter(
      initialLocation: '/picking',
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (_, __) => const Scaffold(body: Text('dashboard body')),
        ),
        GoRoute(
          path: '/picking',
          builder: (_, __) => const Scaffold(
            body: Breadcrumbs(selectedId: 'picking'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Field Operations'), findsOneWidget);
    expect(find.text('Picking'), findsOneWidget);
    // One chevron between each pair of steps, not a leading or trailing one.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.dashboard);
    expect(find.text('dashboard body'), findsOneWidget);
  });

  testWidgets('the section step is not tappable', (tester) async {
    final router = GoRouter(
      initialLocation: '/picking',
      routes: [
        GoRoute(
          path: '/picking',
          builder: (_, __) => const Scaffold(
            body: Breadcrumbs(selectedId: 'picking'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();

    // Exactly one InkWell in the trail: the dashboard. If the section ever
    // became tappable it would navigate nowhere, since it has no route.
    expect(
      find.descendant(
        of: find.byType(Breadcrumbs),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
  });
}
