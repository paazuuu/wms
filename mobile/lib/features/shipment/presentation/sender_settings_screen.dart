import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/sender_profile_controller.dart';
import '../domain/sender_profile.dart';

/// Localized label for a sender field key, shared by the settings form and the
/// print-time picker.
String senderFieldLabel(AppLocalizations l10n, String key) => switch (key) {
      'company' => l10n.fieldCompanyName,
      'postal' => l10n.fieldPostalCode,
      'address' => l10n.fieldAddress,
      'phone' => l10n.fieldPhone,
      'fax' => l10n.fieldFax,
      'contact' => l10n.fieldContact,
      'regno' => l10n.fieldRegistrationNumber,
      'note' => l10n.fieldNote,
      _ => key,
    };

/// Edits and saves the default sender (差出人) profile.
class SenderSettingsScreen extends ConsumerStatefulWidget {
  const SenderSettingsScreen({super.key});

  @override
  ConsumerState<SenderSettingsScreen> createState() =>
      _SenderSettingsScreenState();
}

class _SenderSettingsScreenState extends ConsumerState<SenderSettingsScreen> {
  final Map<String, TextEditingController> _c = {
    for (final k in SenderProfile.fieldKeys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    final p = ref.read(senderProfileControllerProvider);
    for (final k in SenderProfile.fieldKeys) {
      _c[k]!.text = p.valueOf(k);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(senderProfileControllerProvider);
    final profile = SenderProfile(
      companyName: _c['company']!.text.trim(),
      postalCode: _c['postal']!.text.trim(),
      address: _c['address']!.text.trim(),
      phone: _c['phone']!.text.trim(),
      fax: _c['fax']!.text.trim(),
      contact: _c['contact']!.text.trim(),
      registrationNumber: _c['regno']!.text.trim(),
      note: _c['note']!.text.trim(),
      disabled: current.disabled,
    );
    await ref.read(senderProfileControllerProvider.notifier).save(profile);
    if (!mounted) return;
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.senderSaved),
        backgroundColor: scheme.inverseSurface,
      ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    IconData iconFor(String k) => switch (k) {
          'company' => Icons.business_outlined,
          'postal' => Icons.markunread_mailbox_outlined,
          'address' => Icons.location_on_outlined,
          'phone' => Icons.call_outlined,
          'fax' => Icons.fax_outlined,
          'contact' => Icons.person_outline,
          'regno' => Icons.verified_outlined,
          _ => Icons.notes_outlined,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.senderSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.senderSettingsHint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          for (final k in SenderProfile.fieldKeys) ...[
            TextField(
              controller: _c[k],
              textCapitalization: k == 'regno'
                  ? TextCapitalization.characters
                  : TextCapitalization.none,
              keyboardType: (k == 'phone' || k == 'fax' || k == 'postal')
                  ? TextInputType.phone
                  : TextInputType.text,
              maxLines: k == 'address' || k == 'note' ? 2 : 1,
              decoration: InputDecoration(
                labelText: senderFieldLabel(l10n, k),
                prefixIcon: Icon(iconFor(k)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(l10n.actionSave),
          ),
        ),
      ),
    );
  }
}
