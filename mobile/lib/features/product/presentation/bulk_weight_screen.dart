import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../data/spec_lookup.dart';
import '../domain/product.dart';
import 'spec_lookup_sheet.dart' show saveSpecResult, specErrorText;

/// 重さをまとめて調べる (0149): every product in use that has no weight yet,
/// looked up by the AI a few at a time. Nothing is saved until a person
/// ticks what to keep: found on the web with good confidence comes ticked;
/// an estimate (no web search) or a doubtful one does not.
class BulkWeightScreen extends ConsumerStatefulWidget {
  const BulkWeightScreen({super.key});

  @override
  ConsumerState<BulkWeightScreen> createState() => _BulkWeightScreenState();
}

class _BulkWeightScreenState extends ConsumerState<BulkWeightScreen> {
  final Map<int, SpecLookupResult> _found = {};
  final Set<int> _ticked = {};
  bool _running = false;
  bool _stop = false;
  bool _saving = false;
  bool _searchUnavailable = false;
  int _done = 0;
  String? _error;

  static List<Product> _todo(List<Product> all) =>
      [for (final p in all) if (p.isActive && p.unitWeightG == null) p];

  static SpecLookupRequest _ask(Product p) => SpecLookupRequest(
        name: p.name,
        maker: p.maker,
        code: p.sku,
        jan: p.janCode.isEmpty ? null : p.janCode,
        nameEn: p.nameEn,
      );

  /// Taken without a second look: from the web, and the AI sure of it.
  static bool _trusted(SpecLookupResult r) => r.hasWeight && !r.estimated && (r.confidence ?? 0) >= 0.7;

  Future<void> _run(List<Product> todo) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _running = true;
      _stop = false;
      _error = null;
      _done = 0;
      _found.clear();
      _ticked.clear();
    });
    final repo = ref.read(specLookupRepositoryProvider);
    for (var i = 0; i < todo.length && !_stop; i += specLookupBatchSize) {
      final part = todo.sublist(i, i + specLookupBatchSize > todo.length ? todo.length : i + specLookupBatchSize);
      final r = await repo.lookupMany([for (final p in part) _ask(p)]);
      if (!mounted) return;
      switch (r) {
        case ApiSuccess(:final data):
          setState(() {
            _searchUnavailable = _searchUnavailable || data.searchUnavailable;
            for (final (k, p) in part.indexed) {
              final res = data.results[k];
              _found[p.id] = res;
              if (_trusted(res)) _ticked.add(p.id);
            }
            _done += part.length;
          });
          // Out of quota or no key: the rest would fail the same way.
          if (data.results.any((x) => const {'quota', 'auth', 'no_key', 'limit'}.contains(x.errorKind) && !x.found)) {
            setState(() => _error = specErrorText(l10n, data.results.firstWhere((x) => x.errorKind != null).errorKind));
            _stop = true;
          }
        case ApiFailure(:final message):
          setState(() => _error = humanizeApiErrorMessage(l10n, message));
          _stop = true;
      }
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _save(List<Product> todo) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    var saved = 0;
    String? failure;
    for (final p in todo) {
      final r = _found[p.id];
      if (r == null || !_ticked.contains(p.id) || !r.hasWeight) continue;
      // Its size too, when it has none yet and the same answer gave one.
      final f = await saveSpecResult(ref, l10n, p.id, r, weight: true, size: !p.hasSize && r.hasSize);
      if (f != null) {
        failure = f;
        break;
      }
      saved++;
    }
    if (!mounted) return;
    ref.invalidate(productListProvider);
    setState(() {
      _saving = false;
      for (final p in todo) {
        if (_ticked.contains(p.id)) _found.remove(p.id);
      }
      _ticked.clear();
    });
    messenger.showSnackBar(SnackBar(
        content: Text(failure == null ? l10n.bwSaved(saved) : '${l10n.bwSaved(saved)} ${humanizeApiErrorMessage(l10n, failure)}')));
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final all = ref.watch(productListProvider);
    final todo = _todo(all.valueOrNull ?? const []);
    final shown = _found.isEmpty ? todo : [for (final p in todo) if (_found.containsKey(p.id)) p];
    final ticked = [for (final p in todo) if (_ticked.contains(p.id) && (_found[p.id]?.hasWeight ?? false)) p];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bwTitle)),
      body: all.isLoading && all.valueOrNull == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120),
              children: [
                Text(l10n.bwIntro, style: muted),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.bwCount(todo.length), key: const ValueKey('bw-count'), style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                  FilledButton.icon(
                    key: const ValueKey('bw-start'),
                    onPressed: _running || _saving || todo.isEmpty ? null : () => _run(todo),
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: Text(l10n.bwStart(todo.length)),
                  ),
                  if (_running)
                    OutlinedButton.icon(
                      key: const ValueKey('bw-stop'),
                      onPressed: () => setState(() => _stop = true),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(l10n.bwStop),
                    ),
                ]),
                if (_running || _done > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(value: todo.isEmpty ? null : (_done / todo.length).clamp(0, 1).toDouble()),
                  Text(l10n.bwProgress(_done, todo.length), key: const ValueKey('bw-progress'), style: muted),
                ],
                if (_searchUnavailable)
                  Card(
                    key: const ValueKey('bw-estimates'),
                    color: theme.colorScheme.tertiaryContainer,
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.bwEstimates, style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                    ),
                  ),
                if (_error case final e?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(e, key: const ValueKey('bw-error'), style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in shown)
                  _Row(
                    key: ValueKey('bw-row-${p.id}'),
                    product: p,
                    result: _found[p.id],
                    ticked: _ticked.contains(p.id),
                    enabled: !_saving,
                    onTick: (v) => setState(() => v ? _ticked.add(p.id) : _ticked.remove(p.id)),
                    weight: _n,
                  ),
              ],
            ),
      bottomNavigationBar: _found.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton.icon(
                  key: const ValueKey('bw-save'),
                  onPressed: _saving || _running || ticked.isEmpty ? null : () => _save(todo),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.bwSave(ticked.length)),
                ),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.product,
    required this.result,
    required this.ticked,
    required this.enabled,
    required this.onTick,
    required this.weight,
  });

  final Product product;
  final SpecLookupResult? result;
  final bool ticked;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final String Function(double) weight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final r = result;
    final can = r != null && r.hasWeight;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(children: [
          Checkbox(
            key: ValueKey('bw-tick-${product.id}'),
            value: can && ticked,
            onChanged: can && enabled ? (v) => onTick(v ?? false) : null,
          ),
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              Text([product.janCode, if (product.maker != null) product.maker!, if (product.sku != null) product.sku!].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: r == null
                ? Text(l10n.bwWaiting, style: muted)
                : !r.hasWeight
                    ? Text(r.errorKind == null ? l10n.slNothingFound : specErrorText(l10n, r.errorKind),
                        key: ValueKey('bw-none-${product.id}'), style: muted)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${weight(r.weightG!)} g', key: ValueKey('bw-weight-${product.id}'), style: theme.textTheme.titleSmall),
                        Wrap(spacing: AppSpacing.xs, runSpacing: 2, children: [
                          if (r.estimated)
                            StatusPill(tone: StatusTone.warning, label: l10n.bwEstimate, dense: true)
                          else if (r.confidence != null)
                            StatusPill(
                              tone: r.confidence! >= 0.7 ? StatusTone.success : StatusTone.warning,
                              label: l10n.slConfidence((r.confidence! * 100).round()),
                              dense: true,
                            ),
                          if (r.weightBasis == 'package') StatusPill(tone: StatusTone.info, label: l10n.slBasisPackage, dense: true),
                        ]),
                        if (r.bestUrl != null && !r.estimated)
                          Text(r.bestUrl!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      ]),
          ),
        ]),
      ),
    );
  }
}
