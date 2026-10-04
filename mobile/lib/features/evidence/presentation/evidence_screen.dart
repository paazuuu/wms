import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/evidence_providers.dart';
import '../domain/import_document.dart';

String evidencePurposeLabel(AppLocalizations l10n, EvidencePurpose p) => switch (p) {
      EvidencePurpose.plan => l10n.evPurposePlan,
      EvidencePurpose.shipment => l10n.evPurposeShipment,
      EvidencePurpose.training => l10n.evPurposeTraining,
      EvidencePurpose.quote => l10n.evPurposeQuote,
      EvidencePurpose.priceBook => l10n.evPurposePriceBook,
      EvidencePurpose.library => l10n.evPurposeLibrary,
      EvidencePurpose.ocr => l10n.evPurposeOcr,
    };

/// Saves one kept file where the person chooses (a download on the web).
Future<void> downloadEvidence(BuildContext context, WidgetRef ref, ImportDocument doc) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(evidenceRepositoryProvider).download(doc);
  switch (r) {
    case ApiSuccess(:final data):
      final ext = doc.fileName.contains('.') ? doc.fileName.split('.').last : null;
      final saved = await FilePicker.platform.saveFile(
        fileName: doc.fileName,
        bytes: data,
        type: ext == null ? FileType.any : FileType.custom,
        allowedExtensions: ext == null ? null : [ext],
      );
      if (saved != null || data.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.evDownloaded)));
      }
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

/// アップロード履歴 (0132): every file read for inbound, outbound, quotes,
/// the price book, the product library or training, kept as evidence —
/// what it was read as, who sent it in, the plan it became — and downloadable
/// again.
class EvidenceScreen extends ConsumerWidget {
  const EvidenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final purpose = ref.watch(evidencePurposeProvider);
    final async = ref.watch(evidenceListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featEvidence)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: TextField(
            key: const ValueKey('ev-search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.evSearch,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (v) => ref.read(evidenceSearchProvider.notifier).state = v,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                key: const ValueKey('ev-all'),
                label: Text(l10n.evAll),
                selected: purpose == null,
                onSelected: (_) => ref.read(evidencePurposeProvider.notifier).state = null,
              ),
            ),
            for (final p in EvidencePurpose.values)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  key: ValueKey('ev-purpose-${p.wire}'),
                  label: Text(evidencePurposeLabel(l10n, p)),
                  selected: purpose == p,
                  onSelected: (_) => ref.read(evidencePurposeProvider.notifier).state = p,
                ),
              ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(
              message: humanizeApiErrorMessage(l10n, '$e'),
              onRetry: () => ref.invalidate(evidenceListProvider),
            ),
            data: (docs) => docs.isEmpty
                ? EmptyStateView(icon: Icons.folder_open_outlined, title: l10n.evEmpty, message: l10n.evEmptyBody)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(evidenceListProvider),
                    child: ListView.builder(
                      key: const ValueKey('ev-list'),
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => EvidenceCard(doc: docs[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class EvidenceCard extends ConsumerWidget {
  const EvidenceCard({super.key, required this.doc});

  final ImportDocument doc;

  IconData get _icon {
    final n = doc.fileName.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (RegExp(r'\.(xlsx|xlsm|xls|csv)$').hasMatch(n)) return Icons.table_chart_outlined;
    return Icons.image_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final when = DateFormat('yyyy-MM-dd HH:mm').format(doc.uploadedAt);
    final size = doc.byteSize == null
        ? null
        : doc.byteSize! >= 1024 * 1024
            ? '${(doc.byteSize! / 1024 / 1024).toStringAsFixed(1)} MB'
            : '${(doc.byteSize! / 1024).ceil()} KB';
    return Card(
      key: ValueKey('ev-${doc.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_icon, size: 32, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.fileName, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                StatusPill(tone: StatusTone.info, label: evidencePurposeLabel(l10n, doc.purpose), dense: true),
                StatusPill(
                  tone: doc.committed ? StatusTone.success : StatusTone.neutral,
                  label: doc.committed ? l10n.evCommitted(doc.referenceNo ?? doc.docNumber ?? '') : l10n.evNotCommitted,
                  dense: true,
                ),
              ]),
              const SizedBox(height: AppSpacing.xs),
              if (doc.supplierName != null) Text(doc.supplierName!, style: theme.textTheme.bodyMedium),
              Text(
                [
                  if (doc.docNumber != null) doc.docNumber!,
                  if (doc.docDate != null) doc.docDate!,
                  if (doc.lineCount != null) l10n.evLines(doc.lineCount!),
                  if (size != null) size,
                ].join(' · '),
                style: muted,
              ),
              Text([when, if (doc.uploadedByName != null) doc.uploadedByName!].join(' · '), style: muted),
            ]),
          ),
          IconButton(
            key: ValueKey('ev-download-${doc.id}'),
            tooltip: l10n.evDownload,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => downloadEvidence(context, ref, doc),
          ),
        ]),
      ),
    );
  }
}
