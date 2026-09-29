import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_confidence.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../notation/domain/notation.dart';
import '../../notation/presentation/notation_labels.dart';
import '../../product/domain/product.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/delivery_providers.dart';
import '../data/delivery_repository.dart';
import '../../product_library/application/product_library_providers.dart';
import '../../product_library/domain/product_image.dart';
import '../../product_library/presentation/product_thumb.dart';
import '../../product_library/presentation/register_products_sheet.dart';

/// Whether the upload creates an inbound delivery plan or an outbound shipment.
enum ImportTarget { plan, shipment }

/// Back-office upload in two steps:
///   1. Pick a supplier's Excel / PDF / image and READ it — the backend parses
///      the lines and auto-reads the note header (company, registration number,
///      customer code, date) via Gemini, without saving anything.
///   2. REVIEW the header — every field is editable, anything the note could not
///      be read for is flagged — then register the plan.
///
/// When the company can't be read it is filed under a distinct "UNKNOWN"
/// reference series and flagged for manual assignment. The same flow imports an
/// outbound shipment list when [target] is [ImportTarget.shipment]; the caller
/// passes [onImported] to refresh its own list.
class PlanImportScreen extends ConsumerStatefulWidget {
  const PlanImportScreen({
    super.key,
    this.target = ImportTarget.plan,
    this.onImported,
    this.pickFile,
  });

  final ImportTarget target;
  final VoidCallback? onImported;

  /// Injectable for tests, same idea as `BarcodeScanScreen`'s `cameraBuilder`
  /// — real picking goes through file_picker's platform channel, which a
  /// widget test can't drive. Defaults to the real picker.
  final Future<PlatformFile?> Function()? pickFile;

  @override
  ConsumerState<PlanImportScreen> createState() => _PlanImportScreenState();
}

class _PlanImportScreenState extends ConsumerState<PlanImportScreen> {
  final _numberController = TextEditingController();
  final _supplierController = TextEditingController();
  final _codeController = TextEditingController();
  final _regNoController = TextEditingController();
  final _customerCodeController = TextEditingController();
  final _docNumberController = TextEditingController();

  PlatformFile? _file;
  bool _busy = false;

  /// Set once the note has been read; drives the review form.
  ImportPreview? _preview;

  /// The line items shown and edited in the review step. Starts as a copy of
  /// [ImportPreview.lines] but diverges from it once the operator edits,
  /// deletes, adds, splits, or merges a row (spec §31 — 修正 isn't limited to
  /// the header fields). This, not `_preview.lines`, is what gets sent on
  /// commit.
  List<Map<String, dynamic>> _lines = [];

  int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  @override
  void dispose() {
    _numberController.dispose();
    _supplierController.dispose();
    _codeController.dispose();
    _regNoController.dispose();
    _customerCodeController.dispose();
    _docNumberController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = widget.pickFile != null
        ? await widget.pickFile!()
        : await _pickFromPlatform();
    if (picked == null) return;
    setState(() => _file = picked);
  }

  Future<PlatformFile?> _pickFromPlatform() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  /// Step 1 — read the note and pre-fill the review form.
  Future<void> _read() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    if (file == null) {
      _snack(l10n.planImportChooseFirst, tone: StatusTone.warning);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      _snack(l10n.somethingWentWrong, tone: StatusTone.danger);
      return;
    }

    setState(() => _busy = true);
    final result = await ref.read(deliveryRepositoryProvider).previewPlan(
          file: MultipartFile.fromBytes(bytes, filename: file.name),
          deliveryNumber: _numberController.text,
          supplier: _supplierController.text,
          supplierCode: _codeController.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (preview) {
        _numberController.text =
            preview.deliveryNumber ?? _numberController.text;
        _supplierController.text = preview.supplierName ?? '';
        _codeController.text = preview.supplierCode ?? _codeController.text;
        _regNoController.text = preview.registrationNumber ?? '';
        _customerCodeController.text = preview.customerCode ?? '';
        _docNumberController.text = preview.docNumber ?? '';
        setState(() {
          _preview = preview;
          _lines = [
            for (final line in preview.lines) Map<String, dynamic>.from(line),
          ];
        });
        HapticFeedback.selectionClick();
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), tone: StatusTone.danger),
    );
  }

  /// Step 2 — register the reviewed plan.
  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    if (preview == null) return;
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      _snack(l10n.planImportChooseFirst, tone: StatusTone.warning);
      return;
    }

    setState(() => _busy = true);
    final result = await ref.read(deliveryRepositoryProvider).commitPlan(
          PlanCommit(
            deliveryNumber: number,
            supplier: _supplierController.text,
            supplierCode: _codeController.text,
            registrationNumber: _regNoController.text,
            customerCode: _customerCodeController.text,
            docNumber: _docNumberController.text,
            orderDate: preview.orderDate,
            source: preview.source,
            columns: preview.columns,
            lines: _lines,
            target: widget.target == ImportTarget.shipment ? 'shipment' : 'plan',
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (summary) async {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        if (widget.onImported != null) {
          widget.onImported!();
        } else {
          ref.invalidate(deliveryPlansProvider);
        }
        _snack(
          summary.needsReview
              ? l10n.planUnidentifiedNote
              : l10n.planImportedSummary(
                  summary.lineCount, summary.totalQuantity),
          tone: summary.needsReview ? StatusTone.warning : StatusTone.success,
        );
        Navigator.of(context).pop();
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), tone: StatusTone.danger),
    );
  }

  void _snack(String message, {StatusTone tone = StatusTone.neutral}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg) = switch (tone) {
      StatusTone.success => (Icons.check_circle, scheme.inverseSurface),
      StatusTone.warning => (Icons.warning_amber, scheme.inverseSurface),
      StatusTone.danger => (Icons.error_outline, scheme.error),
      _ => (Icons.info_outline, scheme.inverseSurface),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, size: 20, color: scheme.onInverseSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: bg,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviewing = _preview != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(reviewing ? l10n.planReviewTitle : l10n.planImportTitle),
      ),
      body: reviewing ? _buildReview(context, l10n) : _buildPick(context, l10n),
      bottomNavigationBar:
          reviewing ? _reviewBar(context, l10n) : _pickBar(context, l10n),
    );
  }

  Widget _barShell(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
      ),
    );
  }

  Widget _pickBar(BuildContext context, AppLocalizations l10n) {
    return _barShell(
      context,
      SizedBox(
        width: double.infinity,
        height: AppSpacing.minTouch,
        child: FilledButton.icon(
          onPressed: (_busy || _file == null) ? null : _read,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_busy ? l10n.planReading : l10n.planReadAction),
        ),
      ),
    );
  }

  Widget _reviewBar(BuildContext context, AppLocalizations l10n) {
    return _barShell(
      context,
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => setState(() => _preview = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(l10n.changeFile),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SizedBox(
              height: AppSpacing.minTouch,
              child: FilledButton.icon(
                onPressed: _busy ? null : _register,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label:
                    Text(_busy ? l10n.planRegistering : l10n.planCommitAction),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPick(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(l10n.planImportHint,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
        InkWell(
          onTap: _busy ? null : _pick,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                  color: _file == null ? scheme.outlineVariant : scheme.primary),
              color: scheme.surfaceContainerLow,
            ),
            child: Column(
              children: [
                Icon(
                  _file == null
                      ? Icons.upload_file_outlined
                      : Icons.description_outlined,
                  size: 40,
                  color: _file == null ? scheme.onSurfaceVariant : scheme.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_file == null) ...[
                  Text(l10n.importChooseFile,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: scheme.primary)),
                  const SizedBox(height: 2),
                  Text(l10n.importFormatsHint,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Text(
                      _file!.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.changeFile,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.primary)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = _preview!;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                l10n.planPreviewCount(_lines.length, _totalQuantity),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        if (!preview.verified) ...[
          const SizedBox(height: AppSpacing.sm),
          _Notice(l10n.importNotVerified, color: scheme.error),
        ],
        if (_unresolvedCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _Notice(l10n.importUnresolvedLines(_unresolvedCount),
              color: scheme.tertiary, key: const ValueKey('import-unresolved')),
          if (_registrable.isNotEmpty && ref.watch(productLibraryCanManageProvider))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('import-register-products'),
                onPressed: _busy ? null : _registerProducts,
                icon: const Icon(Icons.library_add_outlined, size: 18),
                label: Text(l10n.rpOpen(_registrable.length)),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),

        _SectionLabel(l10n.importHeaderSection),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.planReviewHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.md),
        _field(l10n, _numberController, l10n.deliveryNumberLabel, Icons.tag,
            wasRead: preview.deliveryNumber != null),
        _field(l10n, _supplierController, l10n.fieldSupplier,
            Icons.local_shipping_outlined,
            wasRead: preview.supplierName != null),
        _field(l10n, _regNoController, l10n.fieldRegistrationNumber,
            Icons.verified_outlined,
            wasRead: preview.registrationNumber != null),
        _field(l10n, _customerCodeController, l10n.fieldCustomerCode,
            Icons.badge_outlined,
            wasRead: preview.customerCode != null),
        _field(l10n, _docNumberController, l10n.fieldDocNumber,
            Icons.receipt_long_outlined,
            wasRead: preview.docNumber != null),
        _field(l10n, _codeController, l10n.companyCode, Icons.tag_outlined,
            helper: 'ABC → ABC-00001', caps: true, wasRead: false),

        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _SectionLabel(l10n.importLinesPreview)),
            if (_hasDuplicateJans)
              TextButton.icon(
                onPressed: _mergeDuplicateJans,
                icon: const Icon(Icons.call_merge, size: 18),
                label: Text(l10n.importMergeDuplicates),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _LinesPreview(
          lines: _lines,
          onEdit: (i) => _editLine(index: i),
          onDelete: _deleteLine,
          onSplit: _splitLine,
          onPickProduct: _pickProduct,
        ),
        if (preview.columns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.importColumnsRead),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in preview.columns)
                if (c.header.isNotEmpty)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                        '${c.header} → ${columnFieldLabel(l10n, c.field)}',
                        style: theme.textTheme.bodySmall),
                  ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _editLine(index: null),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.importAddLine),
        ),
      ],
    );
  }

  int get _unresolvedCount => _lines.where((l) => l['product_id'] == null).length;

  static String _janOf(Map<String, dynamic> l) =>
      normalizeJanKey('${l['jan_code'] ?? ''}'.isEmpty ? '${l['raw_jan_code'] ?? ''}' : '${l['jan_code']}');

  /// Indexes of lines with no product that carry a JAN: they can become
  /// products in our format (0111).
  List<int> get _registrable => [
        for (final (i, l) in _lines.indexed)
          if (l['product_id'] == null && const {8, 13}.contains(_janOf(l).length)) i,
      ];

  /// Creates the products this note brings that we do not have yet, in our
  /// format, and ties its lines to them.
  Future<void> _registerProducts() async {
    final l10n = AppLocalizations.of(context);
    final created = await showRegisterProductsSheet(
      context,
      partnerId: _preview?.partnerId,
      lines: [for (final i in _registrable) {..._lines[i], 'row': i}],
    );
    if (created.isEmpty || !mounted) return;
    final byJan = {for (final c in created) normalizeJanKey(c.janCode): c};
    Map<String, dynamic> tie(Map<String, dynamic> l) {
      final c = l['product_id'] == null ? byJan[_janOf(l)] : null;
      if (c == null) return l;
      return {
        ...l,
        'product_id': c.productId,
        'product': {'id': c.productId, 'jan_code': c.janCode, 'name': c.name, 'maker': l['maker']},
        'matched_by': 'registered',
        'flags': [
          for (final f in (l['flags'] as List? ?? const []))
            if (f != 'unresolved' && f != 'no_maker') f,
        ],
      };
    }

    setState(() => _lines = [for (final l in _lines) tie(l)]);
    _snack(l10n.rpRegistered(created.length), tone: StatusTone.success);
  }

  /// Ties a line the dictionary could not place to one of our products. The
  /// company's writing stays on the line; on commit the server books it under
  /// our JAN and learns the writing for next time (0105).
  Future<void> _pickProduct(int index) async {
    final line = _lines[index];
    final writing = _supplierWriting(line);
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductPickerSheet(
        initialQuery: '${line['product_code'] ?? ''}'.trim().isNotEmpty
            ? '${line['product_code']}'
            : '${line['product_name'] ?? ''}',
        subtitle: writing.isEmpty ? null : writing,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lines[index] = {
        ...line,
        'product_id': picked.id,
        'product': {
          'id': picked.id,
          'jan_code': picked.janCode,
          'name': picked.name,
          'sku': picked.sku,
          'maker': picked.maker,
        },
        'matched_by': 'manual',
        'flags': [
          for (final f in (line['flags'] as List? ?? const []))
            if (f != 'unresolved' && f != 'no_maker') f,
        ],
      };
    });
  }

  int get _totalQuantity =>
      _lines.fold(0, (s, l) => s + _int(l['planned_quantity']));

  bool get _hasDuplicateJans {
    final seen = <String>{};
    for (final l in _lines) {
      final jan = (l['jan_code'] ?? '').toString();
      if (jan.isEmpty) continue;
      if (!seen.add(jan)) return true;
    }
    return false;
  }

  void _deleteLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  /// Splits a line's quantity roughly in half into a second line with the
  /// same JAN/product — a starting point the operator then fine-tunes by
  /// editing either resulting row's quantity (spec §31 line-item 分解).
  void _splitLine(int index) {
    final line = _lines[index];
    final qty = _int(line['planned_quantity']);
    if (qty < 2) return;
    final half = qty ~/ 2;
    setState(() {
      _lines[index] = {...line, 'planned_quantity': qty - half};
      _lines.insert(index + 1, {...line, 'planned_quantity': half});
    });
  }

  /// Combines every line sharing a JAN into one, summing quantities and
  /// keeping the first non-empty product name seen for it (spec §31 line-item
  /// 結合) — e.g. when OCR split one delivery-note row across two lines.
  void _mergeDuplicateJans() {
    final byJan = <String, Map<String, dynamic>>{};
    final withoutJan = <Map<String, dynamic>>[];
    final order = <String>[];
    for (final line in _lines) {
      final jan = (line['jan_code'] ?? '').toString();
      if (jan.isEmpty) {
        withoutJan.add(line);
        continue;
      }
      final existing = byJan[jan];
      if (existing == null) {
        order.add(jan);
        byJan[jan] = {...line};
      } else {
        byJan[jan] = {
          ...existing,
          'planned_quantity': _int(existing['planned_quantity']) +
              _int(line['planned_quantity']),
          'product_name':
              (existing['product_name'] as String?)?.isNotEmpty == true
                  ? existing['product_name']
                  : line['product_name'],
        };
      }
    }
    setState(() {
      _lines = [for (final jan in order) byJan[jan]!, ...withoutJan];
    });
  }

  /// Opens the edit sheet for an existing line ([index] given) or a new one
  /// ([index] null), and applies the result.
  Future<void> _editLine({required int? index}) async {
    final existing = index == null ? null : _lines[index];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _LineEditDialog(line: existing),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _lines.add(result);
      } else {
        _lines[index] = result;
      }
    });
  }

  /// One review field. When [wasRead] is false the field is highlighted with a
  /// "could not read — please enter" hint so blanks stand out.
  Widget _field(
    AppLocalizations l10n,
    TextEditingController controller,
    String label,
    IconData icon, {
    String? helper,
    bool caps = false,
    required bool wasRead,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextField(
        controller: controller,
        textCapitalization:
            caps ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper ?? (wasRead ? null : l10n.headerUnreadHint),
          helperMaxLines: 2,
          prefixIcon: Icon(icon),
          suffixIcon: wasRead
              ? null
              : const Icon(Icons.edit_note, size: 20),
        ),
      ),
    );
  }
}

/// A small bold section label used to group the review form.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700));
  }
}

/// A read-only preview of the first parsed lines so the operator can sanity
/// check what was extracted before registering.
/// Editable line items (spec §31): OCR gets the first read, but a misread JAN
/// or quantity, a row it missed, or one it split/merged wrongly is common
/// enough that "just abandon the import and re-enter it elsewhere" isn't
/// good enough — every row here is editable, deletable, and can be split or
/// merged before [PlanCommit] ever sees it.
class _LinesPreview extends StatelessWidget {
  const _LinesPreview({
    required this.lines,
    required this.onEdit,
    required this.onDelete,
    required this.onSplit,
    required this.onPickProduct,
  });

  final List<Map<String, dynamic>> lines;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSplit;
  final ValueChanged<int> onPickProduct;

  int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (lines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.importLinesEmpty,
            style:
                theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            InkWell(
              onTap: () => onEdit(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _LineIdentity(
                        line: lines[i],
                        onPickProduct: () => onPickProduct(i),
                        pickKey: ValueKey('import-pick-$i'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('×${_int(lines[i]['planned_quantity'])}',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: AppFonts.mono,
                            fontWeight: FontWeight.w700)),
                    if (_int(lines[i]['planned_quantity']) >= 2)
                      IconButton(
                        tooltip: l10n.importSplitLine,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.call_split, size: 18),
                        onPressed: () => onSplit(i),
                      ),
                    IconButton(
                      tooltip: l10n.actionDelete,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: scheme.error),
                      onPressed: () => onDelete(i),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How the company wrote a line: JAN, maker, name and 品番 as they appeared.
String _supplierWriting(Map<String, dynamic> line) => [
      line['raw_jan_code'] ?? line['jan_code'],
      line['maker'],
      line['product_name'],
      line['product_code'],
    ]
        .map((v) => (v ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .join(' · ');

/// One line's identity: our product in full, the company's writing faded under
/// it (UI kept the original for checking, 0103), and what the reading flagged.
class _LineIdentity extends StatelessWidget {
  const _LineIdentity({required this.line, required this.onPickProduct, this.pickKey});

  final Map<String, dynamic> line;
  final VoidCallback onPickProduct;
  final Key? pickKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final raw = line['product'];
    final product = raw is Map ? ResolvedProduct.fromJson(Map<String, dynamic>.from(raw)) : null;
    final writing = _supplierWriting(line);
    final faded = theme.textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.6));
    final problems = [
      for (final f in (line['flags'] as List? ?? const []))
        if (NotationFlag.isProblem('$f') && f != 'unresolved') '$f',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product != null) ...[
          ProductWithThumb(
            productId: product.id,
            janCode: product.janCode,
            productName: product.name,
            size: 36,
            child: Text(product.name,
                style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(
            [product.janCode, if (product.maker != null) product.maker!, if (product.sku != null) product.sku!]
                .join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
          ),
          if (writing.isNotEmpty)
            Text(l10n.importSupplierWriting(writing),
                style: faded, maxLines: 2, overflow: TextOverflow.ellipsis),
        ] else ...[
          Text(
            (line['product_name'] as String?)?.isNotEmpty == true
                ? line['product_name'] as String
                : '${line['jan_code']}',
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(writing,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: pickKey,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
              onPressed: onPickProduct,
              icon: Icon(Icons.link, size: 16, color: scheme.tertiary),
              label: Text('${l10n.ntNotMatched} — ${l10n.ntChooseProduct}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary)),
            ),
          ),
        ],
        if (problems.isNotEmpty)
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final f in problems)
                Text('⚠ ${flagLabel(l10n, f)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ],
          ),
        // How sure the reading is, field by field, against the thresholds
        // set in AI設定 (§50). Only the fields that need a look are listed.
        AiConfidenceRow(
          confidence: lineConfidence(
            [for (final f in (line['flags'] as List? ?? const [])) '$f'],
            hasJan: '${line['raw_jan_code'] ?? line['jan_code'] ?? ''}'.isNotEmpty,
            hasProduct: product != null,
          ),
        ),
      ],
    );
  }
}

/// A one-line coloured notice above the review form.
class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

/// Add/edit sheet for one line. Pops the edited map, or null if cancelled.
class _LineEditDialog extends StatefulWidget {
  const _LineEditDialog({this.line});

  /// Null when adding a new line.
  final Map<String, dynamic>? line;

  @override
  State<_LineEditDialog> createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<_LineEditDialog> {
  late final _jan =
      TextEditingController(text: '${widget.line?['jan_code'] ?? ''}');
  late final _product =
      TextEditingController(text: '${widget.line?['product_name'] ?? ''}');
  late final _quantity = TextEditingController(
      text: widget.line == null
          ? ''
          : '${widget.line!['planned_quantity'] ?? ''}');

  @override
  void dispose() {
    _jan.dispose();
    _product.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _scanJan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _jan.text = code);
  }

  void _save() {
    final jan = _jan.text.trim();
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    if (jan.isEmpty || qty <= 0) return;
    final janChanged = widget.line != null && '${widget.line!['jan_code']}' != jan;
    Navigator.pop(context, {
      ...?widget.line,
      // A different JAN is a different product: let the server resolve it.
      if (janChanged) ...{'product_id': null, 'product': null, 'matched_by': null},
      'jan_code': jan,
      'product_name': _product.text.trim(),
      'planned_quantity': qty,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEdit = widget.line != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.importEditLine : l10n.importAddLine),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _jan,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: AppFonts.mono),
            decoration: InputDecoration(
              labelText: l10n.importLineJan,
              suffixIcon: IconButton(
                tooltip: l10n.scanBarcode,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                onPressed: _scanJan,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _product,
            decoration: InputDecoration(labelText: l10n.importLineProduct),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantity,
            autofocus: !isEdit,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            // Large-number UI (spec §35): quantity is the one number this
            // dialog exists to get right.
            style: theme.textTheme.displaySmall
                ?.copyWith(fontFamily: AppFonts.mono, fontWeight: FontWeight.w600),
            decoration: InputDecoration(labelText: l10n.importLineQuantity),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEdit ? l10n.actionSave : l10n.importAddLine),
        ),
      ],
    );
  }
}
