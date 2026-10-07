import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/outbound_repository.dart';
import '../domain/outbound.dart';

/// Opens the form for a destination: a new one, or [existing] to change.
/// Resolves to the saved destination (with its id), or null.
Future<ShipDestination?> showDestinationDialog(BuildContext context, {ShipDestination? existing}) =>
    showDialog<ShipDestination>(context: context, builder: (_) => _DestinationDialog(existing: existing));

class _DestinationDialog extends ConsumerStatefulWidget {
  const _DestinationDialog({this.existing});

  final ShipDestination? existing;

  @override
  ConsumerState<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends ConsumerState<_DestinationDialog> {
  late final Map<String, TextEditingController> _c = {
    'name': TextEditingController(text: widget.existing?.name ?? ''),
    'department': TextEditingController(text: widget.existing?.department ?? ''),
    'contact': TextEditingController(text: widget.existing?.contactName ?? ''),
    'postal': TextEditingController(text: widget.existing?.postalCode ?? ''),
    'address1': TextEditingController(text: widget.existing?.address1 ?? ''),
    'address2': TextEditingController(text: widget.existing?.address2 ?? ''),
    'phone': TextEditingController(text: widget.existing?.phone ?? ''),
    'email': TextEditingController(text: widget.existing?.email ?? ''),
    'country': TextEditingController(text: widget.existing?.countryCode ?? ''),
    'note': TextEditingController(text: widget.existing?.note ?? ''),
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(String k) {
    final t = _c[k]!.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _v('name');
    if (name == null) {
      setState(() => _error = l10n.obNeedName);
      return;
    }
    final d = ShipDestination(
      id: widget.existing?.id,
      name: name,
      department: _v('department'),
      contactName: _v('contact'),
      postalCode: _v('postal'),
      address1: _v('address1'),
      address2: _v('address2'),
      phone: _v('phone'),
      email: _v('email'),
      countryCode: _v('country')?.toUpperCase(),
      note: _v('note'),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(outboundRepositoryProvider).saveDestination(d);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess(:final data):
        ref.invalidate(shipDestinationsProvider);
        Navigator.pop(
            context,
            ShipDestination(
              id: data, name: d.name, department: d.department, contactName: d.contactName, postalCode: d.postalCode,
              address1: d.address1, address2: d.address2, phone: d.phone, email: d.email, countryCode: d.countryCode,
              note: d.note,
            ));
      case ApiFailure(:final message):
        setState(() {
          _busy = false;
          _error = humanizeApiErrorMessage(l10n, message);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget f(String k, String label, {TextInputType? type, String? hint}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: TextField(
            key: ValueKey('sd-$k'),
            controller: _c[k],
            keyboardType: type,
            decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
          ),
        );
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.obDestNew : l10n.obDestEdit),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            f('name', l10n.obDestName),
            f('department', l10n.obDestDepartment),
            f('contact', l10n.obDestContact),
            Row(children: [
              SizedBox(width: 130, child: f('postal', l10n.obDestPostal, hint: '123-4567')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('country', l10n.obDestCountry, hint: 'JP')),
            ]),
            f('address1', l10n.obDestAddress1),
            f('address2', l10n.obDestAddress2),
            f('phone', l10n.obDestPhone, type: TextInputType.phone),
            f('email', l10n.obDestEmail, type: TextInputType.emailAddress),
            f('note', l10n.obDestNote),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const ValueKey('sd-save'), onPressed: _busy ? null : _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}

/// 出荷先: the destinations kept, most used first; add, change or remove.
class ShipDestinationsScreen extends ConsumerWidget {
  const ShipDestinationsScreen({super.key});

  Future<void> _retire(BuildContext context, WidgetRef ref, ShipDestination d) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.obDestRetireQ(d.name)),
        content: Text(l10n.obDestRetireBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.actionCancel)),
          FilledButton(key: const ValueKey('sd-retire-ok'), onPressed: () => Navigator.pop(c, true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await ref.read(outboundRepositoryProvider).retireDestination(d.id!);
    if (!context.mounted) return;
    if (r case ApiFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    ref.invalidate(shipDestinationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(shipDestinationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featShipDestinations)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('sd-add'),
        onPressed: () => showDestinationDialog(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.obDestNew),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: humanizeApiErrorMessage(l10n, '$e'),
          onRetry: () => ref.invalidate(shipDestinationsProvider),
        ),
        data: (rows) => rows.isEmpty
            ? EmptyStateView(icon: Icons.location_on_outlined, title: l10n.obDestEmpty)
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
                children: [
                  for (final d in rows)
                    Card(
                      key: ValueKey('sd-row-${d.id}'),
                      child: ListTile(
                        title: Text([d.name, if (d.department != null) d.department!].join(' ')),
                        subtitle: Text(
                          [
                            if (d.contactName != null) l10n.obDestAttn(d.contactName!),
                            if (d.addressLine.isNotEmpty) d.addressLine,
                            if (d.phone != null) 'TEL ${d.phone}',
                            l10n.obDestUsed(d.useCount),
                          ].join('\n'),
                          style: muted,
                        ),
                        isThreeLine: true,
                        onTap: () => showDestinationDialog(context, existing: d),
                        trailing: IconButton(
                          key: ValueKey('sd-retire-${d.id}'),
                          tooltip: l10n.actionDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _retire(context, ref, d),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
