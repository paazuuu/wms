import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Which rows go to Excel: the ones the screen shows now (its search and
/// filters), or every row.
enum ExportScope { shown, all }

/// An app-bar button offering both: 表示中のN件 and 全件. [shown] is how many
/// the screen shows; the whole count is not known until it is fetched.
class ExcelExportMenu extends StatelessWidget {
  const ExcelExportMenu({super.key, required this.shown, required this.onExport, this.keyPrefix = 'xl'});

  final int shown;
  final void Function(ExportScope scope) onExport;

  /// Keys of the button and its two choices: `<prefix>-export`,
  /// `<prefix>-export-shown`, `<prefix>-export-all`.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ExportScope>(
      key: ValueKey('$keyPrefix-export'),
      tooltip: l10n.xlExport,
      icon: const Icon(Icons.file_download_outlined),
      onSelected: onExport,
      itemBuilder: (_) => [
        PopupMenuItem(
          key: ValueKey('$keyPrefix-export-shown'),
          value: ExportScope.shown,
          enabled: shown > 0,
          child: ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: Text(l10n.xlExportShown(shown)),
            subtitle: Text(l10n.xlExportShownHint),
          ),
        ),
        PopupMenuItem(
          key: ValueKey('$keyPrefix-export-all'),
          value: ExportScope.all,
          child: ListTile(
            leading: const Icon(Icons.select_all),
            title: Text(l10n.xlExportAll),
            subtitle: Text(l10n.xlExportAllHint),
          ),
        ),
      ],
    );
  }
}
