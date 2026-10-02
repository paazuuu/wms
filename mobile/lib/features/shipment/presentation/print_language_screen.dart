import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/fields_dialog.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/print_language_providers.dart';
import '../domain/print_language.dart';

/// Each language by its own name, as a reader of it would look for it.
const printLanguageNames = {'ja': '日本語', 'en': 'English', 'zh': '中文'};

/// The languages documents and carton labels print in, in order, and the
/// words they use (0118). The first language is the main line; the others
/// go under it.
class PrintLanguageScreen extends ConsumerStatefulWidget {
  const PrintLanguageScreen({super.key});

  @override
  ConsumerState<PrintLanguageScreen> createState() => _PrintLanguageScreenState();
}

class _PrintLanguageScreenState extends ConsumerState<PrintLanguageScreen> {
  List<String>? _order;
  bool _busy = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveLanguages(List<String> order) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(printLanguageRepositoryProvider).setLanguages(order);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        _order = null;
        ref.invalidate(printLanguageProvider);
        _snack(l10n.plSaved);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  Future<void> _editWord(PrintLanguage language, String key) async {
    final l10n = AppLocalizations.of(context);
    final words = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: language.word(key, 'ja'),
        keyPrefix: 'pl-word',
        fields: {for (final l in PrintLanguage.supported) l: (printLanguageNames[l]!, language.word(key, l))},
        saveKey: const ValueKey('pl-word-save'),
        saveLabel: l10n.productSave,
        cancelLabel: l10n.actionCancel,
      ),
    );
    if (words == null || !mounted) return;
    if (words.values.any((w) => w.isEmpty)) {
      _snack(l10n.plWordNeedsAll);
      return;
    }
    final r = await ref
        .read(printLanguageRepositoryProvider)
        .setWord(key, ja: words['ja']!, en: words['en']!, zh: words['zh']!);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ref.invalidate(printLanguageProvider);
        _snack(l10n.plSaved);
      case ApiFailure(:final message):
        _snack(humanizeApiErrorMessage(l10n, message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(printLanguageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featPrintLanguage)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(message: '$e', onRetry: () => ref.invalidate(printLanguageProvider)),
        data: (language) {
          final order = _order ?? language.languages;
          final preview = language.copyWith(languages: order);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.plLanguagesTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.plLanguagesHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final l in PrintLanguage.supported)
                    FilterChip(
                      key: ValueKey('pl-lang-$l'),
                      selected: order.contains(l),
                      avatar: order.contains(l)
                          ? CircleAvatar(child: Text('${order.indexOf(l) + 1}'))
                          : null,
                      showCheckmark: false,
                      label: Text(printLanguageNames[l]!),
                      onSelected: (on) {
                        final next = [...order];
                        if (on) {
                          next.add(l);
                        } else if (next.length > 1) {
                          next.remove(l);
                        }
                        setState(() => _order = next);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.plPreview('${preview.words('qty').join(' / ')} · ${preview.words('delivery_note').join(' / ')}'),
                key: const ValueKey('pl-preview'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const ValueKey('pl-save-langs'),
                  onPressed: _busy || _order == null ? null : () => _saveLanguages(order),
                  child: Text(l10n.productSave),
                ),
              ),
              const Divider(height: AppSpacing.xl * 2),
              Text(l10n.plWordsTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.plWordsHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final key in PrintLanguage.keys)
                Card(
                  child: ListTile(
                    key: ValueKey('pl-word-$key'),
                    title: Text(language.word(key, 'ja')),
                    subtitle: Text('${language.word(key, 'en')} · ${language.word(key, 'zh')}'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editWord(language, key),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
