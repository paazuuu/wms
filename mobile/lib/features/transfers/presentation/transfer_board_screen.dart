import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound_file/data/outbound_file_repository.dart' show outboundFileRepositoryProvider;
import '../../outbound_file/domain/outbound_sheet.dart' show parseOutboundSheet, pickOutboundSheet;
import '../../product/domain/product.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../stock_import/domain/ai_read_sheet.dart';
import '../../stock_import/domain/stock_file.dart' show readStockFile;
import '../../stock_ops/presentation/stock_adjustment_screen.dart'
    show adjustOnHand, adjustProductMatches, adjustProductsProvider;
import '../../warehouse_context/domain/warehouse.dart';
import '../../warehouse_context/domain/warehouse_role.dart';
import '../../warehouse_context/presentation/warehouse_overview_screen.dart' show countryLabel;
import '../application/transfer_providers.dart';
import '../data/transfer_repository.dart';
import 'transfer_detail_screen.dart';

/// The file read for a transfer (overridden in tests).
final transferFilePickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((_) => () async {
      final r = await FilePicker.platform
          .pickFiles(withData: true, type: FileType.custom, allowedExtensions: const [
            'xlsx', 'xlsm', 'csv', 'tsv', 'txt', 'pdf', 'png', 'jpg', 'jpeg', 'webp',
          ]);
      final f = r?.files.firstOrNull;
      return f?.bytes == null ? null : (name: f!.name, bytes: f.bytes!);
    });

/// One product to move: what it is, how many, and what the source holds.
class BoardLine {
  const BoardLine({required this.jan, required this.name, required this.quantity, this.maker, this.available});

  final String jan;
  final String name;
  final String? maker;
  final int quantity;

  /// On hand at the source when it was added (null: not known).
  final int? available;

  BoardLine withQuantity(int q) => BoardLine(jan: jan, name: name, maker: maker, quantity: q, available: available);

  bool get over => available != null && quantity > available!;
}

/// 移動を作成: the warehouse it leaves (出庫する倉庫) on one side with what it
/// holds, the one it goes to (入庫する倉庫) on the other; a product dragged
/// across — or sent with its arrow — is to be moved. A file (a shipping list:
/// JAN or 品番 and 数量) fills the right side at once. Made, it is a transfer
/// like any other: picked at the source, received at the destination.
class TransferBoardScreen extends ConsumerStatefulWidget {
  const TransferBoardScreen({super.key, required this.warehouses, this.roles = const {}, this.initialSourceId});

  final List<Warehouse> warehouses;
  final Map<int, WarehouseRole> roles;
  final int? initialSourceId;

  @override
  ConsumerState<TransferBoardScreen> createState() => _TransferBoardScreenState();
}

class _TransferBoardScreenState extends ConsumerState<TransferBoardScreen> {
  late int _sourceId = widget.initialSourceId != null && widget.warehouses.any((w) => w.id == widget.initialSourceId)
      ? widget.initialSourceId!
      : widget.warehouses.first.id;
  late int _destinationId = widget.warehouses.firstWhere((w) => w.id != _sourceId, orElse: () => widget.warehouses.first).id;
  final _search = TextEditingController();
  final _note = TextEditingController();
  final List<BoardLine> _lines = [];
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String t, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t), backgroundColor: danger ? Theme.of(context).colorScheme.error : null));
  }

  String _label(AppLocalizations l10n, Warehouse w) {
    final role = widget.roles[w.id];
    return role == null ? w.name : '${w.name}（${countryLabel(l10n, role.countryCode)}）';
  }

  String? _crossBorderNote(AppLocalizations l10n) {
    final from = widget.roles[_sourceId];
    final to = widget.roles[_destinationId];
    if (from == null || to == null || from.countryCode == to.countryCode) return null;
    return to.receivesCrossBorder
        ? l10n.transferCrossBorderReceived(countryLabel(l10n, to.countryCode))
        : l10n.transferCrossBorderExport(countryLabel(l10n, to.countryCode));
  }

  /// [p] put on the right side: how many asked (all it holds offered).
  Future<void> _add(Product p) async {
    final available = adjustOnHand(p, _sourceId);
    final existing = _lines.indexWhere((l) => l.jan == p.janCode);
    final q = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(
        name: p.name,
        available: available,
        initial: existing >= 0 ? _lines[existing].quantity : (available > 0 ? available : 1),
      ),
    );
    if (q == null || q <= 0 || !mounted) return;
    setState(() {
      final line = BoardLine(jan: p.janCode, name: p.name, maker: p.maker, quantity: q, available: available);
      if (existing >= 0) {
        _lines[existing] = line;
      } else {
        _lines.add(line);
      }
    });
  }

  Future<void> _edit(int i) async {
    final l = _lines[i];
    final q = await showDialog<int>(
      context: context,
      builder: (_) => _QuantityDialog(name: l.name, available: l.available, initial: l.quantity),
    );
    if (q == null || !mounted) return;
    setState(() {
      if (q <= 0) {
        _lines.removeAt(i);
      } else {
        _lines[i] = l.withQuantity(q);
      }
    });
  }

  /// A shipping list read: each row's JAN (or 品番) found in the library and
  /// put on the right with its 数量; what is not found is said.
  Future<void> _readFile(List<Product> library) async {
    final l10n = AppLocalizations.of(context);
    final file = await ref.read(transferFilePickerProvider)();
    if (file == null || !mounted) return;
    final List<({String jan, String? code, String? maker, int quantity})> rows;
    // A PDF or a photo: the AI reads its rows (nothing booked).
    List<XlsxSheetRows>? read;
    if (!readsAsSheet(file.name)) {
      setState(() => _busy = true);
      final r = await ref.read(masterImportRepositoryProvider).read(file.name, file.bytes, keepRows: true);
      if (!mounted) return;
      setState(() => _busy = false);
      switch (r) {
        case ApiSuccess(:final data):
          read = [aiReadAsSheet(data.lines)];
        case ApiFailure(:final message):
          _snack(l10n.rdAiFailed(humanizeApiErrorMessage(l10n, message)), danger: true);
          return;
      }
    }
    try {
      final lower = file.name.toLowerCase();
      final sheets = read ??
          (lower.endsWith('.xlsx') || lower.endsWith('.xlsm')
              ? readXlsxSheets(file.bytes)
              : [(name: file.name, rows: readStockFile(file.name, file.bytes))]);
      final s = sheets[pickOutboundSheet(sheets)];
      rows = [
        for (final r in parseOutboundSheet(s.name, s.rows).rows)
          if ((r.quantity ?? 0) > 0 && (r.jan.isNotEmpty || r.code != null))
            (jan: r.jan, code: r.code, maker: r.maker, quantity: r.quantity!),
      ];
    } catch (e) {
      _snack(l10n.tbFileFailed('$e'), danger: true);
      return;
    }
    if (rows.isEmpty) {
      _snack(l10n.tbFileEmpty, danger: true);
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(outboundFileRepositoryProvider).match([
      for (final row in rows) {'jan': row.jan.isEmpty ? null : row.jan, 'code': row.code, 'maker': row.maker},
    ], _sourceId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message), danger: true);
        return;
      case ApiSuccess(:final data):
        final byJan = {for (final p in library) p.janCode: p};
        final missing = <String>[];
        var added = 0;
        setState(() {
          for (final (i, row) in rows.indexed) {
            final m = i < data.length ? data[i] : null;
            final jan = m?.productId != null ? (m!.jan ?? row.jan) : (byJan.containsKey(row.jan) ? row.jan : '');
            if (jan.isEmpty) {
              missing.add(row.jan.isNotEmpty ? row.jan : (row.code ?? '?'));
              continue;
            }
            final p = byJan[jan];
            final at = _lines.indexWhere((l) => l.jan == jan);
            if (at >= 0) {
              _lines[at] = _lines[at].withQuantity(_lines[at].quantity + row.quantity);
            } else {
              _lines.add(BoardLine(
                jan: jan,
                name: p?.name ?? m?.name ?? jan,
                maker: p?.maker ?? m?.maker,
                quantity: row.quantity,
                available: p == null ? null : adjustOnHand(p, _sourceId),
              ));
            }
            added++;
          }
        });
        _snack(missing.isEmpty ? l10n.tbFileRead(added) : l10n.tbFileReadMissing(added, missing.length, missing.take(5).join(', ')),
            danger: missing.isNotEmpty);
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    if (_sourceId == _destinationId) {
      _snack(l10n.transferNeedsTwoWarehouses, danger: true);
      return;
    }
    if (_lines.isEmpty) {
      _snack(l10n.transferLineRequired, danger: true);
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(transferRepositoryProvider).create(
          sourceWarehouseId: _sourceId,
          destinationWarehouseId: _destinationId,
          lines: [for (final l in _lines) TransferLineDraft(janCode: l.jan, quantity: l.quantity, productName: l.name)],
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (order) {
        ref.invalidate(transferListProvider);
        _snack(l10n.transferCreated(order.transferNumber ?? '#${order.id}'));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TransferDetailScreen(transferId: order.id)));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = ref.watch(adjustProductsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    Widget warehouseField(String key, String label, int value, ValueChanged<int> onChanged, IconData icon) =>
        DropdownButtonFormField<int>(
          key: ValueKey(key),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), isDense: true),
          items: [for (final w in widget.warehouses) DropdownMenuItem(value: w.id, child: Text(_label(l10n, w)))],
          onChanged: (v) => v == null ? null : onChanged(v),
        );

    final header = Row(children: [
      Expanded(
        child: warehouseField('tb-source', l10n.tbSource, _sourceId, (v) => setState(() {
              _sourceId = v;
              _lines.clear();
            }), Icons.outbox_outlined),
      ),
      IconButton(
        key: const ValueKey('tb-swap'),
        tooltip: l10n.tbSwap,
        icon: const Icon(Icons.swap_horiz),
        onPressed: () => setState(() {
          final s = _sourceId;
          _sourceId = _destinationId;
          _destinationId = s;
          _lines.clear();
        }),
      ),
      Expanded(
        child: warehouseField('tb-destination', l10n.tbDestination, _destinationId, (v) => setState(() => _destinationId = v),
            Icons.move_to_inbox_outlined),
      ),
    ]);

    final source = library.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(adjustProductsProvider)),
      data: (all) {
        final shown = [
          for (final p in all)
            if (adjustOnHand(p, _sourceId) > 0 && adjustProductMatches(p, _search.text)) p,
        ].take(200).toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TextField(
              key: const ValueKey('tb-search'),
              controller: _search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.tbSearch, isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(l10n.tbSourceEmpty, textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final p = shown[i];
                      final picked = _lines.any((l) => l.jan == p.janCode);
                      final tile = ListTile(
                        key: ValueKey('tb-src-${p.janCode}'),
                        dense: true,
                        leading: const Icon(Icons.drag_indicator),
                        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([p.maker ?? '', p.janCode, if (p.sku != null) p.sku!].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(l10n.tbOnHand(adjustOnHand(p, _sourceId)), style: theme.textTheme.labelMedium),
                          IconButton(
                            key: ValueKey('tb-add-${p.janCode}'),
                            tooltip: l10n.tbMoveThis,
                            icon: Icon(picked ? Icons.check_circle : Icons.arrow_forward,
                                color: picked ? theme.colorScheme.primary : null),
                            onPressed: () => _add(p),
                          ),
                        ]),
                      );
                      return Draggable<Product>(
                        data: p,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text('${p.name}  ×${adjustOnHand(p, _sourceId)}'),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.4, child: tile),
                        child: tile,
                      );
                    },
                  ),
          ),
        ]);
      },
    );

    final destination = DragTarget<Product>(
      onAcceptWithDetails: (d) => _add(d.data),
      builder: (context, candidates, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        key: const ValueKey('tb-drop'),
        decoration: BoxDecoration(
          // Highlighted while a product is held over it.
          color: candidates.isNotEmpty ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _lines.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.move_down, size: 40, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.tbDropHere, textAlign: TextAlign.center),
                  ]),
                ),
              )
            : ListView(children: [
                for (final (i, l) in _lines.indexed)
                  ListTile(
                    key: ValueKey('tb-line-${l.jan}'),
                    dense: true,
                    title: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [l.maker ?? '', l.jan, if (l.over) l10n.tbOver(l.available!)].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: l.over ? theme.colorScheme.error : null),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        key: ValueKey('tb-qty-${l.jan}'),
                        onPressed: () => _edit(i),
                        child: Text('× ${l.quantity}', style: theme.textTheme.titleMedium),
                      ),
                      IconButton(
                        key: ValueKey('tb-remove-${l.jan}'),
                        tooltip: l10n.tbRemove,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _lines.removeAt(i)),
                      ),
                    ]),
                  ),
              ]),
      ),
    );

    Widget panel(String title, IconData icon, Widget child, {Widget? action}) => Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              color: theme.colorScheme.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(children: [
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (action != null) action,
              ]),
            ),
            Expanded(child: child),
          ]),
        );

    final name = {for (final w in widget.warehouses) w.id: w.name};
    final left = panel(l10n.tbSourcePanel(name[_sourceId] ?? ''), Icons.outbox_outlined, source);
    final right = panel(
      l10n.tbDestinationPanel(name[_destinationId] ?? '', _lines.length, _lines.fold(0, (a, l) => a + l.quantity)),
      Icons.move_to_inbox_outlined,
      destination,
      action: TextButton.icon(
        key: const ValueKey('tb-file'),
        onPressed: _busy ? null : () => _readFile(library.valueOrNull ?? const []),
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: Text(l10n.tbFile),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferNew)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          if (_crossBorderNote(l10n) case final note?)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(children: [const Icon(Icons.public), const SizedBox(width: AppSpacing.sm), Expanded(child: Text(note))]),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.tbHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: left),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Center(child: Icon(Icons.double_arrow, color: theme.colorScheme.primary)),
                    ),
                    Expanded(child: right),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: left),
                    Center(child: Icon(Icons.keyboard_double_arrow_down, color: theme.colorScheme.primary)),
                    Expanded(child: right),
                  ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('tb-note'),
                controller: _note,
                decoration: InputDecoration(labelText: l10n.transferNote, isDense: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.icon(
              key: const ValueKey('tb-create'),
              onPressed: _busy || _lines.isEmpty ? null : _create,
              icon: const Icon(Icons.compare_arrows),
              label: Text(l10n.transferCreate),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.name, required this.initial, this.available});

  final String name;
  final int initial;
  final int? available;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _c = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = int.tryParse(_c.text.trim());
    final over = q != null && widget.available != null && q > widget.available!;
    return AlertDialog(
      key: const ValueKey('tb-qty-dialog'),
      title: Text(widget.name),
      content: TextField(
        key: const ValueKey('tb-qty-field'),
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.transferLineQuantity,
          helperText: widget.available == null ? null : l10n.tbOnHand(widget.available!),
          errorText: over ? l10n.tbOver(widget.available!) : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => Navigator.pop(context, int.tryParse(_c.text.trim())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('tb-qty-ok'),
          onPressed: q == null ? null : () => Navigator.pop(context, int.tryParse(_c.text.trim())),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
