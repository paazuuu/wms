import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../shipment/domain/shipment.dart';
import '../application/picking_ops_providers.dart';
import '../domain/pick_list.dart';
import 'pick_list_detail_screen.dart';
import 'pick_status_ui.dart';

/// Pick lists for the active warehouse. Starting one asks which open shipment
/// to pick against, then hands off to its detail screen.
class PickListIndexScreen extends ConsumerStatefulWidget {
  const PickListIndexScreen({super.key});

  @override
  ConsumerState<PickListIndexScreen> createState() => _PickListIndexScreenState();
}

class _PickListIndexScreenState extends ConsumerState<PickListIndexScreen> {
  bool _busy = false;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _start() async {
    final shipment = await showModalBottomSheet<Shipment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChooseShipmentSheet(),
    );
    if (shipment == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(pickingRepositoryProvider).start(shipment.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (list) {
        ref.invalidate(pickListsProvider);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PickListDetailScreen(pickListId: list.id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickListsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickListsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _start,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.shopping_cart_checkout),
        label: Text(_busy ? l10n.working : l10n.pickStart),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(pickListsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              icon: Icons.shopping_cart_checkout_outlined,
              title: l10n.pickingEmpty,
              message: l10n.pickingEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pickListsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _PickListCard(list: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PickListCard extends StatelessWidget {
  const _PickListCard({required this.list});

  final PickList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = PickListStatusUi.of(l10n, list.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PickListDetailScreen(pickListId: list.id),
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
                      list.shipmentNumber ?? '#${list.shipmentPlanId}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      list.customerName ?? '',
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
                    l10n.pickedProgress(list.doneTasks, list.totalTasks),
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

class _ChooseShipmentSheet extends ConsumerWidget {
  const _ChooseShipmentSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickableShipmentsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.pickChooseShipment,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(pickableShipmentsProvider),
              ),
              data: (shipments) {
                if (shipments.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.inbox_outlined,
                    title: l10n.pickNoShipments,
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  itemCount: shipments.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final s = shipments[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        title: Text(s.shipmentNumber),
                        subtitle: Text(s.customerName ?? ''),
                        trailing: Text(l10n.lineCount(s.lineCount)),
                        onTap: () => Navigator.pop(context, s),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
