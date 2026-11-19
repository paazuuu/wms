import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/edit_drawer.dart';
import '../../../core/ui/popconfirm.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../../record_notes/presentation/record_notes_panel.dart' show noteFilePickerProvider;
import '../../stock_import/presentation/import_view_screen.dart' show OriginalFileView;
import '../data/purchase_request_repository.dart';
import '../data/supplier_answer_repository.dart';

typedef _Picked = ({String name, Uint8List bytes});

/// 仕入先回答 (0218): the answers suppliers send back to a wish list — what
/// they can supply, how many, by when — kept as their files with a memo:
/// looked at on the spot, downloaded again later, found by supplier.
class SupplierAnswersTab extends ConsumerStatefulWidget {
  const SupplierAnswersTab({super.key});

  @override
  ConsumerState<SupplierAnswersTab> createState() => _SupplierAnswersTabState();
}

class _SupplierAnswersTabState extends ConsumerState<SupplierAnswersTab> {
  final _q = TextEditingController();
  bool _busy = false;

  SupplierAnswerRepository get _repo => ref.read(supplierAnswerRepositoryProvider);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool get _canEdit {
    final u = ref.watch(authControllerProvider).user;
    return (u?.hasPermission('purchase_order.manage') ?? false) || (u?.hasPermission('product.manage') ?? false);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// False (and said) when [r] failed.
  bool _ok(ApiResult<Object?> r) {
    if (r case ApiFailure(:final message)) {
      _snack(humanizeApiErrorMessage(AppLocalizations.of(context), message));
      return false;
    }
    return true;
  }

  Future<void> _edit([SupplierAnswer? a]) async {
    final l10n = AppLocalizations.of(context);
    final known = <String>{
      for (final x in ref.read(supplierAnswersProvider).valueOrNull ?? const <SupplierAnswer>[]) x.supplierName,
      for (final r in ref.read(purchaseRequestsProvider).valueOrNull ?? const []) r.supplierName ?? '',
    }.where((s) => s.trim().isNotEmpty).toList()
      ..sort();
    final out = await showEditDrawer<(SupplierAnswerDraft, List<_Picked>)>(
      context,
      builder: (_) => _AnswerForm(answer: a, suppliers: known),
    );
    if (out == null || !mounted) return;
    setState(() => _busy = true);
    final saved = await _repo.save(out.$1);
    if (!mounted) return;
    if (saved case ApiSuccess(:final data)) {
      for (final f in out.$2) {
        if (!_ok(await _repo.addFile(data, f.name, f.bytes))) break;
        if (!mounted) return;
      }
      _snack(l10n.saSaved);
    } else {
      _ok(saved);
    }
    setState(() => _busy = false);
    ref.invalidate(supplierAnswersProvider);
  }

  Future<void> _remove(SupplierAnswer a) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.saRemoveQ(a.supplierName),
      okLabel: l10n.actionDelete,
      okKey: const ValueKey('sa-remove-ok'),
      danger: true,
    );
    if (ok != true || !mounted) return;
    _ok(await _repo.remove(a.id));
    ref.invalidate(supplierAnswersProvider);
  }

  Future<void> _removeFile(SupplierAnswerFile f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showPopconfirm(
      context,
      title: l10n.saFileRemoveQ(f.name),
      okLabel: l10n.actionDelete,
      okKey: const ValueKey('sa-file-remove-ok'),
      danger: true,
    );
    if (ok != true || !mounted) return;
    _ok(await _repo.removeFile(f.id));
    ref.invalidate(supplierAnswersProvider);
  }

  Future<void> _download(SupplierAnswerFile f) async {
    final r = await _repo.fileBytes(f.path);
    if (r case ApiSuccess(:final data)) {
      await ref.read(saveFileProvider)(f.name, data);
    } else {
      _ok(r);
    }
  }

  /// The file as it is, on the spot; downloaded from there too.
  Future<void> _view(SupplierAnswerFile f) async {
    final r = await _repo.fileBytes(f.path);
    if (!mounted) return;
    if (r case ApiSuccess(:final data)) {
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (d) => Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: 1000,
            height: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
                child: Row(children: [
                  Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  TextButton.icon(
                    key: const ValueKey('sa-view-download'),
                    onPressed: () => ref.read(saveFileProvider)(f.name, data),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.saDownload),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(d).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(d),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: OriginalFileView(key: const ValueKey('sa-view'), fileName: f.name, bytes: data)),
            ]),
          ),
        ),
      );
    } else {
      _ok(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(supplierAnswersProvider);
    final day = DateFormat('y/MM/dd');
    final canEdit = _canEdit;
    return async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(
        message: humanizeApiErrorMessage(l10n, '$e'),
        onRetry: () => ref.invalidate(supplierAnswersProvider),
      ),
      data: (all) {
        final q = _q.text.trim().toLowerCase();
        final rows = [
          for (final a in all)
            if (q.isEmpty ||
                [a.supplierName, a.title ?? '', a.note ?? '', a.requestLabel ?? '', ...a.files.map((f) => f.name)]
                    .any((t) => t.toLowerCase().contains(q)))
              a,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
          children: [
            Text(l10n.saIntro, style: muted),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (canEdit)
                FilledButton.icon(
                  key: const ValueKey('sa-add'),
                  onPressed: _busy ? null : () => _edit(),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.note_add_outlined),
                  label: Text(l10n.saAdd),
                ),
              SizedBox(
                width: 320,
                child: TextField(
                  key: const ValueKey('sa-search'),
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.saSearch, isDense: true),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (rows.isEmpty) Text(all.isEmpty ? l10n.saEmpty : l10n.saNoMatch, key: const ValueKey('sa-empty'), style: muted),
            for (final a in rows)
              Card(
                key: ValueKey('sa-answer-${a.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(a.supplierName, style: theme.textTheme.titleSmall),
                          if (a.answeredOn != null) Text(l10n.saAnsweredAt(day.format(a.answeredOn!)), style: muted),
                          if (a.requestId != null)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.playlist_add_check, size: 16),
                              label: Text([
                                if (a.requestNumber != null) a.requestNumber!,
                                if (a.requestLabel != null) a.requestLabel!,
                              ].join('  ')),
                            ),
                        ]),
                      ),
                      if (canEdit) ...[
                        IconButton(
                          key: ValueKey('sa-edit-${a.id}'),
                          tooltip: l10n.saEdit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: _busy ? null : () => _edit(a),
                        ),
                        IconButton(
                          key: ValueKey('sa-remove-${a.id}'),
                          tooltip: l10n.actionDelete,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _remove(a),
                        ),
                      ],
                    ]),
                    if ((a.title ?? '').isNotEmpty) Text(a.title!, style: theme.textTheme.bodyLarge),
                    if ((a.note ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(a.note!, style: theme.textTheme.bodyMedium),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
                      for (final f in a.files)
                        InputChip(
                          key: ValueKey('sa-file-${f.id}'),
                          avatar: const Icon(Icons.description_outlined, size: 16),
                          label: Text(f.name),
                          tooltip: l10n.saView,
                          onPressed: () => _view(f),
                          onDeleted: canEdit ? () => _removeFile(f) : null,
                        ),
                      for (final f in a.files)
                        IconButton(
                          key: ValueKey('sa-download-${f.id}'),
                          tooltip: '${l10n.saDownload}: ${f.name}',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          onPressed: () => _download(f),
                        ),
                      if (a.files.isEmpty) Text(l10n.saNoFiles, style: muted),
                    ]),
                    if (a.createdByName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(a.createdByName!, style: muted),
                      ),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An answer's details and the files to put with it.
class _AnswerForm extends ConsumerStatefulWidget {
  const _AnswerForm({this.answer, this.suppliers = const []});

  final SupplierAnswer? answer;
  final List<String> suppliers;

  @override
  ConsumerState<_AnswerForm> createState() => _AnswerFormState();
}

class _AnswerFormState extends ConsumerState<_AnswerForm> {
  late final _supplier = TextEditingController(text: widget.answer?.supplierName ?? '');
  late final _title = TextEditingController(text: widget.answer?.title ?? '');
  late final _note = TextEditingController(text: widget.answer?.note ?? '');
  late DateTime _on = widget.answer?.answeredOn ?? DateTime.now();
  late int? _requestId = widget.answer?.requestId;
  final List<_Picked> _files = [];
  String? _error;

  @override
  void dispose() {
    _supplier.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ref.read(noteFilePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    setState(() => _files.addAll(picked));
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _on,
      firstDate: DateTime(_on.year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d != null && mounted) setState(() => _on = d);
  }

  void _done() {
    final l10n = AppLocalizations.of(context);
    if (_supplier.text.trim().isEmpty) {
      setState(() => _error = l10n.saNeedSupplier);
      return;
    }
    final a = widget.answer;
    Navigator.pop(context, (
      SupplierAnswerDraft(
        id: a?.id,
        supplierName: _supplier.text.trim(),
        // The supplier's record stays only while its name is unchanged.
        supplierId: a != null && a.supplierName == _supplier.text.trim() ? a.supplierId : null,
        requestId: _requestId,
        answeredOn: _on,
        title: _title.text,
        note: _note.text,
      ),
      _files,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(purchaseRequestsProvider).valueOrNull ?? const [];
    final day = DateFormat('y/MM/dd');
    return EditDrawer(
      title: Text(widget.answer == null ? l10n.saAdd : l10n.saEdit),
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: const ValueKey('sa-supplier'),
          controller: _supplier,
          decoration: InputDecoration(
            labelText: l10n.saSupplier,
            errorText: _error,
            suffixIcon: widget.suppliers.isEmpty
                ? null
                : PopupMenuButton<String>(
                    key: const ValueKey('sa-supplier-pick'),
                    tooltip: l10n.reportPick,
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (v) => setState(() => _supplier.text = v),
                    itemBuilder: (_) => [for (final s in widget.suppliers) PopupMenuItem(value: s, child: Text(s))],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InkWell(
          key: const ValueKey('sa-day'),
          onTap: _pickDay,
          child: InputDecorator(
            decoration: InputDecoration(labelText: l10n.saAnsweredOn, suffixIcon: const Icon(Icons.event_outlined)),
            child: Text(day.format(_on)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<int?>(
          key: const ValueKey('sa-request'),
          initialValue: lists.any((r) => r.id == _requestId) ? _requestId : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.saRequest),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(l10n.saNoRequest)),
            for (final r in lists)
              DropdownMenuItem<int?>(
                value: r.id,
                child: Text([r.number, r.customerName ?? r.title ?? ''].where((t) => t.isNotEmpty).join('  '),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _requestId = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('sa-title'),
          controller: _title,
          decoration: InputDecoration(labelText: l10n.saTitleField),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('sa-note'),
          controller: _note,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: l10n.saNote, alignLabelWithHint: true),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            key: const ValueKey('sa-pick-files'),
            onPressed: _pick,
            icon: const Icon(Icons.attach_file),
            label: Text(l10n.saPickFiles),
          ),
          for (final (i, f) in _files.indexed)
            InputChip(
              key: ValueKey('sa-picked-$i'),
              label: Text(f.name),
              onDeleted: () => setState(() => _files.removeAt(i)),
            ),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('sa-save'), onPressed: _done, child: Text(l10n.actionSave)),
      ],
    );
  }
}
