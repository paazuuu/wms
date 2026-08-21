import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/l10n/language_menu.dart';
import '../../../core/scan/hardware_scanner.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/responsive.dart';
import '../../auth/application/auth_controller.dart';
import '../../inspection/presentation/barcode_scan_screen.dart';
import '../../products/presentation/product_lookup_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';
import 'coming_soon_screen.dart';
import 'dashboard_overview_screen.dart';

/// The authenticated app shell.
///
/// A desktop-first, shadcn-dashboard-style layout: a persistent left sidebar of
/// grouped capabilities, a top bar with an always-available scan box, and a
/// content region that swaps feature screens in place. Below 900px the sidebar
/// folds into a drawer so the same shell serves handheld/tablet field use.
///
/// A [HardwareScanner] wraps the whole shell so a keyboard-wedge barcode
/// scanner works anywhere — no need to click into a field first.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<String> _selected = ValueNotifier<String>('dashboard');

  late final _ContentObserver _observer =
      _ContentObserver((atRoot) {
    if (atRoot) _selected.value = 'dashboard';
  });

  late final Widget _content = Navigator(
    key: _contentNav,
    observers: [_observer],
    onGenerateRoute: (_) => MaterialPageRoute(
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(authControllerProvider).user;
          return DashboardOverviewScreen(
            onOpen: _open,
            userName: user?.name,
            userEmail: user?.email,
          );
        },
      ),
    ),
  );

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  /// Open a catalog feature in the content area.
  void _open(FeatureEntry entry) {
    _select(
      entry.id,
      (ctx) =>
          entry.isReady ? entry.builder!(ctx) : ComingSoonScreen(feature: entry),
    );
  }

  /// Reset the content navigator to the dashboard, then (unless [id] is the
  /// dashboard) push [builder]. Selection is set last so the sidebar highlight
  /// survives the observer firing during [NavigatorState.popUntil].
  void _select(String id, WidgetBuilder builder) {
    final nav = _contentNav.currentState;
    nav?.popUntil((route) => route.isFirst);
    if (id != 'dashboard') {
      nav?.push(MaterialPageRoute(builder: builder));
    }
    _selected.value = id;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  /// Route a scan from the top bar / hardware scanner to Product Lookup.
  void _handleScan(String code) {
    final value = code.trim();
    if (value.isEmpty) return;
    _select(
      'product_lookup',
      (_) => ProductLookupScreen(initialQuery: value),
    );
  }

  Future<void> _openCameraScan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted) return;
    if (code != null && code.isNotEmpty) _handleScan(code);
  }

  void _logout() => ref.read(authControllerProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final user = ref.watch(authControllerProvider).user;

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 268,
                child: _Sidebar(
                  selected: _selected,
                  onOpen: _open,
                  onDashboard: () => _select('dashboard', (_) => const SizedBox()),
                  onLogout: _logout,
                  userName: user?.name,
                  userEmail: user?.email,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _mainColumn(wide: true)),
            ],
          )
        : _mainColumn(wide: false);

    return HardwareScanner(
      onScan: _handleScan,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: wide
            ? null
            : Drawer(
                child: _Sidebar(
                  selected: _selected,
                  onOpen: _open,
                  onDashboard: () =>
                      _select('dashboard', (_) => const SizedBox()),
                  onLogout: _logout,
                  userName: user?.name,
                  userEmail: user?.email,
                ),
              ),
        body: SafeArea(child: body),
      ),
    );
  }

  Widget _mainColumn({required bool wide}) {
    return Column(
      children: [
        _TopBar(
          wide: wide,
          selected: _selected,
          scanController: null,
          onScan: _handleScan,
          onMenu: wide
              ? null
              : () => _scaffoldKey.currentState?.openDrawer(),
          onCamera: _cameraSupported ? _openCameraScan : null,
        ),
        Expanded(child: _content),
      ],
    );
  }
}

/// Maps a selected feature id to its localized display title for the top bar.
String _titleForId(AppLocalizations l10n, String id) {
  if (id == 'dashboard') return l10n.navDashboard;
  for (final group in buildFeatureCatalog()) {
    for (final entry in group.entries) {
      if (entry.id == id) return entry.label(l10n);
    }
  }
  return l10n.navDashboard;
}

/// Observes the content navigator and reports when it returns to its first
/// (dashboard) route so the sidebar highlight can follow in-content back nav.
class _ContentObserver extends NavigatorObserver {
  _ContentObserver(this.onAtRoot);

  final void Function(bool atRoot) onAtRoot;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onAtRoot(previousRoute?.isFirst ?? true);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.isFirst) onAtRoot(true);
  }
}

/// The top bar: menu (narrow) / page title (wide) + a persistent scan box.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.selected,
    required this.scanController,
    required this.onScan,
    required this.onMenu,
    required this.onCamera,
  });

  final bool wide;
  final ValueListenable<String> selected;
  final TextEditingController? scanController;
  final ValueChanged<String> onScan;
  final VoidCallback? onMenu;
  final Future<void> Function()? onCamera;

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
          if (wide)
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: selected,
                builder: (context, id, _) => Text(
                  _titleForId(l10n, id),
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Align(
                alignment: Alignment.centerRight,
                child: ScanField(
                  controller: scanController,
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
          const SizedBox(width: AppSpacing.xs),
          const LanguageMenuButton(),
        ],
      ),
    );
  }
}

/// The grouped navigation sidebar (shadcn-style: brand, sections, footer).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onOpen,
    required this.onDashboard,
    required this.onLogout,
    this.userName,
    this.userEmail,
  });

  final ValueListenable<String> selected;
  final void Function(FeatureEntry entry) onOpen;
  final VoidCallback onDashboard;
  final VoidCallback onLogout;
  final String? userName;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final groups = buildFeatureCatalog();

    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
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
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: selected,
              builder: (context, currentId, _) {
                return ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  children: [
                    _SidebarItem(
                      icon: Icons.dashboard_outlined,
                      label: l10n.navDashboard,
                      selected: currentId == 'dashboard',
                      onTap: onDashboard,
                    ),
                    for (final group in groups) ...[
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
                      for (final entry in group.entries)
                        _SidebarItem(
                          icon: entry.icon,
                          label: entry.label(l10n),
                          selected: currentId == entry.id,
                          onTap: () => onOpen(entry),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.surfaceContainerHigh,
                  child: Icon(Icons.person_outline,
                      size: 20, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (userName != null && userName!.trim().isNotEmpty)
                            ? userName!.trim()
                            : l10n.operatorName,
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
                const LanguageMenuButton(),
                IconButton(
                  tooltip: l10n.signOut,
                  icon: const Icon(Icons.logout),
                  onPressed: onLogout,
                ),
              ],
            ),
          ),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
