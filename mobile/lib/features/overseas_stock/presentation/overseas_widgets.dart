import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/overseas_stock.dart';

Future<({String name, Uint8List bytes})?> pickOverseasFile() async {
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'xlsm', 'csv', 'tsv', 'txt', 'pdf', 'png', 'jpg', 'jpeg', 'webp'],
  );
  final f = r?.files.firstOrNull;
  return f?.bytes == null ? null : (name: f!.name, bytes: f.bytes!);
}

final _qtyFormat = NumberFormat('#,##0.###');

/// A quantity as shown: 1,234 or 1.5.
String overseasQty(num v) => _qtyFormat.format(v);

String overseasKindLabel(AppLocalizations l10n, String kind) =>
    kind == 'partner' ? l10n.osKindPartner : l10n.osKindBranch;

/// A quantity typed by hand.
Future<num?> showOverseasQtyDialog(BuildContext context, num initial) =>
    showDialog<num>(context: context, builder: (_) => _QtyDialog(initial: initial));

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.initial});

  final num initial;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final _c = TextEditingController(text: overseasQty(widget.initial).replaceAll(',', ''));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = num.tryParse(_c.text.replaceAll(',', '').trim());
    if (v != null && v >= 0) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.osQtyEdit),
      content: TextField(
        key: const ValueKey('os-qty-field'),
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('os-qty-ok'), onPressed: _ok, child: Text(l10n.actionSave)),
      ],
    );
  }
}

/// A site's rows: 行, (対象), JAN, 品番, 商品名, メーカー, 数量, 単位. With
/// [excluded], each row has a tick (read from a file, to register); with
/// [onQty], a tap on a quantity changes it.
class OverseasLinesTable extends StatefulWidget {
  const OverseasLinesTable({super.key, required this.lines, this.excluded, this.onInclude, this.onQty, this.height});

  final List<OverseasLine> lines;
  final Set<int>? excluded;
  final void Function(Iterable<int> rows, bool include)? onInclude;
  final void Function(OverseasLine line)? onQty;
  final double? height;

  @override
  State<OverseasLinesTable> createState() => _OverseasLinesTableState();
}

class _OverseasLinesTableState extends State<OverseasLinesTable> {
  final _across = ScrollController();
  static const _widths = [52.0, 44.0, 130.0, 120.0, 280.0, 120.0, 90.0, 64.0];

  @override
  void dispose() {
    _across.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    final ticks = widget.excluded != null;
    Widget cell(int i, Widget child, {bool end = false}) => i == 1 && !ticks
        ? const SizedBox.shrink()
        : Container(
            width: _widths[i],
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          );
    final lines = widget.lines;
    final excluded = widget.excluded ?? const <int>{};
    final on = lines.where((l) => !excluded.contains(l.rowNo)).length;
    final heads = [
      l10n.ofColRow, '', l10n.ofRoleJan, l10n.ofRoleCode, l10n.osColName, l10n.ofRoleMaker, l10n.osColQty, l10n.miFieldUnit,
    ];
    final header = Container(
      color: scheme.surfaceContainerHighest,
      child: Row(children: [
        for (final (i, h) in heads.indexed)
          i == 1
              ? cell(
                  1,
                  Checkbox(
                    key: const ValueKey('os-include-all'),
                    tristate: true,
                    visualDensity: VisualDensity.compact,
                    value: on == lines.length ? true : (on == 0 ? false : null),
                    onChanged: (_) => widget.onInclude?.call([for (final l in lines) l.rowNo ?? -1], on != lines.length),
                  ))
              : cell(i, Text(h, style: theme.textTheme.labelMedium), end: i == 6),
      ]),
    );
    Widget row(OverseasLine l) {
      final out = excluded.contains(l.rowNo);
      return Container(
        key: ValueKey('os-row-${l.rowNo}'),
        decoration: BoxDecoration(
          color: out ? scheme.surfaceContainerLow : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Opacity(
          opacity: out ? 0.55 : 1,
          child: Row(children: [
            cell(0, Text('${l.rowNo ?? ''}', style: small)),
            cell(
              1,
              Checkbox(
                key: ValueKey('os-include-${l.rowNo}'),
                visualDensity: VisualDensity.compact,
                value: !out,
                onChanged: (v) => widget.onInclude?.call([l.rowNo ?? -1], v ?? false),
              ),
            ),
            cell(2, Text(l.jan ?? '', style: small)),
            cell(3, Text(l.code ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(
              4,
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(l.name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                if (l.ours != null)
                  Text('${l10n.osOursBadge}: ${l.ours}',
                      key: ValueKey('os-ours-${l.rowNo}'),
                      style: small?.copyWith(color: scheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ]),
            ),
            cell(5, Text(l.maker ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
            cell(
              6,
              widget.onQty == null
                  ? Text(overseasQty(l.quantity), key: ValueKey('os-qty-${l.rowNo}'), style: theme.textTheme.titleSmall)
                  : InkWell(
                      key: ValueKey('os-qty-${l.rowNo}'),
                      onTap: () => widget.onQty!(l),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(overseasQty(l.quantity), style: theme.textTheme.titleSmall),
                        const SizedBox(width: 2),
                        Icon(Icons.edit_outlined, size: 14, color: scheme.primary),
                      ]),
                    ),
              end: true,
            ),
            cell(7, Text(l.unit ?? '', style: small)),
          ]),
        ),
      );
    }

    final width = [for (final (i, w) in _widths.indexed) if (i != 1 || ticks) w].fold(0.0, (a, w) => a + w);
    final Widget body = lines.length <= 60
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, for (final l in lines) row(l)])
        : SizedBox(
            width: width,
            height: (widget.height ?? MediaQuery.sizeOf(context).height * 0.7).clamp(360.0, 2000.0),
            child: Column(children: [
              header,
              Expanded(child: ListView.builder(itemCount: lines.length, itemBuilder: (_, i) => row(lines[i]))),
            ]),
          );
    return Scrollbar(
      controller: _across,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const ValueKey('os-table'),
        controller: _across,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: body,
      ),
    );
  }
}

/// A site added or changed: its name, ours or a partner, where, who.
Future<Map<String, dynamic>?> showOverseasSiteDialog(BuildContext context, {OverseasSite? site}) =>
    showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SiteDialog(site: site));

class _SiteDialog extends StatefulWidget {
  const _SiteDialog({this.site});

  final OverseasSite? site;

  @override
  State<_SiteDialog> createState() => _SiteDialogState();
}

class _SiteDialogState extends State<_SiteDialog> {
  late final _c = {
    'name': TextEditingController(text: widget.site?.name ?? ''),
    'country': TextEditingController(text: widget.site?.country ?? ''),
    'city': TextEditingController(text: widget.site?.city ?? ''),
    'contact': TextEditingController(text: widget.site?.contact ?? ''),
    'note': TextEditingController(text: widget.site?.note ?? ''),
  };
  late String _kind = widget.site?.kind ?? 'branch';
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final l10n = AppLocalizations.of(context);
    if (_c['name']!.text.trim().isEmpty) return setState(() => _error = l10n.osNameRequired);
    Navigator.pop(context, {
      'id': widget.site?.id,
      'kind': _kind,
      for (final e in _c.entries) e.key: e.value.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget f(String k, String label, {int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TextField(
            key: ValueKey('os-site-$k'),
            controller: _c[k],
            minLines: lines,
            maxLines: lines,
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );
    return AlertDialog(
      title: Text(widget.site == null ? l10n.osAddSite : l10n.osEditSite),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            f('name', l10n.osName),
            SegmentedButton<String>(
              key: const ValueKey('os-site-kind'),
              segments: [
                ButtonSegment(value: 'branch', label: Text(l10n.osKindBranch)),
                ButtonSegment(value: 'partner', label: Text(l10n.osKindPartner)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: f('country', l10n.osCountry)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('city', l10n.osCity)),
            ]),
            f('contact', l10n.osContact),
            f('note', l10n.osNote, lines: 2),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('os-site-ok'), onPressed: _ok, child: Text(l10n.actionSave)),
      ],
    );
  }
}
