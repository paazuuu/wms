import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/sender_profile.dart';
import 'sender_settings_screen.dart';

/// Asks which sender (差出人) fields to include on this print, starting from the
/// saved default. Returns the chosen lines (empty = print without a sender), or
/// null if the operator cancelled. When nothing is saved yet, prints without a
/// sender rather than blocking.
Future<List<SenderLine>?> showSenderPicker(
  BuildContext context,
  SenderProfile profile,
) {
  if (profile.isEmpty) return Future.value(const <SenderLine>[]);

  final selected = {...profile.defaultEnabled};
  var include = selected.isNotEmpty;
  final available =
      SenderProfile.fieldKeys.where((k) => profile.valueOf(k).trim().isNotEmpty);

  return showDialog<List<SenderLine>>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.senderPickTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.senderInclude),
                  value: include,
                  onChanged: (v) => setState(() => include = v),
                ),
                const Divider(height: 1),
                for (final k in available)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    enabled: include,
                    value: selected.contains(k),
                    title: Text(senderFieldLabel(l10n, k)),
                    subtitle: Text(profile.printText(k),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: include
                        ? (v) => setState(() {
                              if (v == true) {
                                selected.add(k);
                              } else {
                                selected.remove(k);
                              }
                            })
                        : null,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                include ? profile.lines(only: selected) : const <SenderLine>[],
              ),
              child: Text(l10n.printMenu),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the sender settings screen.
Future<void> openSenderSettings(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const SenderSettingsScreen()));
