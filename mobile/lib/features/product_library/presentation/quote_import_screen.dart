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
import '../../product/application/product_providers.dart';
import '../application/product_library_providers.dart';
import '../data/quote_repository.dart';
import '../domain/supplier_quote.dart';
import 'register_products_sheet.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) => QuoteRepositoryImpl(
      functions: ref.watch(deliveryDioProvider),
      rest: ref.watch(restDioProvider),
    ));

/// The suppliers a quotation can come from.
final quoteSuppliersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final r = await ref.watch(tradingPartnerRepositoryProvider).list(status: 'active');
  return r.when(
    success: (d) => [for (final p in d) if (p.kind != PartnerKind.customer) p],
    failure: (f) => throw Exception(f.message),
  );
});

/// A supplier's quotation (見積書) into the product library in one go (0119).
///
/// The file — Excel, PDF or a photo — is read by the same reader as a
/// delivery note: columns by their headings, a PDF or photo by the AI, read
/// twice. Each line is matched to our products through what this supplier's
/// writing is known to mean. Then:
///   * the lines with a JAN and no product of ours are registered in our
///     format, after a person checks them;
///   * the quoted prices (単価, 定価 and 掛率, 入数) are kept as this
///     supplier's price for each product, and its writing is learned.
class QuoteImportScreen extends ConsumerStatefulWidget {
  const QuoteImportScreen({super.key, this.pickFile});

  /// Replaces the platform file picker (tests).
  final Future<PlatformFile?> Function()? pickFile;

  @override
  ConsumerState<QuoteImportScreen> createState() => _QuoteImportScreenState();
}

class _QuoteImportScreenState extends ConsumerState<QuoteImportScreen> {
  int? _partnerId;
  PlatformFile? _file;
  bool _busy = false;
  QuoteRead? _read;
  List<Map<String, dynamic>> _lines = const [];
  QuoteSaved? _saved;

  void _snack(String text) =>
      ScaffoldMessenger.of(context)
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
      _lines = const [];
      _saved = null;
    });
  }

  Future<void> _readQuote() async {
    final l10n = AppLocalizations.of(context);
    final partnerId = _partnerId;
    final file = _file;
    if (partnerId == null) return _snack(l10n.quoteChooseSupplier);
    if (file == null || file.bytes == null) return _snack(l10n.planImportChooseFirst);
    setState(() => _busy = true);
    final r = await ref.read(quoteRepositoryProvider).read(
          partnerId: partnerId,
          file: MultipartFile.fromBytes(file.bytes!, filename: file.name),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() {
          _read = data;
          _lines = data.lines;
          _saved = null;
        });
      case ApiFailure(:final message):
        _snack(message.contains('No JAN rows') ? l10n.quoteNothingRead : humanizeApiErrorMessage(l10n, message));
    }
  }

  List<int> get _newOnes => [
        for (final (i, l) in _lines.indexed)
          if (QuoteLine.productId(l) == null && QuoteLine.hasJan(l)) i,
      ];

  int get _matched => _lines.where((l) => QuoteLine.productId(l) != null).length;

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final created = await showRegisterProductsSheet(
      context,
      partnerId: _partnerId,
      lines: [for (final i in _newOnes) {..._lines[i], 'row': i}],
    );
    if (created.isEmpty || !mounted) return;
    final byJan = {for (final c in created) c.janCode.replaceAll(RegExp(r'\D'), ''): c};
    setState(() {
      _lines = [
        for (final l in _lines)
          if (QuoteLine.productId(l) == null && byJan[QuoteLine.jan(l)] != null)
            {
              ...l,
              'product_id': byJan[QuoteLine.jan(l)]!.productId,
              'product': {
                'id': byJan[QuoteLine.jan(l)]!.productId,
                'jan_code': byJan[QuoteLine.jan(l)]!.janCode,
                'name': byJan[QuoteLine.jan(l)]!.name,
                'maker': l['maker'],
              },
              'matched_by': 'registered',
            }
          else
            l,
      ];
    });
    ref.invalidate(productListProvider);
    _snack(l10n.rpRegistered(created.length));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(quoteRepositoryProvider).save(
          partnerId: _partnerId!,
          lines: [for (final l in _lines) if (QuoteLine.productId(l) != null) l],
          note: _file?.name,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        setState(() => _saved = data);
        ref.invalidate(productListProvider);
        ref.invalidate(productLibraryProvider);
        _snack(l10n.quoteSaved(data.prices, data.products));
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final suppliers = ref.watch(quoteSuppliersProvider).valueOrNull ?? const <TradingPartner>[];
    final read = _read;
    final newOnes = _newOnes;
    final noJan = _lines.where((l) => QuoteLine.productId(l) == null && !QuoteLine.hasJan(l)).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quoteImportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.quoteImportIntro, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: const ValueKey('quote-partner'),
            initialValue: suppliers.any((p) => p.id == _partnerId) ? _partnerId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.quoteSupplier),
            items: [for (final p in suppliers) DropdownMenuItem(value: p.id, child: Text(p.name))],
            onChanged: (v) => setState(() {
              _partnerId = v;
              _read = null;
              _lines = const [];
              _saved = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('quote-pick'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_file?.name ?? l10n.quoteChooseFile),
              ),
              FilledButton.icon(
                key: const ValueKey('quote-read'),
                onPressed: _busy || _file == null || _partnerId == null ? null : _readQuote,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(l10n.quoteRead),
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
            Text(
              l10n.quoteSummary(_lines.length, _matched, newOnes.length, noJan),
              key: const ValueKey('quote-summary'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('quote-register'),
                  onPressed: _busy || newOnes.isEmpty ? null : _register,
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(l10n.quoteRegister(newOnes.length)),
                ),
                FilledButton.icon(
                  key: const ValueKey('quote-save'),
                  onPressed: _busy || _matched == 0 ? null : _save,
                  icon: const Icon(Icons.price_check_outlined),
                  label: Text(l10n.quoteSave(_matched)),
                ),
              ],
            ),
            if (_saved case final s?) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusPill(tone: StatusTone.success, label: l10n.quoteSaved(s.prices, s.products)),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final (i, l) in _lines.indexed) _QuoteLineCard(key: ValueKey('quote-line-$i'), line: l),
          ],
        ],
      ),
    );
  }
}

class _QuoteLineCard extends StatelessWidget {
  const _QuoteLineCard({super.key, required this.line});

  final Map<String, dynamic> line;

  String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final matched = QuoteLine.productId(line) != null;
    final (tone, label) = matched
        ? (line['matched_by'] == 'registered'
            ? (StatusTone.success, l10n.quoteLineRegistered)
            : (StatusTone.info, l10n.quoteLineKnown))
        : QuoteLine.hasJan(line)
            ? (StatusTone.warning, l10n.quoteLineNew)
            : (StatusTone.neutral, l10n.quoteLineNoJan);
    final supplierName = widenKana(QuoteLine.supplierName(line));
    final prices = [
      if (QuoteLine.unitPrice(line) case final u?) l10n.quoteUnitPrice(_yen(u)),
      if (QuoteLine.listPrice(line) case final lp?) l10n.quoteListPrice(_yen(lp)),
      if (QuoteLine.discountRate(line) case final r?)
        l10n.quoteRate('${(r * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
      if (QuoteLine.caseQuantity(line) case final c?) l10n.quoteCase(c.toStringAsFixed(0)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widenKana(QuoteLine.name(line)), style: theme.textTheme.titleSmall),
                  if (matched && supplierName.isNotEmpty && supplierName != widenKana(QuoteLine.name(line)))
                    Text(l10n.quoteTheirName(supplierName), style: muted),
                  Text(
                    [
                      if (QuoteLine.jan(line).isNotEmpty) QuoteLine.jan(line),
                      if (QuoteLine.maker(line) case final m?) widenKana(m),
                      if (QuoteLine.code(line) case final c?) widenKana(c),
                    ].join(' · '),
                    style: muted,
                  ),
                  if (prices.isNotEmpty) Text(prices.join('　'), style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(tone: tone, label: label, dense: true),
          ],
        ),
      ),
    );
  }
}
