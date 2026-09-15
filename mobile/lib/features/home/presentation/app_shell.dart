import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/l10n/language_menu.dart';
import '../../../core/router/app_router.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/hardware_scanner.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_scale_menu.dart';
import '../../../core/ui/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../warehouse_context/presentation/warehouse_picker.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';
import 'breadcrumbs.dart';

/// The authenticated app shell.
///
/// A desktop-first, shadcn-dashboard-style layout: a persistent left sidebar
/// of grouped capabilities, a top bar with an always-available scan box, and a
/// content region — [child] — that the router fills. Below 900px the sidebar
/// folds into a drawer so the same shell serves handheld/tablet field use.
///
/// The shell used to own a nested [Navigator] and swap screens itself, holding
/// the current selection in a [ValueNotifier]. Routing replaced both: the
/// content is whatever the router built, and the sidebar highlight and top-bar
/// title are *derived* from the current location. One less piece of state that
/// could disagree with what is on screen.
///
/// A [HardwareScanner] wraps the whole shell so a keyboard-wedge barcode
/// scanner works anywhere — no need to click into a field first.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

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

  @override
  Widget build(BuildContext context) {
    final wide = isWideLayout(context);
    final user = ref.watch(authControllerProvider).user;
    final permissions = user?.permissions ?? const <String>[];
    final selectedId = _selectedIdFor(GoRouterState.of(context).uri.path);

    Widget sidebar() => _Sidebar(
          selectedId: selectedId,
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
          onScan: _handleScan,
          onMenu: wide ? null : () => _scaffoldKey.currentState?.openDrawer(),
          onCamera: _cameraSupported ? _openCameraScan : null,
          onSearch: () => _go(AppRoutes.search),
        ),
        Expanded(child: widget.child),
      ],
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 268, child: sidebar()),
              const VerticalDivider(width: 1),
              Expanded(child: main),
            ],
          )
        : main;

    return HardwareScanner(
      onScan: _handleScan,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: wide ? null : Drawer(child: sidebar()),
        body: SafeArea(child: body),
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

/// The top bar: menu (narrow) / breadcrumb trail (wide) + a persistent scan
/// box. Narrow layouts get no trail on purpose — every feature screen carries
/// its own [AppBar] title, so a second copy would cost a phone two rows of
/// vertical space to say the same thing twice.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.selectedId,
    required this.onScan,
    required this.onMenu,
    required this.onCamera,
    required this.onSearch,
  });

  final bool wide;
  final String selectedId;
  final ValueChanged<String> onScan;
  final VoidCallback? onMenu;
  final Future<void> Function()? onCamera;
  final VoidCallback onSearch;

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

/// The grouped navigation sidebar (shadcn-style: brand, sections, footer).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedId,
    required this.onOpen,
    required this.onDashboard,
    required this.onLogout,
    required this.permissions,
    this.userName,
    this.userEmail,
  });

  final String selectedId;
  final void Function(FeatureEntry entry) onOpen;
  final VoidCallback onDashboard;
  final VoidCallback onLogout;

  /// The signed-in user's permission codes (UI spec §37) — a group with
  /// nothing this user may open is skipped entirely rather than shown empty.
  final List<String> permissions;
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
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: l10n.navDashboard,
                  selected: selectedId == 'dashboard',
                  onTap: onDashboard,
                ),
                for (final group in groups) ...() {
                  final visible = group.visibleEntries(permissions);
                  if (visible.isEmpty) return const <Widget>[];
                  return <Widget>[
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
                        onTap: () => onOpen(entry),
                      ),
                  ];
                }(),
              ],
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
                const TextScaleMenuButton(),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
