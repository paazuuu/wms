import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../delivery/presentation/plan_import_screen.dart';
import '../application/shipment_providers.dart';
import '../domain/shipment.dart';
import 'sender_picker.dart';
import 'shipment_detail_screen.dart';
import 'shipment_status_ui.dart';

/// Lists shipments (出庫) to pack and ship. Import a customer's list, then open
/// one to subdivide it into cartons and confirm the shipment.
class ShipmentListScreen extends ConsumerStatefulWidget {
  const ShipmentListScreen({super.key});

  @override
  ConsumerState<ShipmentListScreen> createState() => _ShipmentListScreenState();
}

class _ShipmentListScreenState extends ConsumerState<ShipmentListScreen> {
  String _query = '';

  bool _matches(Shipment s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.shipmentNumber.toLowerCase().contains(q) ||
        (s.customerName?.toLowerCase().contains(q) ?? false) ||
        (s.customerCode?.toLowerCase().contains(q) ?? false);
  }

  void _import() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlanImportScreen(
        target: ImportTarget.shipment,
        onImported: () => ref.invalidate(shipmentsListProvider),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shipments = ref.watch(shipmentsListProvider);
    final showShipped = ref.watch(showShippedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shipmentListTitle),
        actions: [
          IconButton(
            tooltip:
                showShipped ? l10n.hideCompletedPlans : l10n.showCompletedPlans,
            isSelected: showShipped,
            icon: const Icon(Icons.history_toggle_off),
            selectedIcon: const Icon(Icons.manage_history),
            onPressed: () =>
                ref.read(showShippedProvider.notifier).update((v) => !v),
          ),
          IconButton(
            tooltip: l10n.senderSettingsTitle,
            icon: const Icon(Icons.business_outlined),
            onPressed: () => openSenderSettings(context),
          ),
          IconButton(
            tooltip: l10n.shipmentImportTitle,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: _import,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: ScanField(
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.shipmentSearchHint,
              onSubmitted: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(shipmentsListProvider),
              child: shipments.when(
                data: (items) {
                  final filtered = items.where(_matches).toList();
                  if (items.isEmpty) {
                    return _ScrollableEmpty(
                      icon: Icons.outbox_outlined,
                      title: l10n.shipmentEmpty,
                      message: l10n.shipmentEmptyBody,
                    );
                  }
                  if (filtered.isEmpty) {
                    return _ScrollableEmpty(
                      icon: Icons.search_off,
                      title: l10n.deliveryNoMatches,
                      message: l10n.deliverySearchTip,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) =>
                        _ShipmentCard(shipment: filtered[index]),
                  );
                },
                loading: () => LoadingView(message: l10n.loading),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () => ref.invalidate(shipmentsListProvider),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(l10n.shipmentImportTitle),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = ShipmentStatusUi.of(l10n, shipment.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ShipmentDetailScreen(shipmentId: shipment.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              StatusAvatar(tone: ui.tone, icon: ui.icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shipment.shipmentNumber,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(shipment.customerName ?? l10n.unknownSupplier,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (shipment.referenceNo != null &&
                        shipment.referenceNo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('${l10n.referenceNoLabel}: ${shipment.referenceNo}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'FiraCode', color: scheme.primary)),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusPill(
                            tone: ui.tone,
                            label: ui.label,
                            icon: ui.icon,
                            dense: true),
                        StatusPill(
                          tone: StatusTone.neutral,
                          label: l10n.planPreviewCount(
                              shipment.lineCount, shipment.totalUnits),
                          icon: Icons.list_alt_outlined,
                          dense: true,
                        ),
                        if (shipment.cartonCount > 0)
                          StatusPill(
                            tone: StatusTone.neutral,
                            label: l10n.cartonCountLabel(shipment.cartonCount),
                            icon: Icons.inventory_2_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty(
      {required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: EmptyStateView(icon: icon, title: title, message: message),
        ),
      ),
    );
  }
}
