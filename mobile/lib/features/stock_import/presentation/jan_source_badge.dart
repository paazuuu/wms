import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../notation/presentation/notation_labels.dart' show janSourceLabel;

/// A JAN the document did not print, marked where it is shown (0223): "AI"
/// with a sparkle when the AI found it on the web, else where we had it —
/// カタログ, ライブラリ, 仕入先, 過去. The whole story on hover.
class JanSourceBadge extends StatelessWidget {
  const JanSourceBadge({super.key, required this.source});

  /// library, supplier, history, catalog or web.
  final String source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final web = source == 'web';
    final color = web ? const Color(0xFF7C3AED) : scheme.tertiary;
    final text = switch (source) {
      'web' => l10n.jsbWeb,
      'library' => l10n.jsbLibrary,
      'supplier' => l10n.jsbSupplier,
      'history' => l10n.jsbHistory,
      _ => l10n.jsbCatalog,
    };
    return Tooltip(
      message: l10n.ntFlagJanByCode(janSourceLabel(l10n, source)),
      child: Container(
        key: ValueKey('jan-source-$source'),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (web) ...[Icon(Icons.auto_awesome, size: 11, color: color), const SizedBox(width: 2)],
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, height: 1.2)),
        ]),
      ),
    );
  }
}
