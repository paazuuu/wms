import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/stock_ops_providers.dart';
import '../domain/stock_ops.dart';
import 'stock_count_detail_screen.dart';
import 'stock_ops_ui.dart';

/// Cycle counts for the active warehouse, newest first.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
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

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(writeWarehouseIdProvider);
    if (warehouseId == null) {
      _snack(l10n.adjNeedsWarehouse, danger: true);
      return;
    }

    final options = await showDialog<_CountOptions>(
      context: context,
      builder: (_) => const _StartCountDialog(),
    );
    if (options == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(stockOpsRepositoryProvider).startCount(
          warehouseId: warehouseId,
          blind: options.blind,
          note: options.note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (count) {
        ref.invalidate(stockCountListProvider);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StockCountDetailScreen(countId: count.id),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(stockCountListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cntTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _start,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.playlist_add_check),
        label: Text(_busy ? l10n.working : l10n.cntStart),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(stockCountListProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: l10n.cntEmpty,
              message: l10n.cntEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(stockCountListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                  AppSpacing.lg, AppSpacing.xxl * 2),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _CountCard(count: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count});

  final StockCount count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = CountStatusUi.of(l10n, count.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StockCountDetailScreen(countId: count.id),
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
                    Text('#${count.id}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontFamily: AppFonts.mono)),
                    const SizedBox(height: 2),
                    Text(
                      count.warehouseName ?? count.note ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    l10n.lineCount(count.totalLines),
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

class _CountOptions {
  const _CountOptions(this.blind, this.note);
  final bool blind;
  final String? note;
}

/// Starting a count freezes the current balances into lines, so the blind
/// choice has to be made up front — it cannot be flipped once counting starts.
class _StartCountDialog extends StatefulWidget {
  const _StartCountDialog();

  @override
  State<_StartCountDialog> createState() => _StartCountDialogState();
}

class _StartCountDialogState extends State<_StartCountDialog> {
  final _note = TextEditingController();
  bool _blind = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.cntStart),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: _blind,
            onChanged: (v) => setState(() => _blind = v),
            title: Text(l10n.cntBlind),
            contentPadding: EdgeInsets.zero,
          ),
          Text(l10n.cntBlindHelp,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.fieldNote),
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
              Navigator.pop(context, _CountOptions(_blind, _note.text.trim())),
          child: Text(l10n.cntStart),
        ),
      ],
    );
  }
}
