import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/html_sheet.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/reference_repository.dart';

/// 参照資料 (0160): the catalogs and sites referred to, a copy as each was,
/// by 年度 (April to March). A catalog's copy is its JANs as read (a table
/// in a new tab — the browser's 印刷 makes it a PDF — or Excel), a meclib
/// book's text; a site's is its page (HTML and text) or the PDF itself.
class ReferenceTab extends ConsumerStatefulWidget {
  const ReferenceTab({super.key, this.canManage = true, this.now});

  final bool canManage;

  /// For tests: the moment the current 年度 is reckoned from.
  final DateTime? now;

  @override
  ConsumerState<ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends ConsumerState<ReferenceTab> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  int? _year;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? scheme.error : null));
  }

  String _error(AppLocalizations l10n, String message) {
    if (message.contains('reference_bad_url')) return l10n.refBadUrl;
    if (message.contains('reference_too_large')) return l10n.refTooLarge;
    if (message.contains('reference_unreachable')) return l10n.refUnreachable;
    return humanizeApiErrorMessage(l10n, message);
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    if (_url.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await ref
        .read(referenceRepositoryProvider)
        .addSite(url: _url.text.trim(), title: _title.text, note: _note.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        _url.clear();
        _title.clear();
        _note.clear();
        ref.invalidate(referenceSourcesProvider);
        _snack(l10n.refSaved);
      case ApiFailure(:final message):
        _snack(_error(l10n, message), error: true);
    }
  }

  Future<void> _saveAgain(ReferenceSource s) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(referenceRepositoryProvider).saveAgain(s.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(referenceSourcesProvider);
    switch (r) {
      case ApiSuccess():
        _snack(l10n.refSavedAgain);
      case ApiFailure(:final message):
        _snack(_error(l10n, message), error: true);
    }
  }

  Future<void> _delete(ReferenceSource s) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.refDeleteConfirm(s.title ?? s.url)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          FilledButton(
              key: const ValueKey('ref-delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.jcDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(referenceRepositoryProvider).delete(s.id);
    ref.invalidate(referenceSourcesProvider);
  }

  /// A kept file opened in a new tab (a signed link, for an hour).
  Future<void> _openFile(ReferenceFile f) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(referenceRepositoryProvider).signedUrl(f.path);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        if (!openExternalUrl(data)) _snack(l10n.refOpenInBrowser);
      case ApiFailure(:final message):
        _snack(_error(l10n, message), error: true);
    }
  }

  Future<({List<String> headers, List<List<Object?>> rows, Map<String, dynamic> catalog})?> _entries(
      ReferenceFile f) async {
    final r = await ref.read(referenceRepositoryProvider).fileBytes(f.path);
    if (!mounted) return null;
    switch (r) {
      case ApiSuccess(:final data):
        try {
          return entriesTable((jsonDecode(utf8.decode(data)) as Map).cast<String, dynamic>());
        } catch (_) {
          _snack(AppLocalizations.of(context).refUnreadable, error: true);
          return null;
        }
      case ApiFailure(:final message):
        _snack(_error(AppLocalizations.of(context), message), error: true);
        return null;
    }
  }

  List<List<Object?>> _top(AppLocalizations l10n, ReferenceSource s, ReferenceSnapshot c, Map<String, dynamic> cat) => [
        [l10n.refColTitle, cat['name'] ?? s.title ?? ''],
        [l10n.refColMaker, cat['maker'] ?? s.maker ?? ''],
        [l10n.refColEdition, cat['published'] ?? c.edition ?? ''],
        [l10n.refColUrl, cat['url'] ?? s.url],
        [l10n.refColTaken, DateFormat('yyyy/MM/dd HH:mm').format(c.takenAt)],
        [l10n.refColYear, l10n.refYear(c.fiscalYear)],
      ];

  List<List<Object?>> _shown(AppLocalizations l10n, List<List<Object?>> rows) => [
        for (final r in rows)
          [
            r[0],
            r[1],
            r[2],
            r[3],
            switch (r[4]) {
              'package' => l10n.rcWeightBasisPackage,
              'pack' => l10n.rcWeightBasisPack,
              'product' => l10n.rcWeightBasisProduct,
              _ => '',
            },
            r[5],
            r[6],
          ],
      ];

  /// The JAN list as a sheet in a new tab: opened at the click (a browser
  /// lets a click open one), filled once the copy has come.
  Future<void> _openTable(ReferenceSource s, ReferenceSnapshot c, ReferenceFile f) async {
    final l10n = AppLocalizations.of(context);
    final tab = openHtmlTab();
    if (tab == null) {
      await _saveExcel(s, c, f);
      return;
    }
    final t = await _entries(f);
    if (t == null) {
      tab.close();
      return;
    }
    tab.show(htmlSheet(
      title: '${s.title ?? s.url}（${l10n.refYear(c.fiscalYear)}）',
      headers: t.headers,
      rows: _shown(l10n, t.rows),
      top: _top(l10n, s, c, t.catalog),
      downloadHint: l10n.refTabHint,
    ));
  }

  Future<void> _saveExcel(ReferenceSource s, ReferenceSnapshot c, ReferenceFile f) async {
    final l10n = AppLocalizations.of(context);
    final t = await _entries(f);
    if (t == null || !mounted) return;
    final name = '${(s.title ?? 'catalog').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')}_'
        '${DateFormat('yyyyMMdd').format(c.takenAt)}.xlsx';
    await saveBytes(
      name,
      buildXlsx(
        sheetName: 'JAN',
        headers: t.headers,
        rows: _shown(l10n, t.rows),
        top: _top(l10n, s, c, t.catalog),
        widths: const [16, 24, 12, 28, 10, 8, 60],
      ),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final n = NumberFormat.decimalPattern();
    final when = DateFormat('yyyy/MM/dd HH:mm');
    final async = ref.watch(referenceSourcesProvider);
    final thisYear = fiscalYearOf(widget.now ?? DateTime.now());

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(referenceSourcesProvider)),
      data: (sources) {
        final years = {
          thisYear,
          for (final s in sources)
            for (final c in s.snapshots) c.fiscalYear
        }.toList()
          ..sort((a, b) => b.compareTo(a));
        final year = _year ?? years.first;
        // In this 年度: what was kept then; a site with no copy yet shows in the current one.
        final shown = [
          for (final s in sources)
            if (s.snapshots.any((c) => c.fiscalYear == year) || (s.snapshots.isEmpty && year == thisYear)) s,
        ]..sort((a, b) => (a.isSite ? 1 : 0).compareTo(b.isSite ? 1 : 0) == 0
            ? (a.title ?? a.url).compareTo(b.title ?? b.url)
            : (a.isSite ? 1 : 0).compareTo(b.isSite ? 1 : 0));

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.refIntro, style: muted),
            if (widget.canManage) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    key: const ValueKey('ref-url'),
                    controller: _url,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.refUrl, hintText: 'https://…'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const ValueKey('ref-title'),
                    controller: _title,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.refTitleField),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    key: const ValueKey('ref-note'),
                    controller: _note,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: l10n.refNote),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('ref-add'),
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.refAdd),
                ),
              ),
              if (_busy) const Padding(padding: EdgeInsets.only(top: AppSpacing.sm), child: LinearProgressIndicator()),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final y in years)
                ChoiceChip(
                  key: ValueKey('ref-year-$y'),
                  label: Text(l10n.refYear(y)),
                  selected: y == year,
                  onSelected: (_) => setState(() => _year = y),
                ),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (shown.isEmpty) Text(l10n.refEmpty, key: const ValueKey('ref-empty'), style: muted),
            for (final s in shown)
              Card(
                key: ValueKey('ref-${s.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Chip(
                        label: Text(s.isSite ? l10n.refKindSite : l10n.refKindCatalog),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(s.title ?? s.url, style: theme.textTheme.titleMedium)),
                    ]),
                    if (s.maker != null || s.note != null)
                      Text([s.maker, s.note].whereType<String>().join('・'), style: muted),
                    Text(s.url, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    for (final c in s.snapshots.where((c) => c.fiscalYear == year))
                      Padding(
                        key: ValueKey('ref-copy-${c.id}'),
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(
                            [
                              when.format(c.takenAt),
                              if (c.edition != null) c.edition!,
                              if (c.entryCount != null)
                                l10n.refCounts(n.format(c.entryCount), n.format(c.weightCount ?? 0)),
                            ].join(' · '),
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (c.file('entries') case final f?) ...[
                            TextButton.icon(
                              key: ValueKey('ref-table-${c.id}'),
                              onPressed: () => _openTable(s, c, f),
                              icon: const Icon(Icons.table_chart_outlined, size: 18),
                              label: Text(l10n.refTable),
                            ),
                            TextButton.icon(
                              key: ValueKey('ref-xlsx-${c.id}'),
                              onPressed: () => _saveExcel(s, c, f),
                              icon: const Icon(Icons.download_outlined, size: 18),
                              label: Text(l10n.refExcel),
                            ),
                          ],
                          for (final (kind, label, icon) in [
                            ('pdf', l10n.refPdf, Icons.picture_as_pdf_outlined),
                            ('html', l10n.refPage, Icons.web_outlined),
                            ('text', l10n.refText, Icons.article_outlined),
                            ('file', l10n.refFile, Icons.attach_file),
                          ])
                            if (c.file(kind) case final f?)
                              TextButton.icon(
                                key: ValueKey('ref-$kind-${c.id}'),
                                onPressed: () => _openFile(f),
                                icon: Icon(icon, size: 18),
                                label: Text(label),
                              ),
                        ]),
                      ),
                    if (s.snapshots.isEmpty) Text(l10n.refNoCopy, style: muted),
                    if (s.lastCheckedAt != null) Text(l10n.refChecked(when.format(s.lastCheckedAt!)), style: muted),
                    Wrap(spacing: AppSpacing.sm, children: [
                      if (s.url.startsWith('http'))
                        TextButton.icon(
                          key: ValueKey('ref-open-${s.id}'),
                          onPressed: () {
                            if (!openExternalUrl(s.url)) _snack(l10n.refOpenInBrowser);
                          },
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(l10n.refOpenNow),
                        ),
                      if (widget.canManage && (s.isSite || s.janCatalogId != null))
                        TextButton.icon(
                          key: ValueKey('ref-save-${s.id}'),
                          onPressed: _busy ? null : () => _saveAgain(s),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: Text(l10n.refSaveAgain),
                        ),
                      if (widget.canManage && s.isSite)
                        TextButton.icon(
                          key: ValueKey('ref-delete-${s.id}'),
                          onPressed: _busy ? null : () => _delete(s),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(l10n.jcDelete),
                        ),
                    ]),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
