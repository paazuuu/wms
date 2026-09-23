import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../picking_ops/presentation/pick_list_detail_screen.dart';
import '../application/pick_wave_providers.dart';
import '../domain/pick_wave.dart';
import 'pick_wave_sheet_screen.dart';
import 'pick_wave_status_ui.dart';

/// One wave: its lists, who is working it, and the aggregated sheet (0077).
class PickWaveDetailScreen extends ConsumerWidget {
  const PickWaveDetailScreen({super.key, required this.waveId});

  final int waveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickWaveDetailProvider(waveId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.code ?? l10n.waveListTitle),
        actions: [
          IconButton(
            tooltip: l10n.waveViewSheet,
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PickWaveSheetScreen(waveId: waveId),
            )),
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(pickWaveDetailProvider(waveId)),
        ),
        data: (wave) => _Body(wave: wave),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.wave});

  final PickWave wave;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  PickWave get _wave => widget.wave;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _refresh() {
    ref.invalidate(pickWaveDetailProvider(_wave.id));
    ref.invalidate(pickWaveListProvider);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _assign(String? userId) async {
    setState(() => _busy = true);
    final result =
        await ref.read(pickWaveRepositoryProvider).assign(_wave.id, userId: userId);
    if (!mounted) return;
    setState(() => _busy = false);
    final l10n = AppLocalizations.of(context);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.waveComplete, l10n.waveCompleteQ, l10n.waveComplete)) return;
    setState(() => _busy = true);
    final result = await ref.read(pickWaveRepositoryProvider).complete(_wave.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (outcome) {
        _refresh();
        _snack(l10n.waveCompleted(outcome.count));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.waveCancelAction, l10n.waveCancelQ, l10n.waveCancelAction)) {
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(pickWaveRepositoryProvider).cancel(_wave.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        _snack(l10n.waveCancelled);
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = PickWaveStatusUi.of(l10n, _wave.status);
    final myId = ref.watch(authControllerProvider).user?.id;
    final isMine = _wave.assignedTo != null && _wave.assignedTo == myId;
    final isOpen = _wave.status == PickWaveStatus.open ||
        _wave.status == PickWaveStatus.picking;
    final allDone = _wave.taskCount > 0 && _wave.pickedCount >= _wave.taskCount;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _wave.assignedToName ?? l10n.waveUnassigned,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.waveListsProgress(_wave.pickedCount, _wave.taskCount),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.waveLists, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final list in _wave.lists) ...[
                _WaveListTile(list: list),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
        if (isOpen)
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (isMine)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _assign(null),
                              child: Text(l10n.waveUnassign),
                            ),
                          )
                        else
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _assign(myId),
                              child: Text(l10n.waveAssignToMe),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _cancel,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.error),
                            child: Text(l10n.waveCancelAction),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.minTouch,
                      child: FilledButton.icon(
                        onPressed: _busy || !allDone ? null : _complete,
                        icon: const Icon(Icons.task_alt),
                        label: Text(allDone ? l10n.waveComplete : l10n.waveIncomplete),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WaveListTile extends StatelessWidget {
  const _WaveListTile({required this.list});

  final PickWaveList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          list.isDone ? Icons.check_circle_outline : Icons.pending_outlined,
          color: list.isDone ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(list.shipmentNumber ?? '#${list.shipmentPlanId}'),
        subtitle: Text(list.customerName ?? ''),
        trailing: Text(l10n.waveListsProgress(list.pickedCount, list.taskCount)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PickListDetailScreen(pickListId: list.pickListId),
        )),
      ),
    );
  }
}
