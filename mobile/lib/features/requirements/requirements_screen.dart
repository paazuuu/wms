import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/popconfirm.dart';
import '../../core/ui/state_views.dart';
import '../../l10n/app_localizations.dart';
import 'requirements_repository.dart';

/// One thing a step needs: fixed (kept for the system to be right), or a
/// rule the system administrator can relax (0212).
class _Item {
  const _Item(this.label, {this.hint, this.rule});

  final String label;
  final String? hint;
  final String? rule;
}

/// 必須項目の設定 (0212): each step and what it needs, at a glance; the
/// switches turn a rule off and on (the system administrator only).
class RequirementsScreen extends ConsumerStatefulWidget {
  const RequirementsScreen({super.key});

  @override
  ConsumerState<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends ConsumerState<RequirementsScreen> {
  String? _busy;

  List<(String, IconData, List<_Item>)> _steps(AppLocalizations l10n) => [
        (l10n.rqOpReceipt, Icons.move_to_inbox_outlined, [
          _Item(l10n.rqFixedWarehouse),
          _Item(l10n.rqFixedJan),
          _Item(l10n.rqFixedQty),
          _Item(l10n.rqReceiptPrice, hint: l10n.rqReceiptPriceHint, rule: Req.receiptPrice),
        ]),
        (l10n.rqOpUnplanned, Icons.local_shipping_outlined, [
          _Item(l10n.rqFixedWarehouse),
          _Item(l10n.rqFixedJan),
          _Item(l10n.rqFixedUnplannedPrice),
        ]),
        (l10n.rqOpInspection, Icons.fact_check_outlined, [
          _Item(l10n.rqFixedInspect),
        ]),
        (l10n.rqOpPlan, Icons.event_note_outlined, [
          _Item(l10n.rqFixedWarehouse),
          _Item(l10n.rqFixedPlanDay),
        ]),
        (l10n.rqOpShip, Icons.outbox_outlined, [
          _Item(l10n.rqFixedShipCheck),
          _Item(l10n.rqFixedShipDay),
          _Item(l10n.rqFixedJan),
          _Item(l10n.rqShipCard, hint: l10n.rqShipCardHint, rule: Req.shipCard),
          _Item(l10n.rqShipPrice, hint: l10n.rqShipPriceHint, rule: Req.shipPrice),
          _Item(l10n.rqShipRate, hint: l10n.rqShipRateHint, rule: Req.shipRate),
        ]),
        (l10n.rqOpProxy, Icons.edit_note_outlined, [
          _Item(l10n.rqFixedPrincipal),
          _Item(l10n.rqShipPrice, hint: l10n.rqShipPriceHint, rule: Req.shipPrice),
          _Item(l10n.rqShipRate, hint: l10n.rqShipRateHint, rule: Req.shipRate),
        ]),
        (l10n.rqOpAdjust, Icons.tune, [
          _Item(l10n.rqFixedWarehouse),
          _Item(l10n.rqFixedAdjustConfirm),
        ]),
      ];

  Future<void> _set(_Item item, bool required) async {
    final l10n = AppLocalizations.of(context);
    // Turning a rule off lets numbers go missing: asked first.
    if (!required) {
      final ok = await showPopconfirm(
        context,
        title: l10n.rqRelaxQ(item.label),
        message: l10n.rqRelaxBody,
        okLabel: l10n.rqRelax,
        okKey: const ValueKey('rq-relax-ok'),
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = item.rule);
    final r = await ref.read(requirementsRepositoryProvider).set(item.rule!, required);
    if (!mounted) return;
    setState(() => _busy = null);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(requirementsProvider);
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.rqSaved(item.label, required ? l10n.rqRequired : l10n.rqOptional))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final async = ref.watch(requirementsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featRequirements)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(requirementsProvider)),
        data: (req) => ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          Text(l10n.rqIntro, style: theme.textTheme.bodyMedium),
          if (!req.canEdit) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.rqOnlyAdmin, key: const ValueKey('rq-read-only'), style: muted),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final (title, icon, items) in _steps(l10n)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                  ]),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in items) _row(context, l10n, req, title, item),
                ]),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, Requirements req, String step, _Item item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final rule = item.rule == null ? null : req.rules.where((r) => r.key == item.rule).firstOrNull;
    final on = item.rule == null || (rule?.required ?? true);
    final badge = item.rule == null
        ? (l10n.rqFixed, scheme.onSurfaceVariant, Icons.lock_outline)
        : on
            ? (l10n.rqRequired, scheme.success, Icons.check_circle_outline)
            : (l10n.rqOptional, scheme.warning, Icons.remove_circle_outline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 150,
          child: Row(children: [
            Icon(badge.$3, size: 16, color: badge.$2),
            const SizedBox(width: 4),
            Flexible(
              child: Text(badge.$1,
                  key: item.rule == null ? null : ValueKey('rq-state-${item.rule}-$step'),
                  style: theme.textTheme.labelMedium?.copyWith(color: badge.$2, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.label, style: theme.textTheme.bodyMedium),
            if (item.hint != null) Text(item.hint!, style: muted),
            if (rule != null && !rule.isDefault && rule.updatedAt != null)
              Text(l10n.rqChanged(rule.updatedByName ?? '—', DateFormat('y/MM/dd HH:mm').format(rule.updatedAt!)),
                  style: muted),
          ]),
        ),
        if (item.rule != null)
          Switch(
            key: ValueKey('rq-switch-${item.rule}-$step'),
            value: on,
            onChanged: !req.canEdit || _busy != null ? null : (v) => _set(item, v),
          ),
      ]),
    );
  }
}
