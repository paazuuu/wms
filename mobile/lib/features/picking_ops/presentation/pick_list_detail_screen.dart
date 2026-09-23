import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/scan_feedback.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../audit/presentation/entity_audit_timeline.dart';
import '../../shipment/presentation/shipment_detail_screen.dart';
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

  void _snack(String message, {bool danger = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
        action: action,
      ));
  }

  void _refresh() {
    ref.invalidate(pickListDetailProvider(_list.id));
    ref.invalidate(pickListsProvider);
  }

  Future<void> _record(PickTask task) async {
    final l10n = AppLocalizations.of(context);
    final bins = _list.usesLocations && _list.warehouseId != null
        ? await ref.read(warehouseBinsProvider(_list.warehouseId!).future)
        : const <Bin>[];
    if (!mounted) return;

    // §16's advice, fetched fresh each time: which lot to grab, in the
    // product's picking rule order. Only asked when the task actually
    // resolves to a product — an unlinked JAN has nothing to advise on.
    PickCandidates? candidates;
    if (task.productId != null) {
      final result =
          await ref.read(pickingRepositoryProvider).candidatesFor(task.id);
      candidates = result.when(success: (c) => c, failure: (_) => null);
      if (!mounted) return;
    }

    final draft = await showDialog<_PickDraft>(
      context: context,
      builder: (_) =>
          _RecordPickDialog(task: task, bins: bins, candidates: candidates),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    // Adds a parcel (0074) rather than overwriting the task's total, so a
    // second tap after a short pick records the next parcel, not a
    // correction — the same shape `record_receipt_item` has on the way in.
    final result = await ref.read(pickingRepositoryProvider).recordPickItem(
          task.id,
          quantity: draft.quantity,
          lotCode: draft.lotCode,
          binId: draft.binId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _removeItem(PickTaskItem item) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await ref
        .read(pickingRepositoryProvider)
        .removePickItem(item.id, pickListId: _list.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
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
        // §35: a finished pick is what packing works from, and this list
        // already knows which shipment it belongs to — so offer that exact
        // shipment rather than the shipping list. An action, not an
        // automatic push: a short or over pick is worth re-reading before
        // moving on, and this screen is where those are shown.
        _snack(
          l10n.pickCompleted(
              completed.summary.shortLines, completed.summary.overLines),
          action: SnackBarAction(
            label: l10n.nextStepPacking,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  ShipmentDetailScreen(shipmentId: _list.shipmentPlanId),
            )),
          ),
        );
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
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
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
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
                  // One extra row at the end for the activity timeline.
                  itemCount: _list.tasks.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    if (i == _list.tasks.length) {
                      return EntityAuditTimeline(
                        entityType: 'pick_list',
                        entityId: '${_list.id}',
                      );
                    }
                    return _TaskCard(
                      task: _list.tasks[i],
                      onTap: _list.isOpen && !_busy
                          ? () => _record(_list.tasks[i])
                          : null,
                      onRemoveItem: _list.isOpen && !_busy ? _removeItem : null,
                    );
                  },
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
  const _TaskCard({required this.task, this.onTap, this.onRemoveItem});

  final PickTask task;
  final VoidCallback? onTap;
  final ValueChanged<PickTaskItem>? onRemoveItem;

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
              if (task.items.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                for (final item in task.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            [
                              if (item.lotCode != null) 'L:${item.lotCode}',
                              if (item.serialNumber != null) 'S/N:${item.serialNumber}',
                              if (item.lotCode == null && item.serialNumber == null)
                                l10n.pickItemNoLot,
                              '× ${item.quantity}',
                            ].join('  '),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onRemoveItem != null)
                          IconButton(
                            tooltip: l10n.pickItemRemove,
                            iconSize: 16,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.close, color: scheme.error),
                            onPressed: () => onRemoveItem!(item),
                          ),
                      ],
                    ),
                  ),
                if (task.unattributedQuantity > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.pickItemUnattributed(task.unattributedQuantity),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
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
  const _PickDraft(this.quantity, this.binId, this.lotCode);
  final int quantity;
  final int? binId;
  final String? lotCode;
}

class _RecordPickDialog extends StatefulWidget {
  const _RecordPickDialog({required this.task, required this.bins, this.candidates});

  final PickTask task;
  final List<Bin> bins;

  /// §16's advice — which lot to grab, in the product's picking rule order.
  /// Null when the task has no linked product, or the read failed; either
  /// way the dialog still works, just without a suggestion to show.
  final PickCandidates? candidates;

  @override
  State<_RecordPickDialog> createState() => _RecordPickDialogState();
}

class _RecordPickDialogState extends State<_RecordPickDialog> {
  // What is still outstanding, not the running total — each parcel this
  // dialog records is added to the task, not a corrected overall figure.
  late final TextEditingController _quantity =
      TextEditingController(text: widget.task.outstandingQuantity.toString());
  late final TextEditingController _lotCode = TextEditingController(
      text: widget.candidates?.candidates.firstOrNull?.lotCode ?? '');
  int? _binId;

  /// §16's gate: a quantity is only confirmable once the operator has scanned
  /// the JAN this task is for. Picking the wrong SKU is the expensive mistake
  /// in outbound work — it ships to a customer — and a scan is the only check
  /// that catches it before it leaves the building.
  bool _scanConfirmed = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _binId = widget.task.binId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _lotCode.dispose();
    super.dispose();
  }

  /// Accepts a code from any source — wedge scanner, camera, or the scanner's
  /// own manual-entry fallback — and holds the gate shut unless it matches.
  void _verify(String code) {
    final matches = code.trim() == widget.task.janCode.trim();
    if (matches) {
      const ScanFeedback().success();
      setState(() {
        _scanConfirmed = true;
        _scanError = null;
      });
      return;
    }
    const ScanFeedback().error();
    setState(() => _scanError =
        AppLocalizations.of(context).scanWrongItem(widget.task.janCode));
  }

  Future<void> _scanWithCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScanScreen(
          title: widget.task.productName.isNotEmpty
              ? widget.task.productName
              : widget.task.janCode,
          expectedCode: widget.task.janCode,
        ),
      ),
    );
    if (code == null || !mounted) return;
    _verify(code);
  }

  /// §16's [+1] / [+5] — a picker counting into a cart taps rather than types.
  void _bump(int by) {
    final current = int.tryParse(_quantity.text.trim()) ?? 0;
    _quantity.text = '${current + by}';
  }

  void _submit() {
    if (!_scanConfirmed) return;
    final value = int.tryParse(_quantity.text.trim());
    if (value == null || value < 0) return;
    final lot = _lotCode.text.trim();
    Navigator.pop(context, _PickDraft(value, _binId, lot.isEmpty ? null : lot));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;
    final title = task.productName.isNotEmpty ? task.productName : task.janCode;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${task.janCode} · ${l10n.pickPlanned} ${task.plannedQuantity}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: AppFonts.mono,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            if (!_scanConfirmed) ...[
              Row(
                children: [
                  Expanded(
                    child: ScanField(
                      autofocusOnWide: true,
                      hintText: l10n.pickScanToConfirm,
                      onSubmitted: _verify,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: l10n.pickScanAction,
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: _scanWithCamera,
                  ),
                ],
              ),
              if (_scanError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: scheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(_scanError!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.error)),
                    ),
                  ],
                ),
              ],
            ] else
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l10n.pickScanned,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.primary)),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quantity,
              enabled: _scanConfirmed,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.pickPickedQty),
              style: const TextStyle(fontFamily: AppFonts.mono),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                for (final by in const [1, 5])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: OutlinedButton(
                      onPressed: _scanConfirmed ? () => _bump(by) : null,
                      child: Text('+$by'),
                    ),
                  ),
              ],
            ),
            if (widget.candidates != null &&
                widget.candidates!.candidates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.candidates!.candidates.first.reason ??
                          widget.candidates!.rule,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _lotCode,
              enabled: _scanConfirmed,
              decoration: InputDecoration(
                labelText: l10n.pickLotCode,
                hintText: l10n.pickLotCodeHint,
              ),
              style: const TextStyle(fontFamily: AppFonts.mono),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _scanConfirmed ? _submit : null,
          child: Text(l10n.pickRecord),
        ),
      ],
    );
  }
}
