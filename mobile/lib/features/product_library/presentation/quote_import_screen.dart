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
import '../../product/domain/product.dart';
import '../application/product_library_providers.dart';
import '../data/quote_repository.dart';
import '../domain/supplier_quote.dart';
import 'register_products_sheet.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) => QuoteRepositoryImpl(
      functions: ref.watch(deliveryDioProvider),
      rest: ref.watch(restDioProvider),
    ));

/// Every product, whatever its lifecycle and whatever the library's search
/// says, to tell what each line is tied to.
final quoteAllProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final r = await ref.watch(productRepositoryProvider).list(search: null, status: null);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

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

  /// Whether [_partnerId] was found on the document rather than chosen.
  bool _detected = false;
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
          // The company the document names, when none was chosen.
          if (_partnerId == null && data.partnerId != null) {
            _partnerId = data.partnerId;
            _detected = true;
          }
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

  /// Every product of ours, whatever its lifecycle (0120), by id — so a line
  /// tied to an archived, dormant or discontinued product says so.
  Map<int, Product> get _products => {
        for (final p in ref.read(quoteAllProductsProvider).valueOrNull ?? const <Product>[]) p.id: p,
      };

  /// Products the lines are tied to that are not active.
  List<int> _inactiveIds(Map<int, Product> byId) => {
        for (final l in _lines)
          if (QuoteLine.productId(l) case final id? when byId[id] != null && byId[id]!.lifecycle != ProductLifecycle.active) id,
      }.toList()
        ..sort();

  Future<bool> _restore(List<int> ids) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(productRepositoryProvider).setLifecycle(ids, ProductLifecycle.active);
    if (!mounted) return false;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(productListProvider);
        ref.invalidate(quoteAllProductsProvider);
        _snack(l10n.quoteRestored(data));
        return true;
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
        return false;
    }
  }

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
    ref.invalidate(quoteAllProductsProvider);
    _snack(l10n.rpRegistered(created.length));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    // Saving prices for products that are not active leaves them out of the
    // library's list: offer to make them active at the same time.
    final inactive = _inactiveIds(_products);
    if (inactive.isNotEmpty && ref.read(productCanLifecycleProvider)) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.quoteRestoreQ(inactive.length)),
          content: Text(l10n.quoteRestoreBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.actionCancel)),
            OutlinedButton(
              key: const ValueKey('quote-save-only'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.quoteSaveOnly),
            ),
            FilledButton(
              key: const ValueKey('quote-restore-save'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.quoteRestoreAndSave),
            ),
          ],
        ),
      );
      if (restore == null || !mounted) return;
      if (restore && !await _restore(inactive)) return;
    }
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
    // Watched so a line's state follows the library's.
    final byId = {for (final p in ref.watch(quoteAllProductsProvider).valueOrNull ?? const <Product>[]) p.id: p};
    final inactive = _inactiveIds(byId);
    final canRestore = ref.watch(productCanLifecycleProvider);

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
            decoration: InputDecoration(
              labelText: l10n.quoteSupplierOptional,
              helperText: _detected ? l10n.quoteSupplierDetected : l10n.quoteSupplierHint,
            ),
            items: [
              DropdownMenuItem<int>(value: null, child: Text(l10n.quoteSupplierNone)),
              for (final p in suppliers) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() {
              _partnerId = v;
              _detected = false;
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
                onPressed: _busy || _file == null ? null : _readQuote,
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
                  onPressed: _busy || _matched == 0 || _partnerId == null ? null : _save,
                  icon: const Icon(Icons.price_check_outlined),
                  label: Text(l10n.quoteSave(_matched)),
                ),
              ],
            ),
            // Registered, but archived, dormant or discontinued (0120): the
            // library's list does not show them until they are active again.
            if (inactive.isNotEmpty)
              Card(
                key: const ValueKey('quote-inactive'),
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.quoteInactiveNote(inactive.length)),
                      const SizedBox(height: AppSpacing.sm),
                      if (canRestore)
                        FilledButton.icon(
                          key: const ValueKey('quote-restore'),
                          onPressed: _busy ? null : () => _restore(inactive),
                          icon: const Icon(Icons.unarchive_outlined, size: 18),
                          label: Text(l10n.quoteRestore(inactive.length)),
                        )
                      else
                        Text(l10n.quoteRestoreNeedsAdmin, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            if (_partnerId == null && _matched > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(l10n.quoteSaveNeedsSupplier, style: theme.textTheme.bodySmall),
              ),
            if (_saved case final s?) ...[
              const SizedBox(height: AppSpacing.sm),
              StatusPill(tone: StatusTone.success, label: l10n.quoteSaved(s.prices, s.products)),
            ],
            const SizedBox(height: AppSpacing.md),
            for (final (i, l) in _lines.indexed)
              _QuoteLineCard(
                key: ValueKey('quote-line-$i'),
                line: l,
                lifecycle: byId[QuoteLine.productId(l)]?.lifecycle,
              ),
          ],
        ],
      ),
    );
  }
}

class _QuoteLineCard extends StatelessWidget {
  const _QuoteLineCard({super.key, required this.line, this.lifecycle});

  final Map<String, dynamic> line;

  /// The tied product's lifecycle, when it is known.
  final ProductLifecycle? lifecycle;

  String _yen(double v) => '¥${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final matched = QuoteLine.productId(line) != null;
    final (tone, label) = matched
        ? switch (lifecycle) {
            ProductLifecycle.archived => (StatusTone.danger, l10n.quoteLineArchived),
            ProductLifecycle.dormant => (StatusTone.neutral, l10n.quoteLineDormant),
            ProductLifecycle.discontinued => (StatusTone.warning, l10n.quoteLineDiscontinued),
            _ => line['matched_by'] == 'registered'
                ? (StatusTone.success, l10n.quoteLineRegistered)
                : (StatusTone.info, l10n.quoteLineKnown),
          }
        : QuoteLine.hasJan(line)
            ? (StatusTone.warning, l10n.quoteLineNew)
            : (StatusTone.neutral, l10n.quoteLineNoJan);
    String? t(Object? v) {
      final x = v == null ? '' : widenKana('$v'.trim());
      return x.isEmpty ? null : x;
    }

    // What the reader sorted the line into, each under its own name — the
    // same parts a product of ours is built from.
    final attrs = [
      for (final a in (line['attributes'] as List? ?? const []).whereType<Map>())
        if (t(a['value']) case final v?) ('${a['name'] ?? a['key'] ?? ''}', v),
    ];
    final fields = <(String, String?)>[
      (l10n.pdMaker, t(line['maker'])),
      (l10n.pdBaseName, t(line['product_name'])),
      (l10n.pdCode, t(line['product_code'])),
      (l10n.pdJan, QuoteLine.jan(line).isEmpty ? null : QuoteLine.jan(line)),
      (l10n.quoteTheirCode, t(line['supplier_code'])),
      (l10n.pdSpec, t(line['spec'])),
      for (final (n, v) in attrs) (n, v),
      (l10n.pdUnit, t(line['unit'])),
      (l10n.quoteCaseLabel, QuoteLine.caseQuantity(line)?.toStringAsFixed(0)),
      (l10n.quoteUnitPriceLabel, QuoteLine.unitPrice(line) == null ? null : _yen(QuoteLine.unitPrice(line)!)),
      (l10n.pdListPrice, QuoteLine.listPrice(line) == null ? null : _yen(QuoteLine.listPrice(line)!)),
      (l10n.quoteRateLabel, QuoteLine.discountRate(line) == null
          ? null
          : '${(QuoteLine.discountRate(line)! * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%'),
    ];
    final ours = matched ? widenKana(QuoteLine.name(line)) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ours ?? t(line['product_name']) ?? QuoteLine.jan(line),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill(tone: tone, label: label, dense: true),
              ],
            ),
            if (ours != null) Text(l10n.quoteOurProduct, style: muted),
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
