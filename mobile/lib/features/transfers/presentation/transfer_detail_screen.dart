import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transfer_providers.dart';
import '../domain/transfer_order.dart';
import 'transfer_status_ui.dart';

/// One transfer order, driven through its state machine one step at a time
/// (spec §16): submit → approve → pick → ship → receive → complete. Every
/// step that touches stock — completing picking, completing receiving —
/// refuses while any line is untouched, so a short pick or a transit loss is
/// always a deliberate, recorded number rather than a silent zero.
class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});

  final int transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(transferDetailProvider(transferId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.transferNumber ?? l10n.transferTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(transferDetailProvider(transferId)),
        ),
        data: (order) => _Body(order: order),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});

  final TransferOrder order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  TransferOrder get _order => widget.order;

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
    ref.invalidate(transferDetailProvider(_order.id));
    ref.invalidate(transferListProvider);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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

  Future<void> _run(
    Future<ApiResult<TransferOrder>> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        if (successMessage != null) _snack(successMessage);
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    await _run(() => ref.read(transferRepositoryProvider).submit(_order.id),
        successMessage: l10n.transferSubmitted);
  }

  Future<void> _approve() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.transferApprove, l10n.transferApproveQ, l10n.transferApprove)) {
      return;
    }
    await _run(() => ref.read(transferRepositoryProvider).approve(_order.id),
        successMessage: l10n.transferApproved);
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.transferReject, l10n.transferRejectQ, l10n.transferReject)) {
      return;
    }
    await _run(() => ref.read(transferRepositoryProvider).reject(_order.id),
        successMessage: l10n.transferRejected);
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
        l10n.transferCancelAction, l10n.transferCancelBody, l10n.transferCancelAction)) {
      return;
    }
    await _run(() => ref.read(transferRepositoryProvider).cancel(_order.id),
        successMessage: l10n.transferCancelled);
  }

  Future<void> _startPicking() async {
    await _run(() => ref.read(transferRepositoryProvider).startPicking(_order.id));
  }

  Future<void> _startReceiving() async {
    await _run(() => ref.read(transferRepositoryProvider).startReceiving(_order.id));
  }

  Future<void> _recordPick(TransferLine line) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        line: line,
        label: l10n.transferPickQty,
        initial: line.pickedQuantity ?? line.requestedQuantity,
      ),
    );
    if (value == null) return;
    await _run(
        () => ref.read(transferRepositoryProvider).recordPick(line.id, value));
  }

  Future<void> _recordReceipt(TransferLine line) async {
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        line: line,
        label: l10n.transferReceiveQty,
        initial: line.receivedQuantity ?? line.pickedQuantity ?? 0,
      ),
    );
    if (value == null) return;
    await _run(() =>
        ref.read(transferRepositoryProvider).recordReceipt(line.id, value));
  }

  Future<void> _completePicking() async {
    final l10n = AppLocalizations.of(context);
    if (_order.unpickedLines > 0) {
      _snack(l10n.transferPickIncomplete, danger: true);
      return;
    }
    if (!await _confirm(
        l10n.transferCompletePicking,
        l10n.transferCompletePickingBody(
            _order.sourceWarehouseName ?? '#${_order.sourceWarehouseId}'),
        l10n.transferCompletePicking)) {
      return;
    }
    await _run(() => ref.read(transferRepositoryProvider).completePicking(_order.id));
  }

  Future<void> _completeReceiving() async {
    final l10n = AppLocalizations.of(context);
    if (_order.unreceivedLines > 0) {
      _snack(l10n.transferReceiveIncomplete, danger: true);
      return;
    }
    if (!await _confirm(
        l10n.transferCompleteReceiving,
        l10n.transferCompleteReceivingBody(
            _order.destinationWarehouseName ?? '#${_order.destinationWarehouseId}'),
        l10n.transferCompleteReceiving)) {
      return;
    }
    setState(() => _busy = true);
    final result =
        await ref.read(transferRepositoryProvider).completeReceiving(_order.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (completed) {
        _refresh();
        _snack(l10n.transferCompleted(completed.summary.lossLines));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Widget? _primaryAction(AppLocalizations l10n) {
    switch (_order.status) {
      case TransferStatus.draft:
        return FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.transferSubmit),
        );
      case TransferStatus.pendingApproval:
        return FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(l10n.transferApprove),
        );
      case TransferStatus.approved:
        return FilledButton.icon(
          onPressed: _busy ? null : _startPicking,
          icon: const Icon(Icons.shopping_cart_checkout),
          label: Text(l10n.transferStartPicking),
        );
      case TransferStatus.picking:
        return FilledButton.icon(
          onPressed: _busy ? null : _completePicking,
          icon: const Icon(Icons.local_shipping_outlined),
          label: Text(l10n.transferCompletePicking),
        );
      case TransferStatus.inTransit:
        return FilledButton.icon(
          onPressed: _busy ? null : _startReceiving,
          icon: const Icon(Icons.move_to_inbox_outlined),
          label: Text(l10n.transferStartReceiving),
        );
      case TransferStatus.receiving:
        return FilledButton.icon(
          onPressed: _busy ? null : _completeReceiving,
          icon: const Icon(Icons.done_all),
          label: Text(l10n.transferCompleteReceiving),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ui = TransferStatusUi.of(l10n, _order.status);
    final isPicking = _order.status == TransferStatus.picking;
    final isReceiving = _order.status == TransferStatus.receiving;
    final primary = _primaryAction(l10n);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
                  const SizedBox(width: AppSpacing.sm),
                  if (isPicking)
                    Text(
                      l10n.transferPickProgress(_order.pickedLines, _order.totalLines),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  else if (isReceiving)
                    Text(
                      l10n.transferReceiveProgress(
                          _order.receivedLines, _order.totalLines),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _order.sourceWarehouseName ?? '#${_order.sourceWarehouseId}',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_right_alt, size: 18),
                  Flexible(
                    child: Text(
                      _order.destinationWarehouseName ??
                          '#${_order.destinationWarehouseId}',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _order.lines.isEmpty
              ? EmptyStateView(icon: Icons.compare_arrows, title: l10n.transferEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _order.lines.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _LineCard(
                    line: _order.lines[i],
                    onPick: isPicking && !_busy
                        ? () => _recordPick(_order.lines[i])
                        : null,
                    onReceive: isReceiving && !_busy
                        ? () => _recordReceipt(_order.lines[i])
                        : null,
                  ),
                ),
        ),
        if (primary != null || _order.status.isCancellable)
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
                    if (_order.status == TransferStatus.pendingApproval)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _reject,
                          child: Text(l10n.transferReject),
                        ),
                      )
                    else if (_order.status.isCancellable)
                      SizedBox(
                        height: AppSpacing.minTouch,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          child: Text(l10n.transferCancelAction),
                        ),
                      ),
                    if (primary != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SizedBox(height: AppSpacing.minTouch, child: primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, this.onPick, this.onReceive});

  final TransferLine line;
  final VoidCallback? onPick;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;
    final onTap = onPick ?? onReceive;

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
                        Text(line.janCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Stat(label: l10n.transferPlanned, value: line.requestedQuantity),
                  _Stat(
                    label: l10n.transferPickQty,
                    value: line.pickedQuantity,
                    tone: (line.pickVariance ?? 0) != 0
                        ? StatusTone.warning
                        : StatusTone.neutral,
                  ),
                  _Stat(
                    label: l10n.transferReceiveQty,
                    value: line.receivedQuantity,
                    tone: (line.receiveVariance ?? 0) != 0
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
  });

  final String label;
  final int? value;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      StatusTone.danger => scheme.error,
      StatusTone.warning => scheme.error,
      _ => scheme.onSurface,
    };
    final text = value == null ? '—' : '$value';
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

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.line, required this.label, required this.initial});

  final TransferLine line;
  final String label;
  final int initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _quantity =
      TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_quantity.text.trim());
    if (value == null || value < 0) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = widget.line;
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${line.janCode} · ${l10n.transferPlanned} ${line.requestedQuantity}',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: widget.label),
            style: const TextStyle(fontFamily: AppFonts.mono),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.label)),
      ],
    );
  }
}
