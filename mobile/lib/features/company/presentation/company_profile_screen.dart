import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../application/company_providers.dart';
import '../domain/company_profile.dart';

/// 自社情報 (0131): our name, its other spellings and our 登録番号. When a
/// document is read, the company these name is the addressee (us) and the
/// other company the supplier. The names our documents were addressed to
/// (0132) are offered to fill it in.
class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(companyProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featCompanyProfile)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(companyProfileProvider),
        ),
        data: (p) => _CompanyForm(key: ValueKey(p), profile: p),
      ),
    );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({super.key, required this.profile});

  final CompanyProfile profile;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  late final _name = TextEditingController(text: widget.profile.isUnset ? '' : widget.profile.name);
  late final _kana = TextEditingController(text: widget.profile.nameKana ?? '');
  late final _en = TextEditingController(text: widget.profile.nameEn ?? '');
  late final _aliases = TextEditingController(text: widget.profile.aliases.join('\n'));
  late final _reg = TextEditingController(text: widget.profile.registrationNumber ?? '');
  late final _postal = TextEditingController(text: widget.profile.postalCode ?? '');
  late final _address = TextEditingController(text: widget.profile.address ?? '');
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _fax = TextEditingController(text: widget.profile.fax ?? '');
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _kana, _en, _aliases, _reg, _postal, _address, _phone, _fax, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  List<String> get _aliasList =>
      [for (final a in _aliases.text.split('\n')) if (a.trim().isNotEmpty) a.trim()];

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _t(_name);
    if (name == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cpNameRequired)));
      return;
    }
    setState(() => _busy = true);
    final r = await ref.read(companyRepositoryProvider).save(CompanyProfile(
          name: name,
          nameKana: _t(_kana),
          nameEn: _t(_en),
          aliases: _aliasList,
          registrationNumber: _t(_reg),
          postalCode: _t(_postal),
          address: _t(_address),
          phone: _t(_phone),
          fax: _t(_fax),
          email: _t(_email),
        ));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case ApiSuccess():
        messenger.showSnackBar(SnackBar(content: Text(l10n.cpSaved)));
        ref.invalidate(companyProfileProvider);
      case ApiFailure(:final message):
        messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
  }

  void _useAsName(String n) => setState(() {
        final old = _t(_name);
        if (old != null && old != n && !_aliasList.contains(old)) {
          _aliases.text = [..._aliasList, old].join('\n');
        }
        _name.text = n;
      });

  void _addAlias(String n) => setState(() {
        if (!_aliasList.contains(n) && _t(_name) != n) _aliases.text = [..._aliasList, n].join('\n');
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canEdit = ref.watch(companyCanEditProvider);
    final suggestions = ref.watch(ownNameSuggestionsProvider).valueOrNull ?? const <OwnNameSuggestion>[];
    Widget field(TextEditingController c, String label, String key,
            {int lines = 1, TextInputType? type}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextField(
            key: ValueKey(key),
            controller: c,
            enabled: canEdit && !_busy,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 2,
            keyboardType: type,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.cpHint, style: theme.textTheme.bodyMedium),
                if (widget.profile.isUnset) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    key: const ValueKey('cp-unset'),
                    color: theme.colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(l10n.cpNotSet,
                              style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                        ),
                      ]),
                    ),
                  ),
                ],
                if (!canEdit) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.cpReadOnly,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: AppSpacing.lg),
                field(_name, l10n.cpName, 'cp-name'),
                field(_kana, l10n.cpNameKana, 'cp-kana'),
                field(_en, l10n.cpNameEn, 'cp-en'),
                field(_aliases, l10n.cpAliases, 'cp-aliases', lines: 3),
                if (suggestions.isNotEmpty) ...[
                  Text(l10n.cpSuggestions, style: theme.textTheme.titleSmall),
                  Text(l10n.cpSuggestionsHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  for (final s in suggestions)
                    ListTile(
                      key: ValueKey('cp-suggest-${s.name}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.business_outlined),
                      title: Text(s.name),
                      subtitle: Text(l10n.cpSuggestionCount(s.count)),
                      trailing: canEdit
                          ? Wrap(spacing: AppSpacing.xs, children: [
                              TextButton(onPressed: () => _useAsName(s.name), child: Text(l10n.cpUseAsName)),
                              TextButton(onPressed: () => _addAlias(s.name), child: Text(l10n.cpAddAlias)),
                            ])
                          : null,
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
                field(_reg, l10n.cpRegNo, 'cp-reg'),
                field(_postal, l10n.cpPostal, 'cp-postal'),
                field(_address, l10n.cpAddress, 'cp-address', lines: 2),
                field(_phone, l10n.cpPhone, 'cp-phone', type: TextInputType.phone),
                field(_fax, l10n.cpFax, 'cp-fax', type: TextInputType.phone),
                field(_email, l10n.cpEmail, 'cp-email', type: TextInputType.emailAddress),
                if (canEdit)
                  FilledButton.icon(
                    key: const ValueKey('cp-save'),
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.cpSave),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
