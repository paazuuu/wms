import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/open_window.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/jan_catalog_repository.dart';
import '../data/pdf_catalog_import.dart';
import '../data/pdf_text.dart';

/// Reads a PDF's text in the browser; null where it cannot (see [pdfTextReader]).
final pdfTextReaderProvider = Provider<PdfTextReader?>((ref) => pdfTextReader());

/// Asks for a PDF file: its name and bytes, or null.
final pdfCatalogPickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((ref) => () async {
      final r = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final f = r?.files.firstOrNull;
      if (f?.bytes == null) return null;
      return (name: f!.name, bytes: f.bytes!);
    });

/// JANカタログ (0153): the makers' catalogs read for their JAN codes — the
/// list, one more by its URL, read again, or forgotten.
class JanCatalogScreen extends ConsumerStatefulWidget {
  const JanCatalogScreen({super.key, this.canManage = true});

  /// Adding, reading again and deleting (product.manage); else only the list.
  final bool canManage;

  @override
  ConsumerState<JanCatalogScreen> createState() => _JanCatalogScreenState();
}

class _JanCatalogScreenState extends ConsumerState<JanCatalogScreen> {
  final _url = TextEditingController();
  final _pdfName = TextEditingController();
  final _pdfMaker = TextEditingController();
  final _pdfUrl = TextEditingController();

  /// The URL being read, while it is, and how far.
  String? _busy;
  (int, int)? _steps;

  /// A PDF being read, and how far.
  PdfImportProgress? _pdf;
  bool _pdfBusy = false;

  bool get _anyBusy => _busy != null || _pdfBusy;

  @override
  void dispose() {
    _url.dispose();
    _pdfName.dispose();
    _pdfMaker.dispose();
    _pdfUrl.dispose();
    super.dispose();
  }

  Future<void> _readPdf() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reader = ref.read(pdfTextReaderProvider);
    if (reader == null) return;
    final file = await ref.read(pdfCatalogPickerProvider)();
    if (file == null || !mounted) return;
    setState(() {
      _pdfBusy = true;
      _pdf = null;
    });
    final r = await importPdfCatalog(
      repo: ref.read(janCatalogRepositoryProvider),
      reader: reader,
      bytes: file.bytes,
      fileName: file.name,
      name: _pdfName.text,
      maker: _pdfMaker.text,
      url: _pdfUrl.text,
      onProgress: (p) {
        if (mounted) setState(() => _pdf = p);
      },
    );
    if (!mounted) return;
    final weights = _pdf?.weights ?? 0;
    setState(() => _pdfBusy = false);
    ref.invalidate(janCatalogsProvider);
    switch (r) {
      case ApiSuccess(:final data) when data.entryCount > 0:
        _pdfName.clear();
        _pdfMaker.clear();
        _pdfUrl.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.jcDoneWeights(data.entryCount, weights))));
      case ApiSuccess():
        messenger.showSnackBar(SnackBar(content: Text(l10n.jcNoJan), backgroundColor: scheme.error));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(
            content: Text(message.startsWith('pdf_unreadable') ? l10n.jcPdfUnreadable : _error(l10n, message)),
            backgroundColor: scheme.error));
    }
  }

  String _error(AppLocalizations l10n, String message) {
    if (message.contains('jan_catalog_bad_url')) return l10n.jcBadUrl;
    if (message.contains('jan_catalog_unreachable')) return l10n.jcUnreachable;
    if (message.contains('jan_catalog_empty')) return l10n.jcNoJan;
    if (message.contains('jan_catalog_no_pdf')) return l10n.jcNoPdf;
    return humanizeApiErrorMessage(l10n, message);
  }

  Future<void> _sync(String url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (url.trim().isEmpty) return;
    setState(() {
      _busy = url;
      _steps = null;
    });
    final r = await ref.read(janCatalogRepositoryProvider).sync(url.trim(), onProgress: (page, pages) {
      if (mounted) setState(() => _steps = (page, pages));
    });
    if (!mounted) return;
    setState(() => _busy = null);
    ref.invalidate(janCatalogsProvider);
    switch (r) {
      case ApiSuccess(:final data):
        if (url == _url.text) _url.clear();
        messenger.showSnackBar(SnackBar(content: Text(l10n.jcDone(data.entryCount))));
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(_error(l10n, message)), backgroundColor: scheme.error));
    }
  }

  Future<void> _delete(JanCatalog c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.jcDeleteConfirm(c.name ?? c.url)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('jc-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.jcDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(janCatalogRepositoryProvider).delete(c.id);
    ref.invalidate(janCatalogsProvider);
  }

  void _open(String url) {
    if (openExternalUrl(url)) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).rcCatalogCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final when = DateFormat('yyyy/MM/dd HH:mm');
    final async = ref.watch(janCatalogsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jcTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.jcIntro, style: muted),
          if (widget.canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('jc-url'),
              controller: _url,
              enabled: !_anyBusy,
              decoration: InputDecoration(labelText: l10n.jcUrl, hintText: l10n.jcUrlHint),
              onSubmitted: _sync,
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('jc-add'),
                onPressed: !_anyBusy ? () => _sync(_url.text) : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.jcAdd),
              ),
            ),
          ],
          if (_busy != null) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: _steps == null || _steps!.$2 == 0 ? null : _steps!.$1 / _steps!.$2),
            const SizedBox(height: AppSpacing.xs),
            Text(_steps == null ? l10n.jcSyncing : l10n.jcSyncingPages(_steps!.$1, _steps!.$2),
                key: const ValueKey('jc-syncing'), style: muted),
          ],
          if (widget.canManage) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.jcPdfTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.jcPdfIntro, style: muted),
            if (ref.watch(pdfTextReaderProvider) == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(l10n.jcPdfNeedsBrowser, key: const ValueKey('jc-pdf-browser'), style: muted),
              )
            else ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    key: const ValueKey('jc-pdf-name'),
                    controller: _pdfName,
                    enabled: !_anyBusy,
                    decoration: InputDecoration(labelText: l10n.jcPdfName),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: const ValueKey('jc-pdf-maker'),
                    controller: _pdfMaker,
                    enabled: !_anyBusy,
                    decoration: InputDecoration(labelText: l10n.jcPdfMaker),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: TextField(
                    key: const ValueKey('jc-pdf-url'),
                    controller: _pdfUrl,
                    enabled: !_anyBusy,
                    decoration: InputDecoration(labelText: l10n.jcPdfUrl),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('jc-pdf-pick'),
                  onPressed: !_anyBusy ? _readPdf : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(l10n.jcPdfPick),
                ),
              ),
            ],
            if (_pdfBusy) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: _pdf == null || _pdf!.pages == 0 ? null : _pdf!.page / _pdf!.pages),
              const SizedBox(height: AppSpacing.xs),
              if (_pdf case final p?)
                Text(l10n.jcPdfProgress(p.page, p.pages, p.entries, p.weights),
                    key: const ValueKey('jc-pdf-progress'), style: muted),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          ...async.when(
            loading: () => [const Center(child: CircularProgressIndicator())],
            error: (e, _) => [ErrorStateView(message: '$e', onRetry: () => ref.invalidate(janCatalogsProvider))],
            data: (list) => list.isEmpty
                ? [Text(l10n.jcEmpty, key: const ValueKey('jc-empty'), style: muted)]
                : [
                    for (final c in list)
                      Card(
                        key: ValueKey('jc-${c.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (c.isPdf) ...[
                                Chip(
                                  key: ValueKey('jc-pdf-${c.id}'),
                                  label: Text(l10n.jcPdfBadge),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Expanded(child: Text(c.name ?? c.url, style: theme.textTheme.titleMedium)),
                            ]),
                            if (c.maker != null || c.published != null || c.fileName != null)
                              Text([c.maker, c.published, if (c.isPdf) c.fileName].whereType<String>().join('・'),
                                  style: muted),
                            const SizedBox(height: AppSpacing.xs),
                            Text(l10n.jcCount(c.entryCount, c.pagesRead),
                                key: ValueKey('jc-count-${c.id}'), style: theme.textTheme.bodyMedium),
                            if (c.syncedAt != null) Text(l10n.jcSynced(when.format(c.syncedAt!)), style: muted),
                            if (c.syncError != null)
                              Text(l10n.jcError(c.syncError!),
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(spacing: AppSpacing.sm, children: [
                              if (c.url.startsWith('http'))
                                TextButton.icon(
                                  key: ValueKey('jc-open-${c.id}'),
                                  onPressed: () => _open(c.url),
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: Text(l10n.jcOpen),
                                ),
                              if (widget.canManage) ...[
                                // A PDF is read again by choosing it again.
                                if (!c.isPdf)
                                  TextButton.icon(
                                    key: ValueKey('jc-resync-${c.id}'),
                                    onPressed: !_anyBusy ? () => _sync(c.url) : null,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: Text(l10n.jcResync),
                                  ),
                                TextButton.icon(
                                  key: ValueKey('jc-delete-${c.id}'),
                                  onPressed: !_anyBusy ? () => _delete(c) : null,
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: Text(l10n.jcDelete),
                                ),
                              ],
                            ]),
                          ]),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}
