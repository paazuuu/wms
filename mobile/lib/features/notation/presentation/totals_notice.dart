import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/notation.dart';

/// The lines against the document's own total (0114): a misread quantity or
/// price shows here. [onReport] says whether the warning was right.
class TotalsNotice extends StatelessWidget {
  const TotalsNotice({super.key, required this.totals, this.onReport});

  final ReadTotals totals;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final yen = NumberFormat.decimalPattern('ja');
    String money(double? v) => v == null ? '—' : '¥${yen.format(v)}';
    if (totals.ok == null || totals.linesSum == null) return const SizedBox.shrink();
    final ok = totals.ok!;
    final color = ok ? scheme.primary : scheme.error;
    return Container(
      key: ValueKey(ok ? 'totals-ok' : 'totals-mismatch'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            ok
                ? l10n.totalsOk(money(totals.linesSum))
                : (totals.expected == null
                    ? l10n.totalsNotFound(money(totals.linesSum))
                    : l10n.totalsMismatch(money(totals.linesSum), money(totals.expected))),
            style: theme.textTheme.bodySmall?.copyWith(color: ok ? null : scheme.error),
          ),
        ),
        if (!ok && onReport != null)
          TextButton(
            key: const ValueKey('totals-report'),
            onPressed: onReport,
            child: Text(l10n.totalsReport),
          ),
      ]),
    );
  }
}
