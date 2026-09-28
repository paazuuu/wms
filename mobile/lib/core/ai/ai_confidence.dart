import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_error_mapper.dart';
import '../api/api_result.dart';
import '../theme/app_colors.dart';

// How sure a document reading is, field by field (spec §50), and the two
// thresholds that turn that into what a person has to do (0108).
//
// The numbers are explainable rather than a model's private score: they come
// from what the reader already records on every line — whether the AI's two
// independent reads agreed (ai_disagree), whether the second read ran at all
// (not_verified), the JAN check digit, how the name and 品番 were split, and
// whether quantity × price makes the amount. The same flags always give the
// same confidence, so a stored reading can be re-scored later.

/// The fields a reading is scored on.
const aiConfidenceFields = ['jan', 'maker', 'name', 'code', 'quantity', 'unit_price', 'amount', 'product'];

class AiThresholds extends Equatable {
  const AiThresholds({this.auto = 0.95, this.review = 0.80});

  /// At or above: an automatic candidate.
  final double auto;

  /// At or above (and below [auto]): check recommended. Below: human review.
  final double review;

  factory AiThresholds.fromJson(Map<String, dynamic> j) => AiThresholds(
        auto: (j['auto_threshold'] as num?)?.toDouble() ?? 0.95,
        review: (j['review_threshold'] as num?)?.toDouble() ?? 0.80,
      );

  @override
  List<Object?> get props => [auto, review];
}

enum ConfidenceBand { auto, review, human }

ConfidenceBand confidenceBand(double c, AiThresholds t) =>
    c >= t.auto ? ConfidenceBand.auto : (c >= t.review ? ConfidenceBand.review : ConfidenceBand.human);

/// Confidence per field for one read line, from its flags.
///
/// [verified] is false when the checking read did not run; [spreadsheet] is
/// true for Excel/CSV, where the values are read, not recognised.
Map<String, double> lineConfidence(
  List<String> flags, {
  bool verified = true,
  bool spreadsheet = false,
  bool hasJan = true,
  bool hasProduct = true,
}) {
  final base = spreadsheet ? 0.99 : (verified ? 0.97 : 0.85);
  final c = {for (final f in aiConfidenceFields) f: base};
  void cap(String field, double v) {
    if ((c[field] ?? 1) > v) c[field] = v;
  }

  for (final flag in flags) {
    final parts = flag.split(':');
    switch (parts.first) {
      case 'ai_disagree':
        final field = switch (parts.length > 1 ? parts[1] : '') {
          'raw_jan_code' || 'jan_code' => 'jan',
          'maker' => 'maker',
          'product_name' => 'name',
          'product_code' => 'code',
          'planned_quantity' || 'quantity' => 'quantity',
          'unit_price' => 'unit_price',
          'amount' => 'amount',
          _ => null,
        };
        if (field == null) {
          for (final f in aiConfidenceFields) {
            cap(f, 0.7);
          }
        } else {
          cap(field, 0.6);
        }
      case 'not_verified':
        for (final f in aiConfidenceFields) {
          cap(f, 0.85);
        }
      case 'added_by_check' || 'dropped_by_check':
        for (final f in aiConfidenceFields) {
          cap(f, 0.6);
        }
      case 'jan_check':
        cap('jan', 0.4);
      case 'split_disagree':
        cap('name', 0.65);
        cap('code', 0.65);
      case 'split_single':
        cap('name', 0.85);
        cap('code', 0.85);
      case 'split_failed':
        cap('name', 0.5);
        cap('code', 0.5);
      case 'no_quantity':
        cap('quantity', 0);
      case 'amount_mismatch':
        cap('quantity', 0.7);
        cap('unit_price', 0.7);
        cap('amount', 0.7);
      case 'no_maker':
        cap('maker', 0.5);
      case 'unresolved':
        cap('product', 0.3);
    }
  }
  if (!hasJan) c.remove('jan');
  if (!hasProduct) cap('product', 0.3);
  return c;
}

/// The lowest field decides what a person has to do with the line.
double overallConfidence(Map<String, double> c) =>
    c.isEmpty ? 1 : c.values.reduce((a, b) => a < b ? a : b);

/// The thresholds set in the admin screen.
final aiThresholdsProvider = FutureProvider<AiThresholds>((ref) async {
  final dio = ref.watch(restDioProvider);
  try {
    final r = await dio.post('/rpc/get_ai_settings', data: const {});
    final d = r.data;
    final m = d is List && d.isNotEmpty ? d.first : d;
    return m is Map ? AiThresholds.fromJson(m.cast<String, dynamic>()) : const AiThresholds();
  } on DioException {
    return const AiThresholds();
  }
});

Future<ApiResult<AiThresholds>> saveAiThresholds(Dio dio, double auto, double review) async {
  try {
    final r = await dio.post('/rpc/set_ai_settings', data: {'p_auto': auto, 'p_review': review});
    final d = r.data;
    final m = d is List && d.isNotEmpty ? d.first : d;
    return ApiSuccess(AiThresholds.fromJson((m as Map).cast<String, dynamic>()));
  } on DioException catch (e) {
    return mapDioError<AiThresholds>(e);
  }
}

String confidenceFieldLabel(AppLocalizations l10n, String field) => switch (field) {
      'jan' => l10n.ntFieldJan,
      'maker' => l10n.ntFieldMaker,
      'name' => l10n.ntFieldName,
      'code' => l10n.ntFieldCode,
      'quantity' => l10n.ntFieldQuantity,
      'unit_price' => l10n.ntFieldUnitPrice,
      'amount' => l10n.ntFieldAmount,
      'product' => l10n.aiFieldProduct,
      _ => field,
    };

String confidenceBandLabel(AppLocalizations l10n, ConfidenceBand b) => switch (b) {
      ConfidenceBand.auto => l10n.aiBandAuto,
      ConfidenceBand.review => l10n.aiBandReview,
      ConfidenceBand.human => l10n.aiBandHuman,
    };

Color confidenceColor(ConfidenceBand b) => switch (b) {
      ConfidenceBand.auto => AppColors.success,
      ConfidenceBand.review => AppColors.warning,
      ConfidenceBand.human => AppColors.danger,
    };

/// Field-by-field confidence, coloured by band (§50: 🟢 🟡 🔴). Only the
/// fields below the automatic threshold are listed unless [all].
class AiConfidenceRow extends ConsumerWidget {
  const AiConfidenceRow({super.key, required this.confidence, this.all = false});

  final Map<String, double> confidence;
  final bool all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(aiThresholdsProvider).valueOrNull ?? const AiThresholds();
    final shown = [
      for (final e in confidence.entries)
        if (all || confidenceBand(e.value, t) != ConfidenceBand.auto) e,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        for (final e in shown)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 8, color: confidenceColor(confidenceBand(e.value, t))),
            const SizedBox(width: 2),
            Text('${confidenceFieldLabel(l10n, e.key)} ${(e.value * 100).round()}%', style: style),
          ]),
      ],
    );
  }
}

/// The band of a whole line, as one pill.
class AiBandPill extends ConsumerWidget {
  const AiBandPill({super.key, required this.confidence});

  final Map<String, double> confidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(aiThresholdsProvider).valueOrNull ?? const AiThresholds();
    final band = confidenceBand(overallConfidence(confidence), t);
    final color = confidenceColor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(confidenceBandLabel(l10n, band),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
