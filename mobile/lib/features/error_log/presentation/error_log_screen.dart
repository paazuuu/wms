import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/popconfirm.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../data/error_log_repository.dart';

/// エラーログ (システム管理, 0227): the errors the app ran into, newest first —
/// what, where, who, how often — to read, copy, save as Markdown for the
/// developers, and remove (picked, shown, or older than a time).
class ErrorLogScreen extends ConsumerStatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  ConsumerState<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

String errorKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'api' => l10n.elKindApi,
      'flutter' => l10n.elKindFlutter,
      _ => l10n.elKindUncaught,
    };

String _two(int n) => n.toString().padLeft(2, '0');
String _time(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// One error as Markdown.
String errorToMarkdown(AppLocalizations l10n, AppErrorEntry e) {
  final b = StringBuffer()
    ..writeln('## ${_time(e.lastAt)} ${errorKindLabel(l10n, e.kind)}${e.times > 1 ? '（${l10n.elTimes(e.times)}）' : ''}')
    ..writeln()
    ..writeln('- ${e.message.replaceAll('\n', ' ')}');
  if (e.request != null) b.writeln('- ${l10n.elRequest}: `${e.request}`${e.status != null ? ' (${e.status})' : ''}');
  if (e.place != null) b.writeln('- ${l10n.elPlace}: `${e.place}`');
  if (e.userName != null) b.writeln('- ${e.userName}');
  if (e.times > 1) b.writeln('- ${l10n.elFirstAt}: ${_time(e.firstAt)}');
  if (e.client != null) b.writeln('- ${l10n.elClient}: ${e.client}');
  if (e.detail != null) {
    b
      ..writeln()
      ..writeln('```')
      ..writeln(e.detail!.replaceAll('```', "'''"))
      ..writeln('```');
  }
  return b.toString();
}

String errorsToMarkdown(AppLocalizations l10n, List<AppErrorEntry> list, {DateTime? now}) {
  final b = StringBuffer()
    ..writeln('# ${l10n.elMdTitle(list.length)}')
    ..writeln()
    ..writeln('- ${l10n.elMdExported}: ${_time(now ?? DateTime.now())}');
  for (final e in list) {
    b
      ..writeln()
      ..write(errorToMarkdown(l10n, e));
  }
  return b.toString();
}

class _ErrorLogScreenState extends ConsumerState<ErrorLogScreen> {
  int? _days = 7;
  String? _kind;
  final _search = TextEditingController();
  final _picked = <int>{};
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppErrorEntry> _shown(List<AppErrorEntry> all) {
    final q = _search.text.trim().toLowerCase();
    bool hit(String? s) => s != null && s.toLowerCase().contains(q);
    return [
      for (final e in all)
        if ((_kind == null || e.kind == _kind) &&
            (q.isEmpty || hit(e.message) || hit(e.request) || hit(e.place) || hit(e.userName)))
          e,
    ];
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _save(List<AppErrorEntry> list) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final name = '${l10n.featErrorLog}_${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}.md';
    await ref.read(saveFileProvider)(name, Uint8List.fromList(utf8.encode(errorsToMarkdown(l10n, list, now: now))));
    if (mounted) _snack(l10n.elSaved(name));
  }

  Future<void> _remove({List<int> ids = const [], int? olderThanDays}) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.elRemoveTitle,
      message: olderThanDays != null ? l10n.elRemoveOldConfirm(olderThanDays) : l10n.elRemoveConfirm(ids.length),
      okLabel: l10n.elRemove,
      okKey: const ValueKey('el-remove-ok'),
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(errorLogRepositoryProvider).remove(ids: ids, olderThanDays: olderThanDays);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(l10n.elRemoved(data));
        setState(() => ids.isEmpty ? _picked.clear() : _picked.removeAll(ids));
        ref.invalidate(errorLogProvider);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(errorLogProvider(_days));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featErrorLog), actions: [
        IconButton(
          key: const ValueKey('el-refresh'),
          tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          onPressed: () => ref.invalidate(errorLogProvider),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(errorLogProvider)),
        data: (all) {
          final shown = _shown(all);
          final picked = [for (final e in all) if (_picked.contains(e.id)) e];
          return ListView(
            key: const ValueKey('el-list'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.elIntro, style: muted),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      key: const ValueKey('el-search'),
                      controller: _search,
                      decoration: InputDecoration(
                          isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: l10n.elSearchHint),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  DropdownButton<int?>(
                    key: const ValueKey('el-days'),
                    value: _days,
                    isDense: true,
                    items: [
                      for (final d in const [1, 7, 30]) DropdownMenuItem(value: d, child: Text(l10n.elDays(d))),
                      DropdownMenuItem(value: null, child: Text(l10n.elAllDays)),
                    ],
                    onChanged: (v) => setState(() {
                      _days = v;
                      _picked.clear();
                    }),
                  ),
                  DropdownButton<String?>(
                    key: const ValueKey('el-kind'),
                    value: _kind,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.elAllKinds)),
                      for (final k in const ['api', 'flutter', 'uncaught'])
                        DropdownMenuItem(value: k, child: Text(errorKindLabel(l10n, k))),
                    ],
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  Text(l10n.elShown(shown.length, all.length), key: const ValueKey('el-count'), style: muted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('el-save-shown'),
                    onPressed: shown.isEmpty ? null : () => _save(shown),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.elSaveShown),
                  ),
                  TextButton.icon(
                    key: const ValueKey('el-remove-shown'),
                    onPressed: shown.isEmpty || _busy ? null : () => _remove(ids: [for (final e in shown) e.id]),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(l10n.elRemoveShown),
                  ),
                  PopupMenuButton<int>(
                    key: const ValueKey('el-remove-old'),
                    enabled: !_busy,
                    tooltip: l10n.elRemoveOld,
                    onSelected: (d) => _remove(olderThanDays: d),
                    itemBuilder: (_) => [
                      for (final d in const [7, 30, 90])
                        PopupMenuItem(key: ValueKey('el-old-$d'), value: d, child: Text(l10n.elOlderThan(d))),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_delete_outlined, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text(l10n.elRemoveOld),
                        const Icon(Icons.arrow_drop_down),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('el-pick-all'),
                    onPressed: shown.isEmpty ? null : () => setState(() => _picked.addAll(shown.map((e) => e.id))),
                    child: Text(l10n.elPickAll),
                  ),
                  TextButton(
                    key: const ValueKey('el-pick-none'),
                    onPressed: _picked.isEmpty ? null : () => setState(_picked.clear),
                    child: Text(l10n.elPickNone),
                  ),
                  Text(l10n.elPicked(picked.length), key: const ValueKey('el-picked'), style: muted),
                  OutlinedButton.icon(
                    key: const ValueKey('el-save-picked'),
                    onPressed: picked.isEmpty ? null : () => _save(picked),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.elSavePicked),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('el-remove-picked'),
                    onPressed: picked.isEmpty || _busy ? null : () => _remove(ids: [for (final e in picked) e.id]),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.elRemovePicked),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(l10n.elEmpty, key: const ValueKey('el-empty'), style: muted, textAlign: TextAlign.center),
                ),
              for (final e in shown)
                _ErrorCard(
                  key: ValueKey('el-${e.id}'),
                  entry: e,
                  picked: _picked.contains(e.id),
                  onPick: (v) => setState(() => v ? _picked.add(e.id) : _picked.remove(e.id)),
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: errorToMarkdown(l10n, e)));
                    if (mounted) _snack(l10n.elCopied);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({super.key, required this.entry, required this.picked, required this.onPick, required this.onCopy});

  final AppErrorEntry entry;
  final bool picked;
  final ValueChanged<bool> onPick;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final e = entry;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final color = switch (e.kind) {
      'api' => theme.colorScheme.tertiary,
      'flutter' => theme.colorScheme.secondary,
      _ => theme.colorScheme.error,
    };
    final meta = [
      _time(e.lastAt),
      if (e.userName != null) e.userName!,
      if (e.request != null) '${e.request}${e.status != null ? ' (${e.status})' : ''}',
      if (e.place != null && e.place!.isNotEmpty) e.place!,
    ].join('・');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('el-tile-${e.id}'),
        leading: Checkbox(key: ValueKey('el-pick-${e.id}'), value: picked, onChanged: (v) => onPick(v ?? false)),
        title: Text(e.message, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Wrap(spacing: AppSpacing.xs, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(4)),
            child: Text(errorKindLabel(l10n, e.kind), style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ),
          if (e.times > 1)
            Text(l10n.elTimes(e.times),
                key: ValueKey('el-times-${e.id}'), style: theme.textTheme.labelSmall?.copyWith(color: color)),
          Text(meta, style: muted),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(e.message, key: ValueKey('el-message-${e.id}')),
          const SizedBox(height: AppSpacing.xs),
          if (e.times > 1) Text('${l10n.elFirstAt}: ${_time(e.firstAt)}', style: muted),
          if (e.client != null) Text('${l10n.elClient}: ${e.client}', style: muted),
          if (e.detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.elDetail, style: theme.textTheme.titleSmall),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(e.detail!,
                    key: ValueKey('el-detail-${e.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            key: ValueKey('el-copy-${e.id}'),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(l10n.elCopy),
          ),
        ],
      ),
    );
  }
}
