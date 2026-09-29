import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notation_providers.dart';
import 'notation_labels.dart';

/// Asks whoever is checking a line whether the reader's warning was right
/// (0113), and records the answer so the rules can be tuned from what
/// actually happened.
Future<void> showWarningReport(
  BuildContext context,
  WidgetRef ref, {
  required String flag,
  int? partnerId,
  Map<String, dynamic>? line,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final answer = await showDialog<({bool right, String note})>(
    context: context,
    builder: (_) => _WarningReportDialog(flag: flag),
  );
  if (answer == null) return;
  final r = await ref.read(notationRepositoryProvider).reportWarning(
        partnerId: partnerId,
        flag: flag,
        right: answer.right,
        line: line,
        note: answer.note.isEmpty ? null : answer.note,
      );
  r.when(
    success: (_) {
      ref.invalidate(warningStatsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.wrThanks)));
    },
    failure: (f) => messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
  );
}

class _WarningReportDialog extends StatefulWidget {
  const _WarningReportDialog({required this.flag});

  final String flag;

  @override
  State<_WarningReportDialog> createState() => _WarningReportDialogState();
}

class _WarningReportDialogState extends State<_WarningReportDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.wrTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('⚠ ${flagLabel(l10n, widget.flag)}', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.wrQuestion, style: theme.textTheme.bodyMedium),
        TextField(
          key: const ValueKey('wr-note'),
          controller: _note,
          maxLines: 2,
          decoration: InputDecoration(labelText: l10n.wrNote, hintText: l10n.wrNoteHint),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        OutlinedButton(
          key: const ValueKey('wr-wrong'),
          onPressed: () => Navigator.pop(context, (right: false, note: _note.text.trim())),
          child: Text(l10n.wrWrong),
        ),
        FilledButton(
          key: const ValueKey('wr-right'),
          onPressed: () => Navigator.pop(context, (right: true, note: _note.text.trim())),
          child: Text(l10n.wrRight),
        ),
      ],
    );
  }
}
