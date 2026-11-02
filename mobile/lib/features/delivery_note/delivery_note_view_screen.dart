import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error_text.dart';
import '../../core/api/api_result.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/copy_text.dart';
import '../../l10n/app_localizations.dart';
import '../product/application/product_providers.dart';
import '../product/data/market_names.dart' show marketNameOf;
import '../product/data/web_photos.dart';
import '../product/domain/product.dart';
import '../product_library/presentation/product_thumb.dart';
import 'delivery_note.dart';

/// 納品書を写して見る (0178): a delivery note photographed (or its file
/// chosen), read by the AI, and shown line by line with each good's
/// picture, name, JAN, maker, 品番 and how many — to find the goods by sight
/// rather than by text alone. A good with no picture is shown without one.
/// Tapping a line marks it seen (on this screen only). Nothing is booked.
/// A good not in 商品ライブラリー shows the picture kept for its JAN (0179):
/// from the database when it was found before, else looked up on the web
/// once and kept — never twice for the same JAN.
class DeliveryNoteViewScreen extends ConsumerStatefulWidget {
  const DeliveryNoteViewScreen({super.key, this.lines, this.fileName});

  /// A note already read (from 取込の検品); else one is taken here.
  final List<NoteLine>? lines;
  final String? fileName;

  @override
  ConsumerState<DeliveryNoteViewScreen> createState() => _DeliveryNoteViewScreenState();
}

class _DeliveryNoteViewScreenState extends ConsumerState<DeliveryNoteViewScreen> {
  late List<NoteLine>? _lines = widget.lines;
  late String? _fileName = widget.fileName;
  bool _reading = false;
  String? _error;
  final Set<int> _seen = {};

  /// JAN → kept picture link, for goods not in the library.
  Map<String, String> _janPhotos = const {};

  @override
  void initState() {
    super.initState();
    if (widget.lines != null) WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
  }

  Future<void> _loadPhotos() async {
    final lines = _lines;
    if (lines == null || !mounted) return;
    final known = <String>{};
    try {
      known.addAll((await ref.read(productListProvider.future)).map((p) => p.janCode));
    } catch (_) {}
    final jans = {
      for (final l in lines)
        if (l.jan.isNotEmpty && !known.contains(l.jan)) l.jan
    }.toList();
    if (jans.isEmpty || !mounted) return;
    final r = await ref.read(webPhotoRepositoryProvider).janPhotos(jans, look: true);
    if (!mounted || lines != _lines) return;
    if (r case ApiSuccess(:final data)) setState(() => _janPhotos = data);
  }

  Future<void> _take() async {
    final camera = await askCameraOrFile(context);
    if (camera == null || !mounted) return;
    final f = await ref.read(deliveryNotePickerProvider)(camera: camera);
    if (f == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _reading = true;
      _error = null;
    });
    final r = await readDeliveryNote(ref, f.name, f.bytes);
    if (!mounted) return;
    setState(() {
      _reading = false;
      switch (r) {
        case ApiSuccess(:final data):
          _lines = data;
          _fileName = f.name;
          _seen.clear();
          _janPhotos = const {};
          if (data.isEmpty) _error = l10n.dnNothingRead;
        case ApiFailure(:final message):
          _error = humanizeApiErrorMessage(l10n, message);
      }
    });
    _loadPhotos();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final lines = _lines;
    final products = {for (final p in ref.watch(productListProvider).valueOrNull ?? const <Product>[]) p.janCode: p};
    final units = (lines ?? const <NoteLine>[]).fold<int>(0, (s, l) => s + (l.quantity ?? 0));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dnTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(l10n.dnIntro, style: muted),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey('dn-take'),
            onPressed: _reading ? null : _take,
            icon: _reading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_reading ? l10n.dnReading : (lines == null ? l10n.dnTake : l10n.dnTakeAnother)),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(e, key: const ValueKey('dn-error'), style: TextStyle(color: scheme.error)),
            ),
          if (lines != null && lines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            if (_fileName case final n?) Text(n, style: theme.textTheme.titleSmall),
            Text(
              l10n.dnSummary(lines.length, units, _seen.length),
              key: const ValueKey('dn-summary'),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final l in lines) _line(context, l, products[l.jan]),
          ],
        ],
      ),
    );
  }

  Widget _line(BuildContext context, NoteLine l, Product? p) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final seen = _seen.contains(l.lineNo);
    final name = p == null ? l.name : (marketNameOf(p) ?? p.name);
    return Card(
      key: ValueKey('dn-line-${l.lineNo}'),
      color: seen ? scheme.secondaryContainer.withValues(alpha: 0.6) : null,
      child: InkWell(
        onTap: () => setState(() => seen ? _seen.remove(l.lineNo) : _seen.add(l.lineNo)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The picture first: what to look for on the shelf.
            p != null
                ? ProductThumb(productId: p.id, janCode: p.janCode, productName: p.name, size: 84)
                : _janPhotos[l.jan] != null
                    ? ClipRRect(
                        key: ValueKey('dn-webphoto-${l.lineNo}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _janPhotos[l.jan]!,
                          width: 84,
                          height: 84,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _noPhoto(scheme, l),
                        ),
                      )
                    : _noPhoto(scheme, l),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? l.code : name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 3),
                if ([p?.maker ?? l.maker, p?.sku ?? l.code].any((x) => x.trim().isNotEmpty))
                  Text([p?.maker ?? l.maker, p?.sku ?? l.code].where((x) => x.trim().isNotEmpty).join(' · '),
                      style: muted),
                if (l.jan.isNotEmpty)
                  Row(children: [
                    Text('JAN ${l.jan}', key: ValueKey('dn-jan-${l.lineNo}'), style: theme.textTheme.bodySmall),
                    CopyButton(value: l.jan, size: 14),
                  ])
                else
                  Text(l10n.dnNoJan, style: muted?.copyWith(color: scheme.error)),
                if (p == null && l.jan.isNotEmpty) Text(l10n.dnNotInLibrary, style: muted),
              ]),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                l.quantity == null ? '—' : '${l.quantity}',
                key: ValueKey('dn-qty-${l.lineNo}'),
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(l.unit.isEmpty ? l10n.dnUnits : l.unit, style: muted),
              if (seen) Icon(Icons.check_circle, color: scheme.primary, key: ValueKey('dn-seen-${l.lineNo}')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _noPhoto(ColorScheme scheme, NoteLine l) => Container(
        key: ValueKey('dn-nophoto-${l.lineNo}'),
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
      );
}
