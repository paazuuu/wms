import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';

/// The open tabs, in strip order.
///
/// Deliberately *not* holding which tab is active: that is the router's
/// location. Two copies of "where am I" is exactly the kind of state that
/// drifts, and it already bit this shell once — the sidebar highlight used to
/// be tracked by hand and could disagree with the screen.
class TabsState {
  const TabsState({this.locations = const [AppRoutes.dashboard]});

  final List<String> locations;

  TabsState copyWith({List<String>? locations}) =>
      TabsState(locations: locations ?? this.locations);
}

/// Opens, closes and reorders the shell's tabs.
///
/// A tab is identified by its location, so opening something already open
/// activates it rather than duplicating it.
class TabsController extends StateNotifier<TabsState> {
  TabsController() : super(const TabsState());

  /// The most tabs kept at once. Past this the least recently opened is
  /// dropped: an unbounded strip becomes unreadable long before it becomes
  /// useful, and every open tab is a live screen holding its own data.
  static const maxTabs = 8;

  /// Ensures [location] has a tab, returning nothing — the caller navigates
  /// separately, because the URL is what makes it active.
  ///
  /// Idempotent, so it is safe to call on every build for the current
  /// location. That is how a deep link or a browser-back to a location with
  /// no tab yet gets one.
  void open(String location) {
    if (state.locations.contains(location)) return;

    final next = [...state.locations];

    // A scan is a stream of one-off lookups, not a set of places to keep
    // open. Fifty scans should not mean fifty tabs, so a new stock lookup
    // takes over the existing one.
    if (location.startsWith('/stock/')) {
      final existing = next.indexWhere((l) => l.startsWith('/stock/'));
      if (existing != -1) {
        next[existing] = location;
        state = state.copyWith(locations: next);
        return;
      }
    }

    next.add(location);
    // The dashboard is the one tab worth protecting from eviction: it is the
    // way back to everything else, and closing it by accident is worse than
    // losing an older feature tab.
    while (next.length > maxTabs) {
      final victim = next.indexWhere((l) => l != AppRoutes.dashboard);
      next.removeAt(victim == -1 ? 0 : victim);
    }
    state = state.copyWith(locations: next);
  }

  /// Closes [location] and returns the location to navigate to if the closed
  /// tab was the active one, or null if the caller should stay put.
  ///
  /// Returns the *neighbour* rather than always the dashboard: closing the
  /// third of four tabs should leave you next to where you were, which is
  /// how every editor and browser behaves.
  String? close(String location, {required bool isActive}) {
    final index = state.locations.indexOf(location);
    if (index == -1) return null;

    final next = [...state.locations]..removeAt(index);
    // Never leave the strip empty — there would be nothing on screen and no
    // way to get anywhere.
    if (next.isEmpty) next.add(AppRoutes.dashboard);
    state = state.copyWith(locations: next);

    if (!isActive) return null;
    return next[index.clamp(0, next.length - 1)];
  }

  /// True when [location] may be closed. The last remaining tab may not be —
  /// closing it would leave an empty content area.
  bool canClose(String location) =>
      state.locations.length > 1 && state.locations.contains(location);
}

final tabsControllerProvider =
    StateNotifierProvider<TabsController, TabsState>((ref) {
  return TabsController();
});
