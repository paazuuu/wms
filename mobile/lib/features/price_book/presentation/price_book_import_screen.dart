import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/product_name.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery/application/delivery_providers.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/product.dart';
import '../../partners/domain/trading_partner.dart';
import '../../product_library/data/quote_repository.dart';
import '../../product_library/domain/supplier_quote.dart';
import '../application/price_book_providers.dart';
import '../domain/price_book.dart';

/// The file reader (import-plan, preview only — nothing booked).
final fileReaderProvider = Provider<QuoteRepository>((ref) => QuoteRepositoryImpl(
      functions: ref.watch(deliveryDioProvider),
      rest: ref.watch(restDioProvider),
    ));

/// The suppliers a file's prices can be for.
final importSuppliersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final r = await ref.watch(tradingPartnerRepositoryProvider).list(status: 'active');
  return r.when(
    success: (d) => [for (final p in d) if (p.kind != PartnerKind.customer) p],
    failure: (f) => throw Exception(f.message),
  );
});

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Where a read file goes.
enum ImportTarget {
  /// 価格台帳 (0124): a supplier's quotation, invoice or catalogue, with its
  /// prices as that supplier's terms. Nothing in 商品ライブラリー changes.
  priceBook,

  /// 商品ライブラリー (0129): a product list of our own, registered straight
  /// in the library (`products_import`). Nothing goes into 価格台帳.
  library,
}

/// A file read by the AI — Excel, PDF or a photo — and sorted into maker,
/// 品名, 品番, JAN, spec, attributes, size, weight and prices, then put into
/// [target]:
///
///   * 価格台帳: each line becomes a price book item (or updates the one with
///     its JAN); with a supplier, its prices become that supplier's terms for
///     the branch and from the date given, closing the ones before.
///   * 商品ライブラリー: each line becomes a product — nothing is required —
///     unless its JAN or 品番 is already there or its JAN came earlier in the
///     file: those are alerts (0130), shown here beforehand and kept in the
///     library's アラート tab.
class PriceBookImportScreen extends ConsumerStatefulWidget {
  const PriceBookImportScreen({super.key, this.pickFile, this.today, this.target = ImportTarget.priceBook});

  final Future<PlatformFile?> Function()? pickFile;
  final ImportTarget target;

  /// Today, for tests.
  final DateTime? today;

  @override
  ConsumerState<PriceBookImportScreen> createState() => _PriceBookImportScreenState();
}

class _PriceBookImportScreenState extends ConsumerState<PriceBookImportScreen> {
  int? _partnerId;
  bool _detected = false;
  final _branch = TextEditingController();
  late DateTime _from = widget.today ?? DateTime.now();
  PlatformFile? _file;
  bool _busy = false;
  QuoteRead? _read;
  PriceBookImported? _done;
  LibraryImported? _libraryDone;

  bool get _toLibrary => widget.target == ImportTarget.library;

  /// The lines that will become alerts in the library: a JAN or 品番 that
  /// is already a product's, or a JAN that came earlier in the file.
  static Set<int> _alerts(List<Map<String, dynamic>> lines, Set<String> jans, Set<String> skus) {
    final seen = <String>{};
    final out = <int>{};
    for (final (i, l) in lines.indexed) {
      final jan = QuoteLine.jan(l);
      final code = '${l['product_code'] ?? ''}'.trim();
      if (jan.isNotEmpty && (jans.contains(jan) || seen.contains(jan))) out.add(i);
      if (code.isNotEmpty && skus.contains(code)) out.add(i);
      if (jan.isNotEmpty) seen.add(jan);
    }
    return out;
  }

  @override
  void dispose() {
    _branch.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pick() async {
    final picked = widget.pickFile != null
        ? await widget.pickFile!()
        : (await FilePicker.platform.pickFiles(
            withData: true,
            type: FileType.custom,
            allowedExtensions: const ['xlsx', 'xlsm', 'xls', 'csv', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
          ))
            ?.files
            .firstOrNull;
    if (picked == null) return;
    setState(() {
      _file = picked;
      _read = null;
      _done = null;
      _libraryDone = null;
    });
  }

  Future<void> _readFile() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    if (file == null || file.bytes == null) return _snack(l10n.planImportChooseFirst);
    setState(() => _busy = true);
    final r = await ref.read(fileReaderProvider).read(
          partnerId: _toLibrary ? null : _partnerId,
          file: MultipartFile.fromBytes(file.bytes!, filename: file.name),
          purpose: _toLibrary ? 'library' : 'price_book',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _read = data;
          _done = null;
          _libraryDone = null;
          if (!_toLibrary && _partnerId == null && data.partnerId != null) {
            _partnerId = data.partnerId;
            _detected = true;
          }
        });
      case ApiFailure(:final message):
        _snack(message.contains('No JAN rows') ? l10n.quoteNothingRead : humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _import() async {
    final read = _read;
    if (read == null) return;
    setState(() => _busy = true);
    final lines = [for (final l in read.lines) QuoteLine.toSaveJson(l)];
    if (_toLibrary) return _importToLibrary(lines);
    final l10n = AppLocalizations.of(context);
    final branch = _branch.text.trim();
    final r = await ref.read(priceBookRepositoryProvider).import(
          lines,
          partnerId: _partnerId,
          branch: branch.isEmpty ? null : branch,
          validFrom: _from,
          sourceFile: _file?.name,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _done = data);
        ref.invalidate(priceBookListProvider);
        _snack(l10n.ciDone(data.created, data.updated, data.terms));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _importToLibrary(List<Map<String, dynamic>> lines) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(productRepositoryProvider).importLines(lines, sourceFile: _file?.name);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _libraryDone = data);
        ref.invalidate(productListProvider);
        ref.invalidate(productAlertsProvider);
        _snack(l10n.libImportDone2(data.created, data.alerts));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suppliers = _toLibrary
        ? const <TradingPartner>[]
        : ref.watch(importSuppliersProvider).valueOrNull ?? const <TradingPartner>[];
    // What is there already, by JAN: products for the library, items for
    // the price book.
    final products = _toLibrary ? ref.watch(productListProvider).valueOrNull ?? const <Product>[] : const <Product>[];
    final known = _toLibrary
        ? {for (final p in products) if (p.janCode.isNotEmpty) p.janCode}
        : {
            for (final i in ref.watch(priceBookListProvider).valueOrNull ?? const <PriceBookItem>[])
              if (i.janCode != null) i.janCode!,
          };
    final read = _read;
    final lines = read?.lines ?? const <Map<String, dynamic>>[];
    final knownCount = lines.where((l) => known.contains(QuoteLine.jan(l))).length;
    final alerts = _toLibrary
        ? _alerts(lines, known, {for (final p in products) if (p.sku != null) p.sku!})
        : const <int>{};

    return Scaffold(
      appBar: AppBar(title: Text(_toLibrary ? l10n.libImportTitle : l10n.ciTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(_toLibrary ? l10n.libImportIntro : l10n.ciIntro, key: const ValueKey('ci-intro'), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('ci-pick'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_file?.name ?? l10n.quoteChooseFile),
              ),
              FilledButton.icon(
                key: const ValueKey('ci-read'),
                onPressed: _busy || _file == null ? null : _readFile,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(l10n.quoteRead),
              ),
            ],
          ),
          // What the prices are for (price book only): optional, and only
          // needed for terms.
          if (!_toLibrary) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.ciTermsFor, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('ci-partner'),
                    initialValue: suppliers.any((p) => p.id == _partnerId) ? _partnerId : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.quoteSupplierOptional,
                      helperText: _detected ? l10n.quoteSupplierDetected : null,
                    ),
                    items: [
                      DropdownMenuItem<int>(value: null, child: Text(l10n.quoteSupplierNone)),
                      for (final p in suppliers) DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _partnerId = v;
                      _detected = false;
                    }),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: const ValueKey('ci-branch'),
                    controller: _branch,
                    decoration: InputDecoration(labelText: l10n.ciBranch, hintText: l10n.ciBranchHint),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ci-from'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(l10n.ciValidFrom(_day(_from))),
                ),
              ],
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.quoteReading, style: theme.textTheme.bodySmall),
          ],
          if (read != null) ...[
            const SizedBox(height: AppSpacing.lg),
            if (!read.verified)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StatusPill(tone: StatusTone.warning, label: l10n.quoteUnverified),
              ),
            Text(
              _toLibrary
                  ? l10n.libImportSummary2(lines.length, lines.length - alerts.length, alerts.length)
                  : l10n.ciSummary(lines.length, lines.length - knownCount, knownCount),
              key: const ValueKey('ci-summary'),
              style: theme.textTheme.titleSmall,
            ),
            if (!_toLibrary && _partnerId == null) Text(l10n.ciNoSupplierNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('ci-import'),
              onPressed: _busy || lines.isEmpty ? null : _import,
              icon: Icon(_toLibrary ? Icons.inventory_2_outlined : Icons.library_add_outlined),
              label: Text(_toLibrary ? l10n.libImportAction(lines.length - alerts.length) : l10n.ciImport(lines.length)),
            ),
            if (_done case final d?) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusPill(tone: StatusTone.success, label: l10n.ciDone(d.created, d.updated, d.terms)),
            ],
            if (_libraryDone case final d?) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusPill(
                key: const ValueKey('ci-library-done'),
                tone: d.alerts == 0 ? StatusTone.success : StatusTone.warning,
                label: l10n.libImportDone2(d.created, d.alerts),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final (i, l) in lines.indexed)
              ImportLineCard(
                key: ValueKey('ci-line-$i'),
                line: l,
                known: !_toLibrary && known.contains(QuoteLine.jan(l)),
                alert: alerts.contains(i),
              ),
          ],
        ],
      ),
    );
  }
}

/// One read line, each part under its name.
class ImportLineCard extends StatelessWidget {
  const ImportLineCard({super.key, required this.line, required this.known, this.alert = false});

  final Map<String, dynamic> line;

  /// Whether its JAN is there already (updated rather than new).
  final bool known;

  /// Shown when the line will be an alert in the library (a duplicate).
  final bool alert;

  static String yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String? t(Object? v) {
      final x = v == null ? '' : widenKana('$v'.trim());
      return x.isEmpty ? null : x;
    }

    final rate = QuoteLine.discountRate(line);
    final fields = <(String, String?)>[
      (l10n.pdMaker, t(line['maker'])),
      (l10n.pdBaseName, t(line['product_name'])),
      (l10n.pdCode, t(line['product_code'])),
      (l10n.pdJan, QuoteLine.jan(line).isEmpty ? null : QuoteLine.jan(line)),
      (l10n.quoteTheirCode, t(line['supplier_code'])),
      (l10n.pdSpec, t(line['spec'])),
      for (final a in (line['attributes'] as List? ?? const []).whereType<Map>())
        if (t(a['value']) case final v?) ('${a['name'] ?? a['key'] ?? ''}', v),
      (l10n.pdUnit, t(line['unit'])),
      (l10n.quoteCaseLabel, QuoteLine.caseQuantity(line)?.toStringAsFixed(0)),
      (l10n.quoteUnitPriceLabel, QuoteLine.unitPrice(line) == null ? null : yen(QuoteLine.unitPrice(line)!)),
      (l10n.pdListPrice, QuoteLine.listPrice(line) == null ? null : yen(QuoteLine.listPrice(line)!)),
      (l10n.quoteRateLabel,
          rate == null ? null : '${(rate * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(t(line['product_name']) ?? QuoteLine.jan(line), style: theme.textTheme.titleSmall),
              ),
              if (alert) ...[
                StatusPill(tone: StatusTone.warning, label: l10n.libLineAlert, dense: true),
                const SizedBox(width: AppSpacing.xs),
              ],
              StatusPill(
                tone: known ? StatusTone.info : StatusTone.success,
                label: known ? l10n.ciLineUpdate : l10n.ciLineNew,
                dense: true,
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (name, value) in fields)
                  if (value != null)
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(text: '$name ', style: muted),
                          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
