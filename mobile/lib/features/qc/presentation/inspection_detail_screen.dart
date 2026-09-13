import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
import '../application/inspection_providers.dart';
import '../domain/attachment.dart';
import '../domain/inspection.dart';
import 'qc_result_ui.dart';

/// One inspection: each received line with its pass/fail split, then a sticky
/// action to close it. The backend refuses to close while lines are unchecked
/// (spec §10), so the button explains that rather than failing silently.
class InspectionDetailScreen extends ConsumerWidget {
  const InspectionDetailScreen({super.key, required this.inspectionId});

  final int inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(inspectionDetailProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.deliveryNumber ?? l10n.qcTitle),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(inspectionDetailProvider(inspectionId)),
        ),
        data: (inspection) => _Body(inspection: inspection),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.inspection});

  final Inspection inspection;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Inspection get _inspection => widget.inspection;

  void _snack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    if (_inspection.uncheckedCount > 0) {
      _snack(l10n.qcCompleteBlocked, danger: true);
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .complete(_inspection.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (updated) {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        ref.invalidate(inspectionListProvider);
        final ui = QcResultUi.of(l10n, updated.status);
        _snack(l10n.qcCompleted(ui.label));
      },
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _addPhoto() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.qcAttachmentCamera),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.qcAttachmentGallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _busy = true);
    final bytes = await file.readAsBytes();
    final result = await ref.read(attachmentRepositoryProvider).upload(
          entityType: 'inspection',
          entityId: '${_inspection.id}',
          bytes: bytes,
          fileName: file.name,
          contentType: attachmentContentTypeForFileName(file.name),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(attachmentListProvider(
          (entityType: 'inspection', entityId: '${_inspection.id}'))),
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  Future<void> _editItem(InspectionItem item) async {
    final finding = await showModalBottomSheet<InspectionFinding>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FindingSheet(item: item),
    );
    if (finding == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .saveItem(_inspection.id, item.id, finding);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(inspectionDetailProvider(_inspection.id)),
      failure: (f) => _snack(f.message, danger: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ui = QcResultUi.of(l10n, _inspection.status);
    final unchecked = _inspection.uncheckedCount;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              StatusPill(tone: ui.tone, label: ui.label, icon: ui.icon),
              const SizedBox(width: AppSpacing.sm),
              if (_inspection.supplierName != null)
                Expanded(
                  child: Text(
                    _inspection.supplierName!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (unchecked > 0)
                StatusPill(
                  tone: StatusTone.warning,
                  label: l10n.qcUnchecked(unchecked),
                  dense: true,
                )
              else if (_inspection.failedUnits > 0)
                StatusPill(
                  tone: StatusTone.danger,
                  label: l10n.qcFailedUnits(_inspection.failedUnits),
                  dense: true,
                ),
            ],
          ),
        ),
        _AttachmentsRow(
          entityId: _inspection.id,
          canAdd: _inspection.isOpen,
          busy: _busy,
          onAddPhoto: _addPhoto,
        ),
        Expanded(
          child: _inspection.items.isEmpty
              ? EmptyStateView(
                  icon: Icons.fact_check_outlined, title: l10n.qcListEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _inspection.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _ItemCard(
                    item: _inspection.items[i],
                    onTap: _inspection.isOpen
                        ? () => _editItem(_inspection.items[i])
                        : null,
                  ),
                ),
        ),
        if (_inspection.isOpen)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSpacing.minTouch,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _complete,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.done_all),
                    label: Text(_busy ? l10n.working : l10n.qcComplete),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.onTap});

  final InspectionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = QcResultUi.of(l10n, item.result);
    final title =
        item.productName.isNotEmpty ? item.productName : item.janCode;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(item.janCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(
                      tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _Stat(label: l10n.qcExpected, value: item.expectedQuantity),
                  _Stat(label: l10n.qcActual, value: item.actualQuantity),
                  _Stat(
                      label: l10n.qcPassed,
                      value: item.passedQuantity,
                      tone: StatusTone.success),
                  _Stat(
                      label: l10n.qcFailed,
                      value: item.failedQuantity,
                      tone: item.failedQuantity > 0
                          ? StatusTone.danger
                          : StatusTone.neutral),
                  // Recorded, never corrected away (spec §10).
                  _Stat(
                      label: l10n.qcDiscrepancy,
                      value: item.discrepancy,
                      tone: item.discrepancy != 0
                          ? StatusTone.warning
                          : StatusTone.neutral,
                      showSign: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.tone = StatusTone.neutral,
    this.showSign = false,
  });

  final String label;
  final int value;
  final StatusTone tone;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      StatusTone.success => scheme.primary,
      StatusTone.danger => scheme.error,
      StatusTone.warning => scheme.error,
      _ => scheme.onSurface,
    };
    final text = showSign && value > 0 ? '+$value' : '$value';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(text,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppFonts.mono,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

/// Bottom sheet for recording one line's findings.
class _FindingSheet extends StatefulWidget {
  const _FindingSheet({required this.item});

  final InspectionItem item;

  @override
  State<_FindingSheet> createState() => _FindingSheetState();
}

class _FindingSheetState extends State<_FindingSheet> {
  late final TextEditingController _passed = TextEditingController(
      text: '${widget.item.passedQuantity == 0 && widget.item.failedQuantity == 0 ? widget.item.actualQuantity : widget.item.passedQuantity}');
  late final TextEditingController _failed =
      TextEditingController(text: '${widget.item.failedQuantity}');
  late final TextEditingController _lot =
      TextEditingController(text: widget.item.lot ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.item.note ?? '');
  bool _hold = false;

  @override
  void dispose() {
    _passed.dispose();
    _failed.dispose();
    _lot.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.productName.isNotEmpty
                  ? widget.item.productName
                  : widget.item.janCode,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.qcSplitHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passed,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.qcPassed),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _failed,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l10n.qcFailed),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _lot,
              decoration: InputDecoration(labelText: l10n.qcLot),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.qcNote),
            ),
            SwitchListTile(
              value: _hold,
              onChanged: (v) => setState(() => _hold = v),
              title: Text(l10n.qcHold),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  InspectionFinding(
                    passedQuantity: int.tryParse(_passed.text) ?? 0,
                    failedQuantity: int.tryParse(_failed.text) ?? 0,
                    lot: _lot.text,
                    note: _note.text,
                    hold: _hold,
                  ),
                ),
                child: Text(l10n.qcRecord),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo evidence recorded against the inspection (spec §32, 0031) — a
/// horizontal strip of thumbnails with an add button when the inspection is
/// still open (adding requires `inspection.confirm`, same as recording a
/// finding).
class _AttachmentsRow extends ConsumerWidget {
  const _AttachmentsRow({
    required this.entityId,
    required this.canAdd,
    required this.busy,
    required this.onAddPhoto,
  });

  final int entityId;
  final bool canAdd;
  final bool busy;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(
        attachmentListProvider((entityType: 'inspection', entityId: '$entityId')));

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            if (canAdd) ...[
              _AddPhotoButton(busy: busy, onTap: onAddPhoto),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
                data: (attachments) => attachments.isEmpty
                    ? Text(l10n.qcAttachmentsEmpty,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) =>
                            _AttachmentThumbnail(attachment: attachments[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : Icon(Icons.add_a_photo_outlined,
                color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _AttachmentThumbnail extends ConsumerWidget {
  const _AttachmentThumbnail({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(attachmentSignedUrlProvider(attachment));

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: async.when(
          loading: () => Container(color: theme.colorScheme.surfaceContainerHigh),
          error: (_, __) => _brokenThumb(theme),
          data: (url) => Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _brokenThumb(theme),
          ),
        ),
      ),
    );
  }

  Widget _brokenThumb(ThemeData theme) => Container(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Icon(Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant),
      );
}
