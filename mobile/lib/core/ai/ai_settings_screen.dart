import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/application/delivery_providers.dart';
import '../../l10n/app_localizations.dart';
import '../api/api_error_text.dart';
import '../theme/app_spacing.dart';
import '../ui/state_views.dart';
import 'ai_confidence.dart';
import 'ai_keys_section.dart';
import '../../features/auth/application/auth_controller.dart';

/// AI設定 (spec §50): the two thresholds that decide what a person has to do
/// with a reading — automatic candidate, check recommended, human review.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  double? _auto;
  double? _review;
  bool _busy = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final t = ref.read(aiThresholdsProvider).valueOrNull ?? const AiThresholds();
    setState(() => _busy = true);
    final r = await saveAiThresholds(ref.read(restDioProvider), _auto ?? t.auto, _review ?? t.review);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        ref.invalidate(aiThresholdsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.aiSaved)));
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)), backgroundColor: Theme.of(context).colorScheme.error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final canManageKeys = (user?.hasPermission('ai.key_manage') ?? false) || (user?.hasPermission('user.manage') ?? false);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featAiSettings)),
      body: ref.watch(aiThresholdsProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(aiThresholdsProvider)),
            data: (t) {
              final auto = _auto ?? t.auto;
              final review = _review ?? t.review;
              final current = AiThresholds(auto: auto, review: review);
              Widget example(double c) {
                final band = confidenceBand(c, current);
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, color: confidenceColor(band), size: 14),
                  title: Text('${(c * 100).round()}%'),
                  trailing: Text(confidenceBandLabel(l10n, band)),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(l10n.aiSettingsIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('${l10n.aiAutoThreshold}: ${(auto * 100).round()}%', style: theme.textTheme.titleSmall),
                  Slider(
                    key: const ValueKey('ai-auto'),
                    value: auto,
                    min: 0.5,
                    max: 1,
                    divisions: 50,
                    onChanged: (v) => setState(() {
                      _auto = v;
                      if ((_review ?? t.review) > v) _review = v;
                    }),
                  ),
                  Text('${l10n.aiReviewThreshold}: ${(review * 100).round()}%', style: theme.textTheme.titleSmall),
                  Slider(
                    key: const ValueKey('ai-review'),
                    value: review,
                    min: 0.3,
                    max: 1,
                    divisions: 70,
                    onChanged: (v) => setState(() {
                      _review = v;
                      if ((_auto ?? t.auto) < v) _auto = v;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.aiExample, style: theme.textTheme.labelLarge),
                  for (final c in const [0.99, 0.94, 0.85, 0.71, 0.63]) example(c),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    key: const ValueKey('ai-save'),
                    onPressed: _busy || (_auto == null && _review == null) ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.actionSave),
                  ),
                  // Which Gemini API key the AI is called with (0137), for
                  // whoever may manage the keys.
                  if (canManageKeys) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const AiKeysSection(),
                  ],
                ],
              );
            },
          ),
    );
  }
}
