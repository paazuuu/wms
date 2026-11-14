import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/domain/feature_catalog.dart';
import '../../home/domain/feature_entry.dart';
import '../data/menu_visibility_repository.dart';
import '../domain/user_tier.dart';

/// The label of a tier, as people here say it.
String userTierLabel(AppLocalizations l10n, UserTier t) => switch (t) {
      UserTier.admin => l10n.tierAdmin,
      UserTier.manager => l10n.tierManager,
      UserTier.user => l10n.tierUser,
    };

/// 表示設定 (0193): for each menu entry, and for prices and amounts, whether
/// 管理者ユーザー and 通常ユーザー see it. ADMIN always sees everything. Only
/// an ADMIN saves it; what is shown still needs the permission to use it.
class MenuVisibilityScreen extends ConsumerStatefulWidget {
  const MenuVisibilityScreen({super.key});

  @override
  ConsumerState<MenuVisibilityScreen> createState() => _MenuVisibilityScreenState();
}

class _MenuVisibilityScreenState extends ConsumerState<MenuVisibilityScreen> {
  /// What is on screen: 'feature|tier' → shown, for every entry and tier.
  Map<String, bool>? _draft;
  bool _busy = false;
  bool _dirty = false;

  static const _tiers = [UserTier.manager, UserTier.user];

  Map<String, bool> _resolve(Map<String, bool> saved, {bool defaults = false}) => {
        for (final g in buildFeatureCatalog())
          for (final e in g.entries)
            if (e.inMenu)
              for (final t in _tiers)
                visibilityKey(e.id, t): defaults ? defaultVisible(e.id, g.id, t) : tierSees(saved, e.id, g.id, t),
        for (final t in _tiers)
          visibilityKey(contentPrices, t):
              defaults ? defaultVisible(contentPrices, 'content', t) : tierSees(saved, contentPrices, 'content', t),
      };

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(menuVisibilityRepositoryProvider).save(_draft!);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        _dirty = false;
        ref.invalidate(menuVisibilitySettingsProvider);
        _snack(l10n.mvSaved);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  void _set(String key, bool v) => setState(() {
        _draft = {..._draft!, key: v};
        _dirty = true;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(menuVisibilitySettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featMenuVisibility),
        actions: [
          TextButton(
            key: const ValueKey('mv-defaults'),
            onPressed: _draft == null
                ? null
                : () => setState(() {
                      _draft = _resolve(const {}, defaults: true);
                      _dirty = true;
                    }),
            child: Text(l10n.mvDefaults),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FilledButton.icon(
              key: const ValueKey('mv-save'),
              onPressed: _busy || !_dirty ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.actionSave),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(menuVisibilitySettingsProvider)),
        data: (saved) {
          final draft = _draft ??= _resolve(saved);
          Widget row(String id, String title, {String? subtitle, bool adminOnly = false}) => Padding(
                key: ValueKey('mv-row-$id'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: 72, child: Center(child: Icon(Icons.check, size: 18))),
                  // システム管理: fixed to the system administrator.
                  if (adminOnly)
                    SizedBox(
                      width: 96.0 * _tiers.length,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(child: Text(l10n.mvAdminOnly, style: theme.textTheme.bodySmall)),
                      ]),
                    ),
                  if (!adminOnly)
                  for (final t in _tiers)
                    SizedBox(
                      width: 96,
                      child: Center(
                        child: Checkbox(
                          key: ValueKey('mv-$id-${t.wire}'),
                          value: draft[visibilityKey(id, t)] ?? false,
                          onChanged: (v) => _set(visibilityKey(id, t), v ?? false),
                        ),
                      ),
                    ),
                ]),
              );
          Widget head(String text) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
                child: Row(children: [
                  Expanded(child: Text(text, style: theme.textTheme.titleSmall)),
                  SizedBox(width: 72, child: Center(child: Text(l10n.tierAdmin, style: theme.textTheme.labelSmall))),
                  for (final t in _tiers)
                    SizedBox(width: 96, child: Center(child: Text(userTierLabel(l10n, t), style: theme.textTheme.labelSmall))),
                ]),
              );
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.mvHint, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.mvTierAdmin, style: theme.textTheme.bodySmall),
                    Text(l10n.mvTierManager, style: theme.textTheme.bodySmall),
                    Text(l10n.mvTierUser, style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
              head(l10n.mvContent),
              row(contentPrices, l10n.mvPrices, subtitle: l10n.mvPricesHint),
              for (final g in buildFeatureCatalog())
                if (g.entries.any((e) => e.inMenu)) ...[
                  head(g.adminOnly ? '${g.title(l10n)}（${l10n.groupAdminOnly}）' : g.title(l10n)),
                  for (final FeatureEntry e in g.entries)
                    if (e.inMenu) row(e.id, e.label(l10n), subtitle: e.description(l10n), adminOnly: g.adminOnly),
                ],
            ],
          );
        },
      ),
    );
  }
}
