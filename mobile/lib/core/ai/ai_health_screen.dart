import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_error_text.dart';
import '../api/api_result.dart';
import '../theme/app_spacing.dart';
import '../ui/state_views.dart';
import '../ui/status_pill.dart';
import 'ai_health.dart';

String aiVerdictLabel(AppLocalizations l10n, AiVerdict v) => switch (v) {
      AiVerdict.good => l10n.ahVerdictGood,
      AiVerdict.warn => l10n.ahVerdictWarn,
      AiVerdict.bad => l10n.ahVerdictBad,
      AiVerdict.unknown => l10n.ahVerdictUnknown,
    };

StatusTone aiVerdictTone(AiVerdict v) => switch (v) {
      AiVerdict.good => StatusTone.success,
      AiVerdict.warn => StatusTone.warning,
      AiVerdict.bad => StatusTone.danger,
      AiVerdict.unknown => StatusTone.neutral,
    };

String aiErrorKindLabel(AppLocalizations l10n, String? kind) => switch (kind) {
      'no_key' => l10n.ahKindNoKey,
      'auth' => l10n.ahKindAuth,
      'quota' => l10n.ahKindQuota,
      'overload' => l10n.ahKindOverload,
      'bad_request' => l10n.ahKindBadRequest,
      'network' => l10n.ahKindNetwork,
      'parse' => l10n.ahKindParse,
      _ => l10n.ahKindOther,
    };

/// A measure's value as shown: a rate in %, a time in seconds.
String aiMeasureValue(AiMeasure m, double? v) {
  if (v == null) return '—';
  return m.key == 'latency_p95' ? '${(v / 1000).toStringAsFixed(1)} s' : '${(v * 100).toStringAsFixed(1)}%';
}

/// AIの稼働状況 (0133): is the AI answering, how fast, and are its readings
/// holding up — each judged against a fixed formula, with the worst one as
/// the verdict, plus a one-tap connection test.
class AiHealthScreen extends ConsumerStatefulWidget {
  const AiHealthScreen({super.key});

  @override
  ConsumerState<AiHealthScreen> createState() => _AiHealthScreenState();
}

class _AiHealthScreenState extends ConsumerState<AiHealthScreen> {
  bool _pinging = false;
  AiPingResult? _ping;

  Future<void> _runPing() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _pinging = true);
    final r = await ref.read(aiHealthRepositoryProvider).ping();
    if (!mounted) return;
    setState(() => _pinging = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _ping = data);
        ref.invalidate(aiHealthProvider);
      case ApiFailure(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hours = ref.watch(aiHealthHoursProvider);
    final async = ref.watch(aiHealthProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featAiHealth),
        actions: [
          IconButton(
            tooltip: l10n.ahRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(aiHealthProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            for (final (h, label) in [(24, l10n.ahPeriod24h), (168, l10n.ahPeriod7d), (720, l10n.ahPeriod30d)])
              ChoiceChip(
                key: ValueKey('ah-period-$h'),
                label: Text(label),
                selected: hours == h,
                onSelected: (_) => ref.read(aiHealthHoursProvider.notifier).state = h,
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          _PingCard(busy: _pinging, result: _ping, onPing: _runPing),
          const SizedBox(height: AppSpacing.md),
          async.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: LoadingView(message: l10n.loading),
            ),
            error: (e, _) => ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '$e'),
              onRetry: () => ref.invalidate(aiHealthProvider),
            ),
            data: (h) => _HealthBody(health: h),
          ),
        ],
      ),
    );
  }
}

class _PingCard extends StatelessWidget {
  const _PingCard({required this.busy, required this.result, required this.onPing});

  final bool busy;
  final AiPingResult? result;
  final VoidCallback onPing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          FilledButton.tonalIcon(
            key: const ValueKey('ah-ping'),
            onPressed: busy ? null : onPing,
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: Text(l10n.ahPing),
          ),
          const SizedBox(width: AppSpacing.md),
          if (r != null)
            Expanded(
              child: Text(
                r.ok ? l10n.ahPingOk(r.latencyMs, r.model) : l10n.ahPingFailed(aiErrorKindLabel(l10n, r.errorKind)),
                key: const ValueKey('ah-ping-result'),
                style: TextStyle(
                  color: r.ok ? Colors.green.shade700 : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health});

  final AiHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final h = health;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final nf = NumberFormat.decimalPattern();
    final blocking = switch (h.blocking) {
      'no_key' => l10n.ahBlockingNoKey,
      'auth' => l10n.ahBlockingAuth,
      'quota' => l10n.ahBlockingQuota,
      _ => null,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        key: const ValueKey('ah-overall'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(l10n.featAiHealth, style: theme.textTheme.titleMedium),
              const Spacer(),
              StatusPill(tone: aiVerdictTone(h.overall), label: aiVerdictLabel(l10n, h.overall)),
            ]),
            if (blocking != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(blocking,
                  key: const ValueKey('ah-blocking'),
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.ahCalls(h.total, h.ok, h.failed), style: theme.textTheme.bodyMedium),
            Text(l10n.ahTokens(nf.format(h.inputTokens), nf.format(h.outputTokens)), style: muted),
            Text(l10n.ahFiles(h.files, h.aiFiles), style: muted),
            if (h.lastCallAt != null) Text(l10n.ahLastCall(df.format(h.lastCallAt!)), style: muted),
            if (h.lastOkAt != null) Text(l10n.ahLastOk(df.format(h.lastOkAt!)), style: muted),
          ]),
        ),
      ),
      for (final m in h.measures) _MeasureCard(measure: m),
      const SizedBox(height: AppSpacing.md),
      Text(l10n.ahHowJudged, style: theme.textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(l10n.ahHowJudgedBody, style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.lg),
      Text(l10n.ahRecentErrors, style: theme.textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      if (h.recentErrors.isEmpty)
        Text(l10n.ahNoErrors, key: const ValueKey('ah-no-errors'), style: muted)
      else
        for (final e in h.recentErrors)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
            title: Text([
              aiErrorKindLabel(l10n, e.kind),
              if (e.status != null) 'HTTP ${e.status}',
              if (e.task != null) e.task!,
            ].join(' · ')),
            subtitle: Text([if (e.at != null) df.format(e.at!), if (e.message != null) e.message!].join('\n'),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
    ]);
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({required this.measure});

  final AiMeasure measure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = measure;
    final (title, formula) = switch (m.key) {
      'availability' => (l10n.ahAvailability, l10n.ahAvailabilityFormula),
      'latency_p95' => (l10n.ahLatency, l10n.ahLatencyFormula),
      'agreement' => (l10n.ahAgreement, l10n.ahAgreementFormula),
      _ => (l10n.ahTotals, l10n.ahTotalsFormula),
    };
    final good = aiMeasureValue(m, m.good), warn = aiMeasureValue(m, m.warn);
    return Card(
      key: ValueKey('ah-measure-${m.key}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            Text(aiMeasureValue(m, m.value), style: theme.textTheme.titleMedium),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(tone: aiVerdictTone(m.verdict), label: aiVerdictLabel(l10n, m.verdict), dense: true),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(formula, style: theme.textTheme.bodySmall),
          Text(
            m.higherIsBetter ? l10n.ahThresholdHigher(good, warn) : l10n.ahThresholdLower(good, warn),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}
