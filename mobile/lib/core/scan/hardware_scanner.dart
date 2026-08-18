import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'scan_buffer.dart';

/// Wraps [child] and listens for handheld/keyboard-wedge barcode scanners at
/// the hardware-keyboard level, so a scan works *anywhere* in the app — the
/// operator never has to click into a field first.
///
/// Behaviour:
///  * When a text field currently holds focus, the scanner's keystrokes are
///    left alone so they type into that field (which submits on Enter). This is
///    what the per-screen scan fields rely on.
///  * When nothing editable is focused (dashboard, list screens, detail pages),
///    a fast keystroke burst ending in Enter is captured via [ScanBuffer] and
///    delivered to [onScan].
///
/// The listener is passive (returns `false`) so it never blocks normal input.
class HardwareScanner extends StatefulWidget {
  const HardwareScanner({
    super.key,
    required this.child,
    required this.onScan,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<String> onScan;
  final bool enabled;

  @override
  State<HardwareScanner> createState() => _HardwareScannerState();
}

class _HardwareScannerState extends State<HardwareScanner> {
  final ScanBuffer _buffer = ScanBuffer();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!widget.enabled) return false;
    if (event is! KeyDownEvent) return false;
    // Let focused inputs receive the keystrokes directly.
    if (_isEditableFocused()) return false;

    final now = DateTime.now();
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.flush(now);
      if (code != null) {
        widget.onScan(code);
        return true;
      }
      return false;
    }

    final char = event.character;
    // Accept a single printable character; ignore control keys, modifiers,
    // whitespace and multi-codepoint sequences.
    if (char != null && char.length == 1 && char.trim().isNotEmpty) {
      _buffer.feed(char, now);
    }
    return false;
  }

  /// True when the current primary focus sits on (or contains) an [EditableText]
  /// — i.e. the user is typing into a real text field.
  bool _isEditableFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    var found = false;
    void visit(Element element) {
      if (found) return;
      if (element.widget is EditableText) {
        found = true;
        return;
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
