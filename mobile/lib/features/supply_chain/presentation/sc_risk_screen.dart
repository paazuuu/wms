import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_editors.dart';
import 'sc_labels.dart';
import 'sc_widgets.dart';

/// リスク分析 (§17, §34): suppliers, sites and routes scored by explainable
/// rules — the level set on them, registered risks, capacity, sole
/// sourcing, lateness and damage — each with its reasons; and the risks
/// the business has registered (a price rise, a port closed until a date…).
class ScRiskScreen extends ConsumerWidget {
  const ScRiskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canManage = ref.watch(scCanManageProvider);
    final run = ref.watch(scDashboardProvider);
    final model = ref.watch(scModelProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featScRisk)),
      body: run.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scDashboardProvider)),
        data: (r) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.scRiskRuleNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            ScSection(
              title: l10n.scRiskTitle,
              child: r.risks.isEmpty
                  ? Text(l10n.scNoRisks)
                  : Column(children: [
                      for (final x in r.risks)
                        ListTile(
                          key: ValueKey('sc-risk-${x.kind}-${x.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(width: 72, child: ScRiskBadge(level: x.level)),
                          title: Text('${x.name} · ${scRiskKindLabel(l10n, x.kind)}'),
                          subtitle: Wrap(spacing: AppSpacing.xs, runSpacing: 2, children: [
                            for (final reason in x.reasons) Text('• ${scReasonLabel(l10n, reason)}', style: theme.textTheme.bodySmall),
                          ]),
                          trailing: Text(x.score.toStringAsFixed(0), style: theme.textTheme.titleMedium),
                        ),
                    ]),
            ),
            ScSection(
              title: l10n.scRiskEvents,
              trailing: canManage && model != null
                  ? TextButton.icon(
                      key: const ValueKey('sc-add-risk-event'),
                      onPressed: () => showDialog(context: context, builder: (_) => _RiskEventDialog(model: model)),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.scAddRiskEvent),
                    )
                  : null,
              child: Column(children: [
                for (final e in model?.riskEvents ?? const <ScRiskEvent>[])
                  ListTile(
                    key: ValueKey('sc-risk-event-${e.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: StatusPill(tone: scRiskTone(e.severity), label: scRiskLevelLabel(l10n, e.severity), dense: true),
                    title: Text(e.title),
                    subtitle: Text([
                      scEventKindLabel(l10n, e.kind),
                      if (e.startsOn != null || e.endsOn != null) '${e.startsOn ?? ''} ~ ${e.endsOn ?? ''}',
                      if (e.priceMultiplier != null) '${l10n.scPriceMultiplier} ×${e.priceMultiplier}',
                      if (e.costMultiplier != null) '${l10n.scCostMultiplier} ×${e.costMultiplier}',
                      if (e.capacityMultiplier != null) '${l10n.scCapacityMultiplier} ×${e.capacityMultiplier}',
                      if (e.delayDays != null) '${l10n.scDelayDays} ${scNumber(e.delayDays!)}',
                    ].join(' · ')),
                    onTap: canManage && model != null ? () => showDialog(context: context, builder: (_) => _RiskEventDialog(model: model, event: e)) : null,
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a registered risk applies: a supplier, a site, a route or a mode,
/// as one "kind:id" value.
List<(String, String)> scTargets(AppLocalizations l10n, ScModel m) => [
      for (final p in m.partners) ('partner:${p.id}', '${l10n.scKindSupplier}: ${p.name}'),
      for (final n in m.nodes.where((n) => n.kind != 'supplier')) ('node:${n.id}', '${scNodeKindLabel(l10n, n.kind)}: ${n.name}'),
      for (final r in m.routes) ('route:${r.id}', '${l10n.scRiskKindRoute}: ${r.name}'),
      for (final mode in scModes) ('mode:$mode', '${l10n.scMode}: ${scModeLabel(l10n, mode)}'),
    ];

class _RiskEventDialog extends ConsumerStatefulWidget {
  const _RiskEventDialog({required this.model, this.event});

  final ScModel model;
  final ScRiskEvent? event;

  @override
  ConsumerState<_RiskEventDialog> createState() => _RiskEventDialogState();
}

class _RiskEventDialogState extends ConsumerState<_RiskEventDialog> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _starts = TextEditingController(text: widget.event?.startsOn ?? '');
  late final _ends = TextEditingController(text: widget.event?.endsOn ?? '');
  late final _price = TextEditingController(text: scFieldText(widget.event?.priceMultiplier));
  late final _cost = TextEditingController(text: scFieldText(widget.event?.costMultiplier));
  late final _capacity = TextEditingController(text: scFieldText(widget.event?.capacityMultiplier));
  late final _delay = TextEditingController(text: scFieldText(widget.event?.delayDays));
  late String _kind = widget.event?.kind ?? 'supplier_price';
  late RiskLevel _severity = widget.event?.severity ?? RiskLevel.medium;
  late String? _target = switch (widget.event) {
    ScRiskEvent(partnerId: final int id) => 'partner:$id',
    ScRiskEvent(nodeId: final int id) => 'node:$id',
    ScRiskEvent(routeId: final int id) => 'route:$id',
    ScRiskEvent(mode: final String m) => 'mode:$m',
    _ => null,
  };
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _starts, _ends, _price, _cost, _capacity, _delay]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final targets = scTargets(l10n, widget.model);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    int? targetId(String kind) => _target != null && _target!.startsWith('$kind:') ? int.tryParse(_target!.split(':').last) : null;
    return AlertDialog(
      title: Text(widget.event?.title ?? l10n.scAddRiskEvent),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            SizedBox(width: 480, child: TextField(key: const ValueKey('sc-event-title'), controller: _title, decoration: InputDecoration(labelText: l10n.scRiskEventTitle))),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('sc-event-kind'),
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scRiskKind),
                items: [for (final k in riskEventKinds) DropdownMenuItem(value: k, child: Text(scEventKindLabel(l10n, k)))],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<RiskLevel>(
                initialValue: _severity,
                decoration: InputDecoration(labelText: l10n.scSeverity),
                items: [for (final r in RiskLevel.values) DropdownMenuItem(value: r, child: Text(scRiskLevelLabel(l10n, r)))],
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
            ),
            SizedBox(
              width: 480,
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('sc-event-target'),
                initialValue: targets.any((x) => x.$1 == _target) ? _target : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scTarget),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final (v, label) in targets) DropdownMenuItem<String?>(value: v, child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
            SizedBox(width: 150, child: TextField(controller: _starts, decoration: InputDecoration(labelText: l10n.scStartsOn, hintText: '2026-10-01', isDense: true))),
            SizedBox(width: 150, child: TextField(controller: _ends, decoration: InputDecoration(labelText: l10n.scEndsOn, hintText: '2026-10-14', isDense: true))),
            ScNumberField(controller: _price, label: l10n.scPriceMultiplier, hint: '1.10', width: 150),
            ScNumberField(controller: _cost, label: l10n.scCostMultiplier, hint: '1.20', width: 150),
            ScNumberField(controller: _capacity, label: l10n.scCapacityMultiplier, hint: '0.5', width: 150),
            ScNumberField(controller: _delay, label: l10n.scDelayDays, width: 150),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        if (widget.event?.id != null)
          TextButton(
            onPressed: () => scSaveAndClose(context, ref, () => ref.read(supplyChainRepositoryProvider).archive('risk_event', widget.event!.id!), (m) => setState(() => _error = m)),
            child: Text(l10n.actionDelete),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('sc-event-save'),
          onPressed: () {
            if (_title.text.trim().isEmpty) return setState(() => _error = l10n.scErrorNameRequired);
            scSaveAndClose(
              context,
              ref,
              () => ref.read(supplyChainRepositoryProvider).saveRiskEvent(ScRiskEvent(
                    id: widget.event?.id,
                    title: _title.text.trim(),
                    kind: _kind,
                    severity: _severity,
                    partnerId: targetId('partner'),
                    nodeId: targetId('node'),
                    routeId: targetId('route'),
                    mode: _target != null && _target!.startsWith('mode:') ? _target!.split(':').last : null,
                    startsOn: t(_starts),
                    endsOn: t(_ends),
                    priceMultiplier: scParse(_price),
                    costMultiplier: scParse(_cost),
                    capacityMultiplier: scParse(_capacity),
                    delayDays: scParse(_delay),
                  )),
              (m) => setState(() => _error = m),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
