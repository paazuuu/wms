import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../auth/application/auth_controller.dart';
import '../application/inspection_providers.dart';
import '../domain/inspection.dart';
import 'inspection_detail_screen.dart';
import 'inspection_status_ui.dart';

class InspectionListScreen extends ConsumerWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections = ref.watch(inspectionListProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featInspection),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(inspectionListProvider),
        child: inspections.when(
          data: (items) => items.isEmpty
              ? EmptyStateView(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.emptyInspections,
                  message: l10n.inspectionsEmptyBody,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) =>
                      _InspectionCard(inspection: items[index]),
                ),
          loading: () => LoadingView(message: l10n.loading),
          error: (error, _) => ErrorStateView(
            message: '$error',
            onRetry: () => ref.invalidate(inspectionListProvider),
          ),
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = InspectionStatusUi.of(l10n, inspection.status);
    final count = inspection.itemsCount ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                InspectionDetailScreen(inspectionId: inspection.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: ui.tone, icon: ui.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.code,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inspectionTypeLabel(l10n, inspection.type)} · ${l10n.itemCount(count)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
