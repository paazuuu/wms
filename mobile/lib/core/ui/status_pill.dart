import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Semantic tone for a status. Kept domain-agnostic so any feature can map
/// its own enum onto it (inspection status, match result, sync state...).
enum StatusTone { neutral, info, success, warning, danger }

class _ToneStyle {
  const _ToneStyle(this.fg, this.bg, this.ink);
  final Color fg; // strong color (icon / dot)
  final Color bg; // subtle background
  final Color ink; // readable text on [bg]
}

_ToneStyle _resolve(StatusTone tone, ColorScheme scheme) {
  switch (tone) {
    case StatusTone.success:
      return const _ToneStyle(
          AppColors.success, AppColors.successBg, AppColors.successInk);
    case StatusTone.warning:
      return const _ToneStyle(
          AppColors.warning, AppColors.warningBg, AppColors.warningInk);
    case StatusTone.danger:
      return const _ToneStyle(
          AppColors.danger, AppColors.dangerBg, AppColors.dangerInk);
    case StatusTone.info:
      return const _ToneStyle(
          AppColors.info, AppColors.infoBg, AppColors.infoInk);
    case StatusTone.neutral:
      return _ToneStyle(
          scheme.onSurfaceVariant, scheme.surfaceContainerHigh, scheme.onSurface);
  }
}

/// A compact, high-contrast status pill: coloured background + optional icon +
/// label. Conveys state with BOTH colour and text/icon (accessibility: never
/// colour alone).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.tone,
    required this.label,
    this.icon,
    this.dense = false,
  });

  final StatusTone tone;
  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _resolve(tone, scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: style.fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: style.ink,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// A round leading indicator (icon on a tinted circle) for list rows.
class StatusAvatar extends StatelessWidget {
  const StatusAvatar({super.key, required this.tone, required this.icon});

  final StatusTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _resolve(tone, scheme);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Icon(icon, color: style.fg, size: 24),
    );
  }
}
