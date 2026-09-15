import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Runs [bindings] for matching key combinations anywhere in the app,
/// regardless of what currently holds focus.
///
/// Flutter's own [CallbackShortcuts] resolves through the focus chain, which
/// does not work for an app shell: the shell sits *inside* the router's
/// navigator, so as soon as a navigation moves primary focus up to the
/// enclosing route's modal scope, key events stop reaching anything the shell
/// wrapped. The symptom is a shortcut that works once, on a freshly loaded
/// page, and then silently stops.
///
/// So this listens at the same level [HardwareScanner] does — a
/// [HardwareKeyboard] handler — which sees every key event no matter where
/// focus sits. That is the right altitude for shell-wide shortcuts, which are
/// about the window rather than about whatever is focused inside it.
///
/// Only bind combinations that include Ctrl, Meta, Alt or a function key.
/// A bare-letter binding here would fire while the operator is typing into a
/// field, because a global handler by design does not care about focus.
class GlobalShortcuts extends StatefulWidget {
  const GlobalShortcuts({
    super.key,
    required this.bindings,
    required this.child,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  State<GlobalShortcuts> createState() => _GlobalShortcutsState();
}

class _GlobalShortcutsState extends State<GlobalShortcuts> {
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
    if (event is! KeyDownEvent) return false;
    for (final entry in widget.bindings.entries) {
      if (entry.key.accepts(event, HardwareKeyboard.instance)) {
        entry.value();
        // Claim the event so it does not also reach whatever is focused —
        // Ctrl+B should not additionally do something to a text field.
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
