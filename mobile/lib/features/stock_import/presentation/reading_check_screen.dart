import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../jan_catalog/data/jan_catalog_repository.dart';
import '../../product/presentation/product_labels.dart' show gramsText;
import '../../notation/presentation/notation_labels.dart';
import '../domain/stock_file.dart';
import 'import_view_screen.dart' show OriginalFileView;

/// A column of the check table: its key ([ReadRow]'s own five, else a
/// [LedgerFields] key) and how wide it is.
typedef _Col = ({String key, double width});

/// メーカー and 品名 share a column: most invoices print no name, and an
/// empty 品名 column took the most room. A name, when there is one, is shown
/// after the maker in brackets: 三菱鉛筆（ジェットストリーム…）.
const _core = <_Col>[
  (key: 'jan', width: 140),
  (key: 'maker_name', width: 200),
  (key: 'code', width: 140),
  (key: 'quantity', width: 70),
];

/// メーカー（品名） as one text.
String makerAndName(String maker, String name) {
  final m = maker.trim(), n = name.trim();
  if (n.isEmpty) return m;
  return '$m（$n）';
}

/// メーカー（品名） back into its two: what is in brackets at the end is
/// the name (（）or ()), the rest the maker.
(String, String) splitMakerAndName(String text) {
  final t = text.trim();
  final m = RegExp(r'^(.*?)\s*[（(]([^（）()]*)[）)]\s*$').firstMatch(t);
  if (m == null) return (t, '');
  return (m.group(1)!.trim(), m.group(2)!.trim());
}

/// The ledger's columns, in its order; shown when the file had them.
/// 単価 and 金額 first: what a quantity is checked against.
const _ledger = <_Col>[
  (key: 'unit_price', width: 80),
  (key: 'amount', width: 96),
  (key: 'unit', width: 50),
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

/// The JAN checked against the makers' catalogs (0153): not a field of the
/// reading, shown beside the JAN when there is a catalog to ask.
const _catalogCol = (key: 'catalog', width: 150.0);

/// Its weight as it stands (0155): a person's, the catalog's, or the AI's.
const _weightCol = (key: 'weight', width: 140.0);

final _jan13 = RegExp(r'^\d{13}$');

const _numeric = {'quantity', 'unit_price', 'amount', 'list_price', 'unit_price_tax'};

String _value(ReadRow r, String key) => switch (key) {
      'jan' => r.jan,
      'name' => r.name,
      'maker' => r.maker,
      'maker_name' => makerAndName(r.maker, r.name),
      'code' => r.code,
      'quantity' => r.quantity,
      _ => r.ledger[key],
    };

/// Where the reader's doubt about a row points: the cells to look at first.
Set<String> doubtfulCells(ReadRow r) => {
      for (final f in r.flags)
        ...switch (f) {
          'jan_check' || 'no_jan' || 'jan_code_mismatch' || 'jan_restore_mismatch' || 'ai_disagree:raw_jan_code' => {
              'jan'
            },
          'no_quantity' || 'qty_from_amount' || 'qty_from_cases' || 'ai_disagree:planned_quantity' => {'quantity'},
          'ai_disagree:product_name' => {'maker_name'},
          'ai_disagree:product_code' => {'code'},
          'ai_disagree:maker' => {'maker_name'},
          'ai_disagree:unit_price' => {'unit_price'},
          'ai_disagree:amount' => {'amount'},
          'amount_mismatch' => {'quantity', 'amount'},
          'split_disagree' || 'split_failed' => {'maker_name', 'code'},
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
      : removed = original.humanRemoved,
        cells = {
          for (final c in [..._core, ..._ledger]) c.key: TextEditingController(text: _value(original, c.key)),
        };

  final ReadRow original;
  final bool added;
  final Map<String, TextEditingController> cells;
  bool removed;

  String operator [](String key) => cells[key]!.text.trim();

  bool get blank => cells.values.every((c) => c.text.trim().isEmpty);

  /// 金額 as 数量 × 単価, when both are numbers (whole yen kept whole).
  void recalcAmount() {
    final q = _num(this['quantity']), p = _num(this['unit_price']);
    if (q == null || p == null) return;
    final v = (q * p * 100).round() / 100;
    cells['amount']!.text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

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
    final (maker, name) =
        changed('maker_name') ? splitMakerAndName(this['maker_name']) : (original.maker, original.name);
    return original.copyWith(
      jan: this['jan'],
      name: name,
      maker: maker,
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
  const ReadingCheckScreen(
      {super.key,
      required this.rows,
      this.fileName,
      this.bytes,
      this.readOnly = false,
      this.catalogLookup,
      this.weightLookup});

  final List<ReadRow> rows;
  final String? fileName;
  final Uint8List? bytes;

  /// Looked back at from the import's history: the table as it was left,
  /// beside the original, with nothing to change.
  final bool readOnly;

  /// Asks the JAN catalogs about these JANs (see [lookupJans]); none, no
  /// catalog column.
  final Future<Map<String, JanCatalogHit>> Function(List<String> jans)? catalogLookup;

  /// Asks the AI for the weights nothing else gives (see [findWeightsWithAi]);
  /// none (looked back at, or not permitted), only the weights already known.
  final Future<({List<AiWeight> found, bool stopped})> Function(List<WeightAsk> asks)? weightLookup;

  @override
  State<ReadingCheckScreen> createState() => _ReadingCheckScreenState();
}

class _ReadingCheckScreenState extends State<ReadingCheckScreen> {
  late final List<_EditRow> _rows = [for (final r in widget.rows) _EditRow(r)];
  bool _allColumns = false;
  Map<String, JanCatalogHit> _hits = const {};
  final _asked = <String>{};

  /// JANs the AI is looking for, and those it was asked about.
  final _weighing = <String>{};
  final _weighed = <String>{};
  bool _weightStopped = false;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  /// The catalogs asked about each JAN not yet asked: as read, and as typed.
  void _lookup() {
    final ask = widget.catalogLookup;
    if (ask == null) return;
    final jans = {
      for (final r in _rows)
        if (_jan13.hasMatch(r['jan']) && !_asked.contains(r['jan'])) r['jan'],
    }.toList();
    if (jans.isEmpty) return;
    _asked.addAll(jans);
    ask(jans).then((m) {
      if (!mounted || m.isEmpty) return;
      setState(() => _hits = {..._hits, ...m});
      _weigh();
    });
  }

  /// The AI asked for the weights the catalogs and the products do not give.
  void _weigh() {
    final ask = widget.weightLookup;
    if (ask == null || widget.readOnly || _weightStopped) return;
    final asks = <WeightAsk>[];
    for (final r in _rows) {
      final jan = r['jan'];
      final hit = _hits[jan];
      if (hit == null || !hit.needsWeight || _weighed.contains(jan) || r.removed) continue;
      if (asks.any((a) => a.jan == jan)) continue;
      final (maker, name) = splitMakerAndName(r['maker_name']);
      asks.add((
        jan: jan,
        maker: maker.isEmpty ? hit.maker : maker,
        name: name.isEmpty ? (hit.codeHint ?? '') : name,
        code: r['code'].isEmpty ? null : r['code'],
      ));
    }
    if (asks.isEmpty) return;
    setState(() {
      for (final a in asks) {
        _weighed.add(a.jan);
        _weighing.add(a.jan);
      }
    });
    ask(asks).then((r) {
      if (!mounted) return;
      setState(() {
        _weighing.removeAll(asks.map((a) => a.jan));
        _weightStopped = r.stopped;
        final next = {..._hits};
        for (final f in r.found) {
          final h = next[f.jan];
          if (h == null || !h.needsWeight) continue;
          next[f.jan] = h.withWeight(f.weightG,
              source: 'ai', text: f.note, basis: f.basis, url: f.sourceUrl, estimated: f.estimated);
        }
        _hits = next;
      });
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<_Col> get _cols => [
        ..._core.take(1),
        if (widget.catalogLookup != null) ...[_catalogCol, _weightCol],
        ..._core.skip(1),
        for (final c in _ledger)
          if (_allColumns || _rows.any((r) => r[c.key].isNotEmpty || _value(r.original, c.key).isNotEmpty)) c,
      ];

  String _label(AppLocalizations l10n, String key) => switch (key) {
        'jan' => l10n.ntFieldJan,
        'name' => l10n.ntFieldName,
        'maker' => l10n.ntFieldMaker,
        'maker_name' => l10n.rcMakerName,
        'catalog' => l10n.rcCatalog,
        'weight' => l10n.rcWeight,
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
    final live = [
      for (final r in _rows)
        if (!r.removed) r
    ];
    final qty = live.fold<double>(0, (s, r) => s + (_num(r['quantity']) ?? 0));
    final amount = live.fold<double>(0, (s, r) => s + (_num(r['amount']) ?? 0));
    final mismatches = live.where((r) => amountMismatch(r['quantity'], r['unit_price'], r['amount'])).length;
    final notInCatalog = live.where((r) => _hits[r['jan']]?.missing ?? false).length;
    final bytes = widget.bytes;
    final name = widget.fileName;

    final table = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: Text(widget.readOnly ? l10n.rcReadOnlyIntro : l10n.rcIntro,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!widget.readOnly)
            TextButton.icon(
                key: const ValueKey('rc-add'), onPressed: _add, icon: const Icon(Icons.add), label: Text(l10n.rcAdd)),
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
      Expanded(
        child: _Table(
          rows: _rows,
          cols: _cols,
          label: (k) => _label(l10n, k),
          readOnly: widget.readOnly,
          hits: _hits,
          weighing: _weighing,
          weighed: _weighed,
          onChanged: () {
            _lookup();
            setState(() {});
          },
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.rcTotals(live.length, n.format(qty), n.format(amount)),
                key: const ValueKey('rc-totals'),
                style: theme.textTheme.titleSmall,
              ),
              if (mismatches > 0)
                Text(l10n.rcMismatch(mismatches),
                    key: const ValueKey('rc-mismatch'), style: TextStyle(color: theme.colorScheme.error)),
              if (notInCatalog > 0)
                Text(l10n.rcCatalogMissingCount(notInCatalog),
                    key: const ValueKey('rc-catalog-missing'), style: TextStyle(color: theme.colorScheme.error)),
              if (_weightStopped)
                Text(l10n.rcWeightLimit, key: const ValueKey('rc-weight-stopped'), style: theme.textTheme.bodySmall),
              if (!widget.readOnly)
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
      appBar: AppBar(title: Text(widget.readOnly ? l10n.rcReadOnlyTitle : l10n.rcTitle)),
      body: LayoutBuilder(builder: (context, c) {
        // On a PC the original and the reading side by side; else in tabs.
        if (c.maxWidth >= 1100) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: original),
            const VerticalDivider(width: 1),
            Expanded(flex: 7, child: table),
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
class _Table extends StatefulWidget {
  const _Table({
    required this.rows,
    required this.cols,
    required this.label,
    required this.onChanged,
    this.readOnly = false,
    this.hits = const {},
    this.weighing = const {},
    this.weighed = const {},
  });

  final Map<String, JanCatalogHit> hits;
  final Set<String> weighing;
  final Set<String> weighed;
  final List<_EditRow> rows;
  final List<_Col> cols;
  final String Function(String) label;
  final VoidCallback onChanged;
  final bool readOnly;

  static const _lead = 92.0;

  @override
  State<_Table> createState() => _TableState();
}

class _TableState extends State<_Table> {
  /// Sideways, with its bar always shown: on a PC a table wider than its
  /// pane is otherwise not seen to go on (Shift + wheel, or drag the bar).
  final _across = ScrollController();

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = widget.rows, cols = widget.cols, label = widget.label;
    final width = _Table._lead + cols.fold<double>(0, (s, c) => s + c.width + 4);
    return LayoutBuilder(builder: (context, c) {
      return Scrollbar(
        key: const ValueKey('rc-across'),
        controller: _across,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _across,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: math.max(width, c.maxWidth),
            height: math.max(0, c.maxHeight - 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(
                      width: _Table._lead,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(l10n.rcRow, style: theme.textTheme.labelMedium),
                      )),
                  for (final col in cols)
                    Container(
                      width: col.width,
                      margin: const EdgeInsets.only(right: 4),
                      child: Text(label(col.key),
                          style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  key: const ValueKey('rc-table'),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _RowView(
                      row: rows[i],
                      cols: cols,
                      onChanged: widget.onChanged,
                      readOnly: widget.readOnly,
                      hit: widget.hits[rows[i]['jan']],
                      weighing: widget.weighing.contains(rows[i]['jan']),
                      weighed: widget.weighed.contains(rows[i]['jan'])),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.cols,
    required this.onChanged,
    this.readOnly = false,
    this.hit,
    this.weighing = false,
    this.weighed = false,
  });

  final JanCatalogHit? hit;
  final bool weighing;
  final bool weighed;
  final _EditRow row;
  final List<_Col> cols;
  final VoidCallback onChanged;
  final bool readOnly;

  /// Changed by a person: as it is typed, or — looked back at — what the
  /// reader had beside what they wrote.
  bool _changed(String key) {
    if (!readOnly) return row.changed(key);
    final r = row.original;
    return switch (key) {
      'jan' => r.aiJan != null && r.aiJan!.trim() != r.jan.trim(),
      'quantity' => r.aiQuantity != null && r.aiQuantity!.trim() != r.quantity.trim(),
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final no = row.original.lineNo;
    final doubts = [
      for (final f in row.original.flags)
        if (!_quiet.contains(f) && !humanFlags.contains(f)) flagLabel(l10n, f)
    ];
    // Once a person checked it, the reader's doubts are answered.
    final cells = readOnly && row.original.humanChecked ? const <String>{} : doubtfulCells(row.original);
    final mismatch = amountMismatch(row['quantity'], row['unit_price'], row['amount']);
    // A JAN its maker's catalog does not list: the JAN to look at.
    final notListed = hit?.missing ?? false;
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
            if (readOnly)
              const SizedBox(width: 40)
            else
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
          if (col.key == 'catalog')
            Container(
              width: col.width,
              margin: const EdgeInsets.only(right: 4),
              child: _CatalogCell(key: ValueKey('rc-$no-catalog'), hit: _jan13.hasMatch(row['jan']) ? hit : null),
            )
          else if (col.key == 'weight')
            Container(
              width: col.width,
              margin: const EdgeInsets.only(right: 4),
              child: _WeightCell(
                key: ValueKey('rc-$no-weight'),
                hit: _jan13.hasMatch(row['jan']) ? hit : null,
                looking: weighing,
                askedAi: weighed,
              ),
            )
          else
            Container(
              width: col.width,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                // To look at: what the reader doubted (until changed), a
                // quantity or amount that does not add up, and a JAN the
                // maker's catalog does not list.
                color: (cells.contains(col.key) && !_changed(col.key)) ||
                        (mismatch && (col.key == 'quantity' || col.key == 'amount')) ||
                        (notListed && col.key == 'jan')
                    ? doubtColor(context)
                    : _changed(col.key)
                        ? changedColor(context)
                        : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                key: ValueKey('rc-$no-${col.key}'),
                controller: row.cells[col.key],
                enabled: !row.removed,
                readOnly: readOnly,
                style: style,
                textAlign: _numeric.contains(col.key) ? TextAlign.end : TextAlign.start,
                keyboardType: _numeric.contains(col.key) ? const TextInputType.numberWithOptions(decimal: true) : null,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                onChanged: (_) {
                  // 金額 follows 数量 × 単価, whichever of the two is changed.
                  if (col.key == 'quantity' || col.key == 'unit_price') row.recalcAmount();
                  onChanged();
                },
              ),
            ),
      ]),
    );
  }
}

/// What the catalogs say of a row's JAN: listed (the page and what is
/// printed beside it, a click opens that page), not listed though its
/// maker's catalog is here, or nothing to say.
class _CatalogCell extends StatelessWidget {
  const _CatalogCell({super.key, this.hit});

  final JanCatalogHit? hit;

  void _open(BuildContext context, String url) {
    if (openExternalUrl(url)) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).rcCatalogCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    final h = hit;
    if (h == null) return const SizedBox.shrink();
    if (h.found) {
      final page = h.pageNumber == null ? '' : l10n.rcCatalogPage(h.pageNumber!);
      final text = [page, if ((h.codeHint ?? '').isNotEmpty) h.codeHint!].join(' ');
      final url = h.pageUrl;
      return Tooltip(
        message: l10n.rcCatalogFoundHint(h.catalogName ?? h.maker ?? '', page, h.lineText ?? ''),
        child: InkWell(
          onTap: url == null ? null : () => _open(context, url),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(children: [
              Icon(Icons.menu_book_outlined, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(text,
                    style: small?.copyWith(color: scheme.primary, decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      );
    }
    if (h.missing) {
      return Tooltip(
        message: l10n.rcCatalogMissingHint(h.maker ?? ''),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(color: doubtColor(context), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Icon(Icons.warning_amber_outlined, size: 16, color: scheme.error),
            const SizedBox(width: 4),
            Expanded(
              child: Text(l10n.rcCatalogMissing,
                  style: small?.copyWith(color: scheme.error), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }
    return Tooltip(
      message: l10n.rcCatalogNone,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text('—', style: small?.copyWith(color: scheme.onSurfaceVariant)),
      ),
    );
  }
}

/// A row's weight: from the product (a person's), the catalog, or the AI —
/// said which, the AI's in its own colour; while the AI looks, that.
class _WeightCell extends StatelessWidget {
  const _WeightCell({super.key, this.hit, this.looking = false, this.askedAi = false});

  final JanCatalogHit? hit;
  final bool looking;
  final bool askedAi;

  void _open(BuildContext context, String url) {
    if (openExternalUrl(url)) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).rcCatalogCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    final h = hit;
    const pad = EdgeInsets.symmetric(horizontal: 6, vertical: 8);
    if (h == null) return const SizedBox.shrink();
    if (h.weightG == null) {
      if (looking) {
        return Padding(
          padding: pad,
          child: Row(children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 6),
            Expanded(child: Text(l10n.rcWeightLooking, style: small, overflow: TextOverflow.ellipsis)),
          ]),
        );
      }
      return Padding(
        padding: pad,
        child: Text(askedAi ? l10n.rcWeightNone : '—', style: small?.copyWith(color: scheme.onSurfaceVariant)),
      );
    }
    final basis = switch (h.weightBasis) {
      'package' => l10n.rcWeightBasisPackage,
      'pack' => l10n.rcWeightBasisPack,
      _ => l10n.rcWeightBasisProduct,
    };
    final (tag, tip, color) = switch (h.weightSource) {
      'catalog' => (l10n.rcWeightCatalog, l10n.rcWeightCatalogHint(h.weightText ?? '', basis), Colors.green.shade600),
      'ai' => (
          h.weightEstimated ? l10n.rcWeightEstimate : l10n.rcWeightAi,
          l10n.rcWeightAiHint(h.weightUrl ?? ''),
          Colors.deepPurple.shade300
        ),
      _ => (l10n.rcWeightProduct, l10n.rcWeightProductHint, scheme.primary),
    };
    final url = h.weightUrl;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: url == null || !url.startsWith('http') ? null : () => _open(context, url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: pad,
          child: Row(children: [
            Text(gramsText(h.weightG!), style: theme.textTheme.bodyMedium),
            const SizedBox(width: 4),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(4)),
                child: Text(tag,
                    style: small?.copyWith(color: color, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
