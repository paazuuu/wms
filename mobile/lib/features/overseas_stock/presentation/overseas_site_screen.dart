import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../../record_notes/data/record_notes_repository.dart';
import '../../record_notes/presentation/record_notes_panel.dart';
import '../../stock_import/presentation/import_view_screen.dart' show OriginalFileView;
import '../data/overseas_stock_repository.dart';
import '../domain/overseas_stock.dart';
import '../../outbound_file/presentation/outbound_file_detail_screen.dart';
import 'overseas_import_tab.dart';
import 'overseas_trend_view.dart';
import 'overseas_widgets.dart';
import '../../../core/ui/popconfirm.dart';

final _day = DateFormat('y/MM/dd');

/// One 出荷先 abroad (0207, 0209): its stock as estimated (the partner's
/// last count + what we shipped since), every list shipped to its card, the
/// counts the partner gives (read from their files, each kept with its
/// reading; one can be taken back), the trend and what was used, and メモ.
///
/// Tabs: 推定在庫, 出荷の記録, 最新の報告, 報告を読み込む, 報告の履歴,
/// 推移・分析, メモ.
class OverseasSiteScreen extends ConsumerStatefulWidget {
  const OverseasSiteScreen({super.key, required this.site, this.initialTab = 0});

  final OverseasSite site;
  final int initialTab;

  @override
  ConsumerState<OverseasSiteScreen> createState() => _OverseasSiteScreenState();
}

class _OverseasSiteScreenState extends ConsumerState<OverseasSiteScreen> with SingleTickerProviderStateMixin {
  late OverseasSite _site = widget.site;
  late final _tabs = TabController(length: 7, vsync: this, initialIndex: widget.initialTab);
  final _search = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void _refresh() {
    ref.invalidate(overseasSiteStockProvider(_site.id));
    ref.invalidate(overseasEventsProvider(_site.id));
    ref.invalidate(overseasStockProvider(_site.id));
    ref.invalidate(overseasImportsProvider(_site.id));
    ref.invalidate(overseasSitesProvider);
    ref.invalidate(overseasOverviewProvider);
  }

  Future<void> _edit() async {
    final l10n = AppLocalizations.of(context);
    final m = await showOverseasSiteDialog(context, site: _site);
    if (m == null || !mounted) return;
    final r = await ref.read(overseasStockRepositoryProvider).saveSite(m);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        setState(() => _site = OverseasSite.fromJson({..._site.toJson(), ...m, 'id': _site.id}));
        ref.invalidate(overseasSitesProvider);
        _snack(l10n.osSaved);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _view(OverseasImport i) async {
    final path = i.storagePath;
    if (path == null) return;
    final r = await ref.read(overseasStockRepositoryProvider).fileBytes(path);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(i.fileName ?? ''),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => ref.read(saveFileProvider)(i.fileName ?? 'stock', data),
                ),
              ],
            ),
            body: OriginalFileView(key: const ValueKey('os-file-original'), fileName: i.fileName ?? '', bytes: data),
          ),
        ));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(AppLocalizations.of(context), message));
    }
  }

  /// What was read, kept as Excel (0208).
  Future<void> _downloadReading(OverseasImport i) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(overseasStockRepositoryProvider).fileBytes(i.readPath!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        await ref.read(saveFileProvider)(
            '${(i.fileName ?? 'stock').replaceAll(RegExp(r'\.[^.]+$'), '')}_${l10n.rdSuffix}.xlsx', data);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _undo(OverseasImport i) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.osUndoQ(i.asOf == null ? '' : _day.format(i.asOf!)),
      okLabel: l10n.osUndo,
      okKey: const ValueKey('os-undo-ok'),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(overseasStockRepositoryProvider).undo(i.id);
    if (r case ApiFailure(:final message)) _snack(humanizeApiErrorMessage(l10n, message));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(
        title: Text(_site.name),
        actions: [
          IconButton(key: const ValueKey('os-site-edit'), tooltip: l10n.osEditSite, icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        ],
        bottom: TabBar(controller: _tabs, isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(key: const ValueKey('os-tab-estimate'), text: l10n.osTabEstimate),
          Tab(key: const ValueKey('os-tab-shipments'), text: l10n.osTabShipments),
          Tab(key: const ValueKey('os-tab-stock'), text: l10n.osTabStock),
          Tab(key: const ValueKey('os-tab-import'), text: l10n.osTabImport),
          Tab(key: const ValueKey('os-tab-history'), text: l10n.osTabHistory),
          Tab(key: const ValueKey('os-tab-trend'), text: l10n.osTabTrend),
          Tab(key: const ValueKey('os-tab-notes'), text: l10n.wlTabNotes(_site.noteCount)),
        ]),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Text(
            [
              if (_site.destinationName != null) l10n.osCardIs(_site.destinationName!) else overseasKindLabel(l10n, _site.kind),
              if (_site.country != null || _site.city != null) [_site.country, _site.city].whereType<String>().join(' '),
              if (_site.contact != null) _site.contact!,
              if (_site.note != null) _site.note!,
            ].join(' · '),
            key: const ValueKey('os-site-line'),
            style: muted,
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _estimate(context),
            _shipments(context),
            _stock(context),
            OverseasImportTab(
              site: _site,
              onDone: () {
                _refresh();
                _tabs.animateTo(0);
              },
            ),
            _history(context),
            OverseasTrendView(siteId: _site.id),
            ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              RecordNotesPanel(
                subject: NoteSubject.overseasSite,
                subjectId: _site.id,
                onChanged: () => ref.invalidate(overseasSitesProvider),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  /// 推定在庫: the partner's last count + what we shipped since (or all we
  /// shipped, before any count).
  Widget _estimate(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(overseasSiteStockProvider(_site.id));
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: _refresh),
      data: (rows) {
        if (rows.isEmpty) return EmptyStateView(icon: Icons.inventory_2_outlined, title: l10n.osNoShipments);
        final q = _search.text.trim().toLowerCase();
        final shown = [
          for (final r in rows)
            if (q.isEmpty || '${r.jan ?? ''} ${r.code ?? ''} ${r.name ?? ''} ${r.maker ?? ''}'.toLowerCase().contains(q)) r,
        ];
        final total = shown.fold<num>(0, (a, r) => a + r.estimate);
        return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text(l10n.osEstimateHelp, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 360,
              child: TextField(
                key: const ValueKey('os-estimate-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.osSearch, isDense: true),
              ),
            ),
            Text(l10n.osEstimateTotal(shown.length, overseasQty(total)),
                key: const ValueKey('os-estimate-total'), style: theme.textTheme.titleSmall),
          ]),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey('os-estimate'),
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 52,
              columns: [
                DataColumn(label: Text(l10n.osColName)),
                DataColumn(label: Text(l10n.ofRoleJan)),
                DataColumn(label: Text(l10n.ofRoleMaker)),
                DataColumn(label: Text(l10n.osColShippedTotal), numeric: true),
                DataColumn(label: Text(l10n.osColReported), numeric: true),
                DataColumn(label: Text(l10n.osColSince), numeric: true),
                DataColumn(label: Text(l10n.osColEstimate), numeric: true),
              ],
              rows: [
                for (final (i, r) in shown.indexed)
                  DataRow(key: ValueKey('os-estimate-$i'), cells: [
                    DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (r.code != null) Text(r.code!, style: muted),
                    ])),
                    DataCell(Text(r.jan ?? '', style: muted)),
                    DataCell(Text(r.maker ?? '', style: muted)),
                    DataCell(Text(overseasQty(r.shippedTotal))),
                    DataCell(Text(r.reported == null
                        ? '—'
                        : '${overseasQty(r.reported!)}${r.reportedOn == null ? '' : '（${DateFormat('MM/dd').format(r.reportedOn!)}）'}')),
                    DataCell(Text(overseasQty(r.shippedSince))),
                    DataCell(Text(overseasQty(r.estimate), style: theme.textTheme.titleSmall)),
                  ]),
              ],
            ),
          ),
        ]);
      },
    );
  }

  /// 出荷の記録: every list shipped to this card (出庫済み), newest first.
  Widget _shipments(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(overseasEventsProvider(_site.id));
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: _refresh),
      data: (ev) {
        if (ev.shipments.isEmpty) return EmptyStateView(icon: Icons.local_shipping_outlined, title: l10n.osNoShipments);
        final list = ev.shipments.reversed.toList();
        final units = ev.shipments.fold<num>(0, (a, s) => a + s.units);
        return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text(l10n.osShipmentsTotal(ev.shipments.length, overseasQty(units)),
              key: const ValueKey('os-shipments-total'), style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final s in list)
            Card(
              key: ValueKey('os-shipment-${s.id}'),
              child: ExpansionTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text('${_day.format(s.day)}  ${s.fileName ?? ''}', style: theme.textTheme.titleSmall),
                subtitle: Text(l10n.obSummary(s.lines.length, s.units.round()), style: muted),
                trailing: s.outboundFileId == null
                    ? null
                    : TextButton(
                        key: ValueKey('os-shipment-open-${s.id}'),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => OutboundFileDetailScreen(fileId: s.outboundFileId!))),
                        child: Text(l10n.osOpenOutbound),
                      ),
                children: [
                  for (final l in s.lines)
                    ListTile(
                      dense: true,
                      title: Text(l.label),
                      subtitle: Text([if (l.jan != null) 'JAN ${l.jan}', if (l.maker != null) l.maker!].join(' · ')),
                      trailing: Text('× ${overseasQty(l.quantity)}', style: theme.textTheme.titleSmall),
                    ),
                ],
              ),
            ),
        ]);
      },
    );
  }

  Widget _stock(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(overseasStockProvider(_site.id));
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: _refresh),
      data: (stock) {
        final i = stock.import;
        if (i == null) {
          return EmptyStateView(icon: Icons.inventory_2_outlined, title: l10n.osNoStock);
        }
        final q = _search.text.trim().toLowerCase();
        final lines = [
          for (final l in stock.lines)
            if (q.isEmpty || '${l.jan ?? ''} ${l.code ?? ''} ${l.name ?? ''} ${l.maker ?? ''}'.toLowerCase().contains(q)) l,
        ];
        return LayoutBuilder(
          builder: (context, box) => ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(l10n.osNow, style: theme.textTheme.titleMedium),
              Text(
                l10n.osLatest(i.asOf == null ? '' : _day.format(i.asOf!), i.lineCount, overseasQty(i.units)),
                key: const ValueKey('os-stock-latest'),
                style: theme.textTheme.titleSmall,
              ),
              if (i.fileName != null)
                TextButton.icon(
                  key: const ValueKey('os-stock-file'),
                  onPressed: i.storagePath == null ? null : () => _view(i),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(i.fileName!),
                ),
              if (i.readPath != null)
                TextButton.icon(
                  key: const ValueKey('os-stock-read'),
                  onPressed: () => _downloadReading(i),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: Text(l10n.rdReadResult),
                ),
              Text(i.readBy == 'ai' ? l10n.osReadByAi : l10n.osReadBySheet, style: muted),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: 360,
              child: TextField(
                key: const ValueKey('os-stock-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.osSearch, isDense: true),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OverseasLinesTable(lines: lines, height: box.maxHeight - 140),
          ]),
        );
      },
    );
  }

  Widget _history(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(overseasImportsProvider(_site.id));
    final when = DateFormat('y/MM/dd HH:mm');
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: _refresh),
      data: (list) => list.isEmpty
          ? EmptyStateView(icon: Icons.history, title: l10n.osNoStock)
          : ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              for (final i in list)
                Card(
                  key: ValueKey('os-import-${i.id}'),
                  child: ListTile(
                    leading: Icon(i.readBy == 'ai' ? Icons.auto_awesome : Icons.table_chart_outlined),
                    title: Text(
                      [
                        l10n.osAsOfIs(i.asOf == null ? '' : _day.format(i.asOf!)),
                        if (i.fileName != null) i.fileName!,
                      ].join('  '),
                      style: theme.textTheme.titleSmall?.copyWith(decoration: i.undone ? TextDecoration.lineThrough : null),
                    ),
                    subtitle: Text(
                      [
                        l10n.obSummary(i.lineCount, i.units.round()),
                        if (i.createdByName != null) i.createdByName!,
                        if (i.createdAt != null) when.format(i.createdAt!),
                        if (i.undone) l10n.osUndone,
                      ].join(' · '),
                      style: muted,
                    ),
                    trailing: Wrap(spacing: AppSpacing.xs, children: [
                      if (i.storagePath != null)
                        IconButton(
                          key: ValueKey('os-import-view-${i.id}'),
                          tooltip: l10n.osFileView,
                          icon: const Icon(Icons.description_outlined),
                          onPressed: () => _view(i),
                        ),
                      if (i.readPath != null)
                        IconButton(
                          key: ValueKey('os-import-read-${i.id}'),
                          tooltip: l10n.rdReadResult,
                          icon: const Icon(Icons.table_view_outlined),
                          onPressed: () => _downloadReading(i),
                        ),
                      if (!i.undone)
                        IconButton(
                          key: ValueKey('os-import-undo-${i.id}'),
                          tooltip: l10n.osUndo,
                          icon: const Icon(Icons.undo),
                          onPressed: () => _undo(i),
                        ),
                    ]),
                  ),
                ),
            ]),
    );
  }
}
