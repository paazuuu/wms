import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../data/product_marks.dart';
import '../domain/product.dart';

/// ★ and ⚠ (0167): shown on the library, the product and the inspection; a
/// tap sets or clears one (⚠ asks for its note), for whoever handles goods.
class ProductMarks extends ConsumerStatefulWidget {
  const ProductMarks({super.key, required this.product, this.size = 20, this.onChanged});

  final Product product;
  final double size;

  /// After a change was saved (the list is refreshed too).
  final VoidCallback? onChanged;

  @override
  ConsumerState<ProductMarks> createState() => _ProductMarksState();
}

class _ProductMarksState extends ConsumerState<ProductMarks> {
  Set<String>? _marks;
  String? _note;
  bool _busy = false;

  Set<String> get marks => _marks ?? widget.product.marks;
  String? get note => _marks == null ? widget.product.markNote : _note;

  @override
  void didUpdateWidget(ProductMarks old) {
    super.didUpdateWidget(old);
    if (old.product.marks != widget.product.marks || old.product.markNote != widget.product.markNote) {
      _marks = null;
      _note = null;
    }
  }

  Future<void> _save(Set<String> next, String? nextNote) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _marks = next;
      _note = nextNote;
    });
    final r = await ref.read(productMarksRepositoryProvider).setMarks(widget.product.id, next, note: nextNote);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        ref.invalidate(productListProvider);
        widget.onChanged?.call();
      case ApiFailure(:final message):
        setState(() {
          _marks = null;
          _note = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  Future<void> _warning() async {
    final l10n = AppLocalizations.of(context);
    if (marks.contains('warning')) {
      // Already warned: change the note, or take the warning off.
      final c = TextEditingController(text: note ?? '');
      final r = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(l10n.pmkWarning),
          content: TextField(
              key: const ValueKey('pmk-note'),
              controller: c,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.pmkNote)),
          actions: [
            TextButton(
                key: const ValueKey('pmk-clear'),
                onPressed: () => Navigator.pop(d, '\u0000'),
                child: Text(l10n.pmkClearWarning)),
            FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(l10n.actionSave)),
          ],
        ),
      );
      if (r == null || !mounted) return;
      if (r == '\u0000') {
        await _save({...marks}..remove('warning'), null);
      } else {
        await _save(marks, r);
      }
      return;
    }
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.pmkWarning),
        content: TextField(
            key: const ValueKey('pmk-note'),
            controller: c,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.pmkNote, hintText: l10n.pmkNoteHint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('pmk-save'), onPressed: () => Navigator.pop(d, c.text), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (r == null || !mounted) return;
    await _save({...marks, 'warning'}, r);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final may = ref.watch(canMarkProductsProvider);
    final star = marks.contains('star'), warn = marks.contains('warning');
    final id = widget.product.id;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        key: ValueKey('pmk-star-$id'),
        visualDensity: VisualDensity.compact,
        iconSize: widget.size,
        tooltip: star ? l10n.pmkUnstar : l10n.pmkStar,
        onPressed: !may || _busy ? null : () => _save(star ? ({...marks}..remove('star')) : {...marks, 'star'}, note),
        icon: Icon(star ? Icons.star : Icons.star_border, color: star ? Colors.amber.shade600 : null),
      ),
      IconButton(
        key: ValueKey('pmk-warn-$id'),
        visualDensity: VisualDensity.compact,
        iconSize: widget.size,
        tooltip: warn ? [l10n.pmkWarning, if ((note ?? '').isNotEmpty) note!].join('\n') : l10n.pmkWarn,
        onPressed: !may || _busy ? null : _warning,
        icon: Icon(warn ? Icons.warning_amber_rounded : Icons.report_gmailerrorred_outlined,
            color: warn ? scheme.error : null),
      ),
    ]);
  }
}

/// The warning's note, said in red where it matters (inspection, detail).
class ProductWarningNote extends StatelessWidget {
  const ProductWarningNote({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (!product.warned) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Text('⚠ ${(product.markNote ?? '').isEmpty ? l10n.pmkWarning : product.markNote!}',
        key: ValueKey('pmk-note-${product.id}'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600));
  }
}
