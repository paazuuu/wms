import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/offline/offline_providers.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/inspection_providers.dart';
import '../domain/attachment.dart';
import '../domain/inspection.dart';
import '../domain/inspection_item.dart';
import 'barcode_scan_screen.dart';
import 'inspection_status_ui.dart';

class InspectionDetailScreen extends ConsumerStatefulWidget {
  const InspectionDetailScreen({required this.inspectionId, super.key});

  final int inspectionId;

  @override
  ConsumerState<InspectionDetailScreen> createState() =>
      _InspectionDetailScreenState();
}

class _InspectionDetailScreenState
    extends ConsumerState<InspectionDetailScreen> {
  bool _busy = false;

  /// Fast mode: record each scan with quantity 1 and skip the quantity dialog,
  /// so a handheld scanner can rattle through items hands-free. Turn it off to
  /// confirm a quantity per item.
  bool _fastQtyOne = true;
  final FocusNode _scanFocus = FocusNode();

  int get _id => widget.inspectionId;

  @override
  void dispose() {
    _scanFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(inspectionDetailProvider(_id));
    final code = detail.valueOrNull?.code ?? 'Inspection';
    final pending =
        detail.valueOrNull?.status == InspectionStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: Text(code),
        actions: [
          IconButton(
            tooltip: 'Attach files',
            icon: const Icon(Icons.attach_file),
            onPressed: _busy ? null : _pickAndUpload,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: detail.hasValue && pending
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _scanWithCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          // Inline scan box: a handheld scanner (or manual entry) records an
          // item and immediately re-focuses for the next scan — no camera trip.
          if (detail.hasValue && pending)
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                  AppSpacing.lg, AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ScanField(
                      focusNode: _scanFocus,
                      autofocusOnWide: true,
                      hintText: _fastQtyOne
                          ? 'Scan to record (qty 1)'
                          : 'Scan item barcode to record',
                      onSubmitted: (barcode) {
                        if (!_busy) {
                          _recordScanned(barcode,
                              quantity: _fastQtyOne ? 1 : null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Tooltip(
                    message: _fastQtyOne
                        ? 'Fast mode: records quantity 1 per scan'
                        : 'Prompt for a quantity on each scan',
                    child: FilterChip(
                      showCheckmark: false,
                      avatar: Icon(
                        _fastQtyOne ? Icons.bolt : Icons.tune,
                        size: 18,
                      ),
                      label: const Text('Qty 1'),
                      selected: _fastQtyOne,
                      onSelected: (value) =>
                          setState(() => _fastQtyOne = value),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                detail.when(
                  data: (inspection) => _DetailBody(
                    inspection: inspection,
                    onComplete: _busy ? null : _complete,
                  ),
                  loading: () =>
                      const LoadingView(message: 'Loading inspection…'),
                  error: (error, _) => ErrorStateView(
                    message: '$error',
                    onRetry: () =>
                        ref.invalidate(inspectionDetailProvider(_id)),
                  ),
                ),
                if (_busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66020617),
                      child: LoadingView(message: 'Working…'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Open the camera scanner, then record the decoded barcode.
  Future<void> _scanWithCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code == null || !mounted) return;
    await _recordScanned(code, quantity: _fastQtyOne ? 1 : null);
  }

  /// Record one inspected item and return focus to the inline scan box so the
  /// next scan is captured immediately. When [quantity] is null the operator is
  /// prompted for it; otherwise it is recorded straight away (fast mode).
  Future<void> _recordScanned(String code, {int? quantity}) async {
    final qty = quantity ?? await _promptQuantity(code);
    if (qty == null || !mounted) {
      if (mounted) _scanFocus.requestFocus();
      return;
    }

    final payload = {'scanned_barcode': code, 'actual_quantity': qty};
    final repository = ref.read(inspectionRepositoryProvider);
    setState(() => _busy = true);
    final result = await repository.recordItem(_id, payload);
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      success: (_) async {
        await HapticFeedback.mediumImpact();
        ref.invalidate(inspectionDetailProvider(_id));
        _snack('Item recorded', tone: StatusTone.success);
      },
      failure: (f) async {
        if (_isOffline(f)) {
          await ref
              .read(offlineSyncServiceProvider)
              .enqueueRecordItem(_id, payload);
          _snack('Offline — item queued for sync', tone: StatusTone.warning);
        } else {
          _snack(f.message, tone: StatusTone.danger);
        }
      },
    );

    // Ready for the next scan without touching the screen.
    if (mounted) _scanFocus.requestFocus();
  }

  Future<int?> _promptQuantity(String code) {
    final controller = TextEditingController(text: '1');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actual quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanned: $code',
              style: const TextStyle(fontFamily: 'Fira Code', fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text) ?? 0),
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || !mounted) return;

    final files = <MultipartFile>[];
    final paths = <String>[];
    for (final file in picked.files) {
      if (file.bytes != null) {
        files.add(MultipartFile.fromBytes(file.bytes!, filename: file.name));
      } else if (file.path != null) {
        files.add(await MultipartFile.fromFile(file.path!, filename: file.name));
      }
      if (file.path != null) paths.add(file.path!);
    }
    if (files.isEmpty || !mounted) return;

    final repository = ref.read(inspectionRepositoryProvider);
    setState(() => _busy = true);
    final result = await repository.uploadAttachments(
      _id,
      files: files,
      kind: 'inspection',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      success: (uploaded) async {
        await HapticFeedback.mediumImpact();
        ref.invalidate(inspectionDetailProvider(_id));
        _snack('${uploaded.length} file(s) uploaded', tone: StatusTone.success);
      },
      failure: (f) async {
        if (_isOffline(f) && paths.isNotEmpty) {
          final sync = ref.read(offlineSyncServiceProvider);
          for (final path in paths) {
            await sync.enqueueAttachment(_id,
                filePath: path, kind: 'inspection');
          }
          _snack('Offline — ${paths.length} file(s) queued for sync',
              tone: StatusTone.warning);
        } else {
          _snack(f.message, tone: StatusTone.danger);
        }
      },
    );
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete inspection?'),
        content: const Text(
            'Mark this inspection as complete. You can still view it afterward.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = ref.read(inspectionRepositoryProvider);
    setState(() => _busy = true);
    final result = await repository.complete(_id);
    if (!mounted) return;
    setState(() => _busy = false);

    await result.when(
      success: (_) async {
        await HapticFeedback.mediumImpact();
        ref.invalidate(inspectionDetailProvider(_id));
        _snack('Inspection completed', tone: StatusTone.success);
      },
      failure: (f) async {
        if (_isOffline(f)) {
          await ref.read(offlineSyncServiceProvider).enqueueComplete(_id);
          _snack('Offline — completion queued for sync',
              tone: StatusTone.warning);
        } else {
          _snack(f.message, tone: StatusTone.danger);
        }
      },
    );
  }

  bool _isOffline(ApiFailure failure) => failure.statusCode == null;

  void _snack(String message, {StatusTone tone = StatusTone.neutral}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg) = switch (tone) {
      StatusTone.success => (Icons.check_circle, scheme.inverseSurface),
      StatusTone.warning => (Icons.cloud_off, scheme.inverseSurface),
      StatusTone.danger => (Icons.error_outline, scheme.error),
      _ => (Icons.info_outline, scheme.inverseSurface),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onInverseSurface),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: bg,
        ),
      );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.inspection, required this.onComplete});

  final Inspection inspection;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = inspection.status != InspectionStatus.pending;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
      children: [
        _HeaderCard(inspection: inspection),
        if (inspection.note != null && inspection.note!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _NoteCard(note: inspection.note!),
        ],
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(
          title: 'Items',
          trailing: '${inspection.items.length}',
        ),
        const SizedBox(height: AppSpacing.md),
        if (inspection.items.isEmpty)
          const _EmptyHint(
            icon: Icons.qr_code_scanner,
            text: 'No items yet. Tap Scan to record one.',
          )
        else
          ...inspection.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ItemCard(item: item),
              )),
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(
          title: 'Attachments',
          trailing: '${inspection.attachments.length}',
        ),
        const SizedBox(height: AppSpacing.md),
        if (inspection.attachments.isEmpty)
          const _EmptyHint(
            icon: Icons.attach_file,
            text: 'No attachments. Use the paperclip to add photos or files.',
          )
        else
          ...inspection.attachments.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AttachmentTile(attachment: a),
              )),
        const SizedBox(height: AppSpacing.xxl),
        if (!done)
          FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.done_all),
            label: const Text('Complete inspection'),
          )
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.verified, color: scheme.onSurfaceVariant, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Inspection completed',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = InspectionStatusUi.of(AppLocalizations.of(context), inspection.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusAvatar(tone: ui.tone, icon: ui.icon),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inspection.code, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        inspectionTypeLabel(AppLocalizations.of(context), inspection.type),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
              ],
            ),
            if (inspection.completedAt != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.event_available,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Completed ${_formatDate(inspection.completedAt!)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(note, style: const TextStyle(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing!,
              style: TextStyle(
                fontFamily: 'Fira Code',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final InspectionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = MatchResultUi.of(AppLocalizations.of(context), item.matchResult);
    final barcode =
        item.scannedBarcode ?? item.expectedBarcode ?? 'Item ${item.id}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    barcode,
                    style: const TextStyle(
                      fontFamily: 'Fira Code',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _QtyChip(label: 'Expected', value: item.expectedQuantity),
                const SizedBox(width: AppSpacing.sm),
                _QtyChip(
                  label: 'Actual',
                  value: item.actualQuantity,
                  tone: item.actualQuantity == item.expectedQuantity
                      ? StatusTone.neutral
                      : ui.tone,
                ),
              ],
            ),
            if (item.ngReason != null && item.ngReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.report_gmailerrorred,
                      size: 16, color: scheme.error),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.ngReason!,
                      style: TextStyle(color: scheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  const _QtyChip({
    required this.label,
    required this.value,
    this.tone = StatusTone.neutral,
  });

  final String label;
  final int value;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Fira Code',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tone == StatusTone.danger
                  ? scheme.error
                  : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (attachment.category) {
      'image' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'office' => Icons.description_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  attachment.category,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
