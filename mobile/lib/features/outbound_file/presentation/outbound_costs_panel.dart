import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/edit_drawer.dart';
import '../../../core/ui/popconfirm.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/data/menu_visibility_repository.dart' show showPricesProvider;
import '../data/outbound_costs_repository.dart';
import '../data/outbound_file_repository.dart';
import 'outbound_file_screen.dart' show outboundFileSaverProvider, outboundMoney, outboundTabOpenerProvider;

/// The bills chosen to keep as evidence (overridden in tests).
final costFilePickerProvider = Provider<Future<List<({String name, Uint8List bytes})>> Function()>((_) => () async {
      final r = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true, type: FileType.custom,
          allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic', 'xlsx', 'xls', 'xlsm', 'csv']);
      return [
        for (final f in r?.files ?? const <PlatformFile>[])
          if (f.bytes != null) (name: f.name, bytes: f.bytes!),
      ];
    });

/// A typed yen amount: commas, ¥ and 円 allowed; empty is none. Null on
/// something that is not an amount.
({bool ok, double? value}) parseYen(String text) {
  final t = text.replaceAll(RegExp(r'[,，¥￥円\s]'), '');
  if (t.isEmpty) return (ok: true, value: null);
  final v = double.tryParse(t);
  return v == null || v < 0 ? (ok: false, value: null) : (ok: true, value: v);
}

/// 費用 (0214): a list's 輸送費 — and for a 在庫外出荷 its 委託手数料 —
/// with the bills kept behind them. Each opens in a drawer to be typed,
/// read off a bill by the AI, or given its evidence; the bills open on the
/// spot and download again later. Shown to those who see prices.
class OutboundCostsPanel extends ConsumerWidget {
  const OutboundCostsPanel({super.key, required this.detail, required this.onChanged});

  final OutboundFileDetail detail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showPricesProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final f = detail.file;
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CostRow(detail: detail, kind: OutboundCostKind.freight, onChanged: onChanged),
      if (f.proxy) _CostRow(detail: detail, kind: OutboundCostKind.fee, onChanged: onChanged),
      if (!detail.costsEditable && !f.undone)
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Row(key: const ValueKey('oc-locked'), children: [
            Icon(Icons.lock_outline, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(l10n.ocLocked,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
    ]);
  }
}

Future<void> _openEvidence(BuildContext context, WidgetRef ref, OutboundCostFile c) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final tab = ref.read(outboundTabOpenerProvider)();
  final r = await ref.read(outboundCostsRepositoryProvider).evidenceBytes(c.storagePath);
  switch (r) {
    case ApiSuccess(:final data):
      if (tab != null) {
        tab.showBytes(data, c.mime);
      } else {
        await ref.read(outboundFileSaverProvider)(c.fileName, data);
      }
    case ApiFailure(:final message):
      tab?.close();
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

Future<void> _downloadEvidence(BuildContext context, WidgetRef ref, OutboundCostFile c) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(outboundCostsRepositoryProvider).evidenceBytes(c.storagePath);
  switch (r) {
    case ApiSuccess(:final data):
      await ref.read(outboundFileSaverProvider)(c.fileName, data);
      messenger.showSnackBar(SnackBar(content: Text(l10n.ofFileSaved(c.fileName))));
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

class _CostRow extends ConsumerWidget {
  const _CostRow({required this.detail, required this.kind, required this.onChanged});

  final OutboundFileDetail detail;
  final OutboundCostKind kind;
  final VoidCallback onChanged;

  bool get _fee => kind == OutboundCostKind.fee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final f = detail.file;
    final scheme = Theme.of(context).colorScheme;
    final amount = _fee ? f.feeJpy : f.freightJpy;
    final files = [for (final c in detail.costFiles) if (c.kind == kind) c];
    final label = amount == null
        ? (_fee ? l10n.prFeeNone : l10n.ocFreightNone)
        : (_fee ? l10n.prFeeLabel('¥${outboundMoney(amount)}') : l10n.ocFreightLabel('¥${outboundMoney(amount)}'));
    return Wrap(
      key: ValueKey(_fee ? 'of-fee' : 'of-freight'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Icon(_fee ? Icons.payments_outlined : Icons.local_shipping_outlined, size: 18, color: scheme.onSurfaceVariant),
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: amount == null ? scheme.warning : null)),
        for (final c in files)
          Tooltip(
            message: l10n.ocOpen,
            child: ActionChip(
              key: ValueKey('oc-chip-${c.id}'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.receipt_long_outlined, size: 16),
              label: Text(c.fileName, overflow: TextOverflow.ellipsis),
              onPressed: () => _openEvidence(context, ref, c),
            ),
          ),
        if (detail.costsEditable && !f.undone)
          TextButton.icon(
            key: ValueKey(_fee ? 'of-fee-edit' : 'of-freight-edit'),
            onPressed: () async {
              final saved = await showEditDrawer<bool>(context, builder: (_) => _CostDrawer(detail: detail, kind: kind));
              onChanged();
              if (saved == true && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(_fee ? l10n.prFeeSaved : l10n.ocSaved)));
              }
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(l10n.ocEdit),
          ),
      ],
    );
  }
}

class _CostDrawer extends ConsumerStatefulWidget {
  const _CostDrawer({required this.detail, required this.kind});

  final OutboundFileDetail detail;
  final OutboundCostKind kind;

  @override
  ConsumerState<_CostDrawer> createState() => _CostDrawerState();
}

class _CostDrawerState extends ConsumerState<_CostDrawer> {
  late final _c = TextEditingController(text: () {
    final v = _fee ? widget.detail.file.feeJpy : widget.detail.file.freightJpy;
    return v == null ? '' : outboundMoney(v);
  }());
  late final List<OutboundCostFile> _files = [for (final c in widget.detail.costFiles) if (c.kind == widget.kind) c];
  bool _busy = false;
  String? _note;
  bool _noteWarn = false;
  String? _error;

  bool get _fee => widget.kind == OutboundCostKind.fee;
  OutboundCostsRepository get _repo => ref.read(outboundCostsRepositoryProvider);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _say(String text, {bool warn = false}) => setState(() {
        _note = text;
        _noteWarn = warn;
      });

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final picked = await ref.read(costFilePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    OutboundCostFile? first;
    for (final p in picked) {
      final r = await _repo.addEvidence(
        fileId: widget.detail.file.id,
        warehouseId: widget.detail.file.warehouseId,
        kind: widget.kind,
        name: p.name,
        bytes: p.bytes,
      );
      if (!mounted) return;
      switch (r) {
        case ApiSuccess(:final data):
          first ??= data;
          setState(() => _files.add(data));
          _say(l10n.ocUploaded(p.name));
        case ApiFailure(:final message):
          _say(humanizeApiErrorMessage(l10n, message), warn: true);
      }
    }
    setState(() => _busy = false);
    // With no amount yet, the first bill is read for one to check.
    if (first != null && _c.text.trim().isEmpty) await _read(first);
  }

  Future<void> _read(OutboundCostFile c) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _note = l10n.ocReading;
      _noteWarn = false;
    });
    final r = await _repo.readAmount(c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess(:final data):
        final v = data?.subtotal ?? data?.total;
        if (data == null || v == null) {
          _say(l10n.ocReadNone, warn: true);
          return;
        }
        _c.text = outboundMoney(v);
        _say(l10n.ocReadDone(
          data.subtotal == null ? '—' : '¥${outboundMoney(data.subtotal)}',
          data.total == null ? '—' : '¥${outboundMoney(data.total)}',
          data.subtotal != null ? l10n.ocUsedSubtotal : l10n.ocUsedTotal,
        ));
      case ApiFailure(:final message):
        _say(humanizeApiErrorMessage(l10n, message), warn: true);
    }
  }

  Future<void> _remove(OutboundCostFile c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(context,
        title: l10n.ocRemoveConfirm, okLabel: l10n.ocRemove, danger: true, okKey: const ValueKey('oc-remove-ok'));
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final r = await _repo.removeEvidence(c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        setState(() => _files.removeWhere((e) => e.id == c.id));
      case ApiFailure(:final message):
        _say(humanizeApiErrorMessage(l10n, message), warn: true);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final v = parseYen(_c.text);
    if (!v.ok) {
      setState(() => _error = l10n.ocErrNegative);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final id = widget.detail.file.id;
    final r = _fee
        ? await ref.read(outboundFileRepositoryProvider).setFee(id, v.value)
        : await _repo.setFreight(id, v.value);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        Navigator.pop(context, true);
      case ApiFailure(:final message):
        setState(() => _error = humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = widget.detail.file;
    final key = _fee ? 'of-fee' : 'of-freight';
    return EditDrawer(
      icon: Icon(_fee ? Icons.payments_outlined : Icons.local_shipping_outlined),
      title: Text(_fee ? l10n.pfColFee : l10n.pfColFreight),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_fee ? l10n.prFeeHint : l10n.ocFreightHint, style: theme.textTheme.bodySmall),
        if (f.status == 'shipped' && !f.proxy) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.ocAdminAfterShip,
              key: const ValueKey('oc-admin-note'), style: theme.textTheme.bodySmall?.copyWith(color: scheme.warning)),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: ValueKey('$key-field'),
          controller: _c,
          autofocus: true,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _fee ? l10n.ocFeeField : l10n.ocFreightField,
            prefixText: '¥ ',
            errorText: _error,
          ),
          onSubmitted: (_) => _busy ? null : _save(),
        ),
        if (_note != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_note!,
              key: const ValueKey('oc-note'),
              style: theme.textTheme.bodySmall?.copyWith(color: _noteWarn ? scheme.error : scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          Expanded(child: Text(l10n.ocEvidence, style: theme.textTheme.titleSmall)),
          OutlinedButton.icon(
            key: const ValueKey('oc-add'),
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(l10n.ocAddFile),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        if (_files.isEmpty)
          Text(l10n.ocEvidenceNone, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        for (final c in _files)
          ListTile(
            key: ValueKey('oc-file-${c.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(c.fileName, overflow: TextOverflow.ellipsis),
            subtitle: c.uploadedByName == null ? null : Text(c.uploadedByName!),
            trailing: Wrap(children: [
              IconButton(
                key: ValueKey('oc-open-${c.id}'),
                tooltip: l10n.ocOpen,
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => _openEvidence(context, ref, c),
              ),
              IconButton(
                key: ValueKey('oc-download-${c.id}'),
                tooltip: l10n.ocDownload,
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: () => _downloadEvidence(context, ref, c),
              ),
              IconButton(
                key: ValueKey('oc-read-${c.id}'),
                tooltip: l10n.ocRead,
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                onPressed: _busy ? null : () => _read(c),
              ),
              IconButton(
                key: ValueKey('oc-remove-${c.id}'),
                tooltip: l10n.ocRemove,
                icon: Icon(Icons.link_off, size: 20, color: scheme.error),
                onPressed: _busy ? null : () => _remove(c),
              ),
            ]),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: ValueKey('$key-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
