import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/product.dart';
import 'product_labels.dart';

/// The facts 0057-0060 added, as a wrap of small chips: base unit, each pack
/// unit and what it converts to, the tracking mode when it is not the default,
/// and the barcode count when there is more than the one code.
///
/// A wrap rather than fixed rows, because a product may have none of these
/// (nothing is shown at all) or several (the row grows instead of truncating).
class ProductFacts extends StatelessWidget {
  const ProductFacts({super.key, required this.product, this.oneLine = false});

  final Product product;

  /// One line of text instead of chips, cut at the end (the one-line row).
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = product.baseUom;

    final facts = <Widget>[];
    final words = <String>[];

    Widget chip(String text, {Color? color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: (color ?? scheme.surfaceContainerHighest).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(text,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        );

    void add(String text, {Color? color}) {
      words.add(text);
      facts.add(chip(text, color: color));
    }

    if (base != null) {
      add('${l10n.productBaseUnit}: ${uomName(l10n, base.code, base.name)}');
    }
    for (final uom in product.packUoms) {
      add(l10n.productPackUnit(
        uom.code,
        formatFactor(uom.conversionFactor),
        base == null ? '' : uomName(l10n, base.code, base.name),
      ));
    }
    if (product.trackingMode != TrackingMode.untracked) {
      add(trackingModeLabel(l10n, product.trackingMode), color: scheme.tertiaryContainer);
    }
    if (product.barcodes.length > 1) {
      add(l10n.productCodeCount(product.barcodes.length));
    }

    if (facts.isEmpty) return const SizedBox.shrink();
    if (oneLine) {
      return Text(words.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant));
    }
    return Wrap(spacing: AppSpacing.xs, runSpacing: 2, children: facts);
  }
}
