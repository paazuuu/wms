import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../../warehouse_context/domain/warehouse.dart';
import '../application/transfer_providers.dart';
import '../data/transfer_repository.dart';
import '../domain/transfer_order.dart';
import 'transfer_detail_screen.dart';
import 'transfer_status_ui.dart';

/// Transfers touching the active warehouse, in either direction.
class TransferListScreen extends ConsumerStatefulWidget {
  const TransferListScreen({super.key});

  @override
  ConsumerState<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends ConsumerState<TransferListScreen> {
  bool _busy = false;

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

    final draft = await showModalBottomSheet<_TransferDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateTransferSheet(warehouses: overview.warehouses),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(transferRepositoryProvider).create(
          sourceWarehouseId: draft.sourceId,
          destinationWarehouseId: draft.destinationId,
          lines: draft.lines,
          note: draft.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (order) {
        ref.invalidate(transferListProvider);
        _snack(l10n.transferCreated(order.transferNumber ?? '#${order.id}'));
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TransferDetailScreen(transferId: order.id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _TransferCard(order: list[i]),
            ),
          );
        },
      ),
    );
  }
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

class _TransferDraft {
  const _TransferDraft({
    required this.sourceId,
    required this.destinationId,
    required this.lines,
    this.note,
  });
  final int sourceId;
  final int destinationId;
  final List<TransferLineDraft> lines;
  final String? note;
}

class _CreateTransferSheet extends StatefulWidget {
  const _CreateTransferSheet({required this.warehouses});

  final List<Warehouse> warehouses;

  @override
  State<_CreateTransferSheet> createState() => _CreateTransferSheetState();
}

class _CreateTransferSheetState extends State<_CreateTransferSheet> {
  late int _sourceId = widget.warehouses.first.id;
  late int _destinationId =
      widget.warehouses.length > 1 ? widget.warehouses[1].id : widget.warehouses.first.id;
  final _note = TextEditingController();
  final List<TransferLineDraft> _lines = [];
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final draft = await showDialog<TransferLineDraft>(
      context: context,
      builder: (_) => const _AddLineDialog(),
    );
    if (draft == null) return;
    setState(() {
      _lines.add(draft);
      _error = null;
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_sourceId == _destinationId) {
      setState(() => _error = l10n.transferNeedsTwoWarehouses);
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = l10n.transferLineRequired);
      return;
    }
    Navigator.pop(
      context,
      _TransferDraft(
        sourceId: _sourceId,
        destinationId: _destinationId,
        lines: _lines,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.transferNew, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _sourceId,
              decoration: InputDecoration(labelText: l10n.transferSource),
              items: [
                for (final w in widget.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _sourceId = v ?? _sourceId),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              initialValue: _destinationId,
              decoration: InputDecoration(labelText: l10n.transferDestination),
              items: [
                for (final w in widget.warehouses)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => _destinationId = v ?? _destinationId),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.transferLinesTitle,
                      style: theme.textTheme.labelLarge),
                ),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.transferAddLine),
                ),
              ],
            ),
            for (final line in _lines)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  dense: true,
                  title: Text(line.productName?.isNotEmpty == true
                      ? line.productName!
                      : line.janCode),
                  subtitle: Text(line.janCode,
                      style: const TextStyle(fontFamily: AppFonts.mono)),
                  trailing: Text('${line.quantity}',
                      style: const TextStyle(
                          fontFamily: AppFonts.mono, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.transferNote),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                onPressed: _submit,
                child: Text(l10n.transferCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddLineDialog extends StatefulWidget {
  const _AddLineDialog();

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _jan = TextEditingController();
  final _productName = TextEditingController();
  final _quantity = TextEditingController();

  @override
  void dispose() {
    _jan.dispose();
    _productName.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final jan = _jan.text.trim();
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty || qty <= 0) return;
    Navigator.pop(
      context,
      TransferLineDraft(
        janCode: jan,
        quantity: qty,
        productName: _productName.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.transferAddLine),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _jan,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.transferLineJan),
            style: const TextStyle(fontFamily: AppFonts.mono),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _productName,
            decoration: InputDecoration(labelText: l10n.transferLineProductName),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.transferLineQuantity),
            style: const TextStyle(fontFamily: AppFonts.mono),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.transferAddLine)),
      ],
    );
  }
}
