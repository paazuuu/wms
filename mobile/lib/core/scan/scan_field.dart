import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';

/// A barcode-first text input tuned for warehouse work.
///
/// Works identically for a handheld scanner (types the code + Enter) and manual
/// keying. After each submit it can auto-clear and re-focus so an operator can
/// fire scan-after-scan without touching the screen — the single biggest
/// usability win for a keyboard-wedge scanner on a PC.
class ScanField extends StatefulWidget {
  const ScanField({
    super.key,
    required this.onSubmitted,
    this.controller,
    this.hintText = 'Scan or type a barcode',
    this.autofocus = false,
    this.clearOnSubmit = true,
    this.trailing,
    this.dense = false,
  });

  /// Called with the trimmed value when the field is submitted (Enter / scan).
  final ValueChanged<String> onSubmitted;

  /// Optional external controller. When omitted an internal one is used.
  final TextEditingController? controller;

  final String hintText;
  final bool autofocus;

  /// Clear the text and keep focus after a submit, ready for the next scan.
  final bool clearOnSubmit;

  /// Extra actions rendered inside the field (e.g. a camera button).
  final List<Widget>? trailing;

  /// Compact height for placement in a top bar.
  final bool dense;

  @override
  State<ScanField> createState() => _ScanFieldState();
}

class _ScanFieldState extends State<ScanField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onSubmitted(value);
    if (widget.clearOnSubmit) {
      _controller.clear();
      // Keep the caret in the field so the next scan lands here immediately.
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontFamily: AppFonts.mono, letterSpacing: 0.5),
      inputFormatters: [
        // Strip stray newlines/tabs some scanners append before Enter.
        FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
      ],
      decoration: InputDecoration(
        isDense: widget.dense,
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
        contentPadding: widget.dense
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md)
            : null,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...?widget.trailing,
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: _submit,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}
