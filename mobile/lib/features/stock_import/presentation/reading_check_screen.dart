import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../notation/presentation/notation_labels.dart';
import '../domain/stock_file.dart';
import 'import_view_screen.dart' show OriginalFileView;

/// A column of the check table: its key ([ReadRow]'s own five, else a
/// [LedgerFields] key) and how wide it is.
typedef _Col = ({String key, double width});

const _core = <_Col>[
  (key: 'jan', width: 150),
  (key: 'name', width: 230),
  (key: 'maker', width: 110),
  (key: 'code', width: 140),
  (key: 'quantity', width: 80),
];

/// The ledger's columns, in its order; shown when the file had them.
const _ledger = <_Col>[
  (key: 'unit', width: 60),
  (key: 'unit_price', width: 90),
  (key: 'amount', width: 100),
  (key: 'list_price', width: 90),
  (key: 'unit_price_tax', width: 90),
  (key: 'delivery_date', width: 100),
  (key: 'order_date', width: 100),
  (key: 'serial', width: 70),
  (key: 'order_number', width: 120),
  (key: 'supplier', width: 150),
];

/// Yellow: a cell to look at (the AI was unsure, or it does not add up).
/// Blue: a cell a person changed. The same in light and dark.
Color doubtColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0x80A16207) : const Color(0xFFFEF08A);
Color changedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0x802563EB) : const Color(0xFFBFDBFE);

const _numeric = {'quantity', 'unit_price', 'amount', 'list_price', 'unit_price_tax'};

String _value(ReadRow r, String key) => switch (key) {
      'jan' => r.jan,
      'name' => r.name,
      'maker' => r.maker,
      'code' => r.code,
      'quantity' => r.quantity,
      _ => r.ledger[key],
    };

/// Where the reader's doubt about a row points: the cells to look at first.
Set<String> doubtfulCells(ReadRow r) => {
      for (final f in r.flags)
        ...switch (f) {
          'jan_check' || 'no_jan' || 'jan_code_mismatch' || 'jan_restore_mismatch' || 'ai_disagree:raw_jan_code' => {'jan'},
          'no_quantity' || 'qty_from_amount' || 'qty_from_cases' || 'ai_disagree:planned_quantity' => {'quantity'},
          'ai_disagree:product_name' => {'name'},
          'ai_disagree:product_code' => {'code'},
          'ai_disagree:maker' => {'maker'},
          'ai_disagree:unit_price' => {'unit_price'},
          'ai_disagree:amount' => {'amount'},
          'amount_mismatch' => {'quantity', 'amount'},
          'split_disagree' || 'split_failed' => {'name', 'code'},
          _ => const <String>{},
        },
    };

/// Flags that say nothing about this reading: kept, not shown as doubts.
const _quiet = {'no_maker', 'unresolved', 'split_single'};

double? _num(String v) => double.tryParse(v.replaceAll(RegExp(r'[,，\s¥円]'), ''));

/// 数量 × 単価 against 金額, when the row has all three: a yen of rounding,
/// or half a percent, is let pass.
bool amountMismatch(String quantity, String unitPrice, String amount) {
  final q = _num(quantity), p = _num(unitPrice), a = _num(amount);
  if (q == null || p == null || a == null) return false;
  return (q * p - a).abs() > math.max(1, a.abs() * 0.005);
}

class _EditRow {
  _EditRow(this.original, {this.added = false})
      : cells = {
          for (final c in [..._core, ..._ledger]) c.key: TextEditingController(text: _value(original, c.key)),
        };

  final ReadRow original;
  final bool added;
  final Map<String, TextEditingController> cells;
  bool removed = false;

  String operator [](String key) => cells[key]!.text.trim();

  bool get blank => cells.values.every((c) => c.text.trim().isEmpty);

  bool changed(String key) => this[key] != _value(original, key).trim();

  bool get anyChange => added || cells.keys.any(changed);

  void dispose() {
    for (final c in cells.values) {
      c.dispose();
    }
  }

  /// The row as a person left it: their values, the reader's kept beside
  /// them where they differ, and marked checked (and changed, and left out).
  ReadRow result() {
    var ledger = original.ledger;
    for (final c in _ledger) {
      ledger = ledger.withValue(c.key, this[c.key]);
    }
    final janChanged = changed('jan'), qtyChanged = changed('quantity');
    return original.copyWith(
      jan: this['jan'],
      name: this['name'],
      maker: this['maker'],
      code: this['code'],
      quantity: this['quantity'],
      ledger: ledger,
      // What the reader had, when a person wrote otherwise (or added the row).
      aiJan: original.aiJan ?? (added ? '' : (janChanged ? original.jan : null)),
      aiQuantity: original.aiQuantity ?? (added ? '' : (qtyChanged ? original.quantity : null)),
      flags: {
        ...original.flags,
        humanCheckedFlag,
        if (anyChange) humanCorrectedFlag,
        if (removed) humanRemovedFlag,
      }.toList(),
    );
  }
}

/// 読み取り結果の確認: what the AI read, as a table to set beside the original
/// file and correct cell by cell — a row left out, a row added — before the
/// stock is worked out. Pops with every row as the person left it, each
/// marked checked; null when they go back without it.
class ReadingCheckScreen extends StatefulWidget {
  const ReadingCheckScreen({super.key, required this.rows, this.fileName, this.bytes});

  final List<ReadRow> rows;
  final String? fileName;
  final Uint8List? bytes;

  @override
  State<ReadingCheckScreen> createState() => _ReadingCheckScreenState();
}

class _ReadingCheckScreenState extends State<ReadingCheckScreen> {
  late final List<_EditRow> _rows = [for (final r in widget.rows) _EditRow(r)];
  bool _allColumns = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<_Col> get _cols => [
        ..._core,
        for (final c in _ledger)
          if (_allColumns || _rows.any((r) => r[c.key].isNotEmpty || _value(r.original, c.key).isNotEmpty)) c,
      ];

  String _label(AppLocalizations l10n, String key) => switch (key) {
        'jan' => l10n.ntFieldJan,
        'name' => l10n.ntFieldName,
        'maker' => l10n.ntFieldMaker,
        'code' => l10n.ntFieldCode,
        'quantity' => l10n.ntFieldQuantity,
        'unit' => l10n.lgUnit,
        'unit_price' => l10n.lgUnitPrice,
        'amount' => l10n.lgAmount,
        'list_price' => l10n.lgListPrice,
        'unit_price_tax' => l10n.lgUnitPriceTax,
        'delivery_date' => l10n.lgDeliveryDate,
        'order_date' => l10n.lgOrderDate,
        'serial' => l10n.lgSerial,
        'order_number' => l10n.lgOrderNumber,
        'supplier' => l10n.lgSupplier,
        _ => key,
      };

  void _add() {
    final next = _rows.fold<int>(0, (m, r) => math.max(m, r.original.lineNo)) + 1;
    setState(() => _rows.add(_EditRow(ReadRow(lineNo: next), added: true)));
  }

  void _done() {
    Navigator.of(context).pop([
      for (final r in _rows)
        if (!(r.added && r.blank)) r.result(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final n = NumberFormat.decimalPattern();
    final live = [for (final r in _rows) if (!r.removed) r];
    final qty = live.fold<double>(0, (s, r) => s + (_num(r['quantity']) ?? 0));
    final amount = live.fold<double>(0, (s, r) => s + (_num(r['amount']) ?? 0));
    final mismatches = live.where((r) => amountMismatch(r['quantity'], r['unit_price'], r['amount'])).length;
    final bytes = widget.bytes;
    final name = widget.fileName;

    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Text(l10n.rcIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton.icon(key: const ValueKey('rc-add'), onPressed: _add, icon: const Icon(Icons.add), label: Text(l10n.rcAdd)),
          FilterChip(
            key: const ValueKey('rc-all-columns'),
            label: Text(l10n.rcAllColumns),
            selected: _allColumns,
            onSelected: (v) => setState(() => _allColumns = v),
          ),
          // What the colours mean.
          _Swatch(key: const ValueKey('rc-key-doubt'), color: doubtColor(context), label: l10n.rcKeyDoubt),
          _Swatch(key: const ValueKey('rc-key-changed'), color: changedColor(context), label: l10n.rcKeyChanged),
        ]),
      ),
      Expanded(child: _Table(rows: _rows, cols: _cols, label: (k) => _label(l10n, k), onChanged: () => setState(() {}))),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(
            l10n.rcTotals(live.length, n.format(qty), n.format(amount)),
            key: const ValueKey('rc-totals'),
            style: theme.textTheme.titleSmall,
          ),
          if (mismatches > 0)
            Text(l10n.rcMismatch(mismatches),
                key: const ValueKey('rc-mismatch'), style: TextStyle(color: theme.colorScheme.error)),
          FilledButton.icon(
            key: const ValueKey('rc-ok'),
            onPressed: _done,
            icon: const Icon(Icons.check),
            label: Text(l10n.rcOk),
          ),
        ]),
      ),
    ]);

    final original = bytes == null || name == null
        ? Center(child: Text(l10n.rcNoFile))
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(child: OriginalFileView(key: const ValueKey('rc-original'), fileName: name, bytes: bytes)),
          ]);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rcTitle)),
      body: LayoutBuilder(builder: (context, c) {
        // On a PC the original and the reading side by side; else in tabs.
        if (c.maxWidth >= 1100) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 4, child: original),
            const VerticalDivider(width: 1),
            Expanded(flex: 6, child: table),
          ]);
        }
        return DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Column(children: [
            TabBar(tabs: [
              Tab(key: const ValueKey('rc-tab-original'), text: l10n.rcOriginal),
              Tab(key: const ValueKey('rc-tab-read'), text: l10n.rcRead),
            ]),
            Expanded(child: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [original, table])),
          ]),
        );
      }),
    );
  }
}

/// A colour and what it means.
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// The rows as a table of fields, scrolled both ways, the heading kept on top.
class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.cols, required this.label, required this.onChanged});

  final List<_EditRow> rows;
  final List<_Col> cols;
  final String Function(String) label;
  final VoidCallback onChanged;

  static const _lead = 92.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = _lead + cols.fold<double>(0, (s, c) => s + c.width + 4);
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(width, c.maxWidth),
          height: c.maxHeight,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              color: scheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: _lead, child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(l10n.rcRow, style: theme.textTheme.labelMedium),
                )),
                for (final col in cols)
                  Container(
                    width: col.width,
                    margin: const EdgeInsets.only(right: 4),
                    child: Text(label(col.key), style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('rc-table'),
                itemCount: rows.length,
                itemBuilder: (context, i) => _RowView(row: rows[i], cols: cols, onChanged: onChanged),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row, required this.cols, required this.onChanged});

  final _EditRow row;
  final List<_Col> cols;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final no = row.original.lineNo;
    final doubts = [for (final f in row.original.flags) if (!_quiet.contains(f) && !humanFlags.contains(f)) flagLabel(l10n, f)];
    final cells = doubtfulCells(row.original);
    final mismatch = amountMismatch(row['quantity'], row['unit_price'], row['amount']);
    final style = theme.textTheme.bodyMedium?.copyWith(
      decoration: row.removed ? TextDecoration.lineThrough : null,
      color: row.removed ? scheme.onSurfaceVariant : null,
    );
    return Container(
      key: ValueKey('rc-row-$no'),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: _Table._lead,
          child: Row(children: [
            IconButton(
              key: ValueKey('rc-remove-$no'),
              visualDensity: VisualDensity.compact,
              tooltip: row.removed ? l10n.rcRestore : l10n.rcRemove,
              icon: Icon(row.removed ? Icons.undo : Icons.remove_circle_outline, size: 18),
              onPressed: () {
                row.removed = !row.removed;
                onChanged();
              },
            ),
            Text(row.added ? '+' : '$no', style: theme.textTheme.labelMedium),
            if (doubts.isNotEmpty)
              Tooltip(
                message: doubts.join('\n'),
                child: Icon(Icons.help_outline, key: ValueKey('rc-doubt-$no'), size: 16, color: scheme.error),
              ),
          ]),
        ),
        for (final col in cols)
          Container(
            width: col.width,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              // To look at: what the reader doubted (until changed), and a
              // quantity or amount that does not add up.
              color: (cells.contains(col.key) && !row.changed(col.key)) ||
                      (mismatch && (col.key == 'quantity' || col.key == 'amount'))
                  ? doubtColor(context)
                  : row.changed(col.key)
                      ? changedColor(context)
                      : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              key: ValueKey('rc-$no-${col.key}'),
              controller: row.cells[col.key],
              enabled: !row.removed,
              style: style,
              textAlign: _numeric.contains(col.key) ? TextAlign.end : TextAlign.start,
              keyboardType: _numeric.contains(col.key) ? const TextInputType.numberWithOptions(decimal: true) : null,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
      ]),
    );
  }
}
