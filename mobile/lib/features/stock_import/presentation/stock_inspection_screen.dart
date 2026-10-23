import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../master_import/data/master_import_repository.dart';
import '../../master_import/domain/master_import.dart';
import '../../product/application/product_providers.dart';
import '../../qc/domain/inspection.dart' show normalizeJan;
import '../data/stock_import_repository.dart';
import '../domain/stock_ledger.dart';

/// Whether the person may check stock files in (0148).
bool canInspectStockFiles(WidgetRef ref) {
  final u = ref.watch(authControllerProvider).user;
  return (u?.hasPermission('inspection.confirm') ?? false) || (u?.hasPermission('inventory.adjust') ?? false);
}

/// 取込の検品 (0148): stock read from a file waits here, 「検品未完了」,
/// until someone counts it and checks it in. Only then is it in stock.
/// A separate screen from the import, so the one who reads the file in and
/// the one who counts the goods can be different people at different times.
class StockInspectionScreen extends ConsumerWidget {
  const StockInspectionScreen({super.key, this.openImportId});

  /// Straight to this file's lines (from the import just made).
  final int? openImportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (openImportId case final id?) return StockInspectionDetailScreen(importId: id);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = ref.watch(awaitingImportsProvider);
    final fmt = DateFormat('y/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockInspection)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(awaitingImportsProvider),
        child: list.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorStateView(message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(awaitingImportsProvider)),
          data: (items) => items.isEmpty
              ? ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: Text(l10n.siEmpty, key: const ValueKey('si-empty'))),
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(l10n.siIntro, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    for (final a in items)
                      Card(
                        key: ValueKey('si-import-${a.id}'),
                        child: ListTile(
                          leading: const Icon(Icons.pending_actions_outlined),
                          title: Text(l10n.siFile(a.id, a.fileName ?? '')),
                          subtitle: Text([
                            if (a.warehouseName case final w?) w,
                            l10n.siLeft(a.left, a.lines, a.quantityLeft),
                            if (a.createdAt case final c?) l10n.siBy(a.createdByName ?? '', fmt.format(c)),
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => StockInspectionDetailScreen(importId: a.id)));
                            ref.invalidate(awaitingImportsProvider);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One file's lines to count: tick what was checked, change the count where
/// it differs from the file, and check them in.
class StockInspectionDetailScreen extends ConsumerStatefulWidget {
  const StockInspectionDetailScreen({super.key, required this.importId});

  final int importId;

  @override
  ConsumerState<StockInspectionDetailScreen> createState() => _StockInspectionDetailScreenState();
}

class _StockInspectionDetailScreenState extends ConsumerState<StockInspectionDetailScreen> {
  MasterImport? _import;
  String? _error;
  bool _busy = false;

  /// Lines ticked, and the count typed for each (the file's until changed).
  final Set<int> _ticked = {};
  final Map<int, TextEditingController> _counts = {};
  final _scan = TextEditingController();
  String? _scanMiss;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _counts.values) {
      c.dispose();
    }
    _scan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(masterImportRepositoryProvider).detail(widget.importId);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      switch (r) {
        case ApiSuccess(:final data):
          _import = data;
          _error = null;
          for (final l in data.lines) {
            _counts.putIfAbsent(l.lineNo, () => TextEditingController(text: '${l.quantity}'));
          }
          _ticked.removeWhere((n) => data.lines.any((l) => l.lineNo == n && l.inspected));
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  List<MasterImportLine> get _open => [for (final l in _import?.lines ?? const <MasterImportLine>[]) if (!l.inspected) l];

  int? _count(MasterImportLine l) {
    final v = int.tryParse(_counts[l.lineNo]?.text.trim() ?? '');
    return v == null || v < 0 ? null : v;
  }

  /// A scanned or typed JAN ticks its line.
  void _onScan(String raw) {
    final jan = normalizeJan(raw) ?? raw.trim();
    final hit = _open.where((l) => l.janCode == jan).firstOrNull;
    setState(() {
      _scanMiss = hit == null && jan.isNotEmpty ? jan : null;
      if (hit != null) _ticked.add(hit.lineNo);
    });
    _scan.clear();
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    final lines = [for (final l in _open) if (_ticked.contains(l.lineNo)) l];
    if (lines.isEmpty) return;
    final bad = lines.where((l) => _count(l) == null).toList();
    if (bad.isNotEmpty) {
      setState(() => _error = l10n.siBadCount(bad.first.name ?? bad.first.janCode));
      return;
    }
    final units = lines.fold<int>(0, (s, l) => s + _count(l)!);
    final diff = lines.fold<int>(0, (s, l) => s + _count(l)! - l.quantity);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.siConfirmQ),
        content: Text(l10n.siConfirmBody(lines.length, units, diff > 0 ? '+$diff' : '$diff'), key: const ValueKey('si-confirm-body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('si-confirm'), onPressed: () => Navigator.pop(d, true), child: Text(l10n.siConfirmGo)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref
        .read(stockImportRepositoryProvider)
        .inspect(widget.importId, [for (final l in lines) InspectedLine(l.lineNo, _count(l)!)]);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(pendingInspectionProvider);
        ref.invalidate(awaitingImportsProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(masterImportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.siDone(data.lines, data.left))));
        _ticked.clear();
        await _load();
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = _import;
    final may = canInspectStockFiles(ref);
    final open = _open;
    final ticked = [for (final l in open) if (_ticked.contains(l.lineNo)) l];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.siTitle(widget.importId))),
      body: m == null
          ? (_error == null ? const LoadingView() : ErrorStateView(message: _error!, onRetry: _load))
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
              children: [
                Text(m.originalName ?? '', style: theme.textTheme.titleMedium),
                if (m.warehouseName case final w?) Text(w, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  m.status == MasterImportStatus.awaitingInspection
                      ? l10n.siOpenLines(open.length, m.lines.length)
                      : l10n.siAllDone,
                  key: const ValueKey('si-status'),
                  style: theme.textTheme.titleSmall,
                ),
                if (open.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const ValueKey('si-scan'),
                    controller: _scan,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      labelText: l10n.siScan,
                      border: const OutlineInputBorder(),
                      errorText: _scanMiss == null ? null : l10n.siScanMiss(_scanMiss!),
                    ),
                    onSubmitted: _onScan,
                  ),
                  CheckboxListTile(
                    key: const ValueKey('si-all'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: ticked.length == open.length,
                    onChanged: _busy || !may
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _ticked.addAll(open.map((l) => l.lineNo));
                              } else {
                                _ticked.clear();
                              }
                            }),
                    title: Text(l10n.siAll),
                  ),
                ],
                if (_error case final e?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(e, key: const ValueKey('si-error'), style: TextStyle(color: theme.colorScheme.error)),
                  ),
                for (final l in m.lines)
                  if (l.inspected)
                    ListTile(
                      key: ValueKey('si-done-${l.lineNo}'),
                      dense: true,
                      leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      title: Text(l.name ?? l.janCode),
                      subtitle: Text([
                        l.janCode,
                        l10n.siInspected(l.inspectedQuantity ?? 0, l.inspectedByName ?? ''),
                        if ((l.inspectedQuantity ?? l.quantity) != l.quantity) l10n.siFileSaid(l.quantity),
                      ].join(' · ')),
                    )
                  else
                    _OpenLine(
                      key: ValueKey('si-line-${l.lineNo}'),
                      line: l,
                      ticked: _ticked.contains(l.lineNo),
                      count: _counts[l.lineNo]!,
                      enabled: !_busy && may,
                      onTick: (v) => setState(() => v ? _ticked.add(l.lineNo) : _ticked.remove(l.lineNo)),
                      onCount: () => setState(() {}),
                    ),
                if (!may)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(l10n.siNoPermission, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
      bottomNavigationBar: m == null || open.isEmpty || !may
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const ValueKey('si-check-in'),
                  onPressed: _busy || ticked.isEmpty ? null : _checkIn,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.siCheckIn(ticked.length)),
                ),
              ),
            ),
    );
  }
}

class _OpenLine extends StatelessWidget {
  const _OpenLine({
    super.key,
    required this.line,
    required this.ticked,
    required this.count,
    required this.enabled,
    required this.onTick,
    required this.onCount,
  });

  final MasterImportLine line;
  final bool ticked;
  final TextEditingController count;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final VoidCallback onCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counted = int.tryParse(count.text.trim());
    final differs = counted != null && counted != line.quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Checkbox(
          key: ValueKey('si-tick-${line.lineNo}'),
          value: ticked,
          onChanged: enabled ? (v) => onTick(v ?? false) : null,
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.name ?? line.janCode, style: theme.textTheme.bodyMedium),
            Text(
              [line.janCode, l10n.siFileSaid(line.quantity), if (differs) l10n.siDiff(counted - line.quantity > 0 ? '+${counted - line.quantity}' : '${counted - line.quantity}')].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: differs ? theme.colorScheme.error : null),
            ),
          ]),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: ValueKey('si-count-${line.lineNo}'),
            controller: count,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.end,
            decoration: InputDecoration(labelText: l10n.siCounted, isDense: true, border: const OutlineInputBorder()),
            onChanged: (_) => onCount(),
          ),
        ),
      ]),
    );
  }
}

/// The date a stock file is kept until, in words (0148).
String keptUntilText(AppLocalizations l10n, DateTime filedOn) =>
    l10n.ivKeptUntil(DateFormat('y/MM/dd').format(keptUntil(filedOn)), keepYears);
