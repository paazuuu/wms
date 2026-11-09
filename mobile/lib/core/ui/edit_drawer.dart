import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

/// Opens an edit form as a panel from the right (a drawer), so the list or
/// record being changed stays in view beside it. On a phone it takes the
/// whole width. Pop it with a value as a dialog would; Esc and the close
/// button pop it with null. A click on the page behind does not close it,
/// so a half-typed form is not lost.
Future<T?> showEditDrawer<T>(BuildContext context, {required WidgetBuilder builder, double width = 520}) {
  return showGeneralDialog<T>(
    context: context,
    // Lets Esc close it (the route's own dismiss); clicks on the dimmed
    // page are caught by the frame below and do nothing.
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (c, _, __) => _DrawerFrame(width: width, child: Builder(builder: builder)),
    transitionBuilder: (c, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child,
    ),
  );
}

class _DrawerFrame extends StatelessWidget {
  const _DrawerFrame({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final w = size.width < 640 ? size.width : width.clamp(320.0, size.width - 48);
      return Stack(children: [
        // The page beside the panel: a stray click there must not throw away
        // what was typed.
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, excludeFromSemantics: true, onTap: () {})),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(width: w.toDouble(), height: size.height, child: child),
        ),
      ]);
    });
  }
}

/// The body of an edit drawer, with the same parts as an [AlertDialog]
/// (title, content, actions), so a form written as a dialog becomes a
/// drawer by swapping the one for the other. The title stays at the top,
/// the buttons at the bottom, and the form scrolls between them.
class EditDrawer extends StatelessWidget {
  const EditDrawer({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions,
    // Accepted so an AlertDialog's arguments carry over; a drawer always
    // scrolls and fills its height.
    this.scrollable = true,
    this.contentPadding,
    this.insetPadding,
    this.titlePadding,
    this.actionsPadding,
    this.actionsAlignment,
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? insetPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment? actionsAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const ValueKey('edit-drawer'),
      color: scheme.surface,
      elevation: 8,
      shadowColor: scheme.shadow,
      shape: Border(left: BorderSide(color: scheme.outlineVariant)),
      child: SafeArea(
        left: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(children: [
              if (icon != null) ...[
                IconTheme.merge(data: IconThemeData(color: scheme.onSurfaceVariant, size: 22), child: icon!),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.titleLarge,
                  child: title ?? const SizedBox.shrink(),
                ),
              ),
              IconButton(
                key: const ValueKey('edit-drawer-close'),
                tooltip: AppLocalizations.of(context).close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ]),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              padding: contentPadding ?? const EdgeInsets.all(AppSpacing.lg),
              child: content ?? const SizedBox.shrink(),
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: actions!,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
