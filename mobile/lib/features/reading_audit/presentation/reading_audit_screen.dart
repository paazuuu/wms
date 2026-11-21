import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/popconfirm.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../data/reading_audit_store.dart';
import '../domain/reading_audit.dart';
import 'reading_audit_builder.dart';

/// 読み取り検査 (システム管理): every file reading that ran into trouble —
/// what was not read, misread, read more than one way, covered or not —
/// as sentences to read, copy or save as Markdown for improving the reader.
/// Kept in this browser only.
class ReadingAuditScreen extends ConsumerStatefulWidget {
  const ReadingAuditScreen({super.key});

  @override
  ConsumerState<ReadingAuditScreen> createState() => _ReadingAuditScreenState();
}

class _ReadingAuditScreenState extends ConsumerState<ReadingAuditScreen> {
  AuditSource? _source;
  AuditKind? _kind;

  List<ReadingAudit> _shown(List<ReadingAudit> all) => [
        for (final a in all)
          if ((_source == null || a.source == _source) && (_kind == null || a.count(_kind!) > 0)) a,
      ];

  Future<void> _save(String name, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(saveFileProvider)(name, Uint8List.fromList(utf8.encode(text)));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.raSaved(name))));
  }

  Future<void> _copy(String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.raCopied)));
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.raClear,
      message: l10n.raClearConfirm,
      okLabel: l10n.raClear,
      okKey: const ValueKey('ra-clear-ok'),
      danger: true,
    );
    if (ok) ref.read(readingAuditProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final all = ref.watch(readingAuditProvider);
    final shown = _shown(all);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featReadingAudit)),
      body: ListView(
        key: const ValueKey('ra-list'),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.raIntro(readingAuditMax), style: muted),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
                  for (final k in AuditKind.values) DropdownMenuItem(value: k, child: Text(auditKindLabel(l10n, k))),
                ],
                onChanged: (v) => setState(() => _kind = v),
              ),
              Text(l10n.raShown(shown.length, all.length), key: const ValueKey('ra-count'), style: muted),
              FilledButton.tonalIcon(
                key: const ValueKey('ra-save-all'),
                onPressed: shown.isEmpty
                    ? null
                    : () => _save(auditFileName(l10n, DateTime.now()), auditsToMarkdown(l10n, shown)),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.raSaveAll),
              ),
              TextButton.icon(
                key: const ValueKey('ra-clear'),
                onPressed: all.isEmpty ? null : _clear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(l10n.raClear),
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
              onCopy: () => _copy(auditToMarkdown(l10n, a)),
              onSave: () => _save(auditFileName(l10n, a.at, a.fileName), auditToMarkdown(l10n, a)),
              onRemove: () => ref.read(readingAuditProvider.notifier).remove(a.id),
            ),
        ],
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({super.key, required this.audit, required this.onCopy, required this.onSave, required this.onRemove});

  final ReadingAudit audit;
  final VoidCallback onCopy;
  final VoidCallback onSave;
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
    ].join('・');
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('ra-tile-${a.id}'),
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
            Text(auditKindLabel(l10n, k),
                style: theme.textTheme.titleSmall?.copyWith(color: _color(theme.colorScheme, k))),
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
            TextButton.icon(
              key: ValueKey('ra-remove-${a.id}'),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.raRemoveOne),
            ),
          ]),
        ],
      ),
    );
  }
}
