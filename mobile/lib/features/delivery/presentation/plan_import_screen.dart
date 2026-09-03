import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../application/delivery_providers.dart';

/// Back-office upload: pick a supplier's Excel / PDF / image, and the backend
/// parses it (SheetJS for Excel, Gemini for PDF/image), normalizes JANs, and
/// creates a delivery plan — no command line, no service key on the device.
class PlanImportScreen extends ConsumerStatefulWidget {
  const PlanImportScreen({super.key});

  @override
  ConsumerState<PlanImportScreen> createState() => _PlanImportScreenState();
}

class _PlanImportScreenState extends ConsumerState<PlanImportScreen> {
  final _numberController = TextEditingController();
  final _supplierController = TextEditingController();
  PlatformFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _numberController.dispose();
    _supplierController.dispose();
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    final number = _numberController.text.trim();
    if (file == null || number.isEmpty) {
      _snack(l10n.planImportChooseFirst, tone: StatusTone.warning);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      _snack(l10n.somethingWentWrong, tone: StatusTone.danger);
      return;
    }

    setState(() => _busy = true);
    final result = await ref.read(deliveryRepositoryProvider).importPlan(
          file: MultipartFile.fromBytes(bytes, filename: file.name),
          deliveryNumber: number,
          supplier: _supplierController.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.when(
      success: (summary) async {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        ref.invalidate(deliveryPlansProvider);
        _snack(
          l10n.planImportedSummary(summary.lineCount, summary.totalQuantity),
          tone: StatusTone.success,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planImportTitle)),
      body: ListView(
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
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _numberController,
            decoration: InputDecoration(
              labelText: l10n.deliveryNumberLabel,
              prefixIcon: const Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _supplierController,
            decoration: InputDecoration(
              labelText: l10n.fieldSupplier,
              prefixIcon: const Icon(Icons.local_shipping_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_busy ? l10n.planImporting : l10n.planImportAction),
          ),
        ],
      ),
    );
  }
}
