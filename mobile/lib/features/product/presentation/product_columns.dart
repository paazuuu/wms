import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/local_prefs.dart';
import '../../../l10n/app_localizations.dart';

/// The product library's columns on a PC, left to right: the 商品名 as shops
/// call it (0164; 未登録 when it is only the 品番), then the maker and 品番.
const productColumnKeys = ['name', 'code', 'jan', 'spec', 'stock', 'facts', 'price'];

const productColumnDefaults = <String, double>{
  'name': 260,
  'code': 220,
  'jan': 150,
  'spec': 150,
  'stock': 260,
  'facts': 120,
  'price': 80,
};

const productColumnMin = 56.0;
const productColumnMax = 900.0;
// v3: the 商品名 column came back beside the 品番 (0164); older widths are
// not carried over.
const _prefKey = 'wms.productLibrary.columns.v3';

/// Beside the columns on a row: the picture and its gap, the state pill and
/// the menu, and the gaps between columns.
const productRowLead = 36.0 + AppSpacing.md;
const productRowTail = AppSpacing.sm + 76 + 40;
const productColumnGap = AppSpacing.sm;

/// The widths a person dragged the columns to, kept in this browser.
class ProductColumns extends StateNotifier<Map<String, double>> {
  ProductColumns() : super(_load());

  static Map<String, double> _load() {
    final out = Map<String, double>.of(productColumnDefaults);
    try {
      final raw = readLocalPref(_prefKey);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as Map).entries) {
          final v = (e.value as num?)?.toDouble();
          if (out.containsKey(e.key) && v != null) out[e.key as String] = v.clamp(productColumnMin, productColumnMax);
        }
      }
    } catch (_) {
      // A setting from an older version: the defaults.
    }
    return out;
  }

  void resize(String key, double by) {
    final w = ((state[key] ?? productColumnDefaults[key]!) + by).clamp(productColumnMin, productColumnMax);
    state = {...state, key: w};
    writeLocalPref(_prefKey, jsonEncode(state));
  }

  void reset() {
    state = Map.of(productColumnDefaults);
    writeLocalPref(_prefKey, null);
  }
}

final productColumnsProvider = StateNotifierProvider<ProductColumns, Map<String, double>>((ref) => ProductColumns());

/// The widths as laid out in [available]: as dragged when they fit; else the
/// 商品名 column gives way first (to 140), then every column in proportion — so the
/// heading and every row line up, and nothing runs off the edge.
Map<String, double> fitProductColumns(Map<String, double> widths, double available, {double lead = productRowLead}) {
  final w = {for (final k in productColumnKeys) k: widths[k] ?? productColumnDefaults[k]!};
  final room = available - lead - productRowTail - productColumnGap * productColumnKeys.length;
  double sum() => w.values.fold(0, (s, v) => s + v);
  if (room <= 0) return w;
  if (sum() > room) w['name'] = math.max(140, w['name']! - (sum() - room));
  if (sum() > room) {
    final k = room / sum();
    for (final key in productColumnKeys) {
      w[key] = w[key]! * k;
    }
  }
  return w;
}

String productColumnLabel(AppLocalizations l10n, String key) => switch (key) {
      'name' => l10n.pcName,
      'jan' => l10n.pcJan,
      'code' => l10n.pcCode,
      'spec' => l10n.pcSpec,
      'stock' => l10n.pcStock,
      'facts' => l10n.pcFacts,
      'price' => l10n.pcPrice,
      _ => key,
    };

/// The heading over the wide rows: each column's name, its right edge
/// dragged to widen or narrow it (double-click: back to its default).
class ProductColumnHeader extends ConsumerWidget {
  const ProductColumnHeader({super.key, this.selecting = false});

  /// Rows then start with a checkbox.
  final bool selecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widths = ref.watch(productColumnsProvider);
    final notifier = ref.read(productColumnsProvider.notifier);
    final style = theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
    final lead = productRowLead + (selecting ? 48 : 0);
    return Padding(
      // The card's own padding, so the heading sits over its columns.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: LayoutBuilder(builder: (context, c) {
        final w = fitProductColumns(widths, c.maxWidth, lead: lead);
        return SizedBox(
          height: 30,
          child: Row(children: [
            SizedBox(width: lead),
            for (final k in productColumnKeys)
              SizedBox(
                key: ValueKey('pc-col-$k'),
                width: w[k]! + productColumnGap,
                child: Row(children: [
                  Expanded(
                    child: Text(productColumnLabel(l10n, k),
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: k == 'price' ? TextAlign.end : TextAlign.start),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      key: ValueKey('pc-drag-$k'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => notifier.resize(k, d.delta.dx),
                      onDoubleTap: () => notifier.resize(k, productColumnDefaults[k]! - (widths[k] ?? 0)),
                      child: SizedBox(
                        width: productColumnGap,
                        height: 30,
                        child: Center(child: Container(width: 2, height: 16, color: scheme.outlineVariant)),
                      ),
                    ),
                  ),
                ]),
              ),
            const Spacer(),
            Tooltip(
              message: l10n.pcReset,
              child: IconButton(
                key: const ValueKey('pc-reset'),
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: notifier.reset,
                icon: const Icon(Icons.view_column_outlined),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
