import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_ops_providers.dart';
import '../domain/stock_ops.dart';
import 'stock_ops_ui.dart';

/// One count session: every frozen line, what was counted, and — once the
/// session is closed — the variance the ledger corrected.
///
/// While a blind count is open the backend withholds the system quantity, so
/// this screen never has it to leak. It says so rather than showing a zero.
class StockCountDetailScreen extends ConsumerWidget {
  const StockCountDetailScreen({super.key, required this.countId});

  final int countId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(stockCountDetailProvider(countId));

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.cntTitle} #$countId')),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(stockCountDetailProvider(countId)),
        ),
        data: (count) => _Body(count: count),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.count});

  final StockCount count;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  StockCount get _count => widget.count;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _refresh() {
    ref.invalidate(stockCountDetailProvider(_count.id));
    ref.invalidate(stockCountListProvider);
  }

  Future<void> _record(StockCountLine line) async {
    final counted = await showDialog<int>(
      context: context,
      builder: (_) => _CountLineDialog(line: line, hideSystem: _count.hideSystem),
    );
    if (counted == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(stockOpsRepositoryProvider)
        .recordLine(_count.id, line.id, counted);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => _refresh(),
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    final uncounted = _count.uncountedLines;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.cntCompleteQ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cntCompleteBody),
            // Uncounted lines are left alone, not treated as zero (spec §40).
            if (uncounted > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.cntUncountedWarn(uncounted),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cntComplete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result =
        await ref.read(stockOpsRepositoryProvider).completeCount(_count.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (completed) {
        _refresh();
        _snack(l10n.cntCompleted(
          completed.summary.adjustedLines,
          signed(completed.summary.netChange),
        ));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.cntCancelQ),
        content: Text(l10n.cntCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cntCancel),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result =
        await ref.read(stockOpsRepositoryProvider).cancelCount(_count.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        _refresh();
        _snack(l10n.cntCancelled);
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ui = CountStatusUi.of(l10n, _count.status);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.cntProgress(_count.countedLines, _count.totalLines),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (_count.hideSystem)
                StatusPill(
                  tone: StatusTone.info,
                  label: l10n.cntBlind,
                  dense: true,
                )
              else if (!_count.isOpen && _count.netVariance != 0)
                StatusPill(
                  tone: StatusTone.warning,
                  label: '${l10n.cntVariance} ${signed(_count.netVariance)}',
                  dense: true,
                ),
            ],
          ),
        ),
        Expanded(
          child: _count.lines.isEmpty
              ? EmptyStateView(
                  icon: Icons.inventory_2_outlined, title: l10n.cntEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _count.lines.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _LineCard(
                    line: _count.lines[i],
                    hideSystem: _count.hideSystem,
                    onTap: _count.isOpen && !_busy
                        ? () => _record(_count.lines[i])
                        : null,
                  ),
                ),
        ),
        if (_count.isOpen)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    SizedBox(
                      height: AppSpacing.minTouch,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancel,
                        child: Text(l10n.cntCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.minTouch,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _complete,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.done_all),
                          label:
                              Text(_busy ? l10n.working : l10n.cntComplete),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.hideSystem,
    this.onTap,
  });

  final StockCountLine line;
  final bool hideSystem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;
    final variance = line.variance;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(line.janCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (line.isCounted)
                    Icon(Icons.check_circle,
                        size: 20, color: scheme.primary)
                  else
                    Icon(Icons.radio_button_unchecked,
                        size: 20, color: scheme.outline),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Cell(
                    label: l10n.cntSystem,
                    value: hideSystem ? null : line.systemQuantity,
                    placeholder: l10n.cntHidden,
                  ),
                  _Cell(
                    label: l10n.cntCounted,
                    value: line.countedQuantity,
                    placeholder: '—',
                  ),
                  _Cell(
                    label: l10n.cntVariance,
                    value: hideSystem ? null : variance,
                    placeholder: hideSystem ? l10n.cntHidden : '—',
                    showSign: true,
                    color: variance != null && variance != 0 && !hideSystem
                        ? scheme.error
                        : null,
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

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.placeholder,
    this.showSign = false,
    this.color,
  });

  final String label;
  final int? value;
  final String placeholder;
  final bool showSign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final has = value != null;
    final text = has ? (showSign ? signed(value!) : '${value!}') : placeholder;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            text,
            style: has
                ? theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w600,
                    color: color ?? scheme.onSurface)
                : theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Entering the counted quantity. A blind session shows no system figure here
/// either — that is the whole point of counting blind.
class _CountLineDialog extends StatefulWidget {
  const _CountLineDialog({required this.line, required this.hideSystem});

  final StockCountLine line;
  final bool hideSystem;

  @override
  State<_CountLineDialog> createState() => _CountLineDialogState();
}

class _CountLineDialogState extends State<_CountLineDialog> {
  late final TextEditingController _counted =
      TextEditingController(text: widget.line.countedQuantity?.toString() ?? '');

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = widget.line;
    final title = line.productName.isNotEmpty ? line.productName : line.janCode;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.janCode,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _counted,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.cntCounted),
            style: const TextStyle(fontFamily: AppFonts.mono),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.hideSystem) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.cntBlindHelp,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.cntRecord)),
      ],
    );
  }

  void _submit() {
    final value = int.tryParse(_counted.text.trim());
    if (value == null) return;
    Navigator.pop(context, value);
  }
}
