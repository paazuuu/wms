import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../../warehouse_context/domain/warehouse_role.dart';
import '../application/transfer_providers.dart';
import '../domain/transfer_order.dart';
import 'transfer_board_screen.dart';
import 'transfer_detail_screen.dart';
import 'transfer_status_ui.dart';

/// Transfers touching the active warehouse, in either direction.
class TransferListScreen extends ConsumerStatefulWidget {
  const TransferListScreen({super.key});

  @override
  ConsumerState<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends ConsumerState<TransferListScreen> {
  final bool _busy = false;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    // Awaited rather than read as a cached value: nothing else on this screen
    // watches the overview, so without this a first tap would always see it
    // as still loading.
    final WarehouseOverview overview;
    try {
      overview = await ref.read(warehouseOverviewProvider.future);
    } catch (_) {
      _snack(l10n.transferNeedsTwoWarehouses, danger: true);
      return;
    }
    if (!mounted) return;
    if (overview.warehouses.length < 2) {
      _snack(l10n.transferNeedsTwoWarehouses, danger: true);
      return;
    }

    // Without the roles the sheet still works; it just cannot warn about an
    // export before one is made.
    Map<int, WarehouseRole> roles = const {};
    try {
      roles = await ref.read(warehouseRolesProvider.future);
    } catch (_) {}
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TransferBoardScreen(
        warehouses: overview.warehouses,
        roles: roles,
        initialSourceId: ref.read(activeWarehouseIdProvider),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(transferListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.compare_arrows),
        label: Text(_busy ? l10n.working : l10n.transferNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(transferListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              icon: Icons.compare_arrows,
              title: l10n.transferEmpty,
              message: l10n.transferEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(transferListProvider),
            child: _filtered(context, list),
          );
        },
      ),
    );
  }

  // Filters: state, the warehouse it leaves, the one it goes to, a word.
  _TransferState _state = _TransferState.all;
  int? _from;
  int? _to;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _matches(TransferOrder o) {
    if (!_state.has(o.status)) return false;
    if (_from != null && o.sourceWarehouseId != _from) return false;
    if (_to != null && o.destinationWarehouseId != _to) return false;
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [o.transferNumber, o.sourceWarehouseName, o.destinationWarehouseName, o.note, '${o.id}']
        .any((t) => (t ?? '').toLowerCase().contains(q));
  }

  Widget _filtered(BuildContext context, List<TransferOrder> list) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = ref.watch(activeWarehouseIdProvider);
    final names = <int, String>{
      for (final o in list) o.sourceWarehouseId: o.sourceWarehouseName ?? '#${o.sourceWarehouseId}',
      for (final o in list) o.destinationWarehouseId: o.destinationWarehouseName ?? '#${o.destinationWarehouseId}',
    };
    final shown = list.where(_matches).toList();
    Widget whField(String key, String label, int? value, ValueChanged<int?> onChanged, IconData icon) => SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
            key: ValueKey(key),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), isDense: true),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l10n.tlAll)),
              for (final e in names.entries) DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
            ],
            onChanged: onChanged,
          ),
        );
    Widget section(String key, String title, IconData icon, List<TransferOrder> items) => Column(
          key: ValueKey(key),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
              child: Row(children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('$title（${items.length}）', style: theme.textTheme.titleSmall),
              ]),
            ),
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: Text(l10n.tlNone, style: theme.textTheme.bodySmall)),
            for (final o in items)
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _TransferCard(order: o)),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl * 2),
      children: [
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final st in _TransferState.values)
            ChoiceChip(
              key: ValueKey('tl-state-${st.name}'),
              label: Text(st.label(l10n)),
              selected: _state == st,
              onSelected: (_) => setState(() => _state = st),
            ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          whField('tl-from', l10n.tbSource, _from, (v) => setState(() => _from = v), Icons.outbox_outlined),
          whField('tl-to', l10n.tbDestination, _to, (v) => setState(() => _to = v), Icons.move_to_inbox_outlined),
          SizedBox(
            width: 260,
            child: TextField(
              key: const ValueKey('tl-search'),
              controller: _q,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.tlSearch, isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: Center(child: Text(l10n.tlNone)))
        // A warehouse chosen at the top: what leaves it and what comes in,
        // apart.
        else if (active != null) ...[
          section('tl-out', l10n.tlOutgoing(names[active] ?? ''), Icons.outbox_outlined,
              [for (final o in shown) if (o.sourceWarehouseId == active) o]),
          section('tl-in', l10n.tlIncoming(names[active] ?? ''), Icons.move_to_inbox_outlined,
              [for (final o in shown) if (o.destinationWarehouseId == active) o]),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          for (final o in shown) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _TransferCard(order: o)),
        ],
      ],
    );
  }
}

/// The states the list is narrowed to.
enum _TransferState {
  all,
  open,
  inTransit,
  done,
  closed;

  bool has(TransferStatus s) => switch (this) {
        all => true,
        open => const {TransferStatus.draft, TransferStatus.pendingApproval, TransferStatus.approved, TransferStatus.picking}
            .contains(s),
        inTransit => s == TransferStatus.inTransit || s == TransferStatus.receiving,
        done => s == TransferStatus.completed || s == TransferStatus.exported,
        closed => s == TransferStatus.rejected || s == TransferStatus.cancelled,
      };

  String label(AppLocalizations l10n) => switch (this) {
        all => l10n.tlAll,
        open => l10n.tlOpen,
        inTransit => l10n.tlInTransit,
        done => l10n.tlDone,
        closed => l10n.tlClosed,
      };
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.order});

  final TransferOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = TransferStatusUi.of(l10n, order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TransferDetailScreen(transferId: order.id),
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
                    Text(
                      order.transferNumber ?? '#${order.id}',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.sourceWarehouseName ?? '#${order.sourceWarehouseId}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_right_alt,
                            size: 16, color: scheme.onSurfaceVariant),
                        Flexible(
                          child: Text(
                            order.destinationWarehouseName ??
                                '#${order.destinationWarehouseId}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(tone: ui.tone, label: ui.label, dense: true),
                  if (order.exports && order.status != TransferStatus.exported) ...[
                    const SizedBox(height: 4),
                    StatusPill(
                        tone: StatusTone.warning,
                        label: l10n.transferExportBadge,
                        icon: Icons.public,
                        dense: true),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    l10n.lineCount(order.totalLines),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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
