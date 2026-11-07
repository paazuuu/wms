import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../packing/presentation/packing_screen.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/outbound_file_repository.dart';
import 'outbound_file_detail_screen.dart';

/// 出荷手配 › 出庫日 未定: every list with no day yet — 出荷明細 (出庫予定)
/// and 在庫外出荷 — in all the warehouses one may see, to open again and
/// put right: the rows and the 出荷先 (its detail), the warehouse it ships
/// from, the gross weight estimate, and the day.
class OutboundUndecidedTab extends ConsumerStatefulWidget {
  const OutboundUndecidedTab({super.key});

  @override
  ConsumerState<OutboundUndecidedTab> createState() => _OutboundUndecidedTabState();
}

class _OutboundUndecidedTabState extends ConsumerState<OutboundUndecidedTab> with AutomaticKeepAliveClientMixin {
  /// null: both; 'stock' or 'proxy'.
  String? _kind;

  /// null: all warehouses.
  int? _warehouseId;

  @override
  bool get wantKeepAlive => true;

  void _refresh(int fileId) {
    ref.invalidate(outboundUndecidedProvider);
    ref.invalidate(outboundFileDetailProvider(fileId));
    ref.invalidate(outboundFilesProvider);
  }

  Future<void> _open(OutboundFileSummary f) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OutboundFileDetailScreen(fileId: f.id)));
    if (mounted) _refresh(f.id);
  }

  Future<void> _packing(OutboundFileSummary f) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackingScreen(fileId: f.id)));
    if (mounted) _refresh(f.id);
  }

  Future<void> _setDay(OutboundFileSummary f) async {
    final l10n = AppLocalizations.of(context);
    final day = await showDatePicker(
        context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (day == null || !mounted) return;
    final r = await ref.read(outboundFileRepositoryProvider).reschedule(f.id, day);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        _refresh(f.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.ofRescheduled(DateFormat('y/MM/dd').format(day)))));
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(outboundUndecidedProvider(null));
    final warehouses = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(outboundUndecidedProvider(null))),
      data: (all) {
        final files = [
          for (final f in all)
            if ((_kind == null || f.kind == _kind) && (_warehouseId == null || f.warehouseId == _warehouseId)) f,
        ];
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(outboundUndecidedProvider(null)),
          child: ListView(
            key: const ValueKey('ud-list'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(children: [
                Icon(Icons.event_busy_outlined, color: scheme.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.ofUdTitle(files.length), key: const ValueKey('ud-title'), style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: l10n.pkReload,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(outboundUndecidedProvider(null)),
                ),
              ]),
              Text(l10n.obHelpUndecided, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final (k, label) in [(null, l10n.ofUdKindAll), ('stock', l10n.ofUdKindStock), ('proxy', l10n.obHubProxy)])
                  ChoiceChip(
                    key: ValueKey('ud-kind-${k ?? 'all'}'),
                    label: Text(label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<int?>(
                  key: const ValueKey('ud-warehouse'),
                  value: _warehouseId,
                  isDense: true,
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(l10n.ofUdAllWarehouses)),
                    for (final w in warehouses) DropdownMenuItem<int?>(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _warehouseId = v),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateView(key: const ValueKey('ud-empty'), icon: Icons.event_available_outlined, title: l10n.ofUdEmpty),
                ),
              for (final f in files) _row(context, f),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, OutboundFileSummary f) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: ValueKey('ud-row-${f.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _open(f),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (f.proxy) ...[
                Text(l10n.prBadge, style: theme.textTheme.labelMedium?.copyWith(color: scheme.tertiary, fontWeight: FontWeight.w700)),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(child: Text(f.fileName, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Text(
              [
                l10n.ofWarehouseFrom(f.warehouseName ?? '#${f.warehouseId}'),
                if (f.shipTo != null) f.shipTo!.nameEn ?? f.shipTo!.name else if (f.destination != null) f.destination!,
                l10n.prCardLines(f.lineCount, f.quantityTotal),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            if (f.createdByName != null && f.createdAt != null)
              Text(l10n.ofUdCreated(f.createdByName!, DateFormat('y/MM/dd HH:mm').format(f.createdAt!)), style: muted),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              FilledButton.tonalIcon(
                key: ValueKey('ud-open-${f.id}'),
                onPressed: () => _open(f),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.ofUdOpen),
              ),
              OutlinedButton.icon(
                key: ValueKey('ud-set-day-${f.id}'),
                onPressed: () => _setDay(f),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(l10n.ofSetDay),
              ),
              OutlinedButton.icon(
                key: ValueKey('ud-warehouse-${f.id}'),
                onPressed: () async {
                  if (await changeOutboundWarehouse(context, ref, f) && mounted) _refresh(f.id);
                },
                icon: const Icon(Icons.warehouse_outlined, size: 18),
                label: Text(l10n.ofWarehouseChange),
              ),
              OutlinedButton.icon(
                key: ValueKey('ud-packing-${f.id}'),
                onPressed: () => _packing(f),
                icon: const Icon(Icons.scale_outlined, size: 18),
                label: Text(l10n.ofUdPacking),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
