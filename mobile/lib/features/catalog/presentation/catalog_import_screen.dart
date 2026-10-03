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
import '../../partners/domain/trading_partner.dart';
import '../../product_library/data/quote_repository.dart';
import '../../product_library/domain/supplier_quote.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog.dart';

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

/// A file into 商品ライブラリー (0124): a quotation, invoice, delivery note or
/// catalogue — Excel, PDF or a photo — read and sorted into maker, 品名,
/// 品番, JAN, spec and prices. Each line becomes a library item (or updates
/// the one with its JAN); with a supplier, its prices become that supplier's
/// terms for the branch and from the date given, closing the ones before.
/// Nothing in the product master, stock or anything booked is touched.
class CatalogImportScreen extends ConsumerStatefulWidget {
  const CatalogImportScreen({super.key, this.pickFile, this.today});

  final Future<PlatformFile?> Function()? pickFile;

  /// Today, for tests.
  final DateTime? today;

  @override
  ConsumerState<CatalogImportScreen> createState() => _CatalogImportScreenState();
}

class _CatalogImportScreenState extends ConsumerState<CatalogImportScreen> {
  int? _partnerId;
  bool _detected = false;
  final _branch = TextEditingController();
  late DateTime _from = widget.today ?? DateTime.now();
  PlatformFile? _file;
  bool _busy = false;
  QuoteRead? _read;
  CatalogImported? _done;

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
    });
  }

  Future<void> _readFile() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    if (file == null || file.bytes == null) return _snack(l10n.planImportChooseFirst);
    setState(() => _busy = true);
    final r = await ref.read(fileReaderProvider).read(
          partnerId: _partnerId,
          file: MultipartFile.fromBytes(file.bytes!, filename: file.name),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _read = data;
          _done = null;
          if (_partnerId == null && data.partnerId != null) {
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
    final l10n = AppLocalizations.of(context);
    final read = _read;
    if (read == null) return;
    setState(() => _busy = true);
    final branch = _branch.text.trim();
    final r = await ref.read(catalogRepositoryProvider).import(
          [for (final l in read.lines) QuoteLine.toSaveJson(l)],
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
        ref.invalidate(catalogListProvider);
        _snack(l10n.ciDone(data.created, data.updated, data.terms));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suppliers = ref.watch(importSuppliersProvider).valueOrNull ?? const <TradingPartner>[];
    final inLibrary = {
      for (final i in ref.watch(catalogListProvider).valueOrNull ?? const <CatalogItem>[])
        if (i.janCode != null) i.janCode!: i,
    };
    final read = _read;
    final lines = read?.lines ?? const <Map<String, dynamic>>[];
    final known = lines.where((l) => inLibrary.containsKey(QuoteLine.jan(l))).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ciTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.ciIntro, style: theme.textTheme.bodySmall),
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
          const SizedBox(height: AppSpacing.md),
          // What the prices are for: optional, and only needed for terms.
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
            Text(l10n.ciSummary(lines.length, lines.length - known, known),
                key: const ValueKey('ci-summary'), style: theme.textTheme.titleSmall),
            if (_partnerId == null)
              Text(l10n.ciNoSupplierNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('ci-import'),
              onPressed: _busy || lines.isEmpty ? null : _import,
              icon: const Icon(Icons.library_add_outlined),
              label: Text(l10n.ciImport(lines.length)),
            ),
            if (_done case final d?) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusPill(tone: StatusTone.success, label: l10n.ciDone(d.created, d.updated, d.terms)),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final (i, l) in lines.indexed)
              ImportLineCard(key: ValueKey('ci-line-$i'), line: l, inLibrary: inLibrary.containsKey(QuoteLine.jan(l))),
          ],
        ],
      ),
    );
  }
}

/// One read line, each part under its name.
class ImportLineCard extends StatelessWidget {
  const ImportLineCard({super.key, required this.line, required this.inLibrary});

  final Map<String, dynamic> line;
  final bool inLibrary;

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
              StatusPill(
                tone: inLibrary ? StatusTone.info : StatusTone.success,
                label: inLibrary ? l10n.ciLineUpdate : l10n.ciLineNew,
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
