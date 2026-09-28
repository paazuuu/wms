import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_risk_screen.dart';
import 'sc_widgets.dart';

/// ボトルネック (§18–19): how full each site and leg is against its
/// capacity, whether there is a way around it, and what it costs when one
/// stops for some days — rerouted freight, and sales lost until stock or
/// the alternative arrives.
class ScBottleneckScreen extends ConsumerStatefulWidget {
  const ScBottleneckScreen({super.key});

  @override
  ConsumerState<ScBottleneckScreen> createState() => _ScBottleneckScreenState();
}

class _ScBottleneckScreenState extends ConsumerState<ScBottleneckScreen> {
  String? _target;
  String _kind = 'stop';
  final _days = TextEditingController(text: '14');
  bool _busy = false;
  ScComparison? _impact;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  Future<void> _run(AppLocalizations l10n, String label) async {
    final t = _target;
    final days = double.tryParse(_days.text.trim());
    if (t == null || days == null || days <= 0) return;
    final parts = t.split(':');
    final disruption = <String, dynamic>{
      'kind': _kind,
      if (parts.first == 'partner') 'partner_id': int.parse(parts.last),
      if (parts.first == 'node') 'node_id': int.parse(parts.last),
      if (parts.first == 'route') 'route_id': int.parse(parts.last),
      if (parts.first == 'mode') 'mode': parts.last,
      if (_kind == 'stop') 'days': days else 'delay_days': days,
      'label': '$label ${_kind == 'stop' ? l10n.scStop : l10n.scDelay} ${l10n.scDays(scNumber(days))}',
    };
    setState(() => _busy = true);
    final r = await ref.read(supplyChainRepositoryProvider).disruption(
          warehouseId: ref.read(scWarehouseIdProvider),
          disruptions: [disruption],
          name: disruption['label'] as String,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (c) {
        setState(() => _impact = c);
        ref.invalidate(scResultsProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final model = ref.watch(scModelProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featScBottleneck)),
      body: ref.watch(scDashboardProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scDashboardProvider)),
            data: (run) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ScSection(
                  title: l10n.scLoadsTitle,
                  child: run.bottlenecks.isEmpty
                      ? Text(l10n.scNoLoads)
                      : Column(children: [
                          for (final b in run.bottlenecks)
                            Padding(
                              key: ValueKey('sc-load-${b.kind}-${b.id}'),
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: ScLoadBar(load: b),
                            ),
                        ]),
                ),
                if (model != null) _disruption(context, l10n, model),
              ],
            ),
          ),
    );
  }

  Widget _disruption(BuildContext context, AppLocalizations l10n, ScModel model) {
    final theme = Theme.of(context);
    final targets = scTargets(l10n, model);
    final label = targets.where((t) => t.$1 == _target).map((t) => t.$2).firstOrNull ?? '';
    final c = _impact;
    return ScSection(
      title: l10n.scDisruptionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('sc-disruption-target'),
                initialValue: targets.any((t) => t.$1 == _target) ? _target : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.scDisruptionTarget),
                items: [for (final (v, l) in targets) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'stop', label: Text(l10n.scStop)),
                ButtonSegment(value: 'delay', label: Text(l10n.scDelay)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            ScNumberField(controller: _days, label: l10n.scDisruptionDays, width: 110, fieldKey: const ValueKey('sc-disruption-days')),
            FilledButton.icon(
              key: const ValueKey('sc-disruption-run'),
              onPressed: _busy || _target == null ? null : () => _run(l10n, label),
              icon: const Icon(Icons.bolt),
              label: Text(l10n.scRunDisruption),
            ),
          ]),
          if (c != null) ...[
            const SizedBox(height: AppSpacing.md),
            for (final d in c.scenario.disruptions) ...[
              Text(d.label, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                ScKpiCard(
                  key: const ValueKey('sc-disruption-impact'),
                  label: l10n.scImpact,
                  value: scSigned(d.impact),
                  emphasis: true,
                  tone: null,
                ),
                ScKpiCard(label: l10n.scExtraCost, value: scMoney(d.extraCost)),
                ScKpiCard(label: l10n.scLostProfit, value: scMoney(d.lostProfit)),
                ScKpiCard(label: l10n.scLostUnits, value: scNumber(d.lostUnits)),
              ]),
              for (final p in d.products)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: Text([
                    p.alternative == null ? l10n.scNoAlternativeRoute : l10n.scAlternativeVia(p.alternative!),
                    if (p.coverageDays != null) l10n.scCoverage(scNumber(p.coverageDays!)),
                    '${l10n.scRerouted} ${scNumber(p.reroutedUnits)}',
                    '${l10n.scLostUnits} ${scNumber(p.lostUnits)}',
                    if (p.leadTimeChange != null) '${l10n.scLeadTime} ${p.leadTimeChange! >= 0 ? '+' : ''}${scNumber(p.leadTimeChange!)}',
                  ].join(' · ')),
                  trailing: Text(scSigned(p.impact),
                      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: AppFonts.mono, color: p.impact < 0 ? AppColors.danger : null)),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
