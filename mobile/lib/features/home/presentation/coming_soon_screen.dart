import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../domain/feature_entry.dart';

/// Generic placeholder for a feature whose backend API exists but whose mobile
/// screen has not been built yet. Keeps navigation coherent and communicates
/// that the capability is planned (not broken).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.feature});

  final FeatureEntry feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(feature.label)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(feature.icon,
                      size: 34, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                const StatusPill(
                  tone: StatusTone.info,
                  label: 'Coming soon',
                  icon: Icons.schedule,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  feature.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  feature.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'The server API for this is ready — the mobile screen '
                  'is next on the roadmap.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
