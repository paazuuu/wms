import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound_file/data/outbound_file_repository.dart' show OutboundMatch, outboundFileRepositoryProvider;
import '../../outbound_file/presentation/outbound_file_screen.dart' show outboundFileSaverProvider, outboundTabOpenerProvider;
import '../../shipment/application/packaging_providers.dart' show cartonTypesProvider;
import '../../shipment/domain/packaging.dart' show CartonType;
import '../../warehouse_context/application/warehouse_providers.dart';
import '../data/packing_list_excel.dart';
import '../data/packing_repository.dart';
import '../domain/packing.dart';
import '../domain/packing_list_reader.dart';

/// The packing list chosen to upload (overridden in tests).
final packingListPickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((_) => () async {
      final r = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: const ['xlsx', 'xlsm']);
      final f = r?.files.firstOrNull;
      return f?.bytes == null ? null : (name: f!.name, bytes: f.bytes!);
    });

final _kg = NumberFormat('#,##0.##');
final _m3 = NumberFormat('#,##0.####');

String packingKg(double v) => _kg.format(v);
String packingCbm(double v) => _m3.format(v);

/// "到货明细.xlsx" → "到货明细_改善版.xlsx".
String improvedNameOf(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return '${base}_改善版.xlsx';
}

/// The boxes with what the library knows of each product: its JAN, name
/// and id where the list gave only a 品番 (by JAN, else 品番 and maker).
Future<List<PackBox>> matchPackedProducts(WidgetRef ref, List<PackBox> boxes, int warehouseId) async {
  final keys = <String, Map<String, String?>>{};
  String k(PackItem i) => '${i.jan ?? ''}|${i.code ?? ''}|${i.maker ?? ''}';
  for (final b in boxes) {
    for (final i in b.items) {
      if (i.jan != null || i.code != null) keys.putIfAbsent(k(i), () => {'jan': i.jan, 'code': i.code, 'maker': i.maker});
    }
  }
  if (keys.isEmpty) return boxes;
  final order = keys.keys.toList();
  final r = await ref.read(outboundFileRepositoryProvider).match([for (final o in order) keys[o]!], warehouseId);
  final List<OutboundMatch> matches;
  switch (r) {
    case ApiSuccess(:final data):
      matches = data;
    case ApiFailure():
      return boxes;
  }
  final found = {for (final (i, m) in matches.indexed) order[i]: m};
  return [
    for (final b in boxes)
      b.copyWith(items: [
        for (final i in b.items)
          () {
            final m = found[k(i)];
            if (m == null || m.productId == null) return i;
            return PackItem(
              id: i.id,
              fileLineId: i.fileLineId,
              productId: m.productId,
              jan: i.jan ?? m.jan,
              code: i.code ?? m.sku,
              name: i.name ?? m.name,
              maker: i.maker ?? m.maker,
              quantity: i.quantity,
              unitWeightG: m.unitWeightG,
              checked: i.checked,
            );
          }(),
      ]),
  ];
}

/// What each product's own case is, learned from [boxes] (one product to a
/// box), for the products the library knows.
List<CasePack> learnedCasePacks(List<PackBox> boxes) {
  final byProduct = <int, Map<int, List<PackBox>>>{};
  for (final b in boxes) {
    if (b.items.length != 1 || b.items.single.productId == null || b.items.single.quantity <= 0) continue;
    final i = b.items.single;
    ((byProduct[i.productId!] ??= {})[i.quantity] ??= []).add(b);
  }
  return [
    for (final e in byProduct.entries)
      () {
        final best = e.value.entries.reduce((a, c) => c.value.length > a.value.length ? c : a);
        final b = best.value.firstWhere((x) => x.lengthCm != null, orElse: () => best.value.first);
        return CasePack(
          productId: e.key,
          caseQuantity: best.key,
          lengthCm: b.lengthCm,
          widthCm: b.widthCm,
          heightCm: b.heightCm,
          grossKg: b.grossKg,
          source: 'packing_list',
        );
      }(),
  ];
}

/// A packing list uploaded as someone made it: read (the AI naming the
/// columns its headings do not say), matched with the library, shown, then
/// kept twice — the file as it came and the improved one made from it —
/// with what it says of each product's case learned if wanted. True when
/// it was kept.
Future<bool> importPackingList(BuildContext context, WidgetRef ref, {int? fileId}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void snack(String t) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t)));
  final warehouseId = ref.read(writeWarehouseIdProvider);
  if (warehouseId == null) {
    snack(l10n.pkNoWarehouse);
    return false;
  }
  final file = await ref.read(packingListPickerProvider)();
  if (file == null || !context.mounted) return false;
  final repo = ref.read(packingRepositoryProvider);
  PackingListRead read;
  try {
    read = await readPackingList(file.bytes, ask: (h, s) async {
      final r = await repo.aiColumns(h, s);
      return r is ApiSuccess<Map<int, PlField>> ? r.data : const {};
    });
  } catch (e) {
    snack(l10n.pkReadFailed('$e'));
    return false;
  }
  if (read.boxes.isEmpty) {
    snack(l10n.pkNothingRead);
    return false;
  }
  final boxes = await matchPackedProducts(ref, read.boxes, warehouseId);
  final learn = learnedCasePacks(boxes);
  if (!context.mounted) return false;
  final go = await showDialog<({bool learn})>(
    context: context,
    builder: (_) => _ImportDialog(name: file.name, read: read, boxes: boxes, learnable: learn.length),
  );
  if (go == null || !context.mounted) return false;

  var cartons = const <CartonType>[];
  try {
    cartons = await ref.read(cartonTypesProvider.future);
  } catch (_) {
    // Boxes are named by size alone.
  }
  final marks = boxes.map((b) => b.mark).whereType<String>().toSet().join(' / ');
  final improved = buildPackingListXlsx(boxes, header: PlHeader(marks: marks.isEmpty ? null : marks), cartons: cartons);
  final improvedName = improvedNameOf(file.name);
  final up1 = await repo.upload(warehouseId, file.name, file.bytes);
  final up2 = await repo.upload(warehouseId, improvedName, improved);
  if (up1 is ApiFailure || up2 is ApiFailure) {
    final f = (up1 is ApiFailure ? up1 : up2) as ApiFailure;
    if (context.mounted) snack(humanizeApiErrorMessage(l10n, f.message));
    return false;
  }
  final total = PackingListRead(sheets: read.sheets, boxes: boxes);
  final add = await repo.addList(
    warehouseId: warehouseId,
    source: 'upload',
    fileId: fileId,
    originalName: file.name,
    originalPath: (up1 as ApiSuccess<String>).data,
    improvedName: improvedName,
    improvedPath: (up2 as ApiSuccess<String>).data,
    boxes: boxes.length,
    quantity: total.quantity,
    grossKg: double.parse(total.grossKg.toStringAsFixed(3)),
    cbm: double.parse(total.cbm.toStringAsFixed(4)),
    note: read.askedAi.isEmpty ? null : l10n.pkAiNote(read.askedAi.join(', ')),
  );
  if (!context.mounted) return false;
  switch (add) {
    case ApiFailure(:final message):
      snack(humanizeApiErrorMessage(l10n, message));
      return false;
    case ApiSuccess():
  }
  var learned = 0;
  if (go.learn && learn.isNotEmpty) {
    final r = await repo.saveCasePacks(learn, source: 'packing_list');
    if (r is ApiSuccess<int>) learned = r.data;
    ref.invalidate(casePacksProvider);
  }
  ref.invalidate(packingListsProvider);
  if (context.mounted) snack(learned > 0 ? l10n.pkKeptLearned(learned) : l10n.pkKept);
  return true;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.name, required this.read, required this.boxes, required this.learnable});

  final String name;
  final PackingListRead read;
  final List<PackBox> boxes;
  final int learnable;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late bool _learn = widget.learnable > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = PackingListRead(sheets: widget.read.sheets, boxes: widget.boxes);
    final noJan = widget.boxes.fold(0, (a, b) => a + b.items.where((i) => i.jan == null).length);
    return AlertDialog(
      key: const ValueKey('pk-import-dialog'),
      title: Text(widget.name),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.pkImportHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          for (final s in widget.read.sheets)
            Text(l10n.pkSheetRead(s.name, widget.boxes.where((b) => (b.mark ?? '') == s.mark).length)),
          if (widget.read.askedAi.isNotEmpty)
            Text(l10n.pkAiNote(widget.read.askedAi.join(', ')),
                key: const ValueKey('pk-import-ai'), style: TextStyle(color: theme.colorScheme.primary)),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.pkTotals(r.boxes.length, r.quantity, packingKg(r.grossKg), packingCbm(r.cbm)),
              key: const ValueKey('pk-import-totals'), style: theme.textTheme.titleSmall),
          if (noJan > 0) Text(l10n.pkNoJanRows(noJan), style: TextStyle(color: theme.colorScheme.error)),
          if (widget.learnable > 0)
            CheckboxListTile(
              key: const ValueKey('pk-import-learn'),
              contentPadding: EdgeInsets.zero,
              value: _learn,
              onChanged: (v) => setState(() => _learn = v ?? false),
              title: Text(l10n.pkLearn(widget.learnable)),
              subtitle: Text(l10n.pkLearnHint),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('pk-import-ok'),
          onPressed: () => Navigator.pop(context, (learn: _learn)),
          child: Text(l10n.pkKeep),
        ),
      ],
    );
  }
}

/// A kept file shown as a page: the boxes read back from it. Opened from
/// the click (the tab first), so the browser lets it open.
Future<void> openPackingListPage(BuildContext context, WidgetRef ref, String path, String title) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final tab = ref.read(outboundTabOpenerProvider)();
  final r = await ref.read(packingRepositoryProvider).fileBytes(path);
  switch (r) {
    case ApiSuccess(:final data):
      try {
        final read = await readPackingList(data);
        final html = packingListHtml(read.boxes, title: title);
        if (tab != null) {
          tab.show(html);
        } else {
          await ref.read(outboundFileSaverProvider)(title.endsWith('.html') ? title : '$title.html', Uint8List.fromList(utf8.encode(html)));
        }
      } catch (e) {
        tab?.close();
        messenger.showSnackBar(SnackBar(content: Text(l10n.pkReadFailed('$e'))));
      }
    case ApiFailure(:final message):
      tab?.close();
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

Future<void> downloadPackingFile(BuildContext context, WidgetRef ref, String path, String name) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(packingRepositoryProvider).fileBytes(path);
  switch (r) {
    case ApiSuccess(:final data):
      await ref.read(outboundFileSaverProvider)(name, data);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.ofFileSaved(name))));
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
  }
}

/// The packing lists kept: each uploaded one with the improved one made
/// from it, and those made here from the boxes — to look at or download.
/// [fileId]: one shipping list's only.
class PackingListsScreen extends ConsumerWidget {
  const PackingListsScreen({super.key, this.fileId, this.embedded = false});

  final int? fileId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(packingListsProvider(fileId));
    final body = async.when(
      loading: () => LoadingView(message: l10n.loading),
      error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(packingListsProvider(fileId))),
      data: (lists) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
        children: [
          Text(l10n.pkListsHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (lists.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text(l10n.pkListsEmpty, key: const ValueKey('pk-lists-empty'))),
            ),
          for (final p in lists) PackingListCard(record: p),
        ],
      ),
    );
    final fab = FloatingActionButton.extended(
      key: const ValueKey('pk-upload'),
      onPressed: () => importPackingList(context, ref, fileId: fileId),
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(l10n.pkUpload),
    );
    return Scaffold(
      appBar: embedded ? null : AppBar(title: Text(l10n.pkListsTitle)),
      floatingActionButton: fab,
      body: body,
    );
  }
}

class PackingListCard extends ConsumerWidget {
  const PackingListCard({super.key, required this.record});

  final PackingListRecord record;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.pkWithdrawQ),
        content: Text(l10n.pkWithdrawBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pk-withdraw-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.pkWithdraw)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref.read(packingRepositoryProvider).withdrawList(record.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (r) {
        ApiSuccess() => l10n.pkWithdrawn,
        ApiFailure(:final message) => humanizeApiErrorMessage(l10n, message),
      }),
    ));
    ref.invalidate(packingListsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = record;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      key: ValueKey('pk-list-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            StatusPill(
              tone: p.uploaded ? StatusTone.info : StatusTone.success,
              label: p.uploaded ? l10n.pkSourceUpload : l10n.pkSourceGenerated,
              dense: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(p.title, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (p.boxes != null) l10n.pkTotals(p.boxes!, p.quantity ?? 0, packingKg(p.grossKg ?? 0), packingCbm(p.cbm ?? 0)),
              if (p.fileName != null) l10n.pkForFile(p.fileName!),
              if (p.warehouseName != null) p.warehouseName!,
              if (p.createdAt != null)
                [DateFormat('y/MM/dd HH:mm').format(p.createdAt!), if (p.createdByName != null) p.createdByName!].join(' '),
            ].join(' · '),
            style: muted,
          ),
          if (p.note != null) Text(p.note!, style: muted),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            if (p.improvedPath != null) ...[
              FilledButton.tonalIcon(
                key: ValueKey('pk-open-${p.id}'),
                onPressed: () => openPackingListPage(context, ref, p.improvedPath!, p.improvedName ?? 'PACKING LIST'),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.pkOpenImproved),
              ),
              OutlinedButton.icon(
                key: ValueKey('pk-dl-improved-${p.id}'),
                onPressed: () => downloadPackingFile(context, ref, p.improvedPath!, p.improvedName ?? 'packing_list.xlsx'),
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.pkDownloadImproved),
              ),
            ],
            if (p.originalPath != null)
              OutlinedButton.icon(
                key: ValueKey('pk-dl-original-${p.id}'),
                onPressed: () => downloadPackingFile(context, ref, p.originalPath!, p.originalName ?? 'original.xlsx'),
                icon: const Icon(Icons.description_outlined),
                label: Text(l10n.pkDownloadOriginal),
              ),
            TextButton.icon(
              key: ValueKey('pk-withdraw-${p.id}'),
              onPressed: () => _withdraw(context, ref),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(l10n.pkWithdraw),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            ),
          ]),
        ]),
      ),
    );
  }
}
