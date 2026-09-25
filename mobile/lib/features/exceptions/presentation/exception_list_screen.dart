import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/exception_providers.dart';
import '../domain/warehouse_exception.dart';

/// How much someone has to care, in words.
String exceptionSeverityLabel(AppLocalizations l10n, ExceptionSeverity s) =>
    switch (s) {
      ExceptionSeverity.blocker => l10n.exceptionSeverityBlocker,
      ExceptionSeverity.warning => l10n.exceptionSeverityWarning,
      ExceptionSeverity.info => l10n.exceptionSeverityInfo,
    };

StatusTone exceptionSeverityTone(ExceptionSeverity s) => switch (s) {
      ExceptionSeverity.blocker => StatusTone.danger,
      ExceptionSeverity.warning => StatusTone.warning,
      ExceptionSeverity.info => StatusTone.neutral,
    };

String exceptionResolutionLabel(AppLocalizations l10n, ExceptionResolution r) =>
    switch (r) {
      ExceptionResolution.accepted => l10n.exceptionResolutionAccepted,
      ExceptionResolution.supplierClaim => l10n.exceptionResolutionSupplierClaim,
      ExceptionResolution.returned => l10n.exceptionResolutionReturned,
      ExceptionResolution.scrapped => l10n.exceptionResolutionScrapped,
      ExceptionResolution.corrected => l10n.exceptionResolutionCorrected,
      ExceptionResolution.recounted => l10n.exceptionResolutionRecounted,
      ExceptionResolution.noAction => l10n.exceptionResolutionNoAction,
    };

/// What went wrong on the floor, and what was decided about it (0071).
///
/// A work queue, not a report: blockers first — the server's order, so it still
/// holds when the list is long — and finished work hidden unless asked for,
/// because a queue that keeps its finished work is a list nobody reaches the
/// bottom of.
class ExceptionListScreen extends ConsumerWidget {
  const ExceptionListScreen({super.key});

  Future<void> _acknowledge(
      BuildContext context, WidgetRef ref, WarehouseException e) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(exceptionRepositoryProvider).acknowledge(e.id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(openExceptionsProvider);
        ref.invalidate(exceptionSummaryProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  Future<void> _resolve(
      BuildContext context, WidgetRef ref, WarehouseException e) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ResolveExceptionSheet(exception: e),
    );
  }

  Future<void> _raise(
      BuildContext context, WidgetRef ref, int warehouseId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RaiseExceptionSheet(warehouseId: warehouseId),
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, WarehouseException e) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelExceptionDialog(),
    );
    if (reason == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(exceptionRepositoryProvider)
        .cancel(e.id, reason: reason.isEmpty ? null : reason);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(openExceptionsProvider);
        ref.invalidate(exceptionSummaryProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final category = ref.watch(exceptionCategoryProvider);
    final showClosed = ref.watch(showClosedExceptionsProvider);
    final summary = ref.watch(exceptionSummaryProvider).valueOrNull;

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exceptionsTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.exceptionsNoWarehouse,
          message: l10n.exceptionsEmptyBody,
        ),
      );
    }

    final async = ref.watch(openExceptionsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _raise(context, ref, warehouseId),
        icon: const Icon(Icons.add),
        label: Text(l10n.exceptionRaise),
      ),
      appBar: AppBar(
        title: Text(l10n.exceptionsTitle),
        actions: [
          IconButton(
            tooltip: l10n.exceptionShowClosed,
            isSelected: showClosed,
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history_toggle_off),
            onPressed: () => ref
                .read(showClosedExceptionsProvider.notifier)
                .state = !showClosed,
          ),
          PopupMenuButton<String?>(
            initialValue: category,
            icon: const Icon(Icons.filter_list),
            onSelected: (v) =>
                ref.read(exceptionCategoryProvider.notifier).state = v,
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                  value: null, child: Text(l10n.exceptionsAllCategories)),
              PopupMenuItem<String?>(
                  value: 'RECEIVING',
                  child: Text(l10n.exceptionCategoryReceiving)),
              PopupMenuItem<String?>(
                  value: 'QC', child: Text(l10n.exceptionCategoryQc)),
              PopupMenuItem<String?>(
                  value: 'PUTAWAY',
                  child: Text(l10n.exceptionCategoryPutaway)),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(openExceptionsProvider),
        ),
        data: (exceptions) {
          if (exceptions.isEmpty) {
            return EmptyStateView(
              icon: Icons.check_circle_outline,
              title: l10n.exceptionsEmpty,
              message: l10n.exceptionsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(openExceptionsProvider);
              ref.invalidate(exceptionSummaryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (summary != null && !summary.isClear) ...[
                  _SummaryBar(summary: summary),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final e in exceptions) ...[
                  _ExceptionCard(
                    exception: e,
                    onAcknowledge: () => _acknowledge(context, ref, e),
                    onResolve: () => _resolve(context, ref, e),
                    onCancel: () => _cancel(context, ref, e),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The two numbers worth reading before the list: how much is open, and how much
/// of it is actually blocking work.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final ExceptionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: summary.blockers > 0
          ? scheme.errorContainer
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              summary.blockers > 0 ? Icons.report : Icons.info_outline,
              color: summary.blockers > 0 ? scheme.onErrorContainer : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                summary.blockers > 0
                    ? l10n.exceptionBlockerCount(summary.blockers, summary.open)
                    : l10n.exceptionOpenCount(summary.open),
                style: TextStyle(
                  color: summary.blockers > 0 ? scheme.onErrorContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExceptionCard extends StatelessWidget {
  const _ExceptionCard({
    required this.exception,
    required this.onAcknowledge,
    required this.onResolve,
    required this.onCancel,
  });

  final WarehouseException exception;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final e = exception;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  tone: exceptionSeverityTone(e.severity),
                  label: exceptionSeverityLabel(l10n, e.severity),
                  dense: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(e.exceptionName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (e.quantity != null)
                  Text(l10n.exceptionQuantity(e.quantity!),
                      style: theme.textTheme.bodyMedium),
                if (e.status.isOpen)
                  PopupMenuButton<void>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(
                        onTap: onCancel,
                        child: Text(l10n.exceptionCancel),
                      ),
                    ],
                  ),
              ],
            ),
            if (e.productName != null || e.janCode != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [e.productName, e.janCode].whereType<String>().join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (e.lotCode != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.exceptionLot(e.lotCode!,
                    e.expiryDate == null
                        ? '-'
                        : DateFormat('yyyy-MM-dd').format(e.expiryDate!)),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            if (e.note != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(e.note!, style: theme.textTheme.bodySmall),
            ],
            // Which delivery this came off, because the next question after
            // "what went wrong" is always "on whose delivery".
            if (e.deliveryNumber != null || e.referenceNo != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                [e.deliveryNumber, e.referenceNo, e.supplierName]
                    .whereType<String>()
                    .join(' / '),
                style: TextStyle(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (e.createdAt != null)
                  Expanded(
                    child: Text(
                      l10n.exceptionRaisedAt(df.format(e.createdAt!)),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  const Spacer(),
                if (e.status == ExceptionStatus.acknowledged)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: StatusPill(
                        tone: StatusTone.info,
                        label: l10n.exceptionAcknowledged,
                        dense: true),
                  ),
                if (e.status == ExceptionStatus.resolved) ...[
                  StatusPill(
                      tone: StatusTone.success,
                      label: e.resolution == null
                          ? l10n.exceptionResolved
                          : exceptionResolutionLabel(l10n, e.resolution!),
                      dense: true),
                ] else if (e.status == ExceptionStatus.cancelled)
                  StatusPill(
                      tone: StatusTone.neutral,
                      label: l10n.exceptionCancelled,
                      dense: true)
                else ...[
                  if (e.canAcknowledge)
                    TextButton(
                      onPressed: onAcknowledge,
                      child: Text(l10n.exceptionAcknowledge),
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.tonal(
                    onPressed: onResolve,
                    child: Text(l10n.exceptionResolve),
                  ),
                ],
              ],
            ),
            if (e.status == ExceptionStatus.resolved && e.resolutionNote != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(e.resolutionNote!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Recording what was decided. Deliberately says, in the sheet itself, that this
/// moves no stock — because an operator choosing 廃棄した will reasonably assume
/// it did, and the write-off is a separate act with its own audit trail.
class ResolveExceptionSheet extends ConsumerStatefulWidget {
  const ResolveExceptionSheet({super.key, required this.exception});

  final WarehouseException exception;

  @override
  ConsumerState<ResolveExceptionSheet> createState() =>
      _ResolveExceptionSheetState();
}

class _ResolveExceptionSheetState extends ConsumerState<ResolveExceptionSheet> {
  ExceptionResolution _resolution = ExceptionResolution.accepted;
  final _note = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final note = _note.text.trim();
    // The server refuses these without a note; catching it here means the
    // operator fixes a form instead of reading an error.
    if (_resolution.needsNote && note.isEmpty) {
      setState(() => _error = l10n.exceptionNoteRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(exceptionRepositoryProvider).resolve(
          widget.exception.id,
          _resolution,
          note: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(openExceptionsProvider);
        ref.invalidate(exceptionSummaryProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _saving = false;
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.exceptionResolveTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.exception.exceptionName,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<ExceptionResolution>(
              initialValue: _resolution,
              decoration: InputDecoration(
                labelText: l10n.exceptionResolutionLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final r in ExceptionResolution.values)
                  DropdownMenuItem(
                    value: r,
                    child: Text(exceptionResolutionLabel(l10n, r)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _resolution = v ?? _resolution),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _resolution.needsNote
                    ? l10n.exceptionNoteRequiredLabel
                    : l10n.exceptionNoteLabel,
                hintText: l10n.exceptionNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.exceptionStockNotMovedHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms cancelling an exception raised in error, with an optional reason.
/// Pops the reason (possibly empty) on confirm, or null on cancel — so the
/// caller can tell "cancel this dialog" from "cancel with no reason given"
/// apart. Owns its own controller (the same shape `_RenameDialog` uses
/// elsewhere), so nothing disposes it while the pop transition still needs it.
class _CancelExceptionDialog extends StatefulWidget {
  const _CancelExceptionDialog();

  @override
  State<_CancelExceptionDialog> createState() =>
      _CancelExceptionDialogState();
}

class _CancelExceptionDialogState extends State<_CancelExceptionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.exceptionCancelTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.exceptionCancelBody),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reason,
            decoration: InputDecoration(
              labelText: l10n.exceptionCancelReasonLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(l10n.exceptionCancel),
        ),
      ],
    );
  }
}

/// Manually reporting something the system did not catch on its own
/// (`raise_exception`, 0071) — a person on the floor, not a detector. The type
/// list comes from the server (`list_exception_types`) rather than being
/// guessed client-side, the same reason every other picked-from-a-vocabulary
/// field in this app reads its options off an RPC instead of a constant.
class RaiseExceptionSheet extends ConsumerStatefulWidget {
  const RaiseExceptionSheet({super.key, required this.warehouseId});

  final int warehouseId;

  @override
  ConsumerState<RaiseExceptionSheet> createState() =>
      _RaiseExceptionSheetState();
}

class _RaiseExceptionSheetState extends ConsumerState<RaiseExceptionSheet> {
  ExceptionType? _type;
  final _note = TextEditingController();
  final _janCode = TextEditingController();
  final _quantity = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    _janCode.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final type = _type;
    if (type == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final janCode = _janCode.text.trim();
    final quantity = int.tryParse(_quantity.text.trim());
    final note = _note.text.trim();
    final result = await ref.read(exceptionRepositoryProvider).raise(
          exceptionType: type.code,
          warehouseId: widget.warehouseId,
          note: note.isEmpty ? null : note,
          janCode: janCode.isEmpty ? null : janCode,
          quantity: quantity,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(openExceptionsProvider);
        ref.invalidate(exceptionSummaryProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _saving = false;
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final types = ref.watch(exceptionTypesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.exceptionRaiseTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            types.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e',
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (values) {
                if (values.isEmpty) {
                  return Text(l10n.exceptionRaiseNoTypes,
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant));
                }
                _type ??= values.first;
                return DropdownButtonFormField<ExceptionType>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: l10n.exceptionRaiseType,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in values)
                      DropdownMenuItem(value: t, child: Text(t.name)),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _type = v ?? _type),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _janCode,
              decoration: InputDecoration(
                labelText: l10n.exceptionRaiseJanCode,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.exceptionRaiseQuantity,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.exceptionNoteLabel,
                hintText: l10n.exceptionNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed:
                      _saving || _type == null ? null : _save,
                  child: Text(l10n.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
