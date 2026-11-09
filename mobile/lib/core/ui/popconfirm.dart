import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

/// Where the pointer last went down, so a [showPopconfirm] opens beside the
/// button that asked for it without every caller passing that button in.
class PopconfirmAnchor {
  PopconfirmAnchor._();

  static Offset? _last;
  static DateTime? _at;
  static bool _installed = false;

  /// Starts listening (once, at the app root).
  static void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((e) {
      if (e is PointerDownEvent) {
        _last = e.position;
        _at = DateTime.now();
      }
    });
  }

  /// The point of the click that led here, if it was a moment ago (a key
  /// press opens it in the middle instead).
  static Offset? get recent =>
      _at != null && DateTime.now().difference(_at!) < const Duration(seconds: 2) ? _last : null;
}

/// A small confirmation that opens beside the button pressed (Ant Design's
/// Popconfirm): for a light, local step such as removing a note or archiving
/// a site. Steps that move stock, cannot be undone, or need more than a
/// yes/no keep a full dialog. True only when the OK button is pressed;
/// Esc, Cancel or a click elsewhere answer false.
Future<bool> showPopconfirm(
  BuildContext context, {
  required String title,
  String? message,
  String? okLabel,
  String? cancelLabel,
  Key? okKey,
  Key? cancelKey,
  bool danger = false,
  IconData? icon,
}) async {
  final anchor = PopconfirmAnchor.recent;
  final l10n = AppLocalizations.of(context);
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 125),
    pageBuilder: (c, _, __) => _Popconfirm(
      anchor: anchor,
      title: title,
      message: message,
      okLabel: okLabel ?? l10n.actionOk,
      cancelLabel: cancelLabel ?? l10n.actionCancel,
      okKey: okKey,
      cancelKey: cancelKey,
      danger: danger,
      icon: icon,
    ),
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
    ),
  );
  return r == true;
}

class _Popconfirm extends StatelessWidget {
  const _Popconfirm({
    required this.anchor,
    required this.title,
    required this.message,
    required this.okLabel,
    required this.cancelLabel,
    required this.okKey,
    required this.cancelKey,
    required this.danger,
    required this.icon,
  });

  final Offset? anchor;
  final String title;
  final String? message;
  final String okLabel;
  final String cancelLabel;
  final Key? okKey;
  final Key? cancelKey;
  final bool danger;
  final IconData? icon;

  static const _width = 320.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = Material(
      key: const ValueKey('popconfirm'),
      type: MaterialType.card,
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? (danger ? Icons.error_outline : Icons.help_outline),
                  size: 20, color: danger ? scheme.error : scheme.warningIcon),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(message!,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppSpacing.xs,
              overflowSpacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: cancelKey ?? const ValueKey('popconfirm-cancel'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 32), visualDensity: VisualDensity.compact),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
                FilledButton(
                  key: okKey ?? const ValueKey('popconfirm-ok'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: danger ? scheme.error : null,
                    foregroundColor: danger ? scheme.onError : null,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(okLabel),
                ),
              ]),
        ]),
      ),
    );

    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Actions(
        actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => Navigator.of(context).pop(false))},
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(builder: (context, box) {
            final size = box.biggest;
            final width = _width.clamp(0.0, size.width - 2 * AppSpacing.md);
            if (anchor == null) {
              return Center(child: SizedBox(width: width, child: card));
            }
            // Beside the click: below it, or above when there is no room.
            final left = (anchor!.dx - width / 2).clamp(AppSpacing.md, size.width - width - AppSpacing.md).toDouble();
            final below = anchor!.dy + 14;
            final roomBelow = size.height - below;
            return Stack(children: [
              Positioned(
                left: left,
                width: width,
                top: roomBelow >= 150 ? below : null,
                bottom: roomBelow >= 150 ? null : (size.height - anchor!.dy + 14),
                child: card,
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

extension on ColorScheme {
  /// The caution icon: amber on light, a lighter amber on dark.
  Color get warningIcon => brightness == Brightness.light ? const Color(0xFFB98900) : const Color(0xFFEEC448);
}
