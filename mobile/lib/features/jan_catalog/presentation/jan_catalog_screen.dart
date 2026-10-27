import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/jan_catalog_repository.dart';

/// JANカタログ (0153): the makers' catalogs read for their JAN codes — the
/// list, one more by its URL, read again, or forgotten.
class JanCatalogScreen extends ConsumerStatefulWidget {
  const JanCatalogScreen({super.key, this.canManage = true});

  /// Adding, reading again and deleting (product.manage); else only the list.
  final bool canManage;

  @override
  ConsumerState<JanCatalogScreen> createState() => _JanCatalogScreenState();
}

class _JanCatalogScreenState extends ConsumerState<JanCatalogScreen> {
  final _url = TextEditingController();

  /// The URL being read, while it is.
  String? _busy;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  String _error(AppLocalizations l10n, String message) {
    if (message.contains('jan_catalog_bad_url')) return l10n.jcBadUrl;
    if (message.contains('jan_catalog_unreachable')) return l10n.jcUnreachable;
    if (message.contains('jan_catalog_empty')) return l10n.jcNoJan;
    return humanizeApiErrorMessage(l10n, message);
  }

  Future<void> _sync(String url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (url.trim().isEmpty) return;
    setState(() => _busy = url);
    final r = await ref.read(janCatalogRepositoryProvider).sync(url.trim());
    if (!mounted) return;
    setState(() => _busy = null);
    ref.invalidate(janCatalogsProvider);
    switch (r) {
      case ApiSuccess(:final data):
        if (url == _url.text) _url.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.jcDone(data.entryCount))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(_error(l10n, message)), backgroundColor: scheme.error));
    }
  }

  Future<void> _delete(JanCatalog c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.jcDeleteConfirm(c.name ?? c.url)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('jc-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.jcDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(janCatalogRepositoryProvider).delete(c.id);
    ref.invalidate(janCatalogsProvider);
  }

  void _open(String url) {
    if (openExternalUrl(url)) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).rcCatalogCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final when = DateFormat('yyyy/MM/dd HH:mm');
    final async = ref.watch(janCatalogsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jcTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.jcIntro, style: muted),
          if (widget.canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('jc-url'),
              controller: _url,
              enabled: _busy == null,
              decoration: InputDecoration(labelText: l10n.jcUrl, hintText: l10n.jcUrlHint),
              onSubmitted: _sync,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('jc-add'),
                onPressed: _busy == null ? () => _sync(_url.text) : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.jcAdd),
              ),
            ),
          ],
          if (_busy != null) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.jcSyncing, key: const ValueKey('jc-syncing'), style: muted),
          ],
          const SizedBox(height: AppSpacing.lg),
          ...async.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (e, _) => [ErrorStateView(message: '$e', onRetry: () => ref.invalidate(janCatalogsProvider))],
            data: (list) => list.isEmpty
                ? [Text(l10n.jcEmpty, key: const ValueKey('jc-empty'), style: muted)]
                : [
                    for (final c in list)
                      Card(
                        key: ValueKey('jc-${c.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.name ?? c.url, style: theme.textTheme.titleMedium),
                            if (c.maker != null || c.published != null)
                              Text([c.maker, c.published].whereType<String>().join('・'), style: muted),
                            const SizedBox(height: AppSpacing.xs),
                            Text(l10n.jcCount(c.entryCount, c.pagesRead),
                                key: ValueKey('jc-count-${c.id}'), style: theme.textTheme.bodyMedium),
                            if (c.syncedAt != null) Text(l10n.jcSynced(when.format(c.syncedAt!)), style: muted),
                            if (c.syncError != null)
                              Text(l10n.jcError(c.syncError!),
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(spacing: AppSpacing.sm, children: [
                              TextButton.icon(
                                key: ValueKey('jc-open-${c.id}'),
                                onPressed: () => _open(c.url),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(l10n.jcOpen),
                              ),
                              if (widget.canManage) ...[
                                TextButton.icon(
                                  key: ValueKey('jc-resync-${c.id}'),
                                  onPressed: _busy == null ? () => _sync(c.url) : null,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(l10n.jcResync),
                                ),
                                TextButton.icon(
                                  key: ValueKey('jc-delete-${c.id}'),
                                  onPressed: _busy == null ? () => _delete(c) : null,
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: Text(l10n.jcDelete),
                                ),
                              ],
                            ]),
                          ]),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}
