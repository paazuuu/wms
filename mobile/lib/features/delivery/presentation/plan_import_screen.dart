import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';
import '../data/delivery_repository.dart';

/// Back-office upload in two steps:
///   1. Pick a supplier's Excel / PDF / image and READ it — the backend parses
///      the lines and auto-reads the note header (company, registration number,
///      customer code, date) via Gemini, without saving anything.
///   2. REVIEW the header — every field is editable, anything the note could not
///      be read for is flagged — then register the plan.
///
/// When the company can't be read it is filed under a distinct "UNKNOWN"
/// reference series and flagged for manual assignment.
class PlanImportScreen extends ConsumerStatefulWidget {
  const PlanImportScreen({super.key});

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
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _file = result.files.first);
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
        setState(() => _preview = preview);
        HapticFeedback.selectionClick();
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
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
            lines: preview.lines,
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (summary) async {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        ref.invalidate(deliveryPlansProvider);
        _snack(
          summary.needsReview
              ? l10n.planUnidentifiedNote
              : l10n.planImportedSummary(
                  summary.lineCount, summary.totalQuantity),
          tone: summary.needsReview ? StatusTone.warning : StatusTone.success,
        );
        Navigator.of(context).pop();
      },
      failure: (f) => _snack(f.message, tone: StatusTone.danger),
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
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.pickFile),
        ),
        if (_file != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.planImportSelected(_file!.name),
            style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'FiraCode', color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _busy ? null : _read,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner_outlined),
          label: Text(_busy ? l10n.planReading : l10n.planReadAction),
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
                l10n.planPreviewCount(preview.lineCount, preview.totalQuantity),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.planReviewHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _busy ? null : _register,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(_busy ? l10n.planRegistering : l10n.planCommitAction),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: _busy ? null : () => setState(() => _preview = null),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(l10n.pickFile),
        ),
      ],
    );
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
