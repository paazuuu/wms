import 'package:flutter/material.dart';

/// Makes every text under [child] selectable and copyable, from
/// `MaterialApp.builder`.
///
/// A [SelectionArea] needs an [Overlay] above it for its handles and copy
/// menu, and the app builder sits above the Navigator's overlay. So this
/// brings its own overlay, with one entry that is rebuilt whenever the app
/// hands down a new [child].
class SelectableApp extends StatefulWidget {
  const SelectableApp({super.key, required this.child});

  final Widget child;

  @override
  State<SelectableApp> createState() => _SelectableAppState();
}

class _SelectableAppState extends State<SelectableApp> {
  // Selection takes focus when text is pressed (for Ctrl+C), but is never a
  // Tab stop. Left in the traversal order, the browser giving the window
  // focus at start-up looks for the first focusable box before this one has
  // been laid out, and fails.
  final FocusNode _focus = FocusNode(debugLabel: 'SelectableApp', skipTraversal: true);

  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => SelectionArea(focusNode: _focus, child: widget.child),
  );

  @override
  void didUpdateWidget(SelectableApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The entry is below this widget, so it is rebuilt in this same frame.
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
