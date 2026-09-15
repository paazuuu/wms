import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/delivery/presentation/stock_ledger_screen.dart';
import '../../features/home/domain/feature_catalog.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/coming_soon_screen.dart';
import '../../features/home/presentation/dashboard_overview_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

/// Route paths that are not catalog features.
class AppRoutes {
  const AppRoutes._();

  static const dashboard = '/';
  static const login = '/login';
  static const splash = '/splash';
  static const search = '/search';

  /// The scan destination. A scanned JAN lands on the stock ledger for that
  /// code, so the code belongs *in* the URL — a scan is then a shareable,
  /// reloadable location rather than transient in-memory state.
  static const stockPattern = '/stock/:jan';
  static String stock(String janCode) =>
      '/stock/${Uri.encodeComponent(janCode)}';
}

/// The app's router.
///
/// Before this existed the shell held a nested [Navigator] and swapped screens
/// imperatively. That worked, but it meant the app had exactly one URL: the
/// browser's back button did nothing, no screen could be bookmarked or sent to
/// a colleague, and a reload always dropped the operator back on the dashboard.
/// For a warehouse system people keep open all day in a browser tab, that last
/// one is the expensive part.
///
/// Every top-level feature now has a real location, derived from its catalog
/// id ([FeatureEntry.path]), so the catalog stays the single source of truth
/// for both the menu and the routing table.
///
/// Detail screens reached *from* a list (a specific purchase order, one pick
/// list) are still pushed imperatively onto the shell's navigator. They keep
/// the sidebar visible and their own back button works; what they do not yet
/// have is a URL of their own. Giving them one means a route per entity with
/// typed parameters, which is a larger change than this one and is listed as
/// follow-up work rather than half-done here.
///
/// The URL strategy is left at Flutter's default (hash-based, `/#/inspection`)
/// on purpose. Path-based URLs are prettier but require the host to rewrite
/// every unknown path to `index.html`; without that rewrite a reload on
/// `/inspection` returns a 404, which would break the exact behaviour this
/// change exists to provide. Switching is one call plus a server rule.
final goRouterProvider = Provider<GoRouter>((ref) {
  final catalog = buildFeatureCatalog();

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,

    // Re-run `redirect` whenever the sign-in state changes, so signing out
    // from any screen lands on the login page and signing in returns to the
    // dashboard without either flow having to navigate by hand.
    refreshListenable: _AuthRefresh(ref),

    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      return switch (status) {
        // Still restoring a stored session: hold on the splash screen, but
        // remember where the operator was actually heading so a deep link
        // survives the restore instead of being replaced by the dashboard.
        AuthStatus.unknown =>
          loc == AppRoutes.splash ? null : AppRoutes.splash,
        AuthStatus.unauthenticated =>
          loc == AppRoutes.login ? null : AppRoutes.login,
        AuthStatus.authenticated =>
          (loc == AppRoutes.login || loc == AppRoutes.splash)
              ? AppRoutes.dashboard
              : null,
      };
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),

      // Everything below renders inside the persistent shell (sidebar + top
      // bar + tab strip). The shell keeps every open tab alive in an
      // IndexedStack, which a ShellRoute cannot express — it hands over one
      // child, and an inactive tab has to stay in the tree to keep its state.
      // So the URL decides which tab is *active* and the shell renders the
      // stack; these routes exist to resolve locations and to put them in the
      // browser's history, and build only a marker.
      ShellRoute(
        builder: (context, state, child) => const AppShell(),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const ShellRouteMarker(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (_, __) => const ShellRouteMarker(),
          ),
          GoRoute(
            path: AppRoutes.stockPattern,
            builder: (_, __) => const ShellRouteMarker(),
          ),
          for (final group in catalog)
            for (final entry in group.entries)
              GoRoute(
                path: entry.path,
                builder: (_, __) => const ShellRouteMarker(),
              ),
        ],
      ),
    ],
  );
});

/// Builds the screen for a shell location.
///
/// Lives here, beside the routing table it mirrors, and is the single place a
/// location becomes a widget. [AppShell] calls it for every open tab, which is
/// why the shell routes themselves build only a marker: if both built
/// screens, every tab would be instantiated twice and fire its initial load
/// twice with it.
///
/// Returns null for a location this app does not serve, so the caller decides
/// what an unknown tab looks like rather than having a fallback screen forced
/// on it.
Widget? screenForLocation(BuildContext context, String location) {
  if (location == AppRoutes.dashboard) return const DashboardOverviewScreen();
  if (location == AppRoutes.search) return const GlobalSearchScreen();
  if (location.startsWith('/stock/')) {
    return StockLedgerScreen(
      janCode: Uri.decodeComponent(location.substring('/stock/'.length)),
    );
  }
  for (final group in buildFeatureCatalog()) {
    for (final entry in group.entries) {
      if (entry.path == location) {
        return entry.isReady
            ? entry.builder!(context)
            : ComingSoonScreen(feature: entry);
      }
    }
  }
  return null;
}

/// What a shell route builds. The shell renders the tab stack itself — see
/// [screenForLocation] — so the route only has to resolve; the widget it
/// produces is never shown.
class ShellRouteMarker extends StatelessWidget {
  const ShellRouteMarker({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Bridges Riverpod's auth state to [GoRouter.refreshListenable], which wants
/// a [Listenable]. Notifies only when [AuthState.status] actually changes —
/// a token refresh that leaves the operator signed in should not re-run
/// redirects and risk bouncing them off the screen they are working on.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _last = ref.read(authControllerProvider).status;
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status != _last) {
        _last = next.status;
        notifyListeners();
      }
    });
  }

  late AuthStatus _last;
}
