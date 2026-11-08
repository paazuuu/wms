import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/ship_destinations_screen.dart' show pickDestinationCard;
import '../data/overseas_stock_repository.dart';
import '../domain/overseas_stock.dart';
import 'overseas_site_screen.dart';
import 'overseas_widgets.dart';

final _day = DateFormat('y/MM/dd');

/// 国外の仮想在庫 (0207): the sites abroad — our branches and partner
/// companies — and what each says it holds, read from the files they send;
/// every product across them. Kept apart from our own stock. (The
/// warehouses abroad goods were moved to by 倉庫間移動 (0088) are no longer
/// shown: what is shipped to a partner abroad is counted here, by its card.)
class OverseasStockScreen extends ConsumerStatefulWidget {
  const OverseasStockScreen({super.key});

  @override
  ConsumerState<OverseasStockScreen> createState() => _OverseasStockScreenState();
}

class _OverseasStockScreenState extends ConsumerState<OverseasStockScreen> {
  bool _archived = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// A 出荷先カード chosen (or made there): its site, opened.
  Future<void> _addSite() async {
    final l10n = AppLocalizations.of(context);
    final d = await pickDestinationCard(context);
    if (d?.id == null || !mounted) return;
    final r = await ref.read(overseasStockRepositoryProvider).siteForCard(d!.id!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(overseasSitesProvider);
        await _open(OverseasSite(id: data, name: d.name, destinationId: d.id, destinationName: d.name));
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _open(OverseasSite s, {int tab = 0}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OverseasSiteScreen(site: s, initialTab: tab)));
    ref.invalidate(overseasSitesProvider);
    ref.invalidate(overseasOverviewProvider);
  }

  Future<void> _archive(OverseasSite s) async {
    await ref.read(overseasStockRepositoryProvider).archiveSite(s.id, !s.archived);
    ref.invalidate(overseasSitesProvider);
    ref.invalidate(overseasOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.osTitle),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(key: const ValueKey('os-tab-sites'), text: l10n.osTabSites),
            Tab(key: const ValueKey('os-tab-overview'), text: l10n.osTabOverview),
          ]),
        ),
        body: TabBarView(children: [
          _sites(context),
          _overview(context),
        ]),
      ),
    );
  }

  Widget _sites(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(overseasSitesProvider(_archived));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('os-add-site'),
        onPressed: _addSite,
        icon: const Icon(Icons.add_business_outlined),
        label: Text(l10n.osAddSite),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
            message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(overseasSitesProvider)),
        data: (sites) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          children: [
            Text(l10n.osIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            FilterChip(
              key: const ValueKey('os-show-archived'),
              label: Text(l10n.osShowArchived),
              selected: _archived,
              onSelected: (v) => setState(() => _archived = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sites.isEmpty) Text(l10n.osNoSites, key: const ValueKey('os-no-sites'), style: muted),
            for (final s in sites)
              Card(
                key: ValueKey('os-site-${s.id}'),
                child: ListTile(
                  onTap: () => _open(s),
                  leading: Icon(s.partner ? Icons.handshake_outlined : Icons.store_mall_directory_outlined,
                      color: s.archived ? scheme.onSurfaceVariant : scheme.primary),
                  title: Row(children: [
                    Flexible(child: Text(s.name, style: theme.textTheme.titleSmall)),
                    if (s.isDefault) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Chip(
                        key: ValueKey('os-default-${s.id}'),
                        visualDensity: VisualDensity.compact,
                        label: Text(l10n.osDefaultBadge),
                      ),
                    ],
                  ]),
                  subtitle: Text(
                    [
                      if (s.destinationName != null) l10n.osCardIs(s.destinationName!) else overseasKindLabel(l10n, s.kind),
                      if (s.country != null || s.city != null) [s.country, s.city].whereType<String>().join(' '),
                      l10n.osShippedLine(s.shipmentCount, overseasQty(s.shippedUnits)),
                      if (s.lastShippedOn != null) l10n.osLastShipped(_day.format(s.lastShippedOn!)),
                      if (s.latest case final i?)
                        l10n.osLatest(i.asOf == null ? '' : _day.format(i.asOf!), i.lineCount, overseasQty(i.units))
                      else
                        l10n.osNoReport,
                      l10n.osEstimateLine(s.estimateItems, overseasQty(s.estimateUnits)),
                      if (s.noteCount > 0) l10n.wlNotesBadge(s.noteCount),
                      if (s.archived) l10n.osArchivedBadge,
                    ].join(' · '),
                    style: muted,
                  ),
                  trailing: Wrap(spacing: AppSpacing.xs, children: [
                    IconButton(
                      key: ValueKey('os-site-import-${s.id}'),
                      tooltip: l10n.osTabImport,
                      icon: const Icon(Icons.upload_file_outlined),
                      onPressed: s.archived ? null : () => _open(s, tab: 3),
                    ),
                    IconButton(
                      key: ValueKey('os-site-archive-${s.id}'),
                      tooltip: s.archived ? l10n.osUnarchive : l10n.osArchive,
                      icon: Icon(s.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                      onPressed: () => _archive(s),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(overseasOverviewProvider(_query));
    return ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
      SizedBox(
        width: 420,
        child: TextField(
          key: const ValueKey('os-overview-search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.osSearch,
            isDense: true,
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => _query = _search.text)),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ...async.when(
        loading: () => [LoadingView(message: l10n.loading)],
        error: (e, _) => [ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(overseasOverviewProvider))],
        data: (rows) => rows.isEmpty
            ? [Text(l10n.osOverviewEmpty, key: const ValueKey('os-overview-empty'), style: muted)]
            : [
                for (final (i, p) in rows.indexed)
                  Card(
                    key: ValueKey('os-product-$i'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.label, style: theme.textTheme.titleSmall),
                            Text([if (p.jan != null) 'JAN ${p.jan}', if (p.code != null) p.code!, if (p.maker != null) p.maker!].join(' · '),
                                style: muted),
                            if (p.ours != null)
                              Text('${l10n.osOursBadge}: ${p.ours}', style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                              for (final h in p.sites)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(h.kind == 'partner' ? Icons.handshake_outlined : Icons.store_mall_directory_outlined, size: 16),
                                  label: Text('${h.siteName}  ${overseasQty(h.quantity)}'
                                      '${h.asOf == null ? '' : '（${DateFormat('MM/dd').format(h.asOf!)}）'}'),
                                ),
                            ]),
                          ]),
                        ),
                        Text('${l10n.osColTotal} ${overseasQty(p.total)}${p.unit == null ? '' : ' ${p.unit}'}',
                            key: ValueKey('os-product-total-$i'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ],
      ),
    ]);
  }
}
