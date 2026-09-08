import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';
import 'add_warehouse_screen.dart';
import 'warehouse_overview_screen.dart';

/// The persistent warehouse context control for the top bar (spec §4).
///
/// With a single warehouse it is a quiet label — the operator is never forced to
/// choose (spec §4.1). From two warehouses up it becomes a real picker with an
/// "all warehouses" option and a top-level "add warehouse" action (spec §4.2).
class WarehousePicker extends ConsumerWidget {
  const WarehousePicker({super.key});

  static const _allValue = -1;
  static const _addValue = -2;
  static const _manageValue = -3;

  Future<void> _handle(BuildContext context, WidgetRef ref, int value) async {
    switch (value) {
      case _allValue:
        ref.read(activeWarehouseIdProvider.notifier).state = null;
      case _addValue:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddWarehouseScreen()),
        );
      case _manageValue:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WarehouseOverviewScreen()),
        );
      default:
        ref.read(activeWarehouseIdProvider.notifier).state = value;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(warehouseOverviewProvider);

    // Never block the top bar on this: while loading, or if the warehouse API is
    // unreachable, the rest of the shell stays fully usable.
    final overview = async.valueOrNull;
    if (overview == null || overview.warehouses.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeId = ref.watch(activeWarehouseIdProvider);
    final active = overview.byId(activeId);
    final label = active?.name ??
        (overview.isMultiWarehouse
            ? l10n.whAllWarehouses
            : overview.preferred?.name ?? l10n.whAllWarehouses);

    return PopupMenuButton<int>(
      tooltip: l10n.whSwitch,
      position: PopupMenuPosition.under,
      onSelected: (v) => _handle(context, ref, v),
      itemBuilder: (context) => [
        for (final w in overview.warehouses)
          PopupMenuItem<int>(
            value: w.id,
            child: _WarehouseRow(
              warehouse: w,
              selected: activeId == w.id,
            ),
          ),
        if (overview.isMultiWarehouse) ...[
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: _allValue,
            child: Row(
              children: [
                Icon(Icons.select_all,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(l10n.whAllWarehouses),
                if (activeId == null) ...[
                  const Spacer(),
                  Icon(Icons.check,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: _manageValue,
          child: Row(
            children: [
              Icon(Icons.warehouse_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.whManage),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: _addValue,
          child: Row(
            children: [
              Icon(Icons.add,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.whAdd),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warehouse_outlined, size: 18),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WarehouseRow extends StatelessWidget {
  const _WarehouseRow({required this.warehouse, required this.selected});

  final Warehouse warehouse;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final nf = NumberFormat.decimalPattern();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(warehouse.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${l10n.whStatSku} ${nf.format(warehouse.skuCount)}'
                ' · ${l10n.whStatOnHand} ${nf.format(warehouse.onHand)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (selected) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.check, size: 18, color: scheme.primary),
        ],
      ],
    );
  }
}
