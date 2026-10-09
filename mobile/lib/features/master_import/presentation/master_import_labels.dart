import '../../../core/export/save_bytes.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../l10n/app_localizations.dart';
import '../data/master_import_repository.dart';
import '../domain/master_import.dart';

/// What a problem says, without its line.
String masterProblemText(AppLocalizations l10n, MasterProblem p) => switch (p.code) {
      'jan_missing' => l10n.miPbJanMissing,
      'jan_invalid' => l10n.miPbJanInvalid(p.value ?? ''),
      'jan_duplicate' => l10n.miPbJanDuplicate(p.value ?? ''),
      'name_missing' => l10n.miPbNameMissing,
      'qty_invalid' => l10n.miPbQtyInvalid(p.value ?? ''),
      'qty_missing' => l10n.miPbQtyMissing,
      'ai_disagree' => l10n.miPbAiDisagree,
      'totals_mismatch' => l10n.miPbTotals,
      'unverified' => l10n.miPbUnverified,
      'no_lines' => l10n.miPbNoLines,
      'name_en_missing' => l10n.miPbNameEnMissing,
      'read_failed' => l10n.miPbReadFailed(p.value ?? ''),
      'ai_unavailable' => switch (p.value) {
          'quota' => l10n.miPbAiQuota,
          'auth' => l10n.miPbAiAuth,
          'no_key' => l10n.miPbAiNoKey,
          _ => l10n.miPbAiDown,
        },
      _ => p.code,
    };

/// The line it is on ("3行目"), or the file as a whole.
String masterProblemWhere(AppLocalizations l10n, MasterProblem p) =>
    p.lineNo > 0 ? l10n.miLine(p.lineNo) : l10n.miFile;

String masterStatusLabel(AppLocalizations l10n, MasterImportStatus s) => switch (s) {
      MasterImportStatus.reading => l10n.miStatusReading,
      MasterImportStatus.stopped => l10n.miStatusStopped,
      MasterImportStatus.masterDone => l10n.miStatusMasterDone,
      MasterImportStatus.stockDone => l10n.miStatusStockDone,
      MasterImportStatus.cancelled => l10n.miStatusCancelled,
    };

/// Saves bytes where the person chooses (a download on the web).
typedef SaveBytes = Future<void> Function(String fileName, Uint8List bytes);

Future<void> saveBytesWithPicker(String fileName, Uint8List bytes) async {
  await saveBytes(fileName, bytes);
}

/// Downloads one kept file of an import.
Future<void> downloadMasterFile(BuildContext context, WidgetRef ref, MasterImportFile f, {SaveBytes? save}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(masterImportRepositoryProvider).download(f.path);
  switch (r) {
    case ApiSuccess(:final data):
      await (save ?? saveBytesWithPicker)(f.name, data);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.miDownloaded)));
    case ApiFailure(:final message):
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

String masterFileLabel(AppLocalizations l10n, MasterImportFile f) => switch (f.kind) {
      'original' => l10n.miDownloadOriginal,
      'converted' => l10n.miDownloadConverted,
      _ => l10n.miDownloadCorrected,
    };
