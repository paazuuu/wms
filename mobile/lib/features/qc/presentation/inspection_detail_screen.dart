import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../product/application/product_providers.dart';
import '../../product/domain/product.dart';
import '../../putaway/presentation/putaway_queue_screen.dart';
import '../application/attachment_providers.dart';
import '../application/inspection_providers.dart';
import '../application/qc_scan_mode.dart';
import '../data/delivery_note_reader.dart';
import '../domain/delivery_note.dart';
import '../domain/attachment.dart';
import '../domain/inspection.dart';
import 'qc_result_ui.dart';
import '../../../core/offline/pending_sync_banner.dart';
import '../data/offline_inspection_repository.dart';

/// One inspection: each received line with its count and pass/fail split, then
/// a sticky action to close it.
///
/// Since 0100 inspection is first a count — does what was counted (by scanning
/// piece by piece, or typing it) match what arrived — and goods are good by
/// default: lines nobody judged close as good after one confirmation.
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
        actions: [
          // Per piece, or pick-and-type (0101); kept on the device.
          PopupMenuButton<bool>(
            key: const ValueKey('qc-settings'),
            icon: const Icon(Icons.tune),
            onSelected: (v) {
              ref.read(scanCountsPieceProvider.notifier).set(v);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                    content: Text(v ? l10n.qcScanPieceOn : l10n.qcScanPieceOff)));
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<bool>(
                key: const ValueKey('qc-scan-mode'),
                value: !ref.read(scanCountsPieceProvider),
                checked: ref.read(scanCountsPieceProvider),
                child: Text(l10n.qcScanPieceMode),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Counts made offline wait here until the network is back (§58).
          PendingSyncBanner(onSync: () async {
            final repo = ref.read(inspectionRepositoryProvider);
            final sent = repo is OfflineInspectionRepository ? await repo.flush() : 0;
            ref.invalidate(inspectionDetailProvider(inspectionId));
            return sent;
          }),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(inspectionDetailProvider(inspectionId)),
              ),
              data: (inspection) => _Body(inspection: inspection),
            ),
          ),
        ],
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

  void _snack(String message, {bool danger = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
        action: action,
      ));
  }

  /// What completing the inspection did to the stock (§13, 0068). Held in state
  /// rather than read back, because it is a past event: the ledger has it, this
  /// document does not. Shown until the operator leaves the screen, because
  /// "are the 28 I passed sellable now" deserves more than a SnackBar.
  InspectionStockEffect? _effect;

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    // Nothing passes under the supplier's writing (0103): every line is ours
    // first.
    final unconverted = _inspection.unconvertedCount;
    if (unconverted > 0) {
      _snack(l10n.qcUnconvertedBlock(unconverted), danger: true);
      return;
    }
    // 0100: goods are good by default, so unchecked lines no longer block —
    // but closing them without a look deserves one confirmation.
    final unchecked = _inspection.uncheckedCount;
    if (unchecked > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.qcCompleteDefaultTitle),
          content: Text(l10n.qcCompleteDefaultBody(unchecked)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              key: const ValueKey('qc-complete-default-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.qcCompleteConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
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
        // The held-stock list changes the moment this closes, so it must not
        // serve a cached answer next time someone opens it.
        ref.invalidate(heldStockProvider);
        setState(() => _effect = updated.stockEffect);
        final ui = QcResultUi.of(l10n, updated.status);
        // §35: goods that just passed QC are what put-away works from, so
        // offer that next step rather than making the operator navigate back
        // and find it. An action on the success SnackBar, not an automatic
        // push: whoever wants to re-read the findings they just recorded
        // stays where they are.
        _snack(
          l10n.qcCompleted(ui.label),
          action: SnackBarAction(
            label: l10n.nextStepPutaway,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PutawayQueueScreen(),
            )),
          ),
        );
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
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
          // A photo taken here is QC evidence, not a loose image: §29 asks for
          // the kind so a later claim can find the right file, and the building
          // so RLS can scope it (0070).
          kind: AttachmentKind.qcImage,
          warehouseId: _inspection.warehouseId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(attachmentListProvider(
          (entityType: 'inspection', entityId: '${_inspection.id}'))),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// One line passed in full and settled at once (0099): its goods become
  /// shippable now, whatever the other lines are still waiting for.
  Future<void> _passAll(InspectionItem item) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result =
        await ref.read(inspectionRepositoryProvider).passItems([item.id]);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        ref.invalidate(inspectionListProvider);
        ref.invalidate(heldStockProvider);
        ref.invalidate(openInspectionLinesProvider);
        _snack(l10n.qcPassAllDone(item.actualQuantity));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// A scanned JAN counts one piece of its line (0100): inspection is first a
  /// count. A JAN the delivery did not bring is offered as 誤品.
  Future<void> _onScan(String code) async {
    final l10n = AppLocalizations.of(context);
    final jan = code.trim();
    if (jan.isEmpty || !_inspection.isOpen) return;
    // Ours or as the supplier wrote it, hyphens and case codes alike (0103).
    final key = normalizeJan(jan) ?? jan;
    bool same(InspectionItem i) =>
        (normalizeJan(i.janCode) ?? i.janCode) == key ||
        (i.srcJanCode != null && (normalizeJan(i.srcJanCode) ?? i.srcJanCode) == key);
    InspectionItem? item;
    for (final i in _inspection.items) {
      if (same(i) && !i.isFinal) {
        item = i;
        break;
      }
    }
    if (item == null) {
      if (_inspection.items.any(same)) {
        _snack(l10n.qcFinalBadge);
        return;
      }
      await _offerWrongItem(jan);
      return;
    }
    final line = item;
    // A sampling inspection (0104): a scan is one more piece of the sample.
    if (_inspection.isSampling) {
      await _countSample(line, 1);
      return;
    }
    // Cartons of hundreds: a scan picks the line and the quantity is typed.
    if (!ref.read(scanCountsPieceProvider)) {
      await _enterCount(line);
      return;
    }
    final name = line.productName.isNotEmpty ? line.productName : line.janCode;
    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .recordCount(line.id, 1, mode: InspectionCountMode.add);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (c) {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        _snack(c.difference == 0
            ? l10n.qcScanCountMatched(name, c.counted)
            : l10n.qcScanCounted(name, c.counted, c.received));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// [pieces] more of the line's sample checked (0104). When the sample is
  /// done the server accepts the whole line.
  Future<void> _countSample(InspectionItem item, int pieces) async {
    final l10n = AppLocalizations.of(context);
    final name = item.productName.isNotEmpty ? item.productName : item.janCode;
    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .recordCount(item.id, pieces, mode: InspectionCountMode.sample);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (c) {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        final done = (item.sampledQuantity ?? 0) + pieces;
        final target = item.sampleQuantity ?? 1;
        _snack(done >= target
            ? l10n.qcSampleDone(name)
            : l10n.qcSampleProgress(name, done, target));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// Points a line at one of our products (0103) — the supplier's writing
  /// matched nothing, or matched the wrong thing.
  Future<void> _convert(InspectionItem item) async {
    final l10n = AppLocalizations.of(context);
    final pick = await showModalBottomSheet<({Product product, bool remember})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ConvertSheet(item: item),
    );
    if (pick == null || !mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .convertItem(item.id, pick.product.id, remember: pick.remember);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        ref.invalidate(openInspectionLinesProvider);
        _snack(l10n.qcConverted(pick.product.name));
      },
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _offerWrongItem(String jan) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qcWrongItemTitle),
        content: Text(l10n.qcWrongItemBody(jan)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey('qc-wrong-item-record'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.qcWrongItemRecord),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result =
        await ref.read(inspectionRepositoryProvider).reportWrongItem(_inspection.id, jan);
    if (!mounted) return;
    result.when(
      success: (_) => _snack(l10n.qcWrongItemDone),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// Type the count instead of scanning each piece.
  Future<void> _enterCount(InspectionItem item) async {
    final l10n = AppLocalizations.of(context);
    final entry = await showDialog<({InspectionCountMode mode, int value})>(
      context: context,
      builder: (_) => _CountDialog(item: item),
    );
    if (entry == null || !mounted) return;
    setState(() => _busy = true);
    final result = await ref
        .read(inspectionRepositoryProvider)
        .recordCount(item.id, entry.value, mode: entry.mode);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(inspectionDetailProvider(_inspection.id)),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// Ticked: right goods, about the right number (0101). Unticking takes it
  /// back.
  Future<void> _tick(InspectionItem item, bool on) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final result = await ref.read(inspectionRepositoryProvider).recordCount(
        item.id, 0,
        mode: on ? InspectionCountMode.check : InspectionCountMode.clear);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => ref.invalidate(inspectionDetailProvider(_inspection.id)),
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  /// A photo of the supplier's delivery note, laid against the inspection
  /// (0101): matched lines show the note's figure; the rest are listed.
  Future<void> _readDeliveryNote() async {
    final l10n = AppLocalizations.of(context);
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    } on PlatformException {
      _snack(l10n.ocrUnavailable, danger: true);
      return;
    }
    if (shot == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final lines = await ref
          .read(deliveryNoteReaderProvider)
          .read(shot.path, deliveryPlanId: _inspection.deliveryPlanId);
      if (!mounted) return;
      if (lines.isEmpty) {
        _snack(l10n.qcNoteNone, danger: true);
        return;
      }
      await _applyNote(lines);
    } catch (e) {
      if (mounted) _snack(humanizeApiErrorMessage(l10n, '$e'), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applyNote(List<DeliveryNoteLine> lines) async {
    final l10n = AppLocalizations.of(context);
    final result =
        await ref.read(inspectionRepositoryProvider).applyDeliveryNote(_inspection.id, lines);
    if (!mounted) return;
    await result.when(
      success: (r) async {
        ref.invalidate(inspectionDetailProvider(_inspection.id));
        _snack(l10n.qcNoteApplied(r.matched));
        if (r.unmatched.isNotEmpty) {
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => _UnmatchedNoteSheet(
              lines: r.unmatched,
              onWrongItem: (line) async {
                Navigator.pop(sheetContext);
                final jan = line.janCode ?? line.productCode ?? line.productName ?? '';
                if (jan.isNotEmpty) await _offerWrongItem(jan);
              },
            ),
          );
        }
      },
      failure: (f) async =>
          _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
    );
  }

  Future<void> _scanWithCamera() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (code != null && mounted) await _onScan(code);
  }

  Future<void> _editItem(InspectionItem item) async {
    final l10n = AppLocalizations.of(context);
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
      failure: (f) => _snack(humanizeApiErrorMessage(l10n, f.message), danger: true),
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
        // How many lines have been counted and match what arrived (0100).
        if (_inspection.items.isNotEmpty && _inspection.countedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                tone: _inspection.matchedCount == _inspection.items.length
                    ? StatusTone.success
                    : StatusTone.info,
                icon: Icons.fact_check_outlined,
                label: l10n.qcMatchedSummary(
                    _inspection.matchedCount, _inspection.items.length),
                dense: true,
              ),
            ),
          ),
        if (_inspection.isSampling || _inspection.unconvertedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (_inspection.isSampling)
                    StatusPill(
                      key: const ValueKey('qc-sampling'),
                      tone: StatusTone.info,
                      icon: Icons.filter_center_focus,
                      label: l10n.qcSamplingBadge(
                          _inspection.samplePercent ?? 10, _inspection.sampleMin ?? 1),
                      dense: true,
                    ),
                  if (_inspection.unconvertedCount > 0)
                    StatusPill(
                      key: const ValueKey('qc-unconverted-count'),
                      tone: StatusTone.warning,
                      icon: Icons.swap_horiz,
                      label: l10n.qcUnconvertedCount(_inspection.unconvertedCount),
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
        _AttachmentsRow(
          entityId: _inspection.id,
          canAdd: _inspection.isOpen,
          busy: _busy,
          onAddPhoto: _addPhoto,
        ),
        // Before: what closing this will do to the stock. Since 0068 a failure
        // is not just a note on a document — it moves the goods out of
        // shippable — so the operator should know that before they tap, not
        // after.
        if (_inspection.isOpen && _inspection.failedUnits > 0)
          _WillHoldBanner(failedUnits: _inspection.failedUnits),
        // After: what it actually did.
        if (_effect != null) _StockEffectCard(effect: _effect!),
        if (_inspection.isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: ScanField(
                    hintText: l10n.qcScanHint,
                    autofocusOnWide: true,
                    dense: true,
                    onSubmitted: _onScan,
                  ),
                ),
                IconButton(
                  tooltip: l10n.scanBarcode,
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: _busy ? null : _scanWithCamera,
                ),
                IconButton(
                  key: const ValueKey('qc-read-note'),
                  tooltip: l10n.qcReadNote,
                  icon: const Icon(Icons.document_scanner_outlined),
                  onPressed: _busy ? null : _readDeliveryNote,
                ),
              ],
            ),
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
                  itemBuilder: (context, i) {
                    final item = _inspection.items[i];
                    final open = _inspection.isOpen && !item.isFinal;
                    return _ItemCard(
                      item: item,
                      onTap: open ? () => _editItem(item) : null,
                      onConvert: open && !_busy ? () => _convert(item) : null,
                      onSample: open && !_busy && _inspection.isSampling && !item.sampleDone
                          ? () => _countSample(item, 1)
                          : null,
                      onPassAll: open && !_busy && !item.isUnconverted
                          ? () => _passAll(item)
                          : null,
                      onEnterCount: open && !_busy ? () => _enterCount(item) : null,
                      onTick: open && !_busy ? (v) => _tick(item, v) : null,
                      inspectionOpen: _inspection.isOpen,
                    );
                  },
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
  const _ItemCard({
    required this.item,
    this.onTap,
    this.onPassAll,
    this.onEnterCount,
    this.onTick,
    this.inspectionOpen = true,
    this.onConvert,
    this.onSample,
  });

  /// Point the line at one of our products (0103).
  final VoidCallback? onConvert;

  /// One more piece of the sample checked (0104).
  final VoidCallback? onSample;

  /// Tick (right goods, about the right number) or untick the line (0101).
  final ValueChanged<bool>? onTick;

  /// While open, a short count is "to go", not yet a shortage.
  final bool inspectionOpen;

  final InspectionItem item;
  final VoidCallback? onTap;

  /// Type the count for this line (0100).
  final VoidCallback? onEnterCount;

  /// Pass this line in full and settle it now (0099). Null once settled.
  final VoidCallback? onPassAll;

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
                  if (onTick != null || item.isCounted)
                    Tooltip(
                      message: l10n.qcTick,
                      child: Checkbox(
                        key: ValueKey('qc-tick-${item.id}'),
                        value: item.isCounted,
                        onChanged: onTick == null ? null : (v) => onTick!(v ?? false),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        // Ours (0103): JAN, 品番, maker.
                        Text(
                            [
                              item.janCode,
                              if (item.productSku != null) l10n.qcOwnSku(item.productSku!),
                              if (item.productMaker != null) item.productMaker!,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: AppFonts.mono,
                                color: scheme.onSurfaceVariant)),
                        // The supplier's writing, faded, to check against.
                        if (item.isUnconverted || item.notationDiffers)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l10n.qcSupplierNotation([
                                if (item.srcProductName != null) item.srcProductName!,
                                if (item.srcJanCode != null) 'JAN ${item.srcJanCode}',
                                if (item.srcProductCode != null)
                                  l10n.qcOwnSku(item.srcProductCode!),
                                if (item.srcMaker != null) item.srcMaker!,
                              ].join(' · ')),
                              key: ValueKey('qc-src-${item.id}'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (item.isUnconverted) ...[
                    StatusPill(
                        key: ValueKey('qc-unconverted-${item.id}'),
                        tone: StatusTone.warning,
                        label: l10n.qcUnconverted,
                        icon: Icons.swap_horiz,
                        dense: true),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  StatusPill(
                      tone: ui.tone, label: ui.label, icon: ui.icon, dense: true),
                  if (item.isFinal) ...[
                    const SizedBox(width: AppSpacing.xs),
                    StatusPill(
                        tone: StatusTone.neutral,
                        label: l10n.qcFinalBadge,
                        icon: Icons.lock_outline,
                        dense: true),
                  ],
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
              const SizedBox(height: AppSpacing.sm),
              // Inspection's first question (0100): is the number right?
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusPill(
                    key: ValueKey('qc-count-state-${item.id}'),
                    tone: !item.isCounted
                        ? StatusTone.neutral
                        : item.countMatches
                            ? StatusTone.success
                            : (inspectionOpen && item.countDifference! < 0)
                                ? StatusTone.warning
                                : StatusTone.danger,
                    icon: !item.isCounted
                        ? Icons.pin_outlined
                        : item.countMatches
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                    label: !item.isCounted
                        ? l10n.qcCountNone
                        : item.countMatches
                            ? l10n.qcCountMatch
                            : item.countDifference! < 0
                                ? (inspectionOpen
                                    ? l10n.qcCountRemaining(-item.countDifference!)
                                    : l10n.qcCountShort(-item.countDifference!))
                                : l10n.qcCountOver(item.countDifference!),
                    dense: true,
                  ),
                  if (item.isCounted)
                    Text(l10n.qcCountLine(item.countedQuantity!, item.actualQuantity),
                        style: theme.textTheme.bodySmall),
                  // How far the sample has got (0104).
                  if (item.sampleQuantity != null)
                    StatusPill(
                      key: ValueKey('qc-sample-${item.id}'),
                      tone: item.sampleDone ? StatusTone.success : StatusTone.info,
                      icon: Icons.filter_center_focus,
                      label: l10n.qcSampleState(
                          item.sampledQuantity ?? 0, item.sampleQuantity!),
                      dense: true,
                    ),
                  // What the supplier's delivery note says (0101).
                  if (item.noteQuantity != null)
                    StatusPill(
                      key: ValueKey('qc-note-${item.id}'),
                      tone: item.noteQuantity == item.actualQuantity
                          ? StatusTone.neutral
                          : StatusTone.warning,
                      icon: Icons.receipt_long_outlined,
                      label: l10n.qcNoteQuantity(item.noteQuantity!),
                      dense: true,
                    ),
                ],
              ),
              if (onPassAll != null || onEnterCount != null || onConvert != null ||
                  onSample != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (onConvert != null)
                        TextButton.icon(
                          key: ValueKey('qc-convert-${item.id}'),
                          onPressed: onConvert,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: Text(item.isUnconverted
                              ? l10n.qcConvert
                              : l10n.qcConvertChange),
                        ),
                      if (onSample != null)
                        TextButton.icon(
                          key: ValueKey('qc-sample-add-${item.id}'),
                          onPressed: onSample,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.qcSampleAdd),
                        ),
                      if (onEnterCount != null)
                        TextButton.icon(
                          key: ValueKey('qc-count-${item.id}'),
                          onPressed: onEnterCount,
                          icon: const Icon(Icons.pin_outlined, size: 18),
                          label: Text(l10n.qcEnterCount),
                        ),
                      if (onPassAll != null)
                        TextButton.icon(
                          key: ValueKey('qc-pass-all-${item.id}'),
                          onPressed: onPassAll,
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text(l10n.qcPassAll),
                        ),
                    ],
                  ),
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
                        itemBuilder: (context, i) => _AttachmentThumbnail(
                          attachment: attachments[i],
                          canWithdraw: canAdd,
                        ),
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

/// What a file is, in words (§29's kinds, 0070). A delivery note is not a
/// damage photo, and a claim against a supplier turns on telling them apart.
String attachmentKindLabel(AppLocalizations l10n, AttachmentKind kind) =>
    switch (kind) {
      AttachmentKind.photo => l10n.attachmentKindPhoto,
      AttachmentKind.deliveryNote => l10n.attachmentKindDeliveryNote,
      AttachmentKind.qcImage => l10n.attachmentKindQcImage,
      AttachmentKind.damage => l10n.attachmentKindDamage,
      AttachmentKind.document => l10n.attachmentKindDocument,
      AttachmentKind.label => l10n.attachmentKindLabel,
      AttachmentKind.other => l10n.attachmentKindOther,
    };

class _AttachmentThumbnail extends ConsumerWidget {
  const _AttachmentThumbnail({
    required this.attachment,
    this.canWithdraw = false,
  });

  final Attachment attachment;

  /// Only while the inspection is still open: withdrawing needs the same
  /// permission as recording a finding, and the server enforces it anyway.
  final bool canWithdraw;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.attachmentWithdrawQ),
        content: Text(l10n.attachmentWithdrawBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.attachmentWithdraw),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result = await ref
        .read(attachmentRepositoryProvider)
        .withdraw(attachment.id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(attachmentListProvider((
          entityType: attachment.entityType,
          entityId: attachment.entityId,
        )));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.attachmentWithdrawn)));
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(humanizeApiErrorMessage(l10n, f.message)),
          backgroundColor: Theme.of(context).colorScheme.error,
        )),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(attachmentKindLabel(l10n, attachment.kind)),
              subtitle: Text([
                attachment.caption ?? l10n.attachmentNoCaption,
                if (attachment.byteSize != null)
                  l10n.attachmentSize((attachment.byteSize! / 1024).ceil()),
              ].join('  ·  ')),
              trailing: attachment.isWithdrawn
                  ? StatusPill(
                      tone: StatusTone.neutral,
                      label: l10n.attachmentWithdrawnBadge,
                      dense: true,
                    )
                  : null,
            ),
            if (canWithdraw && !attachment.isWithdrawn)
              ListTile(
                leading: Icon(Icons.undo,
                    color: Theme.of(ctx).colorScheme.error),
                title: Text(l10n.attachmentWithdraw,
                    style:
                        TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _withdraw(context, ref);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(attachmentSignedUrlProvider(attachment));

    return InkWell(
      onTap: () => _open(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 64,
          child: async.when(
            loading: () =>
                Container(color: theme.colorScheme.surfaceContainerHigh),
            error: (_, __) => _brokenThumb(theme),
            data: (url) => Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _brokenThumb(theme),
            ),
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

/// Shown on an open inspection that has failures recorded: closing it will move
/// those goods out of shippable stock (§13).
class _WillHoldBanner extends StatelessWidget {
  const _WillHoldBanner({required this.failedUnits});

  final int failedUnits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.qcWillHold(failedUnits),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// What completing the inspection released and held. The question this answers
/// is "can I ship the ones that passed", which a status word cannot.
class _StockEffectCard extends StatelessWidget {
  const _StockEffectCard({required this.effect});

  final InspectionStockEffect effect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n.qcEffectTitle,
                    style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (effect.releasedToOk > 0)
            Text(l10n.qcEffectReleased(effect.releasedToOk)),
          if (effect.failedQuantity > 0)
            Text(l10n.qcEffectHeld(
                effect.failedQuantity, effect.failedTo ?? 'DAMAGED')),
          // Not an error, and worth saying plainly: part of what was judged was
          // never gated, so nothing moved for it.
          if (effect.countShortHeld > 0)
            Text(l10n.qcEffectCountShort(effect.countShortHeld)),
          if (effect.hasUnheld)
            Text(
              l10n.qcEffectNotHeld(effect.notInQcPending),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (effect.movedNothing)
            Text(
              l10n.qcEffectNothingMoved,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// The count for one line, typed (0100). Owns its controller, so the field
/// outlives the dialog's closing animation.
class _CountDialog extends StatefulWidget {
  const _CountDialog({required this.item});

  final InspectionItem item;

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

/// Pops (mode, value). Adding is the default once something has been counted
/// — the next carton, or tomorrow's share of the same delivery.
class _CountDialogState extends State<_CountDialog> {
  late InspectionCountMode _mode =
      widget.item.isCounted ? InspectionCountMode.add : InspectionCountMode.set;
  late final _controller = TextEditingController(
      text: widget.item.isCounted
          ? ''
          : '${widget.item.noteQuantity ?? widget.item.actualQuantity}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final value = int.tryParse(_controller.text.trim());
    return AlertDialog(
      title: Text(l10n.qcEnterCountTitle(
          item.productName.isNotEmpty ? item.productName : item.janCode)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.qcCountSoFar(item.countedQuantity ?? 0, item.actualQuantity)),
          if (item.noteQuantity != null) Text(l10n.qcNoteQuantity(item.noteQuantity!)),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<InspectionCountMode>(
            segments: [
              ButtonSegment(
                  value: InspectionCountMode.add, label: Text(l10n.qcCountModeAdd)),
              ButtonSegment(
                  value: InspectionCountMode.set, label: Text(l10n.qcCountModeSet)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _mode = v.first;
              _controller.text = _mode == InspectionCountMode.set
                  ? '${item.countedQuantity ?? item.noteQuantity ?? item.actualQuantity}'
                  : '';
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('qc-count-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
                labelText: _mode == InspectionCountMode.add
                    ? l10n.qcCountAddHint
                    : l10n.qcCountSetHint),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('qc-count-save'),
          onPressed: value == null
              ? null
              : () {
                  // Read at the tap, not at the last rebuild.
                  final v = int.tryParse(_controller.text.trim());
                  if (v != null) Navigator.pop(context, (mode: _mode, value: v));
                },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// Delivery-note lines no inspection line answered (0101).
class _UnmatchedNoteSheet extends StatelessWidget {
  const _UnmatchedNoteSheet({required this.lines, required this.onWrongItem});

  final List<DeliveryNoteLine> lines;
  final ValueChanged<DeliveryNoteLine> onWrongItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.qcNoteUnmatchedTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.qcNoteUnmatchedBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final line in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.label),
                subtitle: Text([line.janCode, line.productCode]
                    .whereType<String>()
                    .join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (line.quantity != null) Text('${line.quantity}'),
                    TextButton(
                      onPressed: () => onWrongItem(line),
                      child: Text(l10n.qcWrongItemRecord),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks the product of ours a line is booked under (0103). Opens on a search
/// for how the supplier wrote it; remembering is the default, so the same
/// writing converts by itself next time.
class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.item});

  final InspectionItem item;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  late final _search = TextEditingController(
      text: widget.item.srcProductName ?? widget.item.productName);
  bool _remember = true;
  bool _loading = false;
  String? _error;
  List<Product> _hits = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(productRepositoryProvider).list(search: q.isEmpty ? null : q);
    if (!mounted) return;
    setState(() {
      _loading = false;
      r.when(success: (rows) => _hits = rows, failure: (f) => _error = f.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.qcConvertTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.qcSupplierNotation([
                  if (item.srcProductName != null) item.srcProductName!,
                  if (item.srcJanCode != null) 'JAN ${item.srcJanCode}',
                  if (item.srcProductCode != null) l10n.qcOwnSku(item.srcProductCode!),
                  if (item.srcMaker != null) item.srcMaker!,
                ].join(' · ')),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('qc-convert-search'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.qcConvertSearch,
                ),
                onSubmitted: (_) => _find(),
              ),
              CheckboxListTile(
                key: const ValueKey('qc-convert-remember'),
                contentPadding: EdgeInsets.zero,
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? true),
                title: Text(l10n.qcConvertRemember),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(humanizeApiErrorMessage(l10n, _error!),
                    style: TextStyle(color: scheme.error)),
              Expanded(
                child: _hits.isEmpty && !_loading
                    ? Center(child: Text(l10n.qcConvertNone))
                    : ListView(
                        children: [
                          for (final p in _hits)
                            ListTile(
                              key: ValueKey('qc-convert-pick-${p.id}'),
                              title: Text(p.name),
                              subtitle: Text([
                                p.janCode,
                                if (p.sku != null) l10n.qcOwnSku(p.sku!),
                                if (p.maker != null) p.maker!,
                              ].join(' · ')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(
                                  context, (product: p, remember: _remember)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
