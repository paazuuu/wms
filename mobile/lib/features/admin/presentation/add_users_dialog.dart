import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/admin_providers.dart';
import '../data/user_provisioning_repository.dart';
import '../domain/user_tier.dart';
import 'menu_visibility_screen.dart' show userTierLabel;

/// ユーザーを追加: people pasted from a sheet (email and 区分 a line), checked,
/// then made — each new account with a temporary password shown once to
/// hand over.
Future<void> addUsers(BuildContext context, WidgetRef ref) async {
  final users = await showDialog<List<NewUser>>(context: context, builder: (_) => const _AddUsersDialog());
  if (users == null || users.isEmpty || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final r = await ref.read(userProvisioningRepositoryProvider).create(users);
  if (!context.mounted) return;
  switch (r) {
    case ApiSuccess(:final data):
      ref.invalidate(adminUsersProvider);
      await showDialog<void>(context: context, builder: (_) => _ResultsDialog(results: data));
    case ApiFailure(:final message):
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

/// A new temporary password for one person, shown once.
Future<void> resetUserPassword(BuildContext context, WidgetRef ref, {required String userId, required String email}) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.umResetQ(email)),
      content: Text(l10n.umResetBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('um-reset-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.umReset)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await ref.read(userProvisioningRepositoryProvider).resetPassword(userId);
  if (!context.mounted) return;
  switch (r) {
    case ApiSuccess(:final data):
      await showDialog<void>(
        context: context,
        builder: (_) => _ResultsDialog(results: [
          ProvisionResult(email: email, tier: UserTier.user, status: 'reset', password: data),
        ], showTier: false),
      );
    case ApiFailure(:final message):
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

class _AddUsersDialog extends StatefulWidget {
  const _AddUsersDialog();

  @override
  State<_AddUsersDialog> createState() => _AddUsersDialogState();
}

class _AddUsersDialogState extends State<_AddUsersDialog> {
  final _text = TextEditingController();
  List<NewUser> _users = const [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('um-add-dialog'),
      title: Text(l10n.umAdd),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.umAddHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('um-add-text'),
              controller: _text,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'info@example.com\t普通\nadmin@example.com\t管理',
              ),
              onChanged: (t) => setState(() => _users = parseNewUsers(t)),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (i, u) in _users.indexed)
              Row(key: ValueKey('um-add-row-$i'), children: [
                Expanded(child: Text(u.name == null ? u.email : '${u.email}（${u.name}）', overflow: TextOverflow.ellipsis)),
                DropdownButton<UserTier>(
                  key: ValueKey('um-add-tier-$i'),
                  value: u.tier,
                  items: [
                    for (final t in UserTier.values) DropdownMenuItem(value: t, child: Text(userTierLabel(l10n, t))),
                  ],
                  onChanged: (t) => setState(() {
                    _users = [..._users]..[i] = NewUser(email: u.email, tier: t ?? u.tier, name: u.name);
                  }),
                ),
              ]),
            if (_users.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.umAddRoles, style: theme.textTheme.bodySmall),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('um-add-ok'),
          onPressed: _users.isEmpty ? null : () => Navigator.pop(context, _users),
          child: Text(l10n.umAddN(_users.length)),
        ),
      ],
    );
  }
}

class _ResultsDialog extends StatelessWidget {
  const _ResultsDialog({required this.results, this.showTier = true});

  final List<ProvisionResult> results;
  final bool showTier;

  String _status(AppLocalizations l10n, ProvisionResult r) => switch (r.status) {
        'created' => l10n.umCreated,
        'existing' => l10n.umExisting,
        'reset' => l10n.umResetDone,
        _ => l10n.umFailed(r.error ?? ''),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final copy = [
      for (final r in results)
        if (r.password != null) [r.email, if (showTier) userTierLabel(l10n, r.tier), r.password!].join('\t'),
    ].join('\n');
    return AlertDialog(
      key: const ValueKey('um-results'),
      title: Text(l10n.umResultsTitle),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (copy.isNotEmpty)
              Text(l10n.umPasswordOnce, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
              children: [
                for (final r in results)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(r.email)),
                    Text(showTier ? userTierLabel(l10n, r.tier) : ''),
                    Text(_status(l10n, r), style: TextStyle(color: r.ok ? null : theme.colorScheme.error)),
                    SelectableText(r.password ?? '', key: ValueKey('um-pw-${r.email}'),
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ]),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.umAfterHint, style: theme.textTheme.bodySmall),
          ]),
        ),
      ),
      actions: [
        if (copy.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('um-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: copy));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.umCopied)));
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.umCopy),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.umClose)),
      ],
    );
  }
}

/// The signed-in user's own password, changed (twice typed, 8 or more).
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_a.text.length < 8) {
      setState(() => _error = l10n.pwTooShort);
      return;
    }
    if (_a.text != _b.text) {
      setState(() => _error = l10n.pwMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(userProvisioningRepositoryProvider).changeOwnPassword(_a.text);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pwChanged)));
        Navigator.pop(context);
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey('pw-dialog'),
      title: Text(l10n.pwChange),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const ValueKey('pw-new'),
            controller: _a,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.pwNew, helperText: l10n.pwRule),
          ),
          TextField(
            key: const ValueKey('pw-again'),
            controller: _b,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.pwAgain, errorText: _error),
            onSubmitted: (_) => _save(),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('pw-save'), onPressed: _busy ? null : _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
