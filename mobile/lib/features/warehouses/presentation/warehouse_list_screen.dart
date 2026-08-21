import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';
import 'warehouse_detail_screen.dart';
import 'warehouse_status_ui.dart';

/// Browse and search warehouses (sites). Read-only: tapping a warehouse opens
/// its detail.
class WarehouseListScreen extends ConsumerStatefulWidget {
  const WarehouseListScreen({super.key});

  @override
  ConsumerState<WarehouseListScreen> createState() =>
      _WarehouseListScreenState();
}

class _WarehouseListScreenState extends ConsumerState<WarehouseListScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next == _query) {
      ref.invalidate(warehouseSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(warehouseSearchProvider(_query));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featWarehouses)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.hintWarehouses,
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(warehouseSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.warehouse_outlined,
                        title: _query.isEmpty
                            ? l10n.emptyWarehouses
                            : l10n.noMatchesFor(_query),
                        message: l10n.tryDifferentNameCode,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _WarehouseCard(warehouse: items[index]),
                      ),
                loading: () => LoadingView(message: l10n.loading),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () =>
                      ref.invalidate(warehouseSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  const _WarehouseCard({required this.warehouse});

  final Warehouse warehouse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = WarehouseStatusUi.of(warehouse);
    final count = warehouse.locationsCount;
    final subtitle = warehouse.city?.trim().isNotEmpty == true
        ? warehouse.city!
        : warehouse.displayCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WarehouseDetailScreen(warehouseId: warehouse.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: status.tone, icon: status.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            warehouse.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (warehouse.isDefault) ...[
                          const SizedBox(width: AppSpacing.sm),
                          StatusPill(
                            tone: StatusTone.info,
                            label: l10n.warehouseDefault,
                            icon: Icons.star_outline,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (count != null)
                StatusPill(
                  tone: StatusTone.neutral,
                  label: '$count ${count == 1 ? 'bin' : 'bins'}',
                  icon: Icons.place_outlined,
                  dense: true,
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
