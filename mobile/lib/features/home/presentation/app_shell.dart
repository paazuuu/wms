import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/l10n/language_menu.dart';
import '../../../core/router/app_router.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/global_shortcuts.dart';
import '../../../core/scan/hardware_scanner.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_scale_menu.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../warehouse_context/presentation/warehouse_picker.dart';
import '../application/sidebar_controller.dart';
import '../application/tabs_controller.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';
import 'breadcrumbs.dart';
import 'shortcuts_help.dart';

/// The authenticated app shell.
///
/// A desktop-first, shadcn-dashboard-style layout: a persistent left sidebar
/// of grouped capabilities, a top bar with an always-available scan box, a
/// strip of open tabs, and the content region. Below 900px the sidebar folds
/// into a drawer so the same shell serves handheld/tablet field use.
///
/// The shell used to own a nested [Navigator] and swap screens itself, holding
/// the current selection in a [ValueNotifier]. Routing replaced both, and the
/// sidebar highlight, breadcrumb trail and active tab are all now *derived*
/// from the current location — one source of truth for "where am I" instead
/// of several that could disagree with the screen.
///
/// The shell renders its own content rather than the [ShellRoute] child,
/// because every open tab has to stay mounted to keep its state and a
/// ShellRoute hands over exactly one child. See [_TabStack].
///
/// A [HardwareScanner] wraps the whole shell so a keyboard-wedge barcode
/// scanner works anywhere — no need to click into a field first.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Owned here rather than by the top bar so Ctrl+K can reach it: the
  /// shortcut lives at the shell, the field it focuses does not.
  final FocusNode _scanFocus = FocusNode(debugLabel: 'topbar-scan');

  @override
  void dispose() {
    _scanFocus.dispose();
    super.dispose();
  }

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Flutter web reports the host platform here too, so this covers a browser
  /// on a Mac as well as the desktop build.
  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  void _go(String location) {
    context.go(location);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  /// Route a scan from the top bar / hardware scanner to the stock ledger for
  /// that JAN — on-hand quantity plus why it changed. The code goes into the
  /// URL, so a scan result is a location an operator can reload or send on.
  void _handleScan(String code) {
    final value = code.trim();
    if (value.isEmpty) return;
    _go(AppRoutes.stock(value));
  }

  Future<void> _openCameraScan() async {
    final code = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted) return;
    if (code != null && code.isNotEmpty) _handleScan(code);
  }

  void _logout() => ref.read(authControllerProvider.notifier).logout();

  /// Jump to the nth open tab (1-based), ignoring an index past the end
  /// rather than clamping — Alt+7 with four tabs open means the operator
  /// mis-hit, and silently landing on the fourth would be worse than nothing.
  void _selectTabByIndex(int oneBased) {
    final tabs = ref.read(tabsControllerProvider).locations;
    if (oneBased < 1 || oneBased > tabs.length) return;
    _go(tabs[oneBased - 1]);
  }

  /// The shortcut bindings.
  ///
  /// Chosen around what a browser will not let us have: Ctrl+W closes the
  /// browser tab and Ctrl+1…9 switch browser tabs, so closing a tab has no
  /// shortcut at all and tab switching uses Alt rather than shipping a
  /// binding the host swallows. F1 opens the help because it is the one key
  /// that can never be mistaken for typing.
  Map<ShortcutActivator, VoidCallback> _bindings() {
    // Cmd on macOS, Ctrl everywhere else — using Ctrl on a Mac would collide
    // with text-navigation bindings.
    SingleActivator mod(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key,
            control: !_isMac, meta: _isMac, shift: shift);

    return {
      mod(LogicalKeyboardKey.keyK): () => _scanFocus.requestFocus(),
      mod(LogicalKeyboardKey.keyB): () {
        if (isWideLayout(context)) {
          ref.read(sidebarCollapsedProvider.notifier).toggle();
        }
      },
      mod(LogicalKeyboardKey.keyF, shift: true): () => _go(AppRoutes.search),
      const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsHelp,
      for (var i = 1; i <= 9; i++)
        SingleActivator(_digitKeys[i - 1], alt: true): () =>
            _selectTabByIndex(i),
    };
  }

  void _showShortcutsHelp() =>
      ShortcutsHelpDialog.show(context, isMac: _isMac);

  void _closeTab(String location, String activeLocation) {
    final next = ref
        .read(tabsControllerProvider.notifier)
        .close(location, isActive: location == activeLocation);
    if (next != null) _go(next);
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final user = ref.watch(authControllerProvider).user;
    final permissions = user?.permissions ?? const <String>[];
    final location = GoRouterState.of(context).uri.path;
    final selectedId = _selectedIdFor(location);
    final tabs = ref.watch(tabsControllerProvider).locations;

    // The router can reach a location with no tab yet — a deep link, a
    // pasted URL, browser back onto something since closed. Opening it here
    // keeps the strip a reflection of where the operator can be rather than
    // a second thing to keep in sync. Deferred a frame because it mutates
    // provider state, which must not happen during a build.
    if (!tabs.contains(location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(tabsControllerProvider.notifier).open(location);
      });
    }

    // Collapsing is a wide-layout affordance: in the drawer the sidebar is
    // already overlaid and dismissed by tapping away, so a rail there would
    // shrink something that costs no content width to begin with.
    final collapsed = wide && ref.watch(sidebarCollapsedProvider);

    Widget sidebar({required bool asRail}) => _Sidebar(
          selectedId: selectedId,
          collapsed: asRail,
          onToggleCollapse: wide
              ? () => ref.read(sidebarCollapsedProvider.notifier).toggle()
              : null,
          onOpen: (entry) => _go(entry.path),
          onDashboard: () => _go(AppRoutes.dashboard),
          onLogout: _logout,
          permissions: permissions,
          userName: user?.name,
          userEmail: user?.email,
        );

    final main = Column(
      children: [
        _TopBar(
          wide: wide,
          selectedId: selectedId,
          scanFocus: _scanFocus,
          onScan: _handleScan,
          onMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
          onCamera: _cameraSupported ? _openCameraScan : null,
          onSearch: () => _go(AppRoutes.search),
          // Only offered where there is a keyboard to press. A shortcut list
          // on a handheld is a button that teaches nothing.
          onShortcutsHelp: wide ? _showShortcutsHelp : null,
        ),
        // Hidden while only one thing is open, so the strip costs nothing
        // until the operator actually opens a second screen. Nobody has to
        // learn about tabs to use the app.
        if (tabs.length > 1)
          _TabStrip(
            tabs: tabs,
            activeLocation: location,
            onSelect: _go,
            onClose: (loc) => _closeTab(loc, location),
          ),
        Expanded(
          child: _TabStack(tabs: tabs, activeLocation: location),
        ),
      ],
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated so the content area visibly gives way rather than
              // snapping — at these widths an instant jump reads as a glitch.
              //
              // The width animates but the sidebar swaps between its two
              // forms at once, so for the duration of the tween the content
              // and its box disagree. Laying the child out at its *target*
              // width inside an OverflowBox and clipping the difference lets
              // it keep its natural layout throughout; without this the
              // expanded row is briefly squeezed into 76px and paints
              // overflow stripes on every expand.
              AnimatedContainer(
                width: collapsed ? _railWidth : _sidebarWidth,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: collapsed ? _railWidth : _sidebarWidth,
                    maxWidth: collapsed ? _railWidth : _sidebarWidth,
                    child: sidebar(asRail: collapsed),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: main),
            ],
          )
        : main;

    return GlobalShortcuts(
      bindings: _bindings(),
      child: HardwareScanner(
        onScan: _handleScan,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: wide ? null : Drawer(child: sidebar(asRail: false)),
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}

/// Maps a location back to the catalog id the sidebar should highlight.
///
/// Derived rather than remembered, so arriving at a screen by clicking the
/// sidebar, by deep link, or with the browser's back button all highlight the
/// same entry. A detail screen pushed on top of a list keeps its list's
/// location, which is what should stay highlighted anyway.
String _selectedIdFor(String path) {
  if (path == AppRoutes.dashboard) return 'dashboard';
  if (path == AppRoutes.search) return 'search';
  if (path.startsWith('/stock/')) return 'stock_lookup';
  for (final group in buildFeatureCatalog()) {
    for (final entry in group.entries) {
      if (entry.path == path) return entry.id;
    }
  }
  return 'dashboard';
}

/// The display label for a location, reusing the breadcrumb trail's own
/// resolution so a tab and its breadcrumb can never disagree about what a
/// screen is called.
String labelForLocation(AppLocalizations l10n, String location) =>
    crumbsFor(l10n, _selectedIdFor(location)).last.label;

/// The icon for a location, matched to the sidebar entry so a tab is
/// recognisable by the same glyph the menu used to open it.
IconData iconForLocation(String location) {
  if (location == AppRoutes.dashboard) return Icons.dashboard_outlined;
  if (location == AppRoutes.search) return Icons.search;
  if (location.startsWith('/stock/')) return Icons.inventory_outlined;
  for (final group in buildFeatureCatalog()) {
    for (final entry in group.entries) {
      if (entry.path == location) return entry.icon;
    }
  }
  return Icons.tab;
}

/// Keeps every open tab alive.
///
/// An [IndexedStack] rather than swapping the content widget, because the
/// whole point is that switching away and back does not cost the operator
/// their scroll position, their filters or a half-filled form. Inactive tabs
/// stay mounted; they are just not painted.
///
/// Each tab gets its own [Navigator] so a detail screen pushed from a list
/// belongs to that tab. Without this, opening an order's detail and switching
/// tabs would leave the detail sitting over the wrong screen.
class _TabStack extends StatelessWidget {
  const _TabStack({required this.tabs, required this.activeLocation});

  final List<String> tabs;
  final String activeLocation;

  @override
  Widget build(BuildContext context) {
    final index = tabs.indexOf(activeLocation);

    return IndexedStack(
      // A location the strip has not caught up with yet (the tab is opened a
      // frame later) would otherwise index to -1.
      index: index < 0 ? 0 : index,
      sizing: StackFit.expand,
      children: [
        for (final location in tabs)
          // Keyed by location so reordering or closing a tab moves the right
          // subtree rather than rebuilding its neighbour's state into it.
          KeyedSubtree(
            key: ValueKey('tab:$location'),
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (ctx) =>
                    screenForLocation(ctx, location) ??
                    const _UnknownLocation(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown for a location this build does not serve — a URL from a newer
/// version, or a feature removed since the link was shared. Says so instead
/// of rendering an empty pane.
class _UnknownLocation extends StatelessWidget {
  const _UnknownLocation();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(l10n.unknownLocation, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// The row of open tabs.
class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeLocation,
    required this.onSelect,
    required this.onClose,
  });

  final List<String> tabs;
  final String activeLocation;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      key: tabStripKey,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          for (final location in tabs)
            _Tab(
              label: labelForLocation(l10n, location),
              icon: iconForLocation(location),
              active: location == activeLocation,
              onTap: () => onSelect(location),
              // The last tab has no close button: closing it would leave an
              // empty content area and nothing to click.
              onClose: tabs.length > 1 ? () => onClose(location) : null,
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = active ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 2, vertical: AppSpacing.xs),
      child: Material(
        color: active ? scheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    color: fg,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onClose,
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The top bar: menu (narrow) / breadcrumb trail (wide) + a persistent scan
/// box. Narrow layouts get no trail on purpose — every feature screen carries
/// its own [AppBar] title, so a second copy would cost a phone two rows of
/// vertical space to say the same thing twice.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.selectedId,
    required this.scanFocus,
    required this.onScan,
    required this.onMenu,
    required this.onCamera,
    required this.onSearch,
    required this.onShortcutsHelp,
  });

  final bool wide;
  final String selectedId;
  final FocusNode scanFocus;
  final ValueChanged<String> onScan;
  final VoidCallback? onMenu;
  final Future<void> Function()? onCamera;
  final VoidCallback onSearch;
  final VoidCallback? onShortcutsHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              tooltip: l10n.menu,
              icon: const Icon(Icons.menu),
              onPressed: onMenu,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (!wide) ...[
            const BrandMark(size: 32),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (wide) Expanded(child: Breadcrumbs(selectedId: selectedId)),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Align(
                alignment: Alignment.centerRight,
                child: ScanField(
                  focusNode: scanFocus,
                  dense: true,
                  hintText: l10n.topbarScanHint,
                  onSubmitted: onScan,
                  trailing: onCamera != null
                      ? [
                          IconButton(
                            tooltip: l10n.cameraScan,
                            icon: const Icon(Icons.photo_camera_outlined),
                            onPressed: () => onCamera!(),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: l10n.searchTitle,
            icon: const Icon(Icons.search),
            onPressed: onSearch,
          ),
          if (onShortcutsHelp != null)
            IconButton(
              tooltip: l10n.shortcutsHelp,
              icon: const Icon(Icons.keyboard_outlined),
              onPressed: onShortcutsHelp,
            ),
          const SizedBox(width: AppSpacing.xs),
          const WarehousePicker(),
          const SizedBox(width: AppSpacing.xs),
          const TextScaleMenuButton(),
          const LanguageMenuButton(),
        ],
      ),
    );
  }
}

/// Expanded sidebar width, and the icon-only rail it collapses to. The rail
/// is sized to hold a 48px icon button with breathing room either side.
const double _sidebarWidth = 268;
const double _railWidth = 76;

/// Scopes tests to the sidebar. Several of its labels — the section headings
/// especially — are also rendered by the dashboard's own feature grid, so an
/// unscoped `find.text('Field Operations')` matches either one and proves
/// nothing about the sidebar.
const sidebarKey = Key('app-sidebar');

/// The sidebar's menu filter field.
const menuFilterKey = Key('app-sidebar-filter');

/// Digit keys 1-9, for the Alt+N tab shortcuts. Listed rather than computed
/// because [LogicalKeyboardKey] ids are not contiguous in a way worth
/// relying on.
const _digitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// The open-tabs strip. Absent from the tree entirely while only one tab is
/// open, which is what tests assert against.
const tabStripKey = Key('app-tab-strip');

/// The grouped navigation sidebar (shadcn-style: brand, sections, footer).
///
/// When [collapsed] it renders as an icon-only rail: labels move into
/// tooltips, section headings become dividers (a heading with no room for its
/// words is just noise), and the footer stacks vertically. Everything stays
/// reachable — collapsing trades labels for content width, it does not hide
/// features.
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.selectedId,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpen,
    required this.onDashboard,
    required this.onLogout,
    required this.permissions,
    this.userName,
    this.userEmail,
  });

  final String selectedId;
  final bool collapsed;

  /// Null in the drawer, where collapsing has no meaning.
  final VoidCallback? onToggleCollapse;

  final void Function(FeatureEntry entry) onOpen;
  final VoidCallback onDashboard;
  final VoidCallback onLogout;

  /// The signed-in user's permission codes (UI spec §37) — a group with
  /// nothing this user may open is skipped entirely rather than shown empty.
  final List<String> permissions;
  final String? userName;
  final String? userEmail;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void didUpdateWidget(_Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapsing hides the filter field. Leaving a query active behind it
    // would mean a rail showing a mysteriously short list, and expanding
    // again would restore a filter the operator had forgotten about.
    if (widget.collapsed && !oldWidget.collapsed) _clear();
  }

  void _clear() {
    _filter.clear();
    if (_query.isNotEmpty) setState(() => _query = '');
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final groups = buildFeatureCatalog();
    final selectedId = widget.selectedId;
    final collapsed = widget.collapsed;
    final permissions = widget.permissions;

    // Applied to the dashboard entry too, so filtering narrows the whole menu
    // rather than everything-except-the-first-item.
    final dashboardMatches = _query.trim().isEmpty ||
        l10n.navDashboard.toLowerCase().contains(_query.trim().toLowerCase());

    final visibleByGroup = {
      for (final group in groups)
        group: group
            .visibleEntries(permissions)
            .where((e) => e.matchesQuery(l10n, _query))
            .toList(),
    };
    final nothingMatched = !dashboardMatches &&
        visibleByGroup.values.every((entries) => entries.isEmpty);

    return Container(
      key: sidebarKey,
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            collapsed: collapsed,
            onToggleCollapse: widget.onToggleCollapse,
          ),
          const Divider(height: 1),
          // No field on the rail: 76px cannot hold a usable text input, and
          // the icons are few enough there to scan by eye.
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
              child: TextField(
                key: menuFilterKey,
                controller: _filter,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.menuFilter,
                  prefixIcon: const Icon(Icons.filter_list, size: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  // Only offered once there is something to clear, so the
                  // field is not permanently carrying a dead button.
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              children: [
                if (nothingMatched)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      l10n.menuFilterNoMatch,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (dashboardMatches)
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    label: l10n.navDashboard,
                    selected: selectedId == 'dashboard',
                    collapsed: collapsed,
                    onTap: widget.onDashboard,
                  ),
                for (final group in groups) ...() {
                  final visible = visibleByGroup[group]!;
                  if (visible.isEmpty) return const <Widget>[];
                  return <Widget>[
                    // A rail has no room for the heading's words, so the
                    // grouping is carried by a rule instead of a truncated
                    // label.
                    if (collapsed)
                      const Divider(
                        height: AppSpacing.lg,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                        child: Text(
                          group.title(l10n).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    for (final entry in visible)
                      _SidebarItem(
                        icon: entry.icon,
                        label: entry.label(l10n),
                        selected: selectedId == entry.id,
                        collapsed: collapsed,
                        onTap: () => widget.onOpen(entry),
                      ),
                  ];
                }(),
              ],
            ),
          ),
          const Divider(height: 1),
          _Footer(
            collapsed: collapsed,
            onLogout: widget.onLogout,
            userName: widget.userName,
            userEmail: widget.userEmail,
          ),
        ],
      ),
    );
  }
}

/// Brand block plus the collapse toggle.
///
/// The toggle lives here rather than in the top bar because it acts on the
/// sidebar, and a control sitting on the thing it resizes needs no label to
/// explain itself.
class _Header extends StatelessWidget {
  const _Header({required this.collapsed, required this.onToggleCollapse});

  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final toggle = onToggleCollapse == null
        ? null
        : IconButton(
            tooltip: collapsed ? l10n.sidebarExpand : l10n.sidebarCollapse,
            icon: Icon(
              collapsed ? Icons.chevron_right : Icons.chevron_left,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: onToggleCollapse,
          );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            const BrandMark(size: 32),
            if (toggle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              toggle,
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: [
          const BrandMark(size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: theme.textTheme.titleMedium),
                Text(
                  l10n.brandSubtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (toggle != null) toggle,
        ],
      ),
    );
  }
}

/// Signed-in operator plus the per-operator controls (text size, language,
/// sign out). Stacks vertically on the rail, where three buttons in a row
/// would not fit.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.collapsed,
    required this.onLogout,
    this.userName,
    this.userEmail,
  });

  final bool collapsed;
  final VoidCallback onLogout;
  final String? userName;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final name = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim()
        : l10n.operatorName;

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: scheme.surfaceContainerHigh,
      child: Icon(Icons.person_outline,
          size: 20, color: scheme.onSurfaceVariant),
    );

    final signOut = IconButton(
      tooltip: l10n.signOut,
      icon: const Icon(Icons.logout),
      onPressed: onLogout,
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            // Who is signed in is the one thing the rail cannot show, so the
            // avatar carries it in a tooltip rather than dropping it.
            Tooltip(
              message: userEmail == null || userEmail!.isEmpty
                  ? name
                  : '$name\n$userEmail',
              child: avatar,
            ),
            const SizedBox(height: AppSpacing.xs),
            const TextScaleMenuButton(),
            const LanguageMenuButton(),
            signOut,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (userEmail != null && userEmail!.isNotEmpty)
                  Text(
                    userEmail!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const TextScaleMenuButton(),
          const LanguageMenuButton(),
          signOut,
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurface;

    final content = collapsed
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Icon(icon, size: 22, color: fg),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

    final item = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          // The label is the only way to tell these apart once it is hidden,
          // so on the rail it has to be somewhere — a tooltip keeps it one
          // hover away instead of gone.
          child: collapsed ? Center(child: content) : content,
        ),
      ),
    );

    return collapsed
        ? Tooltip(message: label, waitDuration: const Duration(milliseconds: 300), child: item)
        : item;
  }
}
