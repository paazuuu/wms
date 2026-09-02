import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../application/reconciliation_controller.dart';
import '../domain/delivery_plan.dart';
import '../domain/reconciliation.dart';
import 'delivery_status_ui.dart';

/// Reconciles one delivery plan against what physically arrived. Loads the plan
/// (with its expected lines), then hands off to [_ReconcileView] for the live
/// scan/OCR session.
class ReconciliationScreen extends ConsumerWidget {
  const ReconciliationScreen({super.key, required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(deliveryPlanDetailProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.valueOrNull?.deliveryNumber ?? l10n.featDelivery),
      ),
      body: detail.when(
        data: (plan) => _ReconcileView(plan: plan),
        loading: () => LoadingView(message: l10n.loading),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(deliveryPlanDetailProvider(planId)),
        ),
      ),
    );
  }
}

class _ReconcileView extends ConsumerStatefulWidget {
  const _ReconcileView({required this.plan});

  final DeliveryPlan plan;

  @override
  ConsumerState<_ReconcileView> createState() => _ReconcileViewState();
}

class _ReconcileViewState extends ConsumerState<_ReconcileView> {
  final FocusNode _scanFocus = FocusNode();
  bool _ocrBusy = false;

  DeliveryPlan get _plan => widget.plan;

  ReconciliationController get _controller =>
      ref.read(reconciliationControllerProvider(_plan).notifier);

  @override
  void dispose() {
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _runOcr() async {
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();
    final XFile? shot;
    try {
      shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
    } on PlatformException {
      _snack(l10n.ocrUnavailable, tone: StatusTone.danger);
      return;
    }
    if (shot == null || !mounted) return;

    setState(() => _ocrBusy = true);
    try {
      final scanner = ref.read(deliveryNoteScannerProvider);
      final lines = await scanner.scan(shot.path);
      if (!mounted) return;
      if (lines.isEmpty) {
        _snack(l10n.ocrNoneFound, tone: StatusTone.warning);
      } else {
        _controller.applyOcr(lines);
        await HapticFeedback.mediumImpact();
        _snack(l10n.ocrFound(lines.length), tone: StatusTone.success);
      }
    } on PlatformException {
      if (mounted) _snack(l10n.ocrUnavailable, tone: StatusTone.danger);
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
      if (mounted) _scanFocus.requestFocus();
    }
  }

  Future<void> _editQuantity(ReconLine line) async {
    final l10n = AppLocalizations.of(context);
    final controller =
        TextEditingController(text: '${line.actualQuantity}');
    final qty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(line.productName.isNotEmpty
            ? line.productName
            : l10n.unexpectedItem),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.enterQuantityFor(line.janCode),
              style: const TextStyle(fontFamily: 'Fira Code', fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.quantity),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text) ?? 0),
            child: Text(l10n.actionRecord),
          ),
        ],
      ),
    );
    if (qty == null) return;
    _controller.setQuantity(line.janCode, qty);
    _scanFocus.requestFocus();
  }

  Future<void> _complete(ReconciliationResult result) async {
    final l10n = AppLocalizations.of(context);
    if (result.lines.every((l) => l.actualQuantity == 0)) {
      _snack(l10n.reconcileEmptyCounts, tone: StatusTone.warning);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reconcileConfirmQ),
        content: Text(result.hasDiscrepancies
            ? l10n.reconcileConfirmDiscrepancy
            : l10n.reconcileConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionComplete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final apiResult = await _controller.submit();
    if (!mounted) return;
    apiResult.when(
      success: (_) {
        ref.invalidate(deliveryPlansProvider);
        ref.invalidate(deliveryPlanDetailProvider(_plan.id));
        _snack(l10n.reconcileDone, tone: StatusTone.success);
        Navigator.of(context).pop();
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
    );
  }

  void _snack(String message, {StatusTone tone = StatusTone.neutral}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg) = switch (tone) {
      StatusTone.success => (Icons.check_circle, scheme.inverseSurface),
      StatusTone.warning => (Icons.warning_amber, scheme.inverseSurface),
      StatusTone.danger => (Icons.error_outline, scheme.error),
      _ => (Icons.info_outline, scheme.inverseSurface),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, size: 20, color: scheme.onInverseSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(reconciliationControllerProvider(_plan));
    final result = state.result;

    return Column(
      children: [
        // Scan bar + OCR assist.
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ScanField(
                  focusNode: _scanFocus,
                  autofocusOnWide: true,
                  hintText: l10n.scanDeliveryHint,
                  onSubmitted: _controller.recordScan,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: l10n.ocrAssist,
                child: OutlinedButton.icon(
                  onPressed: _ocrBusy ? null : _runOcr,
                  icon: _ocrBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(l10n.ocrAssist),
                ),
              ),
            ],
          ),
        ),
        _SummaryBar(result: result),
        Expanded(
          child: result.lines.isEmpty
              ? EmptyStateView(
                  icon: Icons.qr_code_scanner,
                  title: l10n.reconcileEmptyCounts,
                  message: l10n.deliveryPlansEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: result.lines.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _ReconLineCard(
                    line: result.lines[index],
                    onEdit: () => _editQuantity(result.lines[index]),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    state.submitting ? null : () => _complete(result),
                icon: state.submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: Text(
                    state.submitting ? l10n.working : l10n.completeReconcile),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact tally of the reconciliation outcome across all lines.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.result});

  final ReconciliationResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (result.matchedCount > 0)
        _CountChip(
            tone: StatusTone.success,
            label: l10n.reconMatched,
            count: result.matchedCount),
      if (result.shortfallCount > 0)
        _CountChip(
            tone: StatusTone.warning,
            label: l10n.reconShortfall,
            count: result.shortfallCount),
      if (result.overCount > 0)
        _CountChip(
            tone: StatusTone.danger,
            label: l10n.reconOver,
            count: result.overCount),
      if (result.unexpectedCount > 0)
        _CountChip(
            tone: StatusTone.danger,
            label: l10n.reconUnexpected,
            count: result.unexpectedCount),
      if (result.pendingCount > 0)
        _CountChip(
            tone: StatusTone.neutral,
            label: l10n.reconPending,
            count: result.pendingCount),
    ];

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            l10n.reconSummaryTitle,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.tone,
    required this.label,
    required this.count,
  });

  final StatusTone tone;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      tone: tone,
      label: '$label $count',
      dense: true,
    );
  }
}

class _ReconLineCard extends StatelessWidget {
  const _ReconLineCard({required this.line, required this.onEdit});

  final ReconLine line;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = ReconLineStatusUi.of(l10n, line.status);
    final title = line.productName.isNotEmpty
        ? line.productName
        : (line.planLine == null ? l10n.unexpectedItem : l10n.unnamedProduct);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
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
                        Text(
                          title,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line.janCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'FiraCode',
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                      tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _QtyStat(label: l10n.deliveryPlanned, value: line.plannedQuantity),
                  _QtyStat(label: l10n.actualLabel, value: line.actualQuantity),
                  _DiffStat(label: l10n.diffLabel, value: line.difference),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStat extends StatelessWidget {
  const _QtyStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontFamily: 'FiraCode', fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DiffStat extends StatelessWidget {
  const _DiffStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = value == 0
        ? scheme.onSurfaceVariant
        : (value > 0 ? scheme.error : scheme.tertiary);
    final text = value > 0 ? '+$value' : '$value';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'FiraCode',
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}
