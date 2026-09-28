import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_editors.dart';
import 'sc_labels.dart';
import 'sc_simulation_screen.dart';
import 'sc_widgets.dart';

/// 物流ルート (§8–10, §22, §33): each supplier's ways into our warehouses,
/// leg by leg — sea, air, truck, customs — with what each leg costs and
/// takes, and the sites they pass through.
class ScRoutesScreen extends ConsumerWidget {
  const ScRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(scCanManageProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featScRoutes),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('sc-tab-routes'), text: l10n.scRoutesTab),
            Tab(key: const ValueKey('sc-tab-nodes'), text: l10n.scNodesTab),
          ]),
        ),
        body: ref.watch(scModelProvider).when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scModelProvider)),
              data: (m) => TabBarView(children: [
                _RoutesTab(model: m, canManage: canManage),
                _NodesTab(model: m, canManage: canManage),
              ]),
            ),
      ),
    );
  }
}

class _RoutesTab extends StatelessWidget {
  const _RoutesTab({required this.model, required this.canManage});

  final ScModel model;
  final bool canManage;

  void _openLeg(BuildContext context, ScRoute route, ScEdge e) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String name(int id) => model.node(id)?.name ?? '#$id';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(scModeIcon(e.mode)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('${scModeLabel(l10n, e.mode)} · ${name(e.fromNodeId)} → ${name(e.toNodeId)}', style: theme.textTheme.titleMedium)),
              ScRiskBadge(level: e.riskLevel),
            ]),
            const SizedBox(height: AppSpacing.md),
            _kv(context, l10n.scLeadTimeDays, scNumber(e.leadTimeDays)),
            if (e.baseCost > 0) _kv(context, l10n.scBaseCost, scMoney(e.baseCost)),
            if (e.costPerKg > 0) _kv(context, l10n.scCostPerKg, scUnitMoney(e.costPerKg)),
            if (e.costPerUnit > 0) _kv(context, l10n.scCostPerUnit, scUnitMoney(e.costPerUnit)),
            if (e.insuranceRate > 0) _kv(context, l10n.scInsuranceRate, scPercent(e.insuranceRate, digits: 2)),
            if (e.capacityKgMonth != null) _kv(context, l10n.scCapacityKg, scNumber(e.capacityKgMonth!)),
            if (e.customsClearance) _kv(context, l10n.scCustomsCost, scMoney(e.customsCost)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('sc-apply-route'),
              onPressed: () {
                Navigator.pop(sheetContext);
                final mode = route.edges.map((x) => x.mode).firstWhere((m) => m == 'sea' || m == 'air', orElse: () => e.mode);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ScSimulationScreen(initialParams: ScScenarioParams(routeMode: mode), initialName: route.name),
                ));
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.scApplyRoute),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Text(v, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final byOrigin = <int, List<ScRoute>>{};
    for (final r in model.routes) {
      byOrigin.putIfAbsent(r.originNodeId, () => []).add(r);
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sc-add-route'),
              onPressed: () => showDialog(context: context, builder: (_) => ScRouteDialog(model: model)),
              icon: const Icon(Icons.add),
              label: Text(l10n.scAddRoute),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (model.routes.isEmpty)
          SizedBox(height: 240, child: EmptyStateView(icon: Icons.alt_route, title: l10n.scNoRoutes, message: l10n.scNoRoutesBody)),
        for (final entry in byOrigin.entries)
          ScSection(
            title: model.node(entry.key)?.name ?? '#${entry.key}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in entry.value)
                  Padding(
                    key: ValueKey('sc-route-${r.id}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('${r.name} · ${l10n.scDays(scNumber(r.leadTimeDays))}', style: theme.textTheme.labelLarge),
                          ),
                          if (canManage)
                            IconButton(
                              tooltip: l10n.actionEdit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showDialog(context: context, builder: (_) => ScRouteDialog(model: model, route: r)),
                            ),
                        ]),
                        ScRouteGraph(route: r, model: model, onLegTap: (e) => _openLeg(context, r, e)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NodesTab extends StatelessWidget {
  const _NodesTab({required this.model, required this.canManage});

  final ScModel model;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nodes = [...model.nodes]..sort((a, b) => scNodeKinds.indexOf(a.kind).compareTo(scNodeKinds.indexOf(b.kind)));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sc-add-node'),
              onPressed: () => showDialog(context: context, builder: (_) => const ScNodeDialog()),
              icon: const Icon(Icons.add),
              label: Text(l10n.scAddNode),
            ),
          ),
        for (final n in nodes)
          Card(
            key: ValueKey('sc-node-${n.id}'),
            child: ListTile(
              leading: Icon(scNodeIcon(n.kind)),
              title: Text(n.name),
              subtitle: Text([
                scNodeKindLabel(l10n, n.kind),
                if (n.countryCode != null) n.countryCode!,
                if (n.capacityUnitsMonth != null) '${l10n.scCapacityUnits} ${scNumber(n.capacityUnitsMonth!)}',
                if (n.capacityKgMonth != null) '${l10n.scCapacityKg} ${scNumber(n.capacityKgMonth!)}',
                if (n.dwellDays > 0) '${l10n.scDwellDays} ${scNumber(n.dwellDays)}',
              ].join(' · ')),
              trailing: ScRiskBadge(level: n.riskLevel),
              onTap: canManage ? () => showDialog(context: context, builder: (_) => ScNodeDialog(node: n)) : null,
            ),
          ),
      ],
    );
  }
}
