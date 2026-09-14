import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../data/delivery_repository.dart';

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
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _editLine(index: null),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.importAddLine),
        ),
      ],
    );
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
  });

  final List<Map<String, dynamic>> lines;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onSplit;

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (lines[i]['product_name'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? lines[i]['product_name'] as String
                                : '${lines[i]['jan_code']}',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${lines[i]['jan_code']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
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
    Navigator.pop(context, {
      ...?widget.line,
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
