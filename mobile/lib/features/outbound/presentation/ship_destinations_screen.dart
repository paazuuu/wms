import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A card chosen from those kept (searched by any of its words), or null.
Future<ShipDestination?> pickDestinationCard(BuildContext context) =>
    showDialog<ShipDestination>(context: context, builder: (_) => const _PickCardDialog());

String transportLabel(AppLocalizations l10n, String? t) => switch (t) {
      null => '',
      'sea' => l10n.sdcTrSea,
      'air' => l10n.sdcTrAir,
      'courier' => l10n.sdcTrCourier,
      'truck' => l10n.sdcTrTruck,
      'other' => l10n.sdcTrOther,
      _ => t,
    };

/// The card as text to paste into an invoice, a packing list or a mail: in
/// English where it has English, as the shipping papers want.
String destinationCardText(ShipDestination d) {
  final lines = <String>[
    'Consignee: ${d.nameEn ?? d.name}',
    if (d.nameEn != null && d.nameEn != d.name) '  (${d.name})',
    if (d.department != null) 'Dept.: ${d.department}',
    'Address: ${d.addressEn ?? d.addressLine}',
    if (d.countryCode != null) 'Country: ${d.countryCode}',
    if (d.contactName != null) 'Attn: ${d.contactName}',
    for (final p in d.allPhones) 'Tel: $p',
    if (d.email != null) 'E-mail: ${d.email}',
    if (d.taxId != null) '${d.taxIdKind ?? 'Tax ID'}: ${d.taxId}',
    if (!d.notifySame && d.notifyName != null) ...[
      'Notify Party: ${d.notifyName}',
      if (d.notifyAddress != null) '  ${d.notifyAddress}',
      if (d.notifyContact != null) '  Attn: ${d.notifyContact}',
      if (d.notifyPhone != null) '  Tel: ${d.notifyPhone}',
    ] else
      'Notify Party: SAME AS CONSIGNEE',
    if (d.port != null) 'Port of Destination: ${d.port}',
    if (d.incoterms != null) 'Incoterms: ${d.incoterms}',
    if (d.transport != null) 'Transport: ${d.transport}',
    if (d.forwarderName != null)
      'Forwarder: ${[d.forwarderName!, if (d.forwarderContact != null) d.forwarderContact!, if (d.forwarderPhone != null) d.forwarderPhone!, if (d.forwarderEmail != null) d.forwarderEmail!].join(' / ')}',
  ];
  return lines.join('\n');
}

Future<void> copyDestinationCard(BuildContext context, ShipDestination d) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: destinationCardText(d)));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.sdcCopied)));
}

/// A card's contents, section by section; only what was written.
class DestinationCardView extends StatelessWidget {
  const DestinationCardView({super.key, required this.destination, this.dense = false});

  final ShipDestination destination;

  /// Company, address and phones only (a list); else everything.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final d = destination;
    Widget row(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: Text(label, style: muted)),
              Expanded(child: SelectableText(value, style: theme.textTheme.bodySmall)),
            ]),
          );
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 2),
          child: Text(t, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text([d.name, if (d.department != null) d.department!].join(' '), style: theme.textTheme.titleSmall),
      if (d.nameEn != null) Text(d.nameEn!, style: theme.textTheme.bodySmall),
      const SizedBox(height: 2),
      row(l10n.obDestContact, d.contactName),
      row(l10n.sdcSecAddress, [d.addressLine, if (d.countryCode != null) '(${d.countryCode})'].where((s) => s.isNotEmpty).join(' ')),
      row(l10n.sdcPhoneNumber, d.allPhones.join('\n')),
      row(l10n.obDestEmail, d.email),
      if (!dense) ...[
        if (d.hasExport) head(l10n.sdcSecExport),
        row(l10n.sdcAddressEn, d.addressEn),
        row(d.taxIdKind ?? l10n.sdcTaxId, d.taxId),
        row(l10n.sdcPort, d.port),
        row(l10n.sdcIncoterms, d.incoterms),
        row(l10n.sdcTransport, transportLabel(l10n, d.transport)),
        if (!d.notifySame) ...[
          head(l10n.sdcSecNotify),
          row(l10n.sdcNotifyName, d.notifyName),
          row(l10n.sdcNotifyAddress, d.notifyAddress),
          row(l10n.sdcNotifyContact, d.notifyContact),
          row(l10n.sdcNotifyPhone, d.notifyPhone),
        ],
        if (d.forwarderName != null) ...[
          head(l10n.sdcSecForwarder),
          row(l10n.sdcFwdName, d.forwarderName),
          row(l10n.sdcFwdContact, d.forwarderContact),
          row(l10n.sdcFwdPhone, d.forwarderPhone),
          row(l10n.sdcFwdEmail, d.forwarderEmail),
        ],
        row(l10n.sdcDocuments, d.documentsNote),
        row(l10n.obDestNote, d.note),
      ],
    ]);
  }
}

class _DestinationDialog extends ConsumerStatefulWidget {
  const _DestinationDialog({this.existing});

  final ShipDestination? existing;

  @override
  ConsumerState<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends ConsumerState<_DestinationDialog> {
  late final ShipDestination? _e = widget.existing;
  late final Map<String, TextEditingController> _c = {
    for (final (k, v) in [
      ('name', _e?.name),
      ('name-en', _e?.nameEn),
      ('department', _e?.department),
      ('contact', _e?.contactName),
      ('postal', _e?.postalCode),
      ('address1', _e?.address1),
      ('address2', _e?.address2),
      ('address-en', _e?.addressEn),
      ('phone', _e?.phone),
      ('email', _e?.email),
      ('country', _e?.countryCode),
      ('tax-kind', _e?.taxIdKind),
      ('tax-id', _e?.taxId),
      ('port', _e?.port),
      ('incoterms', _e?.incoterms),
      ('notify-name', _e?.notifyName),
      ('notify-address', _e?.notifyAddress),
      ('notify-contact', _e?.notifyContact),
      ('notify-phone', _e?.notifyPhone),
      ('fwd-name', _e?.forwarderName),
      ('fwd-contact', _e?.forwarderContact),
      ('fwd-phone', _e?.forwarderPhone),
      ('fwd-email', _e?.forwarderEmail),
      ('documents', _e?.documentsNote),
      ('note', _e?.note),
    ])
      k: TextEditingController(text: v ?? ''),
  };

  /// More phones: (whose, number).
  late final List<(TextEditingController, TextEditingController)> _phones = [
    for (final p in _e?.phones ?? const <DestinationPhone>[])
      (TextEditingController(text: p.label ?? ''), TextEditingController(text: p.number)),
  ];
  late String? _transport = _e?.transport;
  late bool _notifySame = _e?.notifySame ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    for (final (a, b) in _phones) {
      a.dispose();
      b.dispose();
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
      id: _e?.id,
      name: name,
      nameEn: _v('name-en'),
      department: _v('department'),
      contactName: _v('contact'),
      postalCode: _v('postal'),
      address1: _v('address1'),
      address2: _v('address2'),
      addressEn: _v('address-en'),
      phone: _v('phone'),
      phones: [
        for (final (a, b) in _phones)
          if (b.text.trim().isNotEmpty)
            DestinationPhone(label: a.text.trim().isEmpty ? null : a.text.trim(), number: b.text.trim()),
      ],
      email: _v('email'),
      countryCode: _v('country')?.toUpperCase(),
      taxIdKind: _v('tax-kind'),
      taxId: _v('tax-id'),
      port: _v('port'),
      incoterms: _v('incoterms')?.toUpperCase(),
      transport: _transport,
      notifySame: _notifySame,
      notifyName: _notifySame ? null : _v('notify-name'),
      notifyAddress: _notifySame ? null : _v('notify-address'),
      notifyContact: _notifySame ? null : _v('notify-contact'),
      notifyPhone: _notifySame ? null : _v('notify-phone'),
      forwarderName: _v('fwd-name'),
      forwarderContact: _v('fwd-contact'),
      forwarderPhone: _v('fwd-phone'),
      forwarderEmail: _v('fwd-email'),
      documentsNote: _v('documents'),
      note: _v('note'),
      useCount: _e?.useCount ?? 0,
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
        Navigator.pop(context, d.withId(data));
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
    final theme = Theme.of(context);
    Widget f(String k, String label, {TextInputType? type, String? hint, int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: TextField(
            key: ValueKey('sd-$k'),
            controller: _c[k],
            keyboardType: lines > 1 ? TextInputType.multiline : type,
            minLines: lines > 1 ? 2 : 1,
            maxLines: lines,
            decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
          ),
        );
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(t, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
        );
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.obDestNew : l10n.obDestEdit),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            head(l10n.sdcSecBasic),
            f('name', l10n.obDestName),
            f('name-en', l10n.sdcNameEn, hint: 'Test Trading Co., Ltd.'),
            f('department', l10n.obDestDepartment),
            f('contact', l10n.obDestContact),
            head(l10n.sdcSecAddress),
            Row(children: [
              SizedBox(width: 130, child: f('postal', l10n.obDestPostal, hint: '123-4567')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('country', l10n.obDestCountry, hint: 'JP / CN / US')),
            ]),
            f('address1', l10n.obDestAddress1),
            f('address2', l10n.obDestAddress2),
            f('address-en', l10n.sdcAddressEn, lines: 3),
            head(l10n.sdcSecContact),
            f('phone', l10n.sdcPhoneMain, type: TextInputType.phone),
            for (final (i, (a, b)) in _phones.indexed)
              Row(key: ValueKey('sd-phone-row-$i'), children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: ValueKey('sd-phone-label-$i'),
                    controller: a,
                    decoration: InputDecoration(labelText: l10n.sdcPhoneLabel, isDense: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: ValueKey('sd-phone-number-$i'),
                    controller: b,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: l10n.sdcPhoneNumber, isDense: true),
                  ),
                ),
                IconButton(
                  key: ValueKey('sd-phone-remove-$i'),
                  tooltip: l10n.sdcPhoneRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    final (x, y) = _phones.removeAt(i);
                    x.dispose();
                    y.dispose();
                  }),
                ),
              ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('sd-phone-add'),
                onPressed: () => setState(() => _phones.add((TextEditingController(), TextEditingController()))),
                icon: const Icon(Icons.add_call),
                label: Text(l10n.sdcPhoneAdd),
              ),
            ),
            f('email', l10n.obDestEmail, type: TextInputType.emailAddress),
            head(l10n.sdcSecExport),
            Row(children: [
              Expanded(child: f('tax-kind', l10n.sdcTaxKind, hint: l10n.sdcTaxKindHint)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('tax-id', l10n.sdcTaxId)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: f('port', l10n.sdcPort, hint: 'Shanghai / PVG')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('incoterms', l10n.sdcIncoterms, hint: destinationIncoterms.take(4).join(' / '))),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('sd-transport'),
                initialValue: destinationTransports.contains(_transport) ? _transport : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.sdcTransport, isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final t in destinationTransports)
                    DropdownMenuItem<String?>(value: t, child: Text(transportLabel(l10n, t))),
                ],
                onChanged: (v) => setState(() => _transport = v),
              ),
            ),
            head(l10n.sdcSecNotify),
            SwitchListTile(
              key: const ValueKey('sd-notify-same'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.sdcNotifySame),
              value: _notifySame,
              onChanged: (v) => setState(() => _notifySame = v),
            ),
            if (!_notifySame) ...[
              f('notify-name', l10n.sdcNotifyName),
              f('notify-address', l10n.sdcNotifyAddress, lines: 3),
              f('notify-contact', l10n.sdcNotifyContact),
              f('notify-phone', l10n.sdcNotifyPhone, type: TextInputType.phone),
            ],
            head(l10n.sdcSecForwarder),
            f('fwd-name', l10n.sdcFwdName),
            Row(children: [
              Expanded(child: f('fwd-contact', l10n.sdcFwdContact)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: f('fwd-phone', l10n.sdcFwdPhone, type: TextInputType.phone)),
            ]),
            f('fwd-email', l10n.sdcFwdEmail, type: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.sm),
            f('documents', l10n.sdcDocuments, hint: l10n.sdcDocumentsHint, lines: 3),
            f('note', l10n.obDestNote),
            if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
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

/// The cards, searched by any of their words; one chosen.
class _PickCardDialog extends ConsumerStatefulWidget {
  const _PickCardDialog();

  @override
  ConsumerState<_PickCardDialog> createState() => _PickCardDialogState();
}

class _PickCardDialogState extends ConsumerState<_PickCardDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(shipDestinationsProvider).valueOrNull ?? const <ShipDestination>[];
    final shown = [for (final d in all) if (destinationMatches(d, _search.text)) d];
    return AlertDialog(
      key: const ValueKey('sd-pick-dialog'),
      title: Text(l10n.ofPickCard),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(children: [
          TextField(
            key: const ValueKey('sd-pick-search'),
            controller: _search,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.sdcSearch),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: all.isEmpty
                ? Center(child: Text(l10n.ofCardNone, textAlign: TextAlign.center))
                : ListView(children: [
                    for (final d in shown)
                      Card(
                        key: ValueKey('sd-pick-${d.id}'),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, d),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: DestinationCardView(destination: d, dense: true),
                          ),
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
          key: const ValueKey('sd-pick-new'),
          onPressed: () async {
            final d = await showDestinationDialog(context);
            if (d != null && context.mounted) Navigator.pop(context, d);
          },
          child: Text(l10n.obDestNew),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
      ],
    );
  }
}

/// Whether every word of [query] is somewhere on the card.
bool destinationMatches(ShipDestination d, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final hay = [
    d.name, d.nameEn, d.department, d.contactName, d.addressLine, d.addressEn, d.countryCode, ...d.allPhones, d.email,
    d.taxId, d.port, d.forwarderName, d.notifyName,
  ].whereType<String>().join('\n').toLowerCase();
  return words.every(hay.contains);
}

/// 出荷先カード: the destinations kept, most used first — each with what an
/// export needs — searched, added, changed, copied as text or removed.
class ShipDestinationsScreen extends ConsumerStatefulWidget {
  const ShipDestinationsScreen({super.key, this.embedded = false});

  /// A tab of 出庫 (the hub): no title of its own.
  final bool embedded;

  @override
  ConsumerState<ShipDestinationsScreen> createState() => _ShipDestinationsScreenState();
}

class _ShipDestinationsScreenState extends ConsumerState<ShipDestinationsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _retire(ShipDestination d) async {
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
    if (ok != true || !mounted) return;
    final r = await ref.read(outboundRepositoryProvider).retireDestination(d.id!);
    if (!mounted) return;
    if (r case ApiFailure(:final message)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
    }
    ref.invalidate(shipDestinationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final async = ref.watch(shipDestinationsProvider);
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.featShipDestinations)),
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
        data: (rows) {
          if (rows.isEmpty) return EmptyStateView(icon: Icons.location_on_outlined, title: l10n.obDestEmpty);
          final shown = [for (final d in rows) if (destinationMatches(d, _search.text)) d];
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
            children: [
              TextField(
                key: const ValueKey('sd-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.sdcSearch,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                for (final d in shown)
                  SizedBox(
                    width: 420,
                    child: Card(
                      key: ValueKey('sd-row-${d.id}'),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showDestinationDialog(context, existing: d),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            DestinationCardView(destination: d),
                            const SizedBox(height: AppSpacing.xs),
                            Row(children: [
                              Expanded(child: Text(l10n.obDestUsed(d.useCount), style: muted)),
                              IconButton(
                                key: ValueKey('sd-copy-${d.id}'),
                                tooltip: l10n.sdcCopy,
                                icon: const Icon(Icons.copy_all_outlined),
                                onPressed: () => copyDestinationCard(context, d),
                              ),
                              IconButton(
                                key: ValueKey('sd-retire-${d.id}'),
                                tooltip: l10n.actionDelete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _retire(d),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
