import 'package:flutter/material.dart';

/// A tab that says what it is for when the pointer rests on it (or it is
/// long-pressed): a signpost, so a screen of tabs is learned by looking.
class HelpTab extends StatelessWidget {
  const HelpTab({super.key, required this.help, required this.child});

  /// When and why this tab is used, in a sentence or two.
  final String help;

  /// The [Tab] itself.
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: help,
        waitDuration: const Duration(milliseconds: 350),
        preferBelow: true,
        constraints: const BoxConstraints(maxWidth: 360),
        child: child,
      );
}
