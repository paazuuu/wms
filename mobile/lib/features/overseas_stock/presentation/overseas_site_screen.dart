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
import 'overseas_import_tab.dart';
import 'overseas_widgets.dart';

final _day = DateFormat('y/MM/dd');

/// One site abroad (0207): its stock now, a file read in for it, the files
/// read before (each can be taken back), and メモ with files.
class OverseasSiteScreen extends ConsumerStatefulWidget {
  const OverseasSiteScreen({super.key, required this.site, this.initialTab = 0});

  final OverseasSite site;
  final int initialTab;

  @override
  ConsumerState<OverseasSiteScreen> createState() => _OverseasSiteScreenState();
}

class _OverseasSiteScreenState extends ConsumerState<OverseasSiteScreen> with SingleTickerProviderStateMixin {
  late OverseasSite _site = widget.site;
  late final _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
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

  Future<void> _undo(OverseasImport i) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.osUndoQ(i.asOf == null ? '' : _day.format(i.asOf!))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('os-undo-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.osUndo)),
        ],
      ),
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
          Tab(key: const ValueKey('os-tab-stock'), text: l10n.osTabStock),
          Tab(key: const ValueKey('os-tab-import'), text: l10n.osTabImport),
          Tab(key: const ValueKey('os-tab-history'), text: l10n.osTabHistory),
          Tab(key: const ValueKey('os-tab-notes'), text: l10n.wlTabNotes(_site.noteCount)),
        ]),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Text(
            [
              overseasKindLabel(l10n, _site.kind),
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
            _stock(context),
            OverseasImportTab(
              site: _site,
              onDone: () {
                _refresh();
                _tabs.animateTo(0);
              },
            ),
            _history(context),
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
