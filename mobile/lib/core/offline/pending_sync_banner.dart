import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_error_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pending_sync.dart';

/// The field screens' strip for a weak connection (spec §58): offline or
/// not, how many records wait on the device, a button to send them now, and
/// the records the server refused (with its reason). While anything waits it
/// retries by itself every [retryEvery].
class PendingSyncBanner extends ConsumerStatefulWidget {
  const PendingSyncBanner({super.key, required this.onSync, this.retryEvery = const Duration(seconds: 30)});

  /// Sends the queue; returns how many were sent.
  final Future<int> Function() onSync;
  final Duration retryEvery;

  @override
  ConsumerState<PendingSyncBanner> createState() => _PendingSyncBannerState();
}

class _PendingSyncBannerState extends ConsumerState<PendingSyncBanner> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Back in the app: the network may be back too.
    if (s == AppLifecycleState.resumed && ref.read(pendingSyncProvider).ops.isNotEmpty) _sync(silent: true);
  }

  void _arm(bool pending) {
    if (pending && _timer == null) {
      _timer = Timer.periodic(widget.retryEvery, (_) => _sync(silent: true));
    } else if (!pending && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  Future<void> _sync({bool silent = false}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sent = await widget.onSync();
    if (!mounted || silent) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.syncSent(sent))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(pendingSyncProvider);
    _arm(s.ops.isNotEmpty);
    if (s.ops.isEmpty && s.failed.isEmpty && !s.offline) return const SizedBox.shrink();
    final color = s.offline ? AppColors.warning : AppColors.info;
    return Container(
      key: const ValueKey('pending-sync-banner'),
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(s.offline ? Icons.cloud_off : Icons.cloud_upload_outlined, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                s.offline ? l10n.syncOffline(s.ops.length) : l10n.syncPending(s.ops.length),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (s.ops.isNotEmpty)
              TextButton(
                key: const ValueKey('pending-sync-now'),
                onPressed: s.syncing ? null : () => _sync(),
                child: s.syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.syncNow),
              ),
          ]),
          for (final f in s.failed)
            Row(children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.syncRefused(humanizeApiErrorMessage(l10n, f.error)),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger)),
              ),
              IconButton(
                tooltip: l10n.syncDismiss,
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => ref.read(pendingSyncProvider.notifier).dismissFailed(f),
              ),
            ]),
        ],
      ),
    );
  }
}
