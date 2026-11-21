import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../reports/application/report_providers.dart';
import '../domain/stock_file.dart' show classCodeOf;

/// The 識別コード kept with the imports registered so far (class_codes_in_use,
/// 0218): every code read or typed in, once its import went in. Empty when
/// it cannot be had.
final pastClassCodesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final r = await ref.watch(reportRepositoryProvider).classCodes();
  return r is ApiSuccess<List<String>> ? r.data : const <String>[];
});

/// One line offered for a 識別コード (0218): its number, what it is, and the
/// code it has now (empty when none).
class ClassCodeRow {
  const ClassCodeRow({required this.lineNo, required this.label, this.code = ''});

  final int lineNo;
  final String label;
  final String code;
}

/// 識別コードをまとめて入力: a code, and the lines to give it — at first the
/// ones with none. Pops with the code (upper case; empty takes it off) and
/// the lines chosen; null when cancelled.
Future<({String code, Set<int> lineNos})?> showClassCodeBulkDialog(BuildContext context, List<ClassCodeRow> rows) =>
    showDialog<({String code, Set<int> lineNos})>(context: context, builder: (_) => _ClassCodeDialog(rows: rows));

class _ClassCodeDialog extends ConsumerStatefulWidget {
  const _ClassCodeDialog({required this.rows});

  final List<ClassCodeRow> rows;

  @override
  ConsumerState<_ClassCodeDialog> createState() => _ClassCodeDialogState();
}

class _ClassCodeDialogState extends ConsumerState<_ClassCodeDialog> {
  final _code = TextEditingController();
  final _q = TextEditingController();
  late final Set<int> _chosen = {for (final r in widget.rows) if (r.code.isEmpty) r.lineNo};

  @override
  void dispose() {
    _code.dispose();
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // This file's codes first, then the ones registered before.
    final inUse = ({for (final r in widget.rows) if (r.code.isNotEmpty) r.code}.toList()..sort());
    final before = [
      for (final c in ref.watch(pastClassCodesProvider).valueOrNull ?? const <String>[])
        if (!inUse.contains(c)) c,
    ];
    Widget chips(String title, List<String> codes, String keyPrefix) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: muted),
                for (final c in codes)
                  ActionChip(
                    key: ValueKey('$keyPrefix-$c'),
                    label: Text(c),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _code.text = c),
                  ),
              ]),
        );
    final q = _q.text.trim().toLowerCase();
    final listed = [
      for (final r in widget.rows)
        if (q.isEmpty || r.label.toLowerCase().contains(q) || r.code.toLowerCase().contains(q)) r,
    ];
    final typed = _code.text.trim();
    final valid = typed.isEmpty || classCodeOf(typed) != null;
    return AlertDialog(
      title: Text(l10n.ccBulkTitle),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.ccBulkIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('cc-code'),
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.lgClassCode,
              hintText: 'HL / BL',
              isDense: true,
              errorText: valid ? null : l10n.ccInvalid,
            ),
          ),
          if (inUse.isNotEmpty) chips(l10n.ccInFile, inUse, 'cc-use'),
          if (before.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: SingleChildScrollView(child: chips(l10n.ccUsedBefore, before, 'cc-past')),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('cc-search'),
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.ccSearch, isDense: true),
          ),
          Wrap(spacing: AppSpacing.xs, children: [
            TextButton(
              key: const ValueKey('cc-pick-all'),
              onPressed: () => setState(() => _chosen.addAll(listed.map((r) => r.lineNo))),
              child: Text(l10n.reportFilterAll),
            ),
            TextButton(
              key: const ValueKey('cc-pick-empty'),
              onPressed: () => setState(() {
                _chosen
                  ..clear()
                  ..addAll([for (final r in widget.rows) if (r.code.isEmpty) r.lineNo]);
              }),
              child: Text(l10n.ccPickEmpty),
            ),
            TextButton(
              key: const ValueKey('cc-pick-none'),
              onPressed: () => setState(() => _chosen.removeAll(listed.map((r) => r.lineNo))),
              child: Text(l10n.reportFilterNone),
            ),
          ]),
          Expanded(
            child: ListView(children: [
              for (final r in listed)
                CheckboxListTile(
                  key: ValueKey('cc-row-${r.lineNo}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _chosen.contains(r.lineNo),
                  title: Text('${r.lineNo}  ${r.label}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  secondary: r.code.isEmpty ? null : Text(r.code, style: theme.textTheme.labelLarge),
                  onChanged: (on) => setState(() => on == true ? _chosen.add(r.lineNo) : _chosen.remove(r.lineNo)),
                ),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('cc-apply'),
          onPressed: !valid || _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, (code: classCodeOf(typed) ?? '', lineNos: {..._chosen})),
          child: Text(typed.isEmpty ? l10n.ccClear(_chosen.length) : l10n.ccApply(_chosen.length)),
        ),
      ],
    );
  }
}
