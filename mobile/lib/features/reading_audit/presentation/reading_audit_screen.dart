import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/local_prefs.dart';
import '../../../core/ui/popconfirm.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../data/reading_audit_repository.dart';
import '../domain/reading_audit.dart';
import 'reading_audit_builder.dart';

/// Where the first version kept readings, in the browser: sent to the
/// server once, then cleared.
const _oldLocalKey = 'reading_audit_v1';

/// 読み取り検査 (システム管理): the files read in 発注, 予定外の入荷 and 出庫
/// that ran into trouble — what was not read, misread, read more than one
/// way, covered or not — as sentences to read, copy or save as Markdown, with
/// the file itself; kept on the server (0224) apart from products and stock,
/// and removable.
class ReadingAuditScreen extends ConsumerStatefulWidget {
  const ReadingAuditScreen({super.key});

  @override
  ConsumerState<ReadingAuditScreen> createState() => _ReadingAuditScreenState();
}

class _ReadingAuditScreenState extends ConsumerState<ReadingAuditScreen> {
  AuditSource? _source;
  AuditKind? _kind;

  /// The readings ticked, by id: saved or removed together.
  final _picked = <String>{};
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOldLocal());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Readings the first version kept in this browser: kept on the server
  /// now, so every PC sees them.
  Future<void> _sendOldLocal() async {
    String? raw;
    try {
      raw = readLocalPref(_oldLocalKey);
    } catch (_) {
      return;
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        final recorder = ref.read(readingAuditRecorderProvider);
        for (final j in list.whereType<Map>()) {
          await recorder.keep(ReadingAudit.fromJson(j.cast<String, dynamic>()));
        }
      }
    } on FormatException {
      // Unreadable: nothing to send.
    }
    writeLocalPref(_oldLocalKey, null);
    if (mounted) ref.invalidate(readingAuditsProvider);
  }

  List<ReadingAudit> _shown(List<ReadingAudit> all) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final a in all)
        if ((_source == null || a.source == _source) &&
            (_kind == null || a.count(_kind!) > 0) &&
            (q.isEmpty || a.fileName.toLowerCase().contains(q) || (a.supplier ?? '').toLowerCase().contains(q)))
          a,
    ];
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save(String name, String text) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(saveFileProvider)(name, Uint8List.fromList(utf8.encode(text)));
    if (mounted) _snack(l10n.raSaved(name));
  }

  Future<void> _copy(String text) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack(l10n.raCopied);
  }

  Future<void> _download(ReadingAudit a) async {
    final path = a.filePath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(readingAuditRepositoryProvider).fileBytes(path);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(saveFileProvider)(a.fileName, data);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// Erases [list] for good, after asking with [message].
  Future<void> _remove(List<ReadingAudit> list, String message) async {
    final ids = [for (final a in list) if (a.serverId != null) a.serverId!];
    if (ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.raRemoveTitle,
      message: message,
      okLabel: l10n.raRemoveOne,
      okKey: const ValueKey('ra-remove-ok'),
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(readingAuditRepositoryProvider).remove(ids);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        _snack(l10n.raRemoved(data));
        setState(() => _picked.removeAll(list.map((a) => a.id)));
        ref.invalidate(readingAuditsProvider);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(readingAuditsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featReadingAudit), actions: [
        IconButton(
          key: const ValueKey('ra-refresh'),
          tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
          onPressed: () => ref.invalidate(readingAuditsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(readingAuditsProvider)),
        data: (all) {
          final shown = _shown(all);
          final picked = [for (final a in all) if (_picked.contains(a.id)) a];
          final now = DateTime.now();
          List<ReadingAudit> olderThan(int days) =>
              [for (final a in all) if (a.at.isBefore(now.subtract(Duration(days: days)))) a];
          return ListView(
            key: const ValueKey('ra-list'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.raIntro, style: muted),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      key: const ValueKey('ra-search'),
                      controller: _search,
                      decoration: InputDecoration(
                          isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: l10n.raSearchHint),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  DropdownButton<AuditSource?>(
                    key: const ValueKey('ra-source'),
                    value: _source,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.raAllScreens)),
                      for (final s in AuditSource.values)
                        DropdownMenuItem(value: s, child: Text(auditSourceLabel(l10n, s))),
                    ],
                    onChanged: (v) => setState(() => _source = v),
                  ),
                  DropdownButton<AuditKind?>(
                    key: const ValueKey('ra-kind'),
                    value: _kind,
                    isDense: true,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.raAllKinds)),
                      for (final k in AuditKind.values)
                        DropdownMenuItem(value: k, child: Text(auditKindLabel(l10n, k))),
                    ],
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  Text(l10n.raShown(shown.length, all.length), key: const ValueKey('ra-count'), style: muted),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('ra-save-all'),
                    onPressed: shown.isEmpty
                        ? null
                        : () => _save(auditFileName(l10n, DateTime.now()), auditsToMarkdown(l10n, shown)),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.raSaveAll),
                  ),
                  TextButton.icon(
                    key: const ValueKey('ra-remove-shown'),
                    onPressed:
                        shown.isEmpty || _busy ? null : () => _remove(shown, l10n.raRemoveShownConfirm(shown.length)),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(l10n.raRemoveShown),
                  ),
                  // Older than a week, a month, three months: all of them,
                  // whatever is shown.
                  PopupMenuButton<int>(
                    key: const ValueKey('ra-remove-old'),
                    enabled: all.isNotEmpty && !_busy,
                    tooltip: l10n.raRemoveOld,
                    onSelected: (days) {
                      final old = olderThan(days);
                      if (old.isNotEmpty) _remove(old, l10n.raRemoveOldConfirm(days, old.length));
                    },
                    itemBuilder: (_) => [
                      for (final d in const [7, 30, 90])
                        PopupMenuItem(
                          key: ValueKey('ra-old-$d'),
                          value: d,
                          enabled: olderThan(d).isNotEmpty,
                          child: Text(l10n.raOlderThan(d, olderThan(d).length)),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_delete_outlined, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text(l10n.raRemoveOld),
                        const Icon(Icons.arrow_drop_down),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // Ticked one by one, or all that is shown.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('ra-pick-all'),
                    onPressed: shown.isEmpty ? null : () => setState(() => _picked.addAll(shown.map((a) => a.id))),
                    child: Text(l10n.raPickAll),
                  ),
                  TextButton(
                    key: const ValueKey('ra-pick-none'),
                    onPressed: _picked.isEmpty ? null : () => setState(_picked.clear),
                    child: Text(l10n.raPickNone),
                  ),
                  Text(l10n.raPicked(picked.length), key: const ValueKey('ra-picked'), style: muted),
                  OutlinedButton.icon(
                    key: const ValueKey('ra-save-picked'),
                    onPressed: picked.isEmpty
                        ? null
                        : () => _save(auditFileName(l10n, DateTime.now()), auditsToMarkdown(l10n, picked)),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.raSavePicked),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('ra-remove-picked'),
                    onPressed: picked.isEmpty || _busy
                        ? null
                        : () => _remove(picked, l10n.raRemovePickedConfirm(picked.length)),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.raRemovePicked),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(l10n.raEmpty, key: const ValueKey('ra-empty'), style: muted, textAlign: TextAlign.center),
                ),
              for (final a in shown)
                _AuditCard(
                  key: ValueKey('ra-${a.id}'),
                  audit: a,
                  busy: _busy,
                  picked: _picked.contains(a.id),
                  onPick: (v) => setState(() => v ? _picked.add(a.id) : _picked.remove(a.id)),
                  onCopy: () => _copy(auditToMarkdown(l10n, a)),
                  onSave: () => _save(auditFileName(l10n, a.at, a.fileName), auditToMarkdown(l10n, a)),
                  onFile: a.filePath == null ? null : () => _download(a),
                  onRemove: () => _remove([a], l10n.raRemoveConfirm),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB'
    : bytes >= 1024
        ? '${(bytes / 1024).toStringAsFixed(0)}KB'
        : '${bytes}B';

class _AuditCard extends StatelessWidget {
  const _AuditCard({
    super.key,
    required this.audit,
    required this.busy,
    required this.picked,
    required this.onPick,
    required this.onCopy,
    required this.onSave,
    required this.onFile,
    required this.onRemove,
  });

  final ReadingAudit audit;
  final bool busy;
  final bool picked;
  final ValueChanged<bool> onPick;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback? onFile;
  final VoidCallback onRemove;

  Color _color(ColorScheme c, AuditKind k) => switch (k) {
        AuditKind.unresolved => c.error,
        AuditKind.missing || AuditKind.misread => c.tertiary,
        AuditKind.ambiguous || AuditKind.doubt => c.secondary,
        AuditKind.remedied => c.primary,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = audit;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final meta = [
      auditTime(a.at),
      auditSourceLabel(l10n, a.source),
      a.byAi ? l10n.raByAi : l10n.raBySheet,
      if (a.supplier != null) a.supplier!,
      if (a.byName != null) l10n.raBy(a.byName!),
      if (a.fileSize != null) _size(a.fileSize!),
    ].join('・');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('ra-tile-${a.id}'),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(key: ValueKey('ra-pick-${a.id}'), value: picked, onChanged: (v) => onPick(v ?? false)),
          Icon(a.filePath == null ? Icons.description_outlined : Icons.attach_file, size: 20),
        ]),
        title: Text(a.fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meta, style: muted),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            for (final (k, n) in a.counts)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: _color(theme.colorScheme, k)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.raKindCount(auditKindLabel(l10n, k), n),
                    style: theme.textTheme.labelSmall?.copyWith(color: _color(theme.colorScheme, k))),
              ),
          ]),
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (k, _) in a.counts) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(auditKindLabel(l10n, k), style: theme.textTheme.titleSmall?.copyWith(color: _color(theme.colorScheme, k))),
            for (final (n, i) in a.issues.indexed)
              if (i.kind == k)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SelectableText('・${auditIssueText(l10n, i)}', key: ValueKey('ra-${a.id}-issue-$n')),
                ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, children: [
            TextButton.icon(
              key: ValueKey('ra-copy-${a.id}'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(l10n.raCopy),
            ),
            TextButton.icon(
              key: ValueKey('ra-save-${a.id}'),
              onPressed: onSave,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(l10n.raSaveOne),
            ),
            if (onFile != null)
              TextButton.icon(
                key: ValueKey('ra-file-${a.id}'),
                onPressed: busy ? null : onFile,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text(l10n.raOpenFile),
              ),
            TextButton.icon(
              key: ValueKey('ra-remove-${a.id}'),
              onPressed: busy ? null : onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.raRemoveOne),
            ),
          ]),
        ],
      ),
    );
  }
}
