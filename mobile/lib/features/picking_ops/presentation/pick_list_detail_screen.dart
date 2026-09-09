import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../stock_ops/presentation/stock_ops_ui.dart' show signed;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/picking_ops_providers.dart';
import '../domain/pick_list.dart';
import 'pick_status_ui.dart';

/// One pick list: every task, what was actually picked, and — for a warehouse
/// that uses locations — which bin it came from. A short or over pick shows as
/// its own status rather than being rounded to plan (spec §10).
class PickListDetailScreen extends ConsumerWidget {
  const PickListDetailScreen({super.key, required this.pickListId});

  final int pickListId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pickListDetailProvider(pickListId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.shipmentNumber ?? l10n.pickListsTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(pickListDetailProvider(pickListId)),
        ),
        data: (list) => _Body(list: list),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.list});

  final PickList list;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  PickList get _list => widget.list;

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
    ref.invalidate(pickListDetailProvider(_list.id));
    ref.invalidate(pickListsProvider);
  }

  Future<void> _record(PickTask task) async {
    final bins = _list.usesLocations && _list.warehouseId != null
        ? await ref.read(warehouseBinsProvider(_list.warehouseId!).future)
        : const <Bin>[];
    if (!mounted) return;

    final draft = await showDialog<_PickDraft>(
      context: context,
      builder: (_) => _RecordPickDialog(task: task, bins: bins),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(pickingRepositoryProvider).recordPick(
          task.id,
          quantity: draft.quantity,
          binId: draft.binId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    final pending = _list.pendingTasks;
    if (pending > 0) {
      // Not counting a line is not the same as picking it as zero — the
      // backend refuses, so the UI explains rather than lets the tap fail
      // silently.
      _snack(l10n.pickCompleteBlocked, danger: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.pickCompleteQ),
        content: Text(l10n.pickCompleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pickComplete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(pickingRepositoryProvider).complete(_list.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (completed) {
        _refresh();
        _snack(l10n.pickCompleted(
            completed.summary.shortLines, completed.summary.overLines));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.pickCancelQ),
        content: Text(l10n.pickCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pickCancelAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(pickingRepositoryProvider).cancel(_list.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        _snack(l10n.pickCancelled);
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ui = PickListStatusUi.of(l10n, _list.status);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
              const SizedBox(width: AppSpacing.sm),
              if (_list.customerName != null)
                Expanded(
                  child: Text(
                    _list.customerName!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              Text(
                l10n.pickedProgress(_list.doneTasks, _list.totalTasks),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: _list.tasks.isEmpty
              ? EmptyStateView(
                  icon: Icons.shopping_cart_checkout_outlined,
                  title: l10n.noLinesToPick)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _list.tasks.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _TaskCard(
                    task: _list.tasks[i],
                    onTap: _list.isOpen && !_busy
                        ? () => _record(_list.tasks[i])
                        : null,
                  ),
                ),
        ),
        if (_list.isOpen)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    SizedBox(
                      height: AppSpacing.minTouch,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancel,
                        child: Text(l10n.pickCancelAction),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.minTouch,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _complete,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.done_all),
                          label: Text(_busy ? l10n.working : l10n.pickComplete),
                        ),
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.onTap});

  final PickTask task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = PickTaskStatusUi.of(l10n, task.status);
    final title = task.productName.isNotEmpty ? task.productName : task.janCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(task.janCode,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: AppFonts.mono,
                                      color: scheme.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (task.binCode != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Icon(Icons.place_outlined,
                                  size: 14, color: scheme.onSurfaceVariant),
                              Text(task.binCode!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: AppFonts.mono,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Stat(label: l10n.pickPlanned, value: task.plannedQuantity),
                  _Stat(label: l10n.pickPickedQty, value: task.pickedQuantity),
                  _Stat(
                    label: l10n.pickVariance,
                    value: task.variance,
                    showSign: true,
                    tone: (task.variance ?? 0) != 0
                        ? StatusTone.danger
                        : StatusTone.neutral,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.tone = StatusTone.neutral,
    this.showSign = false,
  });

  final String label;
  final int? value;
  final StatusTone tone;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      StatusTone.success => scheme.primary,
      StatusTone.danger => scheme.error,
      StatusTone.warning => scheme.error,
      _ => scheme.onSurface,
    };
    final text = value == null ? '—' : (showSign ? signed(value!) : '${value!}');
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(text,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppFonts.mono,
                  fontWeight: FontWeight.w600,
                  color: value == null ? scheme.onSurfaceVariant : color)),
        ],
      ),
    );
  }
}

class _PickDraft {
  const _PickDraft(this.quantity, this.binId);
  final int quantity;
  final int? binId;
}

class _RecordPickDialog extends StatefulWidget {
  const _RecordPickDialog({required this.task, required this.bins});

  final PickTask task;
  final List<Bin> bins;

  @override
  State<_RecordPickDialog> createState() => _RecordPickDialogState();
}

class _RecordPickDialogState extends State<_RecordPickDialog> {
  late final TextEditingController _quantity = TextEditingController(
      text: (widget.task.pickedQuantity ?? widget.task.plannedQuantity).toString());
  int? _binId;

  @override
  void initState() {
    super.initState();
    _binId = widget.task.binId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_quantity.text.trim());
    if (value == null || value < 0) return;
    Navigator.pop(context, _PickDraft(value, _binId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final task = widget.task;
    final title = task.productName.isNotEmpty ? task.productName : task.janCode;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${task.janCode} · ${l10n.pickPlanned} ${task.plannedQuantity}',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.pickPickedQty),
            style: const TextStyle(fontFamily: AppFonts.mono),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.bins.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int?>(
              initialValue: _binId,
              decoration: InputDecoration(labelText: l10n.pickBin),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.pickBinNone)),
                for (final bin in widget.bins)
                  DropdownMenuItem(value: bin.id, child: Text(bin.code)),
              ],
              onChanged: (v) => setState(() => _binId = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.pickRecord)),
      ],
    );
  }
}
