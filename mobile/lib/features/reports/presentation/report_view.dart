import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/report_export.dart';
import '../domain/report.dart';
import '../domain/report_table.dart';

/// Where a report file is saved (overridden in tests).
final reportFileSaverProvider =
    Provider<Future<void> Function(String name, Uint8List bytes)>((_) => (n, b) async => saveBytes(n, b));

/// The Japanese for the PDF (overridden in tests).
final reportPdfFontProvider = Provider<Future<Uint8List> Function()>((_) => loadReportPdfFont);

/// Rows on one A4 page of the preview.
const reportRowsPerPage = 30;

/// A report's result as it will print: A4 portrait pages with the title and
/// the conditions on the first, the table with its heading on every page,
/// and the total at the end — narrowed by any column's values, and saved as
/// Excel or PDF just as it is shown.
class ReportView extends ConsumerStatefulWidget {
  const ReportView({super.key, required this.result, required this.title, required this.conditions});

  final ReportResult result;
  final String title;
  final List<String> conditions;

  @override
  ConsumerState<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends ConsumerState<ReportView> {
  late final ReportTable _all = reportTable(widget.result);

  /// Column index → the values kept.
  final Map<int, Set<String>> _filters = {};
  bool _busy = false;
  final DateTime _madeAt = DateTime.now();

  ReportTable get _shown => _all.where(_filters);

  ReportDoc _doc(AppLocalizations l10n) {
    final t = _shown;
    return ReportDoc(
      title: widget.title,
      conditions: [
        ...widget.conditions,
        for (final f in _filters.entries)
          l10n.reportCondColumn(_all.columns[f.key].label, (f.value.toList()..sort()).join('、')),
      ],
      table: t,
      madeAt: _madeAt,
      totalLabel: l10n.reportTotal,
      countText: l10n.reportCount(t.rows.length),
      madeText: l10n.reportMadeAt(DateFormat('y/MM/dd HH:mm').format(_madeAt)),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _excel() async {
    final l10n = AppLocalizations.of(context);
    final d = _doc(l10n);
    final name = '${d.fileStem}.xlsx';
    await ref.read(reportFileSaverProvider)(name, buildReportXlsx(d));
    _snack(l10n.reportFileSaved(name));
  }

  Future<void> _pdf() async {
    final l10n = AppLocalizations.of(context);
    final d = _doc(l10n);
    setState(() => _busy = true);
    _snack(l10n.reportPdfMaking);
    try {
      final bytes = await buildReportPdf(d, await ref.read(reportPdfFontProvider)());
      final name = '${d.fileStem}.pdf';
      await ref.read(reportFileSaverProvider)(name, bytes);
      _snack(l10n.reportFileSaved(name));
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _filter(int i) async {
    final kept = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ValuesDialog(
        column: _all.columns[i].label,
        values: _all.values(i),
        chosen: _filters[i],
      ),
    );
    if (kept == null || !mounted) return;
    setState(() {
      if (kept.length == _all.values(i).length) {
        _filters.remove(i);
      } else {
        _filters[i] = kept;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_all.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(children: [
          Icon(Icons.table_chart_outlined, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.reportEmpty, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      );
    }

    final shown = _shown;
    final pages = shown.pages(reportRowsPerPage);
    final doc = _doc(l10n);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // The count, and the downloads.
      Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(
          _filters.isEmpty ? l10n.reportRowCount(shown.rows.length) : l10n.reportFiltered(shown.rows.length, _all.rows.length),
          key: const ValueKey('report-count'),
          style: theme.textTheme.titleSmall,
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('report-excel'),
          onPressed: shown.rows.isEmpty ? null : _excel,
          icon: const Icon(Icons.table_view_outlined),
          label: Text(l10n.reportExcel),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('report-pdf'),
          onPressed: _busy || shown.rows.isEmpty ? null : _pdf,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.reportPdf),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      // Each column's values to keep.
      Text(l10n.reportColumnFilter, style: theme.textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
        for (final (i, c) in _all.columns.indexed)
          FilterChip(
            key: ValueKey('report-col-${c.key}'),
            label: Text(_filters.containsKey(i) ? '${c.label}（${_filters[i]!.length}）' : c.label),
            avatar: const Icon(Icons.filter_list, size: 16),
            selected: _filters.containsKey(i),
            showCheckmark: false,
            onSelected: (_) => _filter(i),
          ),
        if (_filters.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('report-filter-reset'),
            onPressed: () => setState(_filters.clear),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: Text(l10n.reportFilterReset),
          ),
      ]),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.reportPreviewHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: AppSpacing.sm),
      // The pages, as paper.
      for (final (n, rows) in (pages.isEmpty ? [<List<String>>[]] : pages).indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: _A4Page(
                key: ValueKey('report-page-${n + 1}'),
                doc: doc,
                rows: rows,
                page: n + 1,
                pages: pages.isEmpty ? 1 : pages.length,
                totals: n == pages.length - 1 ? shown.totals() : null,
              ),
            ),
          ),
        ),
    ]);
  }
}

/// One A4 portrait page (210 × 297), drawn at 794 × 1123 and scaled to fit:
/// white paper with dark ink whatever the app's design.
class _A4Page extends StatelessWidget {
  const _A4Page({super.key, required this.doc, required this.rows, required this.page, required this.pages, this.totals});

  final ReportDoc doc;
  final List<List<String>> rows;
  final int page;
  final int pages;
  final List<String?>? totals;

  static const _ink = Color(0xFF1F2328);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFD7DBE0);
  static const _head = Color(0xFFEEF1F4);
  static const _stripe = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final t = doc.table;
    final cols = t.columns;
    final size = cols.length <= 6 ? 12.0 : (cols.length <= 9 ? 11.0 : 9.5);
    TextStyle style({bool bold = false, Color color = _ink, double? s}) => TextStyle(
        fontSize: s ?? size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, height: 1.25);
    Widget cell(String text, ReportColumn c, {bool bold = false}) => Expanded(
          flex: (c.flex * 100).round(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                style: style(bold: bold)),
          ),
        );
    Widget row(List<String?> cells, {Color? fill, bool bold = false}) => Container(
          height: 26,
          decoration: BoxDecoration(color: fill, border: const Border(bottom: BorderSide(color: _line, width: 0.8))),
          child: Row(children: [for (final (i, c) in cols.indexed) cell(cells[i] ?? '', c, bold: bold)]),
        );

    return AspectRatio(
      aspectRatio: 210 / 297,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 794,
            height: 1123,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 48, 48, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (page == 1) ...[
                  Text(doc.title, style: style(bold: true, s: 22)),
                  const SizedBox(height: 8),
                  for (final c in doc.conditions) Text(c, style: style(color: _muted, s: 11.5)),
                  Text(doc.countText, style: style(color: _muted, s: 11.5)),
                  const SizedBox(height: 14),
                ] else ...[
                  Text(doc.title, style: style(color: _muted, s: 10.5)),
                  const SizedBox(height: 8),
                ],
                row([for (final c in cols) c.label], fill: _head, bold: true),
                for (final (i, r) in rows.indexed) row(r, fill: i.isOdd ? _stripe : null),
                if (totals != null && totals!.any((v) => v != null))
                  row([for (final (i, v) in totals!.indexed) i == 0 && v == null ? doc.totalLabel : v], bold: true),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(doc.madeText, style: style(color: _muted, s: 10)),
                  Text(AppLocalizations.of(context).reportPageOf(page, pages), style: style(color: _muted, s: 10)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The values of one column, ticked to keep.
class _ValuesDialog extends StatefulWidget {
  const _ValuesDialog({required this.column, required this.values, this.chosen});

  final String column;
  final List<String> values;
  final Set<String>? chosen;

  @override
  State<_ValuesDialog> createState() => _ValuesDialogState();
}

class _ValuesDialogState extends State<_ValuesDialog> {
  late final Set<String> _kept = {...(widget.chosen ?? widget.values.toSet())};
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _q.text.trim().toLowerCase();
    final listed = [for (final v in widget.values) if (q.isEmpty || v.toLowerCase().contains(q)) v];
    return AlertDialog(
      title: Text(widget.column),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          TextField(
            key: const ValueKey('report-values-search'),
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.reportFilterSearch, isDense: true),
          ),
          Row(children: [
            TextButton(
                key: const ValueKey('report-values-all'),
                onPressed: () => setState(() => _kept.addAll(listed)),
                child: Text(l10n.reportFilterAll)),
            TextButton(
                key: const ValueKey('report-values-none'),
                onPressed: () => setState(() => _kept.removeAll(listed)),
                child: Text(l10n.reportFilterNone)),
          ]),
          Expanded(
            child: ListView(children: [
              for (final v in listed)
                CheckboxListTile(
                  key: ValueKey('report-value-$v'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _kept.contains(v),
                  title: Text(v.isEmpty ? '（空欄）' : v, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onChanged: (on) => setState(() => on == true ? _kept.add(v) : _kept.remove(v)),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('report-values-apply'),
          onPressed: () => Navigator.pop(context, _kept),
          child: Text(l10n.reportFilterApply),
        ),
      ],
    );
  }
}
