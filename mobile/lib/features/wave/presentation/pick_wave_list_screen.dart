import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../picking_ops/application/picking_ops_providers.dart';
import '../../shipment/domain/shipment.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/pick_wave_providers.dart';
import '../domain/pick_wave.dart';
import 'pick_wave_detail_screen.dart';
import 'pick_wave_status_ui.dart';

/// §15's waves: grouping several shipments' pick lists so the same parcel
/// wanted by more than one order becomes one stop, not one walk per order.
class PickWaveListScreen extends ConsumerStatefulWidget {
  const PickWaveListScreen({super.key});

  @override
  ConsumerState<PickWaveListScreen> createState() => _PickWaveListScreenState();
}

class _PickWaveListScreenState extends ConsumerState<PickWaveListScreen> {
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

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<List<Shipment>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChooseShipmentsSheet(),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final warehouseId = ref.read(activeWarehouseIdProvider);
    if (warehouseId == null) return;

    setState(() => _busy = true);
    final result = await ref.read(pickWaveRepositoryProvider).create(
          warehouseId: warehouseId,
          shipmentPlanIds: selected.map((s) => s.id).toList(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (created) {
        ref.invalidate(pickWaveListProvider);
        final code = created.code ?? '#${created.waveId}';
        _snack(created.skipped.isEmpty
            ? l10n.waveCreated(code, created.pickListIds.length)
            : l10n.waveCreatedWithSkips(
                code, created.pickListIds.length, created.skipped.length));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PickWaveDetailScreen(waveId: created.waveId),
        ));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickWaveListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waveListTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.route_outlined),
        label: Text(_busy ? l10n.working : l10n.waveCreate),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(pickWaveListProvider),
        ),
        data: (waves) {
          if (waves.isEmpty) {
            return EmptyStateView(
              icon: Icons.route_outlined,
              title: l10n.waveEmpty,
              message: l10n.waveEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pickWaveListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: waves.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _WaveCard(wave: waves[i]),
            ),
          );
        },
      ),
    );
  }
}

class _WaveCard extends StatelessWidget {
  const _WaveCard({required this.wave});

  final PickWave wave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = PickWaveStatusUi.of(l10n, wave.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PickWaveDetailScreen(waveId: wave.id),
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
                      wave.code ?? '#${wave.id}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontFamily: AppFonts.mono),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wave.assignedToName ?? l10n.waveUnassigned,
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
                    l10n.waveListsProgress(wave.pickedCount, wave.taskCount),
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

class _ChooseShipmentsSheet extends ConsumerStatefulWidget {
  const _ChooseShipmentsSheet();

  @override
  ConsumerState<_ChooseShipmentsSheet> createState() => _ChooseShipmentsSheetState();
}

class _ChooseShipmentsSheetState extends ConsumerState<_ChooseShipmentsSheet> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickableShipmentsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.waveChooseShipments,
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
                    title: l10n.waveNoShipments,
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
                    final checked = _selected.contains(s.id);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: CheckboxListTile(
                        value: checked,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(s.id);
                          } else {
                            _selected.remove(s.id);
                          }
                        }),
                        title: Text(s.shipmentNumber),
                        subtitle: Text(s.customerName ?? ''),
                        secondary: Text(l10n.lineCount(s.lineCount)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouch,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          final chosen = (async.valueOrNull ?? const <Shipment>[])
                              .where((s) => _selected.contains(s.id))
                              .toList();
                          Navigator.pop(context, chosen);
                        },
                  child: Text(l10n.waveCreate),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
