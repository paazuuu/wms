import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_confidence.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../delivery/application/delivery_providers.dart';
import '../application/documents_providers.dart';
import '../domain/documents.dart';
import 'documents_labels.dart';

/// A supplier's invoice (§55): typed, or read from its PDF / photo / Excel by
/// the same reader as delivery notes — read twice by the AI and checked
/// against the company's learned writing — with each field's confidence
/// shown against the thresholds (§50). A person checks it and saves; the
/// match against the order follows.
class InvoiceEditorScreen extends ConsumerStatefulWidget {
  const InvoiceEditorScreen({super.key, required this.purchaseOrderId, this.invoiceId, this.supplierName, this.pickFile});

  final int purchaseOrderId;
  final int? invoiceId;
  final String? supplierName;

  /// Injectable for tests; defaults to the platform picker.
  final Future<PlatformFile?> Function()? pickFile;

  @override
  ConsumerState<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  final _number = TextEditingController();
  final _date = TextEditingController();
  final _total = TextEditingController();
  List<InvoiceLine> _lines = [];
  String _source = 'manual';
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _date.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await ref.read(documentsRepositoryProvider).invoice(widget.invoiceId!);
    if (!mounted) return;
    r.when(
      success: (inv) => setState(() {
        _number.text = inv.invoiceNumber;
        _date.text = inv.invoiceDate ?? '';
        _total.text = inv.total == null ? '' : docNum(inv.total!);
        _lines = [...inv.lines];
        _source = inv.source;
        _loading = false;
      }),
      failure: (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
    );
  }

  Future<void> _read() async {
    final l10n = AppLocalizations.of(context);
    final file = widget.pickFile != null
        ? await widget.pickFile!()
        : (await FilePicker.platform.pickFiles(
            withData: true,
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'xlsx', 'xlsm', 'csv'],
          ))
            ?.files
            .firstOrNull;
    if (file?.bytes == null || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(deliveryRepositoryProvider).previewPlan(
          file: MultipartFile.fromBytes(file!.bytes!, filename: file.name),
          supplier: widget.supplierName,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (p) {
        final sheet = p.source == 'xlsx' || p.source == 'csv';
        setState(() {
          _source = 'document';
          if (_number.text.trim().isEmpty) _number.text = p.docNumber ?? p.deliveryNumber ?? '';
          if (_date.text.trim().isEmpty) _date.text = p.docDate ?? '';
          _lines = [
            for (final l in p.lines)
              InvoiceLine(
                productId: (l['product_id'] as num?)?.toInt(),
                janCode: (l['raw_jan_code'] ?? l['jan_code'])?.toString(),
                productCode: l['product_code']?.toString(),
                productName: l['product_name']?.toString(),
                maker: l['maker']?.toString(),
                quantity: (l['planned_quantity'] as num?)?.toDouble() ?? 0,
                unitPrice: (l['unit_price'] as num?)?.toDouble(),
                amount: (l['amount'] as num?)?.toDouble(),
                flags: [for (final f in (l['flags'] as List? ?? const [])) f.toString()],
                confidence: lineConfidence(
                  [for (final f in (l['flags'] as List? ?? const [])) f.toString()],
                  verified: p.verified,
                  spreadsheet: sheet,
                  hasJan: '${l['raw_jan_code'] ?? l['jan_code'] ?? ''}'.isNotEmpty,
                  hasProduct: l['product_id'] != null,
                ),
              ),
          ];
        });
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, f.message)))),
    );
  }

  Future<void> _editLine(int? index) async {
    final line = await showDialog<InvoiceLine>(
      context: context,
      builder: (_) => _LineDialog(line: index == null ? null : _lines[index]),
    );
    if (line == null) return;
    setState(() {
      if (index == null) {
        _lines = [..._lines, line];
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_number.text.trim().isEmpty) {
      setState(() => _error = l10n.docInvoiceNumberRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(documentsRepositoryProvider).save(SupplierInvoice(
          id: widget.invoiceId,
          invoiceNumber: _number.text.trim(),
          purchaseOrderId: widget.purchaseOrderId,
          invoiceDate: _date.text.trim().isEmpty ? null : _date.text.trim(),
          total: double.tryParse(_total.text.trim().replaceAll(',', '')),
          source: _source,
          lines: _lines,
        ));
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (res) {
        ref.invalidate(documentExceptionsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.docSaved} · ${invoiceStatusLabel(l10n, res.status)}')));
        Navigator.pop(context, true);
      },
      failure: (f) => setState(() => _error = humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = _lines.fold<double>(0, (s, l) => s + l.lineAmount);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.docInvoice)),
      body: _loading
          ? LoadingView(message: l10n.loading)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('doc-read'),
                  onPressed: _busy ? null : _read,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(l10n.docReadFromFile),
                ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                  SizedBox(width: 220, child: TextField(key: const ValueKey('doc-number'), controller: _number, decoration: InputDecoration(labelText: l10n.docInvoiceNumber))),
                  SizedBox(width: 160, child: TextField(controller: _date, decoration: InputDecoration(labelText: l10n.docInvoiceDate, hintText: '2026-09-30'))),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const ValueKey('doc-total'),
                      controller: _total,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.docInvoiceTotal, prefixText: '¥'),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(child: Text('${l10n.docLines} (${_lines.length}) · ¥${docNum(total)}', style: theme.textTheme.titleSmall)),
                  TextButton.icon(key: const ValueKey('doc-add-line'), onPressed: () => _editLine(null), icon: const Icon(Icons.add), label: Text(l10n.docAddLine)),
                ]),
                for (var i = 0; i < _lines.length; i++)
                  Card(
                    key: ValueKey('doc-edit-line-$i'),
                    child: ListTile(
                      onTap: () => _editLine(i),
                      title: Row(children: [
                        Expanded(child: Text(_lines[i].productName ?? _lines[i].janCode ?? '—')),
                        if (_lines[i].confidence != null) AiBandPill(confidence: _lines[i].confidence!),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text([
                          if (_lines[i].janCode != null) _lines[i].janCode!,
                          '${docNum(_lines[i].quantity)} × ${_lines[i].unitPrice == null ? '—' : '¥${docNum(_lines[i].unitPrice!)}'}',
                          '¥${docNum(_lines[i].lineAmount)}',
                        ].join(' · ')),
                        if (_lines[i].confidence != null) AiConfidenceRow(confidence: _lines[i].confidence!),
                      ]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _lines = [..._lines]..removeAt(i)),
                      ),
                    ),
                  ),
                if (_error != null) Padding(padding: const EdgeInsets.all(AppSpacing.sm), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            key: const ValueKey('doc-save'),
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.docSaveAndMatch),
          ),
        ),
      ),
    );
  }
}

class _LineDialog extends StatefulWidget {
  const _LineDialog({this.line});

  final InvoiceLine? line;

  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  late final _jan = TextEditingController(text: widget.line?.janCode ?? '');
  late final _name = TextEditingController(text: widget.line?.productName ?? '');
  late final _qty = TextEditingController(text: widget.line == null ? '' : docNum(widget.line!.quantity));
  late final _price = TextEditingController(text: widget.line?.unitPrice == null ? '' : docNum(widget.line!.unitPrice!));

  @override
  void dispose() {
    for (final c in [_jan, _name, _qty, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.docLines),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const ValueKey('doc-line-jan'), controller: _jan, decoration: InputDecoration(labelText: l10n.ntFieldJan)),
        TextField(controller: _name, decoration: InputDecoration(labelText: l10n.ntFieldName)),
        TextField(key: const ValueKey('doc-line-qty'), controller: _qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.ntFieldQuantity)),
        TextField(key: const ValueKey('doc-line-price'), controller: _price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.ntFieldUnitPrice)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('doc-line-save'),
          onPressed: () {
            final qty = double.tryParse(_qty.text.trim()) ?? 0;
            final price = double.tryParse(_price.text.trim());
            final base = widget.line ?? const InvoiceLine();
            Navigator.pop(
              context,
              base.copyWith(
                janCode: _jan.text.trim(),
                productName: _name.text.trim(),
                quantity: qty,
                unitPrice: price,
                clearAmount: true,
              ),
            );
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
