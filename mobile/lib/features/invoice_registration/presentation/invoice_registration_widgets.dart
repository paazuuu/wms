import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../l10n/app_localizations.dart';
import '../data/invoice_registration_repository.dart';
import '../domain/invoice_registration.dart';

/// 国税庁の公表サイト, for a person to look by hand.
const ntaPublicationSite = 'https://www.invoice-kohyo.nta.go.jp/';

final _day = DateFormat('y/MM/dd');

/// A registration in words, with what it says of the invoice's [company].
List<(IconData, Color, String)> registrationLines(
    AppLocalizations l10n, ColorScheme scheme, InvoiceRegistration r, String? company) {
  String d(DateTime? t) => t == null ? '' : _day.format(t);
  return switch (r.status) {
    RegStatus.valid => [
        (Icons.verified_outlined, scheme.primary, l10n.irRegistered(r.name ?? r.number)),
        if ((company ?? '').trim().isNotEmpty)
          r.names(company)
              ? (Icons.check, scheme.primary, l10n.irNameMatches)
              : (Icons.warning_amber_rounded, scheme.error, l10n.irNameDiffers(company!.trim())),
      ],
    RegStatus.notFound => [(Icons.help_outline, scheme.error, l10n.irNotFound)],
    RegStatus.revoked => [(Icons.block, scheme.error, l10n.irRevoked(d(r.disposalDate)))],
    RegStatus.expired => [(Icons.event_busy_outlined, scheme.error, l10n.irExpired(d(r.expireDate)))],
  };
}

/// 登録番号の確認 beside a document's (or our own) 登録番号: registered and in
/// force under which name, the name against [company], or why not; asked
/// again on a tap. Nothing when [number] is not one.
class InvoiceRegistrationBadge extends ConsumerWidget {
  const InvoiceRegistrationBadge({super.key, required this.number, this.company});

  final String? number;

  /// The company the document prints, to set beside the registered name.
  final String? company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = normalizeRegNo(number);
    if (n == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    Widget line(IconData icon, Color color, String text, {Key? key}) => Row(key: key, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(text, style: small?.copyWith(color: color))),
        ]);
    final async = ref.watch(invoiceRegistrationProvider(n));
    return Padding(
      key: ValueKey('ir-badge-$n'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: async.when(
        loading: () => const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => line(Icons.error_outline, scheme.error, l10n.irFailed(humanizeApiErrorMessage(l10n, '$e'))),
        data: (check) {
          final r = check.of(n);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (r != null)
              for (final (i, (icon, color, text)) in registrationLines(l10n, scheme, r, company).indexed)
                line(icon, color, text, key: ValueKey('ir-line-$n-$i')),
            if (r == null && !check.configured)
              line(Icons.info_outline, scheme.onSurfaceVariant, l10n.irNotConfigured, key: ValueKey('ir-unset-$n')),
            if (check.failure != null)
              line(Icons.cloud_off_outlined, scheme.error, l10n.irFailed(check.failure!), key: ValueKey('ir-failed-$n')),
            Wrap(spacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (r?.checkedAt != null)
                Text(l10n.irCheckedAt(_day.format(r!.checkedAt!)), style: small?.copyWith(color: scheme.onSurfaceVariant)),
              if (check.configured)
                TextButton(
                  key: ValueKey('ir-refresh-$n'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () async {
                    await ref.read(invoiceRegistrationRepositoryProvider).check([n], refresh: true);
                    ref.invalidate(invoiceRegistrationProvider(n));
                  },
                  child: Text(l10n.irRefresh),
                )
              else
                TextButton(
                  key: ValueKey('ir-site-$n'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => openExternalUrl(ntaPublicationSite),
                  child: Text(l10n.irOpenSite),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// 登録番号の確認 by hand: numbers typed or pasted, each one's answer.
Future<void> showInvoiceCheckDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _InvoiceCheckDialog());

class _InvoiceCheckDialog extends ConsumerStatefulWidget {
  const _InvoiceCheckDialog();

  @override
  ConsumerState<_InvoiceCheckDialog> createState() => _InvoiceCheckDialogState();
}

class _InvoiceCheckDialogState extends ConsumerState<_InvoiceCheckDialog> {
  final _text = TextEditingController();
  InvoiceCheck? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final given = _text.text.split(RegExp(r'[\n,、，\t]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (given.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(invoiceRegistrationRepositoryProvider).check(given, refresh: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case ApiSuccess(:final data):
          _result = data;
          _error = null;
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final r = _result;
    return AlertDialog(
      key: const ValueKey('ir-dialog'),
      title: Text(l10n.irTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('ir-input'),
              controller: _text,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(hintText: l10n.irInputHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
            if (r != null) ...[
              if (!r.configured) Text(l10n.irNotConfigured, key: const ValueKey('ir-dialog-unset'), style: muted),
              if (r.failure != null) Text(l10n.irFailed(r.failure!), style: TextStyle(color: scheme.error)),
              for (final b in r.bad) Text(l10n.irBadFormat(b), style: TextStyle(color: scheme.error)),
              for (final x in r.results)
                Card(
                  key: ValueKey('ir-result-${x.number}'),
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SelectableText(x.number, style: theme.textTheme.titleSmall),
                      for (final (icon, color, text) in registrationLines(l10n, scheme, x, null))
                        Row(children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(child: Text(text, style: TextStyle(color: color))),
                        ]),
                      if (x.kind != null)
                        Text(x.kind == 'individual' ? l10n.irIndividual : l10n.irCorporation, style: muted),
                      if (x.address != null) Text(l10n.irAddress(x.address!), style: muted),
                      if (x.registrationDate != null) Text(l10n.irRegisteredOn(_day.format(x.registrationDate!)), style: muted),
                    ]),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.irNotice, style: muted),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => openExternalUrl(ntaPublicationSite), child: Text(l10n.irOpenSite)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).closeButtonLabel)),
        FilledButton(
          key: const ValueKey('ir-check'),
          onPressed: _busy ? null : _check,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.irCheck),
        ),
      ],
    );
  }
}

/// 自社情報: the Web-API's アプリケーションID, set (never shown back) by the
/// system administrator.
class NtaKeyCard extends ConsumerStatefulWidget {
  const NtaKeyCard({super.key});

  @override
  ConsumerState<NtaKeyCard> createState() => _NtaKeyCardState();
}

class _NtaKeyCardState extends ConsumerState<NtaKeyCard> {
  final _id = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await ref.read(invoiceRegistrationRepositoryProvider).setKey(value);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        _id.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.irKeySaved)));
        ref.invalidate(ntaKeyStatusProvider);
        ref.invalidate(invoiceRegistrationProvider);
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final status = ref.watch(ntaKeyStatusProvider).valueOrNull;
    return Card(
      key: const ValueKey('ir-key-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.irKeyTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.irKeyHelp, style: muted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            status == null
                ? ''
                : status.set
                    ? l10n.irKeySet(status.updatedAt == null ? '' : _day.format(status.updatedAt!), status.updatedBy ?? '')
                    : l10n.irKeyUnset,
            key: const ValueKey('ir-key-status'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('ir-key-field'),
            controller: _id,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.irKeyField, border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, children: [
            FilledButton(
              key: const ValueKey('ir-key-save'),
              onPressed: _busy ? null : () => _id.text.trim().isEmpty ? null : _save(_id.text.trim()),
              child: Text(l10n.irKeySave),
            ),
            if (status?.set ?? false)
              TextButton(
                key: const ValueKey('ir-key-clear'),
                onPressed: _busy ? null : () => _save(''),
                child: Text(l10n.irKeyClear),
              ),
            TextButton(onPressed: () => openExternalUrl(ntaPublicationSite), child: Text(l10n.irOpenSite)),
          ]),
        ]),
      ),
    );
  }
}
