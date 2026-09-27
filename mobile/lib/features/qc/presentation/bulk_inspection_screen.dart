import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/inspection_providers.dart';
import '../domain/bulk_inspection.dart';

/// Settle many inspection lines as good in one go (0099).
///
/// Most deliveries are fine, and checking each line on a phone is slow. Here
/// the operator narrows what is waiting — by arrival date, by purchase order,
/// or to one product by scanning its JAN — and everything shown starts
/// selected. Untick whatever still needs a closer look; the rest is passed in
/// full, becomes shippable at once, and the unticked lines stay waiting.
class BulkInspectionScreen extends ConsumerStatefulWidget {
  const BulkInspectionScreen({super.key});

  @override
  ConsumerState<BulkInspectionScreen> createState() => _BulkInspectionScreenState();
}

/// "No purchase order" in the purchase-order filter.
const _noPo = -1;

class _BulkInspectionScreenState extends ConsumerState<BulkInspectionScreen> {
  String? _date;
  int? _po;
  String? _jan;
  final Set<int> _unticked = {};
  bool _busy = false;

  static final _df = DateFormat('yyyy-MM-dd');

  String _dateKey(OpenInspectionLine l) => l.arrivedOn == null ? '' : _df.format(l.arrivedOn!);

  List<OpenInspectionLine> _visible(List<OpenInspectionLine> all) => [
        for (final l in all)
          if ((_date == null || _dateKey(l) == _date) &&
              (_po == null || (_po == _noPo ? l.purchaseOrderId == null : l.purchaseOrderId == _po)) &&
              (_jan == null || l.janCode == _jan))
            l,
      ];

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  void _useScan(String code, List<OpenInspectionLine> all) {
    final l10n = AppLocalizations.of(context);
    final jan = code.trim();
    if (jan.isEmpty) return;
    if (!all.any((l) => l.janCode == jan)) {
      _snack(l10n.bulkQcNoMatch, danger: true);
      return;
    }
    setState(() => _jan = jan);
  }

  Future<void> _scanWithCamera(List<OpenInspectionLine> all) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code != null && mounted) _useScan(code, all);
  }

  Future<void> _pass(List<OpenInspectionLine> selected) async {
    final l10n = AppLocalizations.of(context);
    final units = selected.fold(0, (s, l) => s + l.quantity);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.bulkQcConfirmTitle),
        content: Text(l10n.bulkQcConfirmBody(selected.length, units)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey('bulk-qc-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.qcPassAll),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .passItems([for (final l in selected) l.itemId]);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (r) {
        _unticked.clear();
        ref.invalidate(openInspectionLinesProvider);
        ref.invalidate(inspectionListProvider);
        ref.invalidate(heldStockProvider);
        _snack(l10n.bulkQcDone(r.items, units));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(openInspectionLinesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bulkQcTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(openInspectionLinesProvider),
        ),
        data: (all) {
          if (all.isEmpty) {
            return EmptyStateView(
              icon: Icons.verified_outlined,
              title: l10n.bulkQcEmpty,
              message: l10n.bulkQcEmptyBody,
            );
          }
          // A filter whose lines were all just settled would match nothing
          // and point the dropdown at a value it no longer offers.
          if (_date != null && !all.any((l) => _dateKey(l) == _date)) _date = null;
          if (_po != null &&
              !all.any((l) => _po == _noPo ? l.purchaseOrderId == null : l.purchaseOrderId == _po)) {
            _po = null;
          }
          if (_jan != null && !all.any((l) => l.janCode == _jan)) _jan = null;
          final visible = _visible(all);
          // A line not yet converted to ours cannot pass (0103).
          final selected = [
            for (final l in visible)
              if (!_unticked.contains(l.itemId) && !l.isUnconverted) l,
          ];
          final selectable = visible.where((l) => !l.isUnconverted).length;
          return Column(
            children: [
              _Filters(
                all: all,
                date: _date,
                po: _po,
                jan: _jan,
                onDate: (v) => setState(() => _date = v),
                onPo: (v) => setState(() => _po = v),
                onClearJan: () => setState(() => _jan = null),
                onScan: (code) => _useScan(code, all),
                onCamera: () => _scanWithCamera(all),
              ),
              Expanded(
                child: _Lines(
                  lines: visible,
                  unticked: _unticked,
                  onToggle: (ids, tick) => setState(() {
                    if (tick) {
                      _unticked.removeAll(ids);
                    } else {
                      _unticked.addAll(ids);
                    }
                  }),
                ),
              ),
              _PassBar(
                selected: selected,
                busy: _busy,
                allSelected: selected.length == selectable,
                onSelectAll: () => setState(() {
                  if (selected.length == selectable) {
                    _unticked.addAll(visible.map((l) => l.itemId));
                  } else {
                    _unticked.removeAll(visible.map((l) => l.itemId));
                  }
                }),
                onPass: () => _pass(selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.all,
    required this.date,
    required this.po,
    required this.jan,
    required this.onDate,
    required this.onPo,
    required this.onClearJan,
    required this.onScan,
    required this.onCamera,
  });

  final List<OpenInspectionLine> all;
  final String? date;
  final int? po;
  final String? jan;
  final ValueChanged<String?> onDate;
  final ValueChanged<int?> onPo;
  final VoidCallback onClearJan;
  final ValueChanged<String> onScan;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd');
    final dates = {for (final l in all) if (l.arrivedOn != null) df.format(l.arrivedOn!)}.toList()
      ..sort((a, b) => b.compareTo(a));
    final pos = <int, String>{};
    var anyWithoutPo = false;
    for (final l in all) {
      if (l.purchaseOrderId == null) {
        anyWithoutPo = true;
      } else {
        pos[l.purchaseOrderId!] =
            [l.poNumber ?? '#${l.purchaseOrderId}', l.supplierName].whereType<String>().join(' · ');
      }
    }
    final productName = jan == null
        ? null
        : all.firstWhere((l) => l.janCode == jan, orElse: () => all.first).title;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ScanField(
                  hintText: l10n.bulkQcScanHint,
                  autofocusOnWide: true,
                  onSubmitted: onScan,
                  dense: true,
                ),
              ),
              IconButton(
                tooltip: l10n.scanBarcode,
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: onCamera,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('bulk-qc-date'),
                  initialValue: date,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.bulkQcGroupDate, isDense: true),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.bulkQcAllDates)),
                    for (final d in dates) DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: onDate,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: const ValueKey('bulk-qc-po'),
                  initialValue: po,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.bulkQcGroupPo, isDense: true),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.bulkQcAllPos)),
                    for (final e in pos.entries)
                      DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis)),
                    if (anyWithoutPo)
                      DropdownMenuItem(value: _noPo, child: Text(l10n.bulkQcNoPo)),
                  ],
                  onChanged: onPo,
                ),
              ),
            ],
          ),
          if (productName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                key: const ValueKey('bulk-qc-product'),
                label: Text(l10n.bulkQcProductFilter(productName)),
                onDeleted: onClearJan,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.unticked, required this.onToggle});

  final List<OpenInspectionLine> lines;
  final Set<int> unticked;
  final void Function(Iterable<int> ids, bool tick) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('yyyy-MM-dd');
    // One group per receipt: that is what arrived together.
    final groups = <int, List<OpenInspectionLine>>{};
    for (final l in lines) {
      groups.putIfAbsent(l.reconciliationId ?? -l.inspectionId, () => []).add(l);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        for (final g in groups.values) ...[
          Builder(builder: (context) {
            final first = g.first;
            final open = g.where((l) => !l.isUnconverted).toList();
            final ticked = open.where((l) => !unticked.contains(l.itemId)).length;
            final value = open.isNotEmpty && ticked == open.length
                ? true
                : (ticked == 0 ? false : null);
            return CheckboxListTile(
              tristate: true,
              value: value,
              onChanged: open.isEmpty
                  ? null
                  : (_) => onToggle(open.map((l) => l.itemId), value != true),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                [
                  if (first.arrivedOn != null) l10n.bulkQcArrived(df.format(first.arrivedOn!)),
                  first.supplierName,
                  first.poNumber,
                ].whereType<String>().join(' · '),
                style: theme.textTheme.titleSmall,
              ),
              subtitle: Text(
                  [first.referenceNo, first.deliveryNumber].whereType<String>().join(' · ')),
            );
          }),
          for (final l in g)
            CheckboxListTile(
              key: ValueKey('bulk-qc-line-${l.itemId}'),
              value: !l.isUnconverted && !unticked.contains(l.itemId),
              onChanged: l.isUnconverted ? null : (v) => onToggle([l.itemId], v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.lg),
              title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text([l.janCode, l.lot].whereType<String>().join(' · ')),
                  if (l.srcProductName != null && l.srcProductName != l.productName ||
                      l.srcJanCode != null && l.srcJanCode != l.janCode)
                    Text(
                      l10n.qcSupplierNotation([l.srcProductName, l.srcJanCode]
                          .whereType<String>()
                          .join(' · ')),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              secondary: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.heldStockQuantity(l.quantity), style: theme.textTheme.titleSmall),
                  if (l.isUnconverted)
                    StatusPill(tone: StatusTone.warning, label: l10n.qcUnconverted, dense: true)
                  else if (l.checked)
                    StatusPill(tone: StatusTone.info, label: l10n.bulkQcRecordedBadge, dense: true),
                ],
              ),
            ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _PassBar extends StatelessWidget {
  const _PassBar({
    required this.selected,
    required this.busy,
    required this.allSelected,
    required this.onSelectAll,
    required this.onPass,
  });

  final List<OpenInspectionLine> selected;
  final bool busy;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final units = selected.fold(0, (s, l) => s + l.quantity);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.bulkQcSummary(selected.length, units))),
                  TextButton(
                    key: const ValueKey('bulk-qc-select-all'),
                    onPressed: onSelectAll,
                    child: Text(allSelected ? l10n.bulkQcSelectNone : l10n.bulkQcSelectAll),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouch,
                child: FilledButton.icon(
                  key: const ValueKey('bulk-qc-pass'),
                  onPressed: busy || selected.isEmpty ? null : onPass,
                  icon: busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.done_all),
                  label: Text(l10n.bulkQcPass),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
