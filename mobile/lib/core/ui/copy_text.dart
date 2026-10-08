import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Puts [value] on the clipboard and says what was copied.
Future<void> copyToClipboard(BuildContext context, String value) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: value));
  final shown = value.length > 40 ? '${value.substring(0, 40)}…' : value;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.copiedValue(shown)), duration: const Duration(seconds: 2)));
}

/// A small button that copies [value]. Nothing is shown for an empty or
/// placeholder value.
class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.value, this.size = 16});

  final String value;
  final double size;

  static bool worthCopying(String v) => v.trim().isNotEmpty && v.trim() != '—' && v.trim() != '-';

  @override
  Widget build(BuildContext context) {
    if (!worthCopying(value)) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppLocalizations.of(context).copyAction,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size + 16, height: size + 16),
      iconSize: size,
      icon: Icon(Icons.content_copy_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
      onPressed: () => copyToClipboard(context, value),
    );
  }
}

/// [text] with a copy button after it, for codes and values people paste
/// elsewhere (JAN, 品番, numbers, addresses).
class CopyableText extends StatelessWidget {
  const CopyableText(this.text, {super.key, this.style, this.maxLines, this.copyValue, this.buttonKey});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  /// What goes on the clipboard, when it differs from what is shown.
  final String? copyValue;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(text, style: style, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis),
          ),
          const SizedBox(width: 2),
          CopyButton(key: buttonKey, value: copyValue ?? text),
        ],
      );
}
