import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/xlsx.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../product/application/product_providers.dart';
import '../../product_library/data/english_name_suggester.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/master_import_repository.dart';
import '../domain/master_import.dart';
import 'master_import_labels.dart';

enum _Phase { pick, working, stopped, manual, stock, done }

/// ファイルから商品・在庫登録 (0138): one file, chosen once, goes into
/// ①商品マスタ — the supplier's name, the English name and the rest, by JAN —
/// and then ②the stock in 商品ライブラリー, added to what is there.
///
/// Anything that makes the reading doubtful stops the file before a single
/// product is written, and offers the other ways on: go through the lines by
/// hand, or turn the reading into an Excel sheet, check it, and choose that
/// sheet instead. The original file and every sheet are kept with the import.
class MasterImportScreen extends ConsumerStatefulWidget {
  const MasterImportScreen({super.key, this.pickFile, this.saveFile, this.resumeImportId});

  /// For tests: what choosing a file gives.
  final Future<PlatformFile?> Function()? pickFile;

  /// For tests: where a download goes.
  final SaveBytes? saveFile;

  /// Opens an import whose 商品マスタ stage is done at its stock stage.
  final int? resumeImportId;

  @override
  ConsumerState<MasterImportScreen> createState() => _MasterImportScreenState();
}

class _MasterImportScreenState extends ConsumerState<MasterImportScreen> {
  _Phase _phase = _Phase.pick;
  String _working = '';
  PlatformFile? _file;
  int? _importId;
  List<MasterLine> _lines = const [];
  List<MasterProblem> _problems = const [];

  /// True once a person has gone through the lines (by hand or in Excel):
  /// the reader's own doubts no longer stop the file.
  bool _checked = false;
  MasterRead? _read;
  final Map<String, MasterImportFile> _files = {};
  bool _converted = false;
  MasterCommitResult? _commit;

  // Stage 2.
  int? _warehouseId;
  MasterImport? _detail;
  final Map<int, TextEditingController> _qty = {};
  final Map<int, TextEditingController> _fix = {};

  MasterImportRepository get _repo => ref.read(masterImportRepositoryProvider);

  @override
  void initState() {
    super.initState();
    if (widget.resumeImportId != null) {
      _importId = widget.resumeImportId;
      _phase = _Phase.working;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadStock());
    }
  }

  @override
  void dispose() {
    for (final c in [..._qty.values, ..._fix.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  static String _type(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.xlsx') || n.endsWith('.xlsm')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (n.endsWith('.csv')) return 'text/csv';
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<PlatformFile?> _choose({bool excelOnly = false}) async {
    if (widget.pickFile != null) return widget.pickFile!();
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: excelOnly
          ? const ['xlsx', 'xlsm']
          : const ['xlsx', 'xlsm', 'xls', 'csv', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    return r?.files.firstOrNull;
  }

  Future<void> _keep(String kind, String name, Uint8List bytes) async {
    final id = _importId;
    if (id == null) return;
    final r = await _repo.keepFile(id, kind, name, bytes, _type(name));
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _files[kind] = MasterImportFile(kind: kind, name: name, path: data));
      case ApiFailure():
        _snack(AppLocalizations.of(context).miUploadFailed);
    }
  }

  /// A sheet of ours (or any .xlsx with a JAN column) is read here, as the
  /// person left it; anything else goes to the reader.
  static List<MasterLine>? _ownSheet(PlatformFile f) {
    final n = f.name.toLowerCase();
    if (!(n.endsWith('.xlsx') || n.endsWith('.xlsm')) || f.bytes == null) return null;
    try {
      final table = readXlsx(f.bytes!);
      final header = table.take(20).expand((r) => r).map((c) => c.trim()).toSet();
      if (!header.contains('仕入先の商品名') && !header.contains('英語の商品名')) return null;
      return MasterSheet.parse(table);
    } on FormatException {
      return null;
    }
  }

  // ------------------------------------------------------------ stage 1

  Future<void> _pickAndRun() async {
    final f = await _choose();
    if (f == null || f.bytes == null || !mounted) return;
    setState(() {
      _file = f;
      _importId = null;
      _files.clear();
      _converted = false;
      _checked = false;
      _commit = null;
    });
    await _run();
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    final f = _file;
    if (f == null || f.bytes == null) return;
    setState(() {
      _phase = _Phase.working;
      _working = l10n.miReading;
    });
    if (_importId == null) {
      final started = await _repo.start(fileName: f.name, contentType: _type(f.name));
      if (!mounted) return;
      switch (started) {
        case ApiSuccess(:final data):
          _importId = data;
        case ApiFailure(:final message):
          setState(() => _phase = _Phase.pick);
          return _snack(humanizeApiErrorMessage(l10n, message));
      }
      await _keep('original', f.name, f.bytes!);
      if (!mounted) return;
    }

    final own = _ownSheet(f);
    if (own != null) {
      _read = null;
      return _settle(own, checked: true);
    }
    final r = await _repo.read(f.name, f.bytes!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        _read = data;
        await _settle(data.lines, checked: false);
      case ApiFailure(:final message):
        _read = null;
        _lines = const [];
        await _stop([
          MasterProblem('read_failed',
              value: message.contains('No JAN rows') ? l10n.miPbNoLines : humanizeApiErrorMessage(l10n, message)),
        ]);
    }
  }

  /// Checks [lines]; stops on any problem that would make them doubtful,
  /// registers them otherwise.
  Future<void> _settle(List<MasterLine> lines, {required bool checked}) async {
    _lines = lines;
    _checked = checked;
    final problems = checkMasterLines(lines,
        checked: checked, verified: _read?.verified ?? true, totalsOk: _read?.totalsOk, aiFailure: _read?.aiFailure);
    if (problems.any((p) => p.blocking)) return _stop(problems);
    _problems = problems;
    await _register();
  }

  Future<void> _stop(List<MasterProblem> problems) async {
    setState(() {
      _problems = problems;
      _phase = _Phase.stopped;
    });
    final id = _importId;
    if (id != null) await _repo.stop(id, problems, _lines.length);
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final id = _importId;
    if (id == null) return;
    setState(() {
      _phase = _Phase.working;
      _working = l10n.miRegistering;
    });
    await _suggestEnglish(quiet: true);
    if (!mounted) return;
    final r = await _repo.commit(id, _lines, supplierId: _read?.supplierId);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data) when data.ok:
        _commit = data;
        ref.invalidate(productListProvider);
        _snack(l10n.miMasterDone(data.created, data.updated, data.mapped));
        await _loadStock();
      case ApiSuccess(:final data):
        setState(() {
          _problems = data.problems;
          _phase = _Phase.stopped;
        });
      case ApiFailure(:final message):
        setState(() => _phase = _checked ? _Phase.manual : _Phase.stopped);
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  /// English names for the new products that have none, from the AI. Only
  /// fills empty fields; when the AI cannot answer the names stay empty.
  Future<void> _suggestEnglish({bool quiet = false}) async {
    final asked = [
      for (final (i, l) in _lines.indexed)
        if (l.nameEn.trim().isEmpty && l.knownProductId == null && l.supplierName.trim().isNotEmpty)
          NameRequest(
            index: i,
            supplierName: l.supplierName,
            maker: l.maker.isEmpty ? null : l.maker,
            code: l.productCode.isEmpty ? null : l.productCode,
            spec: l.spec.isEmpty ? null : l.spec,
            supplier: _read?.supplierName,
          ),
    ];
    if (asked.isEmpty) return;
    final r = await ref.read(englishNameSuggesterProvider).suggest(asked);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _lines = [
              for (final (i, l) in _lines.indexed)
                data[i] != null && l.nameEn.trim().isEmpty ? l.copyWith(nameEn: data[i]) : l,
            ]);
        if (!quiet) _snack(AppLocalizations.of(context).rpEnglishSuggested(data.length));
      case ApiFailure(:final message):
        if (!quiet) _snack(humanizeApiErrorMessage(AppLocalizations.of(context), message));
    }
  }

  // ------------------------------------------------------------ other ways

  void _manual() => setState(() {
        _phase = _Phase.manual;
        _problems = checkMasterLines(_lines, checked: true);
      });

  Future<void> _registerChecked() async {
    final problems = checkMasterLines(_lines, checked: true);
    setState(() {
      _problems = problems;
      _checked = true;
    });
    if (problems.any((p) => p.blocking)) {
      _snack(AppLocalizations.of(context).miProblemsCount(problems.where((p) => p.blocking).length));
      return;
    }
    await _register();
  }

  Future<void> _toExcel() async {
    final l10n = AppLocalizations.of(context);
    final (rows, flagged) = MasterSheet.rows(_lines, _problems, (p) => masterProblemText(l10n, p));
    final bytes = buildXlsx(
      sheetName: l10n.miSheetName,
      headers: MasterSheet.headers,
      rows: rows,
      flagged: flagged,
      widths: MasterSheet.widths,
    );
    final base = (_file?.name ?? 'import').replaceFirst(RegExp(r'\.[^.]+$'), '');
    final name = _lines.isEmpty ? '${base}_記入用.xlsx' : '${base}_確認用.xlsx';
    await _keep('converted', name, bytes);
    await (widget.saveFile ?? saveBytesWithPicker)(name, bytes);
    if (!mounted) return;
    setState(() => _converted = true);
    _snack(l10n.miExcelSaved);
  }

  Future<void> _pickCorrected() async {
    final l10n = AppLocalizations.of(context);
    final f = await _choose(excelOnly: true);
    if (f == null || f.bytes == null || !mounted) return;
    List<MasterLine> lines;
    try {
      lines = MasterSheet.parse(readXlsx(f.bytes!));
    } on FormatException {
      return _snack(l10n.miNotOurSheet);
    }
    await _keep('corrected', f.name, f.bytes!);
    if (!mounted) return;
    await _settle(lines, checked: true);
  }

  Future<void> _cancel() async {
    final id = _importId;
    if (id != null) await _repo.cancel(id);
    if (mounted) Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------ stage 2

  Future<void> _loadStock() async {
    final id = _importId;
    if (id == null) return;
    final wh = _warehouseId ?? ref.read(writeWarehouseIdProvider);
    final r = await _repo.detail(id, warehouseId: wh);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _warehouseId = wh;
          _detail = data;
          for (final l in data.lines) {
            _qty.putIfAbsent(l.lineNo, () => TextEditingController(text: '${l.quantity}'));
            _fix.putIfAbsent(l.lineNo, TextEditingController.new);
          }
          for (final f in data.files) {
            _files[f.kind] = f;
          }
          _phase = data.status == MasterImportStatus.stockDone ? _Phase.done : _Phase.stock;
        });
      case ApiFailure(:final message):
        setState(() => _phase = _Phase.pick);
        _snack(humanizeApiErrorMessage(AppLocalizations.of(context), message));
    }
  }

  static int? _int(String s) {
    final t = s.replaceAll(',', '').trim();
    return RegExp(r'^\d+$').hasMatch(t) ? int.parse(t) : null;
  }

  Future<void> _applyStock() async {
    final l10n = AppLocalizations.of(context);
    final id = _importId;
    final wh = _warehouseId;
    final detail = _detail;
    if (id == null || detail == null) return;
    if (wh == null) return _snack(l10n.miChooseWarehouse);
    final lines = <Map<String, dynamic>>[];
    for (final l in detail.lines) {
      final q = _int(_qty[l.lineNo]?.text ?? '');
      final fixText = _fix[l.lineNo]?.text.trim() ?? '';
      final fix = fixText.isEmpty ? null : _int(fixText);
      if (q == null || (fixText.isNotEmpty && fix == null)) {
        return _snack('${l10n.miLine(l.lineNo)}: ${l10n.miPbQtyInvalid(q == null ? _qty[l.lineNo]?.text ?? '' : fixText)}');
      }
      lines.add({'line_no': l.lineNo, 'quantity': q, if (fix != null) 'on_hand_set': fix});
    }
    setState(() {
      _phase = _Phase.working;
      _working = l10n.miApplying;
    });
    final r = await _repo.applyStock(id, wh, lines);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        _snack(l10n.miStockDone(detail.lines.length, data));
        ref.invalidate(productListProvider);
        await _loadStock();
      case ApiFailure(:final message):
        setState(() => _phase = _Phase.stock);
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final step = _detail != null ? 2 : (_phase == _Phase.pick ? 0 : 1);
    final children = <Widget>[
      _Steps(current: step, done: _phase == _Phase.done),
      const SizedBox(height: AppSpacing.md),
    ];
    switch (_phase) {
      case _Phase.pick:
        children.addAll([
          Text(l10n.miIntro, key: const ValueKey('mi-intro'), style: muted),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('mi-pick'),
            onPressed: _pickAndRun,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.miPick),
          ),
        ]);
      case _Phase.working:
        children.addAll([
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.sm),
          Text(_working, key: const ValueKey('mi-working')),
        ]);
      case _Phase.stopped:
        children.addAll(_stoppedView(l10n, theme));
      case _Phase.manual:
        children.addAll(_manualView(l10n, theme));
      case _Phase.stock:
        children.addAll(_stockView(l10n, theme));
      case _Phase.done:
        children.addAll(_doneView(l10n, theme));
    }
    if (_files.isNotEmpty && _phase != _Phase.pick && _phase != _Phase.working) {
      children.addAll([
        const SizedBox(height: AppSpacing.lg),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          for (final k in const ['original', 'converted', 'corrected'])
            if (_files[k] case final f?)
              OutlinedButton.icon(
                key: ValueKey('mi-download-$k'),
                onPressed: () => downloadMasterFile(context, ref, f, save: widget.saveFile),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(masterFileLabel(l10n, f)),
              ),
        ]),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.miTitle)),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: children),
    );
  }

  Widget _problemList(AppLocalizations l10n, ThemeData theme, {bool blockingOnly = false}) {
    final shown = [for (final p in _problems) if (!blockingOnly || p.blocking) p];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final p in shown.take(50))
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(p.blocking ? Icons.error_outline : Icons.info_outline,
                size: 16, color: p.blocking ? theme.colorScheme.error : theme.colorScheme.tertiary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text('${masterProblemWhere(l10n, p)}: ${masterProblemText(l10n, p)}',
                  style: theme.textTheme.bodySmall),
            ),
          ]),
        ),
      if (shown.length > 50) Text('…', style: theme.textTheme.bodySmall),
    ]);
  }

  List<Widget> _stoppedView(AppLocalizations l10n, ThemeData theme) {
    final blocking = _problems.where((p) => p.blocking).length;
    final readFailed = _problems.any((p) => p.code == 'read_failed');
    Widget way({required Key key, required IconData icon, required String title, required String body, required VoidCallback onTap}) =>
        Card(
          child: ListTile(
            key: key,
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(body),
            onTap: onTap,
          ),
        );
    return [
      Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.miStoppedTitle,
                key: const ValueKey('mi-stopped'),
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.miStoppedBody, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.miProblemsCount(blocking), style: theme.textTheme.titleSmall),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      _problemList(l10n, theme),
      const SizedBox(height: AppSpacing.md),
      way(
        key: const ValueKey('mi-way-manual'),
        icon: Icons.edit_note_outlined,
        title: l10n.miWayManual,
        body: l10n.miWayManualDesc,
        onTap: _manual,
      ),
      way(
        key: const ValueKey('mi-way-excel'),
        icon: Icons.grid_on_outlined,
        title: _lines.isEmpty ? l10n.miWayTemplate : l10n.miWayExcel,
        body: _lines.isEmpty ? l10n.miWayTemplateDesc : l10n.miWayExcelDesc,
        onTap: _toExcel,
      ),
      if (_converted || _files.containsKey('converted'))
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: FilledButton.icon(
            key: const ValueKey('mi-pick-corrected'),
            onPressed: _pickCorrected,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.miPickCorrected),
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: AppSpacing.sm, children: [
        if (readFailed && _file != null)
          TextButton.icon(
            key: const ValueKey('mi-retry'),
            onPressed: _run,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.miRetryRead),
          ),
        TextButton(key: const ValueKey('mi-cancel'), onPressed: _cancel, child: Text(l10n.miCancel)),
      ]),
    ];
  }

  List<Widget> _manualView(AppLocalizations l10n, ThemeData theme) {
    final byLine = <int, List<MasterProblem>>{};
    for (final p in _problems) {
      byLine.putIfAbsent(p.lineNo, () => []).add(p);
    }
    return [
      Text(l10n.miManualTitle, style: theme.textTheme.titleMedium),
      Text(l10n.miManualHint, style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const ValueKey('mi-suggest-en'),
          onPressed: () => _suggestEnglish(),
          icon: const Icon(Icons.translate, size: 18),
          label: Text(l10n.miSuggestEn),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      for (final (i, l) in _lines.indexed)
        _LineEditor(
          key: ValueKey('mi-line-${l.lineNo}-${_lines.length}'),
          line: l,
          problems: byLine[l.lineNo] ?? const [],
          onChanged: (next) => setState(() => _lines = [for (final (j, x) in _lines.indexed) j == i ? next : x]),
          onDelete: () => setState(() {
            _lines = [
              for (final (n, x) in _lines.where((x) => x.lineNo != l.lineNo).indexed) x.copyWith(lineNo: n + 1),
            ];
            _problems = checkMasterLines(_lines, checked: true);
          }),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('mi-add-line'),
          onPressed: () => setState(() => _lines = [..._lines, MasterLine(lineNo: _lines.length + 1)]),
          icon: const Icon(Icons.add),
          label: Text(l10n.miAddLine),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        key: const ValueKey('mi-register-checked'),
        onPressed: _lines.isEmpty ? null : _registerChecked,
        icon: const Icon(Icons.library_add_check_outlined),
        label: Text(l10n.miRegisterChecked),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(onPressed: () => setState(() => _phase = _Phase.stopped), child: Text(l10n.miBack)),
    ];
  }

  Widget _warehousePicker(AppLocalizations l10n) {
    final list = ref.watch(warehouseOverviewProvider).valueOrNull?.warehouses ?? const [];
    return DropdownButtonFormField<int>(
      key: const ValueKey('mi-warehouse'),
      initialValue: list.any((w) => w.id == _warehouseId) ? _warehouseId : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.miWarehouse, helperText: _warehouseId == null ? l10n.miChooseWarehouse : null),
      items: [for (final w in list) DropdownMenuItem(value: w.id, child: Text(w.name))],
      onChanged: (v) {
        setState(() => _warehouseId = v);
        _loadStock();
      },
    );
  }

  List<Widget> _stockView(AppLocalizations l10n, ThemeData theme) {
    final detail = _detail!;
    final canStock = ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false;
    final c = _commit;
    return [
      if (c != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: StatusPill(
            key: const ValueKey('mi-master-done'),
            tone: StatusTone.success,
            label: l10n.miMasterDone(c.created, c.updated, c.mapped),
          ),
        ),
      Text(l10n.miStockTitle, style: theme.textTheme.titleMedium),
      Text(l10n.miStockIntro, style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.sm),
      _warehousePicker(l10n),
      if (!canStock)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(l10n.miNeedAdjust, style: TextStyle(color: theme.colorScheme.error)),
        ),
      const SizedBox(height: AppSpacing.md),
      for (final l in detail.lines)
        _StockLineCard(
          key: ValueKey('mi-stock-${l.lineNo}'),
          line: l,
          qty: _qty[l.lineNo]!,
          fix: _fix[l.lineNo]!,
          showNow: _warehouseId != null,
          onChanged: () => setState(() {}),
        ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        key: const ValueKey('mi-apply-stock'),
        onPressed: canStock && _warehouseId != null && detail.lines.isNotEmpty ? _applyStock : null,
        icon: const Icon(Icons.inventory_outlined),
        label: Text(l10n.miApplyStock(detail.lines.length)),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        key: const ValueKey('mi-later'),
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(l10n.miLater),
      ),
    ];
  }

  List<Widget> _doneView(AppLocalizations l10n, ThemeData theme) {
    final detail = _detail!;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String n(int? v) => v == null ? '—' : '$v';
    return [
      StatusPill(
        key: const ValueKey('mi-stock-done'),
        tone: StatusTone.success,
        label: l10n.miStockDone(detail.stockLines, detail.stockAdded),
      ),
      if (detail.warehouseName != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text('${l10n.miWarehouse}: ${detail.warehouseName}', style: muted),
      ],
      const SizedBox(height: AppSpacing.md),
      for (final l in detail.lines)
        Card(
          key: ValueKey('mi-result-${l.lineNo}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name ?? l.supplierName ?? l.janCode, style: theme.textTheme.titleSmall),
              Text('JAN ${l.janCode}${l.nameEn == null ? '' : ' · ${l.nameEn}'}', style: muted),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l.onHandSet == null
                    ? l10n.miResultLine(n(l.onHandBefore), n(l.added), n(l.onHandAfter))
                    : l10n.miResultLineFixed(n(l.onHandBefore), n(l.onHandSet), n(l.added), n(l.onHandAfter)),
                key: ValueKey('mi-result-text-${l.lineNo}'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.miFinish)),
    ];
  }
}

/// Where the import is: the file, 商品マスタ, then the stock.
class _Steps extends StatelessWidget {
  const _Steps({required this.current, required this.done});

  final int current;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labels = [l10n.miStepFile, l10n.miStepMaster, l10n.miStepStock];
    return Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
      for (final (i, t) in labels.indexed)
        Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            done || i < current ? Icons.check_circle : (i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            size: 18,
            color: done || i <= current ? scheme.primary : scheme.outline,
          ),
          label: Text(t),
        ),
    ]);
  }
}

/// One line, field by field, with what is wrong with it.
class _LineEditor extends StatefulWidget {
  const _LineEditor({super.key, required this.line, required this.problems, required this.onChanged, required this.onDelete});

  final MasterLine line;
  final List<MasterProblem> problems;
  final ValueChanged<MasterLine> onChanged;
  final VoidCallback onDelete;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final Map<String, TextEditingController> _c = {
    'jan': TextEditingController(text: widget.line.janCode),
    'supplier': TextEditingController(text: widget.line.supplierName),
    'name': TextEditingController(text: widget.line.name),
    'en': TextEditingController(text: widget.line.nameEn),
    'maker': TextEditingController(text: widget.line.maker),
    'code': TextEditingController(text: widget.line.productCode),
    'qty': TextEditingController(text: widget.line.quantity),
    'unit': TextEditingController(text: widget.line.unit),
  };

  @override
  void didUpdateWidget(covariant _LineEditor old) {
    super.didUpdateWidget(old);
    // An English name the AI just proposed shows in its field.
    if (widget.line.nameEn != _c['en']!.text && widget.line.nameEn != old.line.nameEn) {
      _c['en']!.text = widget.line.nameEn;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(widget.line.copyWith(
        janCode: _c['jan']!.text,
        supplierName: _c['supplier']!.text,
        name: _c['name']!.text,
        nameEn: _c['en']!.text,
        maker: _c['maker']!.text,
        productCode: _c['code']!.text,
        quantity: _c['qty']!.text,
        unit: _c['unit']!.text,
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final codes = {for (final p in widget.problems) p.code};
    bool bad(Set<String> c) => codes.any(c.contains);
    Widget field(String k, String label, {bool error = false, TextInputType? type}) => TextField(
          key: ValueKey('mi-$k-${widget.line.lineNo}'),
          controller: _c[k],
          keyboardType: type,
          onChanged: (_) => _emit(),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: error,
            fillColor: error ? const Color(0x33FFD54F) : null,
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l10n.miLine(widget.line.lineNo), style: theme.textTheme.titleSmall)),
            if (widget.line.knownName != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: StatusPill(tone: StatusTone.info, label: l10n.miUpdated, dense: true),
              ),
            IconButton(
              key: ValueKey('mi-delete-${widget.line.lineNo}'),
              tooltip: l10n.miDeleteLine,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: widget.onDelete,
            ),
          ]),
          for (final p in widget.problems)
            Text(masterProblemText(l10n, p),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: p.blocking ? theme.colorScheme.error : theme.colorScheme.tertiary)),
          field('jan', l10n.miFieldJan, error: bad({'jan_missing', 'jan_invalid', 'jan_duplicate'}), type: TextInputType.number),
          field('supplier', l10n.miFieldSupplierName, error: bad({'name_missing'})),
          field('name', widget.line.knownName == null ? l10n.miFieldName : l10n.miFieldNameKnown(widget.line.knownName!)),
          field('en', l10n.miFieldNameEn, error: bad({'name_en_missing'})),
          Row(children: [
            Expanded(child: field('maker', l10n.miFieldMaker)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: field('code', l10n.miFieldCode)),
          ]),
          Row(children: [
            Expanded(child: field('qty', l10n.miFieldQty, error: bad({'qty_invalid', 'qty_missing'}), type: TextInputType.number)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: field('unit', l10n.miFieldUnit)),
          ]),
        ]),
      ),
    );
  }
}

/// One product's stock: what is there now (correctable by hand), what the
/// file adds, and what it will come to.
class _StockLineCard extends StatelessWidget {
  const _StockLineCard({
    super.key,
    required this.line,
    required this.qty,
    required this.fix,
    required this.showNow,
    required this.onChanged,
  });

  final MasterImportLine line;
  final TextEditingController qty;
  final TextEditingController fix;
  final bool showNow;
  final VoidCallback onChanged;

  static int? _int(String s) {
    final t = s.replaceAll(',', '').trim();
    return RegExp(r'^\d+$').hasMatch(t) ? int.parse(t) : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final now = line.onHandNow ?? 0;
    final base = fix.text.trim().isEmpty ? now : _int(fix.text);
    final add = _int(qty.text);
    final total = base == null || add == null ? null : base + add;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(line.name ?? line.supplierName ?? line.janCode, style: theme.textTheme.titleSmall)),
            StatusPill(
              tone: line.masterStatus == 'new' ? StatusTone.success : StatusTone.info,
              label: line.masterStatus == 'new' ? l10n.miNew : l10n.miUpdated,
              dense: true,
            ),
          ]),
          Text(
            [
              'JAN ${line.janCode}',
              if (line.nameEn != null) line.nameEn!,
              if (line.supplierName != null && line.supplierName != line.name) l10n.miSupplierCalls(line.supplierName!),
            ].join(' · '),
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (showNow)
              Text('${l10n.miOnHandNow}: $now', key: ValueKey('mi-now-${line.lineNo}'), style: theme.textTheme.bodyMedium),
            SizedBox(
              width: 150,
              child: TextField(
                key: ValueKey('mi-fix-${line.lineNo}'),
                controller: fix,
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(labelText: l10n.miOnHandFix, isDense: true, hintText: '$now'),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                key: ValueKey('mi-qty-${line.lineNo}'),
                controller: qty,
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(labelText: l10n.miAddQty, isDense: true),
              ),
            ),
            Text(
              '${l10n.miTotal}: ${total ?? '—'}',
              key: ValueKey('mi-total-${line.lineNo}'),
              style: theme.textTheme.titleSmall,
            ),
          ]),
        ]),
      ),
    );
  }
}
