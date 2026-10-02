import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A dialog of labelled text fields that returns what was typed, by key, or
/// null when cancelled. It owns its controllers, so they live as long as the
/// dialog does — through its closing animation too.
class FieldsDialog extends StatefulWidget {
  const FieldsDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.saveLabel,
    required this.cancelLabel,
    this.saveKey,
    this.keyPrefix = 'field',
    this.header,
  });

  final String title;

  /// key → (label, initial text), in order.
  final Map<String, (String, String)> fields;
  final String saveLabel;
  final String cancelLabel;
  final Key? saveKey;

  /// Each field is keyed `<keyPrefix>-<key>`.
  final String keyPrefix;

  /// Shown above the fields.
  final Widget? header;

  @override
  State<FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<FieldsDialog> {
  late final Map<String, TextEditingController> _ctl = {
    for (final e in widget.fields.entries) e.key: TextEditingController(text: e.value.$2),
  };

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.header != null) ...[widget.header!, const SizedBox(height: AppSpacing.md)],
                for (final e in widget.fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TextField(
                      key: ValueKey('${widget.keyPrefix}-${e.key}'),
                      controller: _ctl[e.key],
                      decoration: InputDecoration(labelText: e.value.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel)),
          FilledButton(
            key: widget.saveKey,
            onPressed: () => Navigator.pop(context, {for (final e in _ctl.entries) e.key: e.value.text.trim()}),
            child: Text(widget.saveLabel),
          ),
        ],
      );
}
