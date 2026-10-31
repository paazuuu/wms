import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/inspection_providers.dart';
import '../domain/inspection.dart';
import 'bulk_inspection_screen.dart';
import 'inspection_detail_screen.dart';
import 'qc_result_ui.dart';
import '../../../core/offline/pending_sync_banner.dart';
import '../data/offline_inspection_repository.dart';
import '../../home/presentation/feature_link.dart';
import '../../stock_import/data/stock_import_repository.dart' show awaitingImportsProvider;
import '../../master_import/data/master_import_repository.dart' show masterImportsProvider;
import '../../master_import/domain/master_import.dart';
import '../../stock_import/presentation/import_view_screen.dart' show ImportViewScreen;
import '../../stock_import/presentation/stock_inspection_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';

/// Where what is checked came from (0174): stock taken in from a file
/// (発注), or goods received (受領).
enum InspectionSource { all, file, receipt }

final inspectionSourceProvider = StateProvider<InspectionSource>((_) => InspectionSource.all);

/// 検品 (0174): everything waiting to be checked in one place — stock taken
/// in from a file first, then goods received — and what was checked below.
/// 取込の検品 is no longer a menu of its own; a file opens its lines here.
/// The 合格・不合格 kinds are the received goods' only, shown for 受領.
class QcInspectionListScreen extends ConsumerWidget {
  const QcInspectionListScreen({super.key});

  static const _filters = <String?>[
    null,
    'PENDING',
    'PARTIAL',
    'FAIL',
    'HOLD',
    'PASS',
  ];

  String _filterLabel(AppLocalizations l10n, String? status) => switch (status) {
        null => l10n.filterAll,
        'PENDING' => l10n.qcResultPending,
        'PASS' => l10n.qcResultPass,
        'FAIL' => l10n.qcResultFail,
        'PARTIAL' => l10n.qcResultPartial,
        'HOLD' => l10n.qcResultHold,
        _ => status,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = ref.watch(inspectionSourceProvider);
    final async = source == InspectionSource.file ? null : ref.watch(inspectionListProvider);
    final active = ref.watch(inspectionStatusFilterProvider);

    void choose(InspectionSource s) {
      ref.read(inspectionSourceProvider.notifier).state = s;
      // The kinds belong to 受領: elsewhere every one is shown.
      if (s != InspectionSource.receipt) ref.read(inspectionStatusFilterProvider.notifier).state = null;
    }

    final receipts = async?.valueOrNull ?? const <Inspection>[];
    final waitingReceipts = [for (final i in receipts) if (i.status == QcResult.pending) i];
    final checkedReceipts = [for (final i in receipts) if (i.status != QcResult.pending) i];
    final files = source != InspectionSource.receipt;

    Widget heading(String text, {Key? key}) => Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.xs),
          child: Text(text, key: key, style: theme.textTheme.titleSmall),
        );

    final children = <Widget>[
      if (source == InspectionSource.receipt) ...[
        // 受領 only: by its result, as before.
        ...?async?.when(
          loading: () => [SizedBox(height: 320, child: LoadingView(message: l10n.loading))],
          error: (e, _) => [
            SizedBox(
                height: 320,
                child: ErrorStateView(message: '$e', onRetry: () => ref.invalidate(inspectionListProvider))),
          ],
          data: (list) => list.isEmpty
              ? [
                  SizedBox(
                    height: 360,
                    child: EmptyStateView(
                      key: const ValueKey('qc-receipt-empty'),
                      icon: Icons.fact_check_outlined,
                      title: l10n.qcListEmpty,
                      message: l10n.qcListEmptyBody,
                    ),
                  ),
                ]
              : [for (final i in list) _InspectionCard(inspection: i)],
        ),
      ] else ...[
        // Waiting: files first, then received goods.
        const StockFileWaiting(all: true),
        if (source == InspectionSource.all && waitingReceipts.isNotEmpty) ...[
          heading(l10n.qcReceiptWaiting(waitingReceipts.length), key: const ValueKey('qc-receipt-waiting')),
          for (final i in waitingReceipts) _InspectionCard(inspection: i),
        ],
        // Checked.
        StockFileChecked(showHeading: true, extra: source == InspectionSource.all ? checkedReceipts.length : 0),
        if (source == InspectionSource.all)
          for (final i in checkedReceipts) _InspectionCard(inspection: i),
        _NothingWaiting(files: files, receipts: source == InspectionSource.all ? receipts.length : 0),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qcTitle),
        actions: [
          IconButton(
            key: const ValueKey('qc-open-bulk'),
            tooltip: l10n.bulkQcTitle,
            icon: const Icon(Icons.done_all),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkInspectionScreen()),
            ),
          ),
          const FeatureLinkButton('held_stock'),
        ],
      ),
      body: Column(
        children: [
          // A weak connection: what waits on the device, and a way to send it.
          PendingSyncBanner(onSync: () async {
            final repo = ref.read(inspectionRepositoryProvider);
            final sent = repo is OfflineInspectionRepository ? await repo.flush() : 0;
            ref.invalidate(inspectionListProvider);
            return sent;
          }),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                for (final (s, label) in [
                  (InspectionSource.all, l10n.filterAll),
                  (InspectionSource.file, l10n.qcFileBadge),
                  (InspectionSource.receipt, l10n.qcReceiptBadge),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: ChoiceChip(
                        key: ValueKey('qc-src-${s.name}'),
                        selected: source == s,
                        label: Text(label),
                        onSelected: (_) => choose(s),
                      ),
                    ),
                  ),
                if (source == InspectionSource.receipt) ...[
                  const VerticalDivider(indent: 14, endIndent: 14),
                  const SizedBox(width: AppSpacing.sm),
                  for (final f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Center(
                        child: FilterChip(
                          selected: active == f,
                          label: Text(_filterLabel(l10n, f)),
                          onSelected: (_) => ref.read(inspectionStatusFilterProvider.notifier).state = f,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(inspectionListProvider);
                ref.invalidate(awaitingImportsProvider);
                ref.invalidate(masterImportsProvider);
              },
              child: ListView(
                key: const ValueKey('qc-list'),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing to check at all: said once, with where things come from.
class _NothingWaiting extends ConsumerWidget {
  const _NothingWaiting({required this.files, required this.receipts});

  final bool files;
  final int receipts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final waiting = (ref.watch(awaitingImportsProvider).valueOrNull ?? const [])
        .where((a) => warehouseId == null || a.warehouseId == warehouseId)
        .length;
    final checked = StockFileChecked.itemsOf(ref).length;
    if (receipts > 0 || (files && waiting + checked > 0)) return const SizedBox.shrink();
    return SizedBox(
      height: 360,
      child: EmptyStateView(
        key: const ValueKey('qc-empty'),
        icon: Icons.fact_check_outlined,
        title: l10n.qcListEmpty,
        message: l10n.qcNothingBody,
      ),
    );
  }
}

/// Stock files checked and in stock, for the warehouse in view: the latest
/// few, each opening as taken in.
class StockFileChecked extends ConsumerWidget {
  const StockFileChecked({super.key, this.showHeading = true, this.extra = 0});

  final bool showHeading;

  /// Checked received goods listed after these, counted in the heading.
  final int extra;

  static const shown = 10;

  static List<MasterImport> itemsOf(WidgetRef ref) {
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final all = ref.watch(masterImportsProvider).valueOrNull ?? const <MasterImport>[];
    return [
      for (final m in all)
        if (m.source == 'stock_file' &&
            m.status == MasterImportStatus.stockDone &&
            m.undoneAt == null &&
            (warehouseId == null || m.warehouseId == null || m.warehouseId == warehouseId))
          m,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = itemsOf(ref);
    if (items.isEmpty && extra == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showHeading)
        Padding(
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.xs),
          child: Text(l10n.qcChecked(items.length + extra), key: const ValueKey('qc-checked'), style: theme.textTheme.titleSmall),
        ),
      for (final m in items.take(shown))
        Card(
          key: ValueKey('qc-file-done-${m.id}'),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListTile(
            dense: true,
            leading: const StatusAvatar(tone: StatusTone.success, icon: Icons.inventory_outlined),
            title: Text(l10n.siFile(m.id, m.originalName ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              if (m.warehouseName case final w?) w,
              l10n.calInStock,
            ].join(' · ')),
            trailing: StatusPill(tone: StatusTone.success, label: l10n.qcFileBadge, dense: true),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportViewScreen(importId: m.id))),
          ),
        ),
    ]);
  }
}

/// Stock files waiting for inspection, for the warehouse in view: the first
/// few, each opening its lines to count, and a way to all of them.
class StockFileWaiting extends ConsumerWidget {
  const StockFileWaiting({super.key, this.all = false});

  /// Every one (検品), not only the first few.
  final bool all;

  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final all = ref.watch(awaitingImportsProvider).valueOrNull ?? const [];
    final items = [for (final a in all) if (warehouseId == null || a.warehouseId == warehouseId) a];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('qc-file-waiting'),
      padding: EdgeInsets.fromLTRB(this.all ? 0 : AppSpacing.lg, this.all ? AppSpacing.sm : 0, this.all ? 0 : AppSpacing.lg, AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.pending_actions_outlined, size: 18, color: scheme.tertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(l10n.qcFileWaiting(items.length), style: theme.textTheme.titleSmall)),
          if (!this.all && items.length > shown)
            TextButton(
              key: const ValueKey('qc-file-waiting-all'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockInspectionScreen())),
              child: Text(l10n.qcFileWaitingAll(items.length)),
            ),
        ]),
        Text(l10n.qcFileWaitingHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        for (final a in this.all ? items : items.take(shown))
          Card(
            key: ValueKey('qc-file-${a.id}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ListTile(
              dense: true,
              leading: const StatusAvatar(tone: StatusTone.warning, icon: Icons.pending_actions_outlined),
              title: Text(l10n.siFile(a.id, a.fileName ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                if (a.warehouseName case final w?) w,
                l10n.siLeft(a.left, a.lines, a.quantityLeft),
              ].join(' · ')),
              trailing: StatusPill(tone: StatusTone.warning, label: l10n.qcFileBadge, dense: true),
              onTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: a.id)));
                ref.invalidate(awaitingImportsProvider);
              },
            ),
          ),
      ]),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = QcResultUi.of(l10n, inspection.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              InspectionDetailScreen(inspectionId: inspection.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              StatusAvatar(tone: ui.tone, icon: ui.icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.deliveryNumber ?? '#${inspection.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inspection.supplierName ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lineCount(inspection.lineCount),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
