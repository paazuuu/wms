import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../../product_library/application/product_library_providers.dart';
import '../application/notation_providers.dart';
import '../domain/notation.dart';
import 'notation_labels.dart';

// 項目ライブラリー (0112): one entry per field a document column can mean
// (JAN, メーカー, 品番, …) and per product attribute. Each carries every
// heading companies use for it (JAN / JANコード / ジャパンコード …), and the
// name the system shows for it is ours to choose, per language.

final _partnersProvider = FutureProvider.autoDispose<List<TradingPartner>>((ref) async =>
    (await ref.watch(tradingPartnerRepositoryProvider).list()).when(success: (d) => d, failure: (f) => throw Exception(f.message)));

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

class FieldLibraryScreen extends ConsumerWidget {
  const FieldLibraryScreen({super.key});

  Future<void> _editNames(BuildContext context, WidgetRef ref, DocumentField f, String builtIn) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _NamesDialog(field: f, builtIn: builtIn),
    );
    if (result == null || !context.mounted) return;
    final r = await ref.read(notationRepositoryProvider).saveFieldLabels(f.key, result);
    if (!context.mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(fieldLibraryProvider);
        ref.invalidate(fieldLabelsProvider);
        _snack(context, l10n.flSaved);
      },
      failure: (e) => _snack(context, humanizeApiErrorMessage(l10n, e.message)),
    );
  }

  Future<void> _addHeading(BuildContext context, WidgetRef ref, ColumnChoice choice, String title) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<({String header, int? partnerId})>(
      context: context,
      builder: (_) => _HeadingDialog(title: title),
    );
    if (result == null || !context.mounted) return;
    final r = await ref
        .read(notationRepositoryProvider)
        .setHeading(partnerId: result.partnerId, header: result.header, choice: choice);
    if (!context.mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(fieldLibraryProvider);
        ref.invalidate(columnAliasesProvider);
        _snack(context, l10n.flHeadingAdded(result.header));
      },
      failure: (e) => _snack(context, humanizeApiErrorMessage(l10n, e.message)),
    );
  }

  Future<void> _removeHeading(BuildContext context, WidgetRef ref, FieldHeading h) async {
    final l10n = AppLocalizations.of(context);
    final r = await ref.read(notationRepositoryProvider).removeColumnAlias(h.id);
    if (!context.mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(fieldLibraryProvider);
        ref.invalidate(columnAliasesProvider);
      },
      failure: (e) => _snack(context, humanizeApiErrorMessage(l10n, e.message)),
    );
  }

  Widget _headings(BuildContext context, WidgetRef ref, List<FieldHeading> headings, bool canManage) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final h in headings)
          InputChip(
            key: ValueKey('fl-heading-${h.id}'),
            visualDensity: VisualDensity.compact,
            label: Text(h.partnerName == null ? h.header : '${h.header}（${h.partnerName}）'),
            tooltip: h.partnerName == null ? l10n.flEveryone : l10n.flOnlyFor(h.partnerName!),
            onDeleted: canManage && !h.isSeed ? () => _removeHeading(context, ref, h) : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final canManage = ref.watch(productLibraryCanManageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.flTitle)),
      body: ref.watch(fieldLibraryProvider).when(
            loading: () => LoadingView(message: l10n.loading),
            error: (e, _) => ErrorStateView(
                message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(fieldLibraryProvider)),
            data: (lib) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(l10n.flIntro, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                for (final f in lib.fields)
                  if (f.key != 'attr')
                    Builder(builder: (context) {
                      final builtIn = columnFieldLabel(l10n, f.field);
                      final shown = f.labels[lang] ?? builtIn;
                      return Card(
                        key: ValueKey('fl-field-${f.key}'),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(shown, key: ValueKey('fl-name-${f.key}'), style: theme.textTheme.titleMedium),
                                  if (f.labels[lang] != null)
                                    Text(l10n.flBuiltIn(builtIn),
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  if (f.description != null) Text(f.description!, style: theme.textTheme.bodySmall),
                                ]),
                              ),
                              if (canManage)
                                IconButton(
                                  key: ValueKey('fl-edit-${f.key}'),
                                  tooltip: l10n.flEditNames,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editNames(context, ref, f, builtIn),
                                ),
                            ]),
                            const SizedBox(height: AppSpacing.xs),
                            Text(l10n.flHeadings(f.headings.length), style: theme.textTheme.labelMedium),
                            const SizedBox(height: AppSpacing.xs),
                            _headings(context, ref, f.headings, canManage),
                            if (canManage && f.field != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: ValueKey('fl-add-${f.key}'),
                                  onPressed: () => _addHeading(context, ref, ColumnChoice(f.field!), shown),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(l10n.flAddHeading),
                                ),
                              ),
                          ]),
                        ),
                      );
                    }),
                if (lib.attributes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.flAttributes, style: theme.textTheme.titleSmall),
                  Text(l10n.flAttributesHint,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final a in lib.attributes)
                    Card(
                      key: ValueKey('fl-attr-${a.key}'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.flHeadings(a.headings.length), style: theme.textTheme.labelMedium),
                          const SizedBox(height: AppSpacing.xs),
                          _headings(context, ref, a.headings, canManage),
                          if (canManage)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: ValueKey('fl-add-attr-${a.key}'),
                                onPressed: () => _addHeading(context, ref, ColumnChoice.attr(a.key), a.name),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.flAddHeading),
                              ),
                            ),
                        ]),
                      ),
                    ),
                ],
              ],
            ),
          ),
    );
  }
}

/// Our name for a field in each language; an empty one is the built-in name.
class _NamesDialog extends StatefulWidget {
  const _NamesDialog({required this.field, required this.builtIn});

  final DocumentField field;
  final String builtIn;

  @override
  State<_NamesDialog> createState() => _NamesDialogState();
}

class _NamesDialogState extends State<_NamesDialog> {
  late final _c = {
    for (final lang in const ['ja', 'en', 'zh']) lang: TextEditingController(text: widget.field.labels[lang] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = {'ja': l10n.flLangJa, 'en': l10n.flLangEn, 'zh': l10n.flLangZh};
    return AlertDialog(
      title: Text(l10n.flEditNames),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.flNamesHint(widget.builtIn), style: Theme.of(context).textTheme.bodySmall),
        for (final e in _c.entries)
          TextField(
            key: ValueKey('fl-label-${e.key}'),
            controller: e.value,
            decoration: InputDecoration(labelText: names[e.key]),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('fl-save'),
          onPressed: () => Navigator.pop(context, {for (final e in _c.entries) e.key: e.value.text.trim()}),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// A heading that means this field — for everyone, or one company.
class _HeadingDialog extends ConsumerStatefulWidget {
  const _HeadingDialog({required this.title});

  final String title;

  @override
  ConsumerState<_HeadingDialog> createState() => _HeadingDialogState();
}

class _HeadingDialogState extends ConsumerState<_HeadingDialog> {
  final _header = TextEditingController();
  int? _partnerId;

  @override
  void dispose() {
    _header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final partners = ref.watch(_partnersProvider).valueOrNull ?? const <TradingPartner>[];
    return AlertDialog(
      title: Text(l10n.flAddHeadingTo(widget.title)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: const ValueKey('fl-heading'),
          controller: _header,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.flHeading),
        ),
        DropdownButtonFormField<int?>(
          key: const ValueKey('fl-heading-partner'),
          initialValue: _partnerId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.ntPartner),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(l10n.flEveryone)),
            for (final p in partners) DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
          ],
          onChanged: (v) => setState(() => _partnerId = v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('fl-heading-save'),
          onPressed: () {
            final h = _header.text.trim();
            if (h.isEmpty) return;
            Navigator.pop(context, (header: h, partnerId: _partnerId));
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
