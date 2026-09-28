import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/supply_chain_providers.dart';
import '../domain/supply_chain.dart';
import 'sc_labels.dart';
import 'sc_simulation_screen.dart';

/// シナリオ履歴 (rule 4): saved what-ifs, to run again against today's data,
/// and every run kept as it was.
class ScHistoryScreen extends ConsumerWidget {
  const ScHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featScHistory),
          bottom: TabBar(tabs: [
            Tab(key: const ValueKey('sc-tab-scenarios'), text: l10n.scSavedScenarios),
            Tab(key: const ValueKey('sc-tab-runs'), text: l10n.scRunHistory),
          ]),
        ),
        body: const TabBarView(children: [_Scenarios(), _Runs()]),
      ),
    );
  }
}

class _Scenarios extends ConsumerWidget {
  const _Scenarios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManage = ref.watch(scCanManageProvider);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return ref.watch(scScenariosProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scScenariosProvider)),
          data: (rows) => rows.isEmpty
              ? EmptyStateView(icon: Icons.bookmark_border, title: l10n.scNoScenarios)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final s in rows)
                      Card(
                        key: ValueKey('sc-scenario-${s.id}'),
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text([
                            if (s.updatedAt != null) df.format(s.updatedAt!.toLocal()),
                            if (s.lastProfit != null) '${l10n.scProfit} ${scMoney(s.lastProfit!)}',
                            if (s.lastProfit != null && s.lastBaselineProfit != null)
                              '${l10n.scDifference} ${scSigned(s.lastProfit! - s.lastBaselineProfit!)}',
                          ].join(' · ')),
                          trailing: Wrap(children: [
                            IconButton(
                              key: ValueKey('sc-scenario-run-${s.id}'),
                              tooltip: l10n.scRunAgain,
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ScSimulationScreen(
                                  initialParams: ScScenarioParams.fromJson(s.params),
                                  initialName: s.name,
                                  scenarioId: s.id,
                                ),
                              )),
                            ),
                            if (canManage)
                              IconButton(
                                tooltip: l10n.actionDelete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref.read(supplyChainRepositoryProvider).archive('scenario', s.id);
                                  ref.invalidate(scScenariosProvider);
                                },
                              ),
                          ]),
                        ),
                      ),
                  ],
                ),
        );
  }
}

class _Runs extends ConsumerWidget {
  const _Runs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return ref.watch(scResultsProvider).when(
          loading: () => LoadingView(message: l10n.loading),
          error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(scResultsProvider)),
          data: (rows) => rows.isEmpty
              ? EmptyStateView(icon: Icons.history, title: l10n.scNoRuns)
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(scResultsProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      for (final r in rows)
                        ListTile(
                          key: ValueKey('sc-run-${r.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: StatusPill(tone: StatusTone.info, label: scRunKindLabel(l10n, r.kind), dense: true),
                          title: Text(r.name ?? r.scenarioName ?? scRunKindLabel(l10n, r.kind)),
                          subtitle: Text([
                            if (r.createdAt != null) df.format(r.createdAt!.toLocal()),
                            if (r.createdByName != null) r.createdByName!,
                            if (r.margin != null) '${l10n.scMargin} ${scPercent(r.margin)}',
                          ].join(' · ')),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (r.profit != null) Text(scMoney(r.profit!), style: theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.mono)),
                              if (r.deltaProfit != null)
                                Text(scSigned(r.deltaProfit!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: AppFonts.mono, color: r.deltaProfit! < 0 ? AppColors.danger : AppColors.success)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        );
  }
}
