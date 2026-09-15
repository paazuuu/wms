import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/router/app_router.dart';
import 'package:wms_mobile/features/home/application/tabs_controller.dart';

void main() {
  late TabsController tabs;
  setUp(() => tabs = TabsController());
  tearDown(() => tabs.dispose());

  test('starts with the dashboard open', () {
    expect(tabs.state.locations, [AppRoutes.dashboard]);
    // Nothing to close when it is the only way back to everything else.
    expect(tabs.canClose(AppRoutes.dashboard), isFalse);
  });

  test('opening appends, and opening again does not duplicate', () {
    tabs.open('/picking');
    tabs.open('/purchase-orders');
    expect(tabs.state.locations,
        [AppRoutes.dashboard, '/picking', '/purchase-orders']);

    tabs.open('/picking');
    expect(tabs.state.locations,
        [AppRoutes.dashboard, '/picking', '/purchase-orders'],
        reason: 'a tab is identified by its location');
  });

  test('a stock scan reuses the existing stock tab', () {
    tabs.open('/picking');
    tabs.open(AppRoutes.stock('4901234567894'));
    expect(tabs.state.locations.length, 3);

    // Scanning is a stream of one-off lookups; fifty scans must not mean
    // fifty tabs.
    tabs.open(AppRoutes.stock('4900000000001'));
    tabs.open(AppRoutes.stock('4900000000002'));

    expect(tabs.state.locations.length, 3);
    expect(tabs.state.locations.last, AppRoutes.stock('4900000000002'));
    // Reused in place, so the tab does not jump to the end of the strip.
    expect(tabs.state.locations[1], '/picking');
  });

  test('past the cap the oldest non-dashboard tab is dropped', () {
    final opened = <String>[];
    for (var i = 0; i < TabsController.maxTabs + 3; i++) {
      final loc = '/feature-$i';
      opened.add(loc);
      tabs.open(loc);
    }

    expect(tabs.state.locations.length, TabsController.maxTabs);
    // The dashboard survives eviction: it is the route back to everything
    // else, so losing it costs more than losing an old feature tab.
    expect(tabs.state.locations.first, AppRoutes.dashboard);
    expect(tabs.state.locations.contains(opened.first), isFalse);
    expect(tabs.state.locations.contains(opened.last), isTrue);
  });

  test('closing an inactive tab leaves the caller where they are', () {
    tabs.open('/picking');
    tabs.open('/purchase-orders');

    final next = tabs.close('/picking', isActive: false);

    expect(next, isNull);
    expect(tabs.state.locations, [AppRoutes.dashboard, '/purchase-orders']);
  });

  test('closing the active tab hands back its neighbour', () {
    tabs.open('/a');
    tabs.open('/b');
    tabs.open('/c');

    // Closing the third of four should leave you next to where you were,
    // the way an editor or a browser behaves — not back at the dashboard.
    final next = tabs.close('/b', isActive: true);

    expect(tabs.state.locations, [AppRoutes.dashboard, '/a', '/c']);
    expect(next, '/c');
  });

  test('closing the last tab in the strip falls back to its left', () {
    tabs.open('/a');
    final next = tabs.close('/a', isActive: true);

    expect(tabs.state.locations, [AppRoutes.dashboard]);
    expect(next, AppRoutes.dashboard);
  });

  test('the strip is never left empty', () {
    // Guards the invariant directly: an empty strip means an empty content
    // area with nothing to click.
    final next = tabs.close(AppRoutes.dashboard, isActive: true);

    expect(tabs.state.locations, isNotEmpty);
    expect(next, AppRoutes.dashboard);
  });

  test('closing an unopened location is a no-op', () {
    expect(tabs.close('/never-opened', isActive: false), isNull);
    expect(tabs.state.locations, [AppRoutes.dashboard]);
  });
}
