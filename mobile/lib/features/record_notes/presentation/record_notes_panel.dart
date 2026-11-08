import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import '../data/record_notes_repository.dart';

/// Files chosen to put with a note (overridden in tests).
final noteFilePickerProvider = Provider<Future<List<({String name, Uint8List bytes})>> Function()>((_) => () async {
      final r = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
      return [
        for (final f in r?.files ?? const <PlatformFile>[])
          if (f.bytes != null) (name: f.name, bytes: f.bytes!),
      ];
    });

/// メモ (0207): notes on a record — a 入荷希望リスト, a site abroad — each
/// with files; written, changed, taken off. The files download on a tap.
class RecordNotesPanel extends ConsumerStatefulWidget {
  const RecordNotesPanel({super.key, required this.subject, required this.subjectId, this.onChanged});

  final NoteSubject subject;
  final int subjectId;

  /// A note added or taken off (to count them again).
  final VoidCallback? onChanged;

  @override
  ConsumerState<RecordNotesPanel> createState() => _RecordNotesPanelState();
}

class _RecordNotesPanelState extends ConsumerState<RecordNotesPanel> {
  final _body = TextEditingController();
  final List<({String name, Uint8List bytes})> _pending = [];
  bool _busy = false;

  (NoteSubject, int) get _key => (widget.subject, widget.subjectId);
  RecordNotesRepository get _repo => ref.read(recordNotesRepositoryProvider);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void _refresh() {
    ref.invalidate(recordNotesProvider(_key));
    widget.onChanged?.call();
  }

  Future<bool> _ok<T>(ApiResult<T> r) async {
    if (r case ApiFailure(:final message)) {
      if (mounted) _snack(humanizeApiErrorMessage(AppLocalizations.of(context), message));
      return false;
    }
    return true;
  }

  Future<void> _attach() async {
    final files = await ref.read(noteFilePickerProvider)();
    if (files.isEmpty || !mounted) return;
    setState(() => _pending.addAll(files));
  }

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final body = _body.text.trim();
    if (body.isEmpty && _pending.isEmpty) return _snack(l10n.rnNeedText);
    setState(() => _busy = true);
    final r = await _repo.write(subject: widget.subject, subjectId: widget.subjectId, body: body);
    if (r case ApiSuccess(data: final id)) {
      for (final f in _pending) {
        if (!await _ok(await _repo.addFile(id, f.name, f.bytes))) break;
      }
      _body.clear();
      _pending.clear();
      _snack(l10n.rnSaved);
    } else {
      await _ok(r);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _edit(RecordNote n) async {
    final l10n = AppLocalizations.of(context);
    final text = await showDialog<String>(context: context, builder: (_) => _EditNoteDialog(initial: n.body));
    if (text == null || !mounted) return;
    if (await _ok(await _repo.write(id: n.id, subject: widget.subject, subjectId: widget.subjectId, body: text))) {
      _snack(l10n.rnSaved);
    }
    _refresh();
  }

  Future<void> _remove(RecordNote n) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.rnRemoveQ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('rn-remove-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.rnRemove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _ok(await _repo.remove(n.id));
    _refresh();
  }

  Future<void> _addFiles(RecordNote n) async {
    final files = await ref.read(noteFilePickerProvider)();
    if (files.isEmpty || !mounted) return;
    for (final f in files) {
      if (!await _ok(await _repo.addFile(n.id, f.name, f.bytes))) break;
    }
    _refresh();
  }

  Future<void> _removeFile(NoteFile f) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.rnFileRemoveQ(f.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('rn-file-remove-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _ok(await _repo.removeFile(f.id));
    _refresh();
  }

  Future<void> _download(NoteFile f) async {
    final r = await _repo.fileBytes(f.path);
    if (r case ApiSuccess(:final data)) {
      await ref.read(saveFileProvider)(f.name, data);
    } else {
      await _ok(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final notes = ref.watch(recordNotesProvider(_key));
    final when = DateFormat('y/MM/dd HH:mm');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(l10n.rnTitle, style: theme.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      // Write one.
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              key: const ValueKey('rn-body'),
              controller: _body,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(hintText: l10n.rnHint, isDense: true),
            ),
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.rnPending(_pending.length), style: muted),
              Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                for (final (i, f) in _pending.indexed)
                  InputChip(
                    key: ValueKey('rn-pending-$i'),
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: Text(f.name),
                    onDeleted: () => setState(() => _pending.removeAt(i)),
                  ),
              ]),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              OutlinedButton.icon(
                key: const ValueKey('rn-attach'),
                onPressed: _busy ? null : _attach,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(l10n.rnAttach),
              ),
              FilledButton.icon(
                key: const ValueKey('rn-add'),
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: Text(l10n.rnAdd),
              ),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ...notes.when(
        loading: () => [const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator()))],
        error: (e, _) => [Text(humanizeApiErrorMessage(l10n, '$e'), style: TextStyle(color: theme.colorScheme.error))],
        data: (list) => list.isEmpty
            ? [Text(l10n.rnEmpty, key: const ValueKey('rn-empty'), style: muted)]
            : [
                for (final n in list)
                  Card(
                    key: ValueKey('rn-note-${n.id}'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              [if (n.createdByName != null) n.createdByName!, if (n.createdAt != null) when.format(n.createdAt!)]
                                  .join(' · '),
                              style: muted,
                            ),
                          ),
                          IconButton(
                            key: ValueKey('rn-file-add-${n.id}'),
                            tooltip: l10n.rnAddFile,
                            icon: const Icon(Icons.attach_file, size: 18),
                            onPressed: () => _addFiles(n),
                          ),
                          IconButton(
                            key: ValueKey('rn-edit-${n.id}'),
                            tooltip: l10n.rnEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _edit(n),
                          ),
                          IconButton(
                            key: ValueKey('rn-remove-${n.id}'),
                            tooltip: l10n.rnRemove,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _remove(n),
                          ),
                        ]),
                        if (n.body.isNotEmpty) SelectableText(n.body, style: theme.textTheme.bodyMedium),
                        if (n.files.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                            for (final f in n.files)
                              InputChip(
                                key: ValueKey('rn-file-${f.id}'),
                                avatar: const Icon(Icons.download_outlined, size: 16),
                                label: Text(f.name),
                                onPressed: () => _download(f),
                                onDeleted: () => _removeFile(f),
                              ),
                          ]),
                        ],
                      ]),
                    ),
                  ),
              ],
      ),
    ]);
  }
}

class _EditNoteDialog extends StatefulWidget {
  const _EditNoteDialog({required this.initial});

  final String initial;

  @override
  State<_EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<_EditNoteDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.rnEdit),
      content: SizedBox(
        width: 480,
        child: TextField(key: const ValueKey('rn-edit-field'), controller: _c, minLines: 3, maxLines: 10, autofocus: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('rn-edit-ok'), onPressed: () => Navigator.pop(context, _c.text.trim()), child: Text(l10n.actionSave)),
      ],
    );
  }
}
