import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/presentation/warehouse_overview_screen.dart' show countryLabel;
import '../application/trading_partner_providers.dart';
import '../domain/trading_partner.dart';

/// The supplier/customer directory (spec §46 checklist item 8, 0035) — one
/// list serving both roles, since a real-world company can be either (or
/// both). Anyone can open this screen; the server is the real gate
/// (`partner.view`/`partner.manage`), same pattern as every other screen.
class TradingPartnerListScreen extends ConsumerWidget {
  const TradingPartnerListScreen({super.key});

  void _snackError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {TradingPartner? partner}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PartnerFormSheet(partner: partner),
    );
    if (saved == true) {
      ref.invalidate(tradingPartnerListProvider);
    }
  }

  Future<void> _toggleStatus(
      BuildContext context, WidgetRef ref, TradingPartner partner) async {
    final l10n = AppLocalizations.of(context);
    final nextStatus = partner.isActive ? 'inactive' : 'active';
    final result = await ref
        .read(tradingPartnerRepositoryProvider)
        .setStatus(partner.id, nextStatus);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(tradingPartnerListProvider),
      failure: (f) => _snackError(context, humanizeApiErrorMessage(l10n, f.message)),
    );
  }

  String _kindLabel(AppLocalizations l10n, PartnerKind? kind) => switch (kind) {
        null => l10n.partnerKindAll,
        PartnerKind.supplier => l10n.partnerKindSupplier,
        PartnerKind.customer => l10n.partnerKindCustomer,
        PartnerKind.both => l10n.partnerKindBoth,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(tradingPartnerListProvider);
    final showInactive = ref.watch(showInactivePartnersProvider);
    final kindFilter = ref.watch(partnerKindFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.partnersTitle),
        actions: [
          // How our codes for companies are numbered (0112).
          IconButton(
            key: const ValueKey('partner-code-rules'),
            tooltip: l10n.pcRulesTitle,
            icon: const Icon(Icons.pin_outlined),
            onPressed: () async {
              await showDialog<void>(context: context, builder: (_) => const PartnerCodeRulesDialog());
              ref.invalidate(tradingPartnerListProvider);
            },
          ),
          IconButton(
            tooltip: l10n.productsShowInactive,
            icon: Icon(showInactive
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => ref
                .read(showInactivePartnersProvider.notifier)
                .update((v) => !v),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.partnersSearchHint,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
              onChanged: (value) =>
                  ref.read(partnerSearchProvider.notifier).state = value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final kind in [null, ...PartnerKind.values])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(_kindLabel(l10n, kind)),
                        selected: kindFilter == kind,
                        onSelected: (_) =>
                            ref.read(partnerKindFilterProvider.notifier).state = kind,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: async.when(
              loading: () => LoadingView(message: l10n.loading),
              error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(tradingPartnerListProvider),
              ),
              data: (partners) {
                if (partners.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.handshake_outlined,
                    title: l10n.partnersEmpty,
                    message: l10n.partnersEmptyBody,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(tradingPartnerListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    itemCount: partners.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _PartnerCard(
                      partner: partners[i],
                      onTap: () =>
                          _openForm(context, ref, partner: partners[i]),
                      onToggleStatus: () =>
                          _toggleStatus(context, ref, partners[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onTap,
    required this.onToggleStatus,
  });

  final TradingPartner partner;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  String _kindLabel(AppLocalizations l10n) => switch (partner.kind) {
        PartnerKind.supplier => l10n.partnerKindSupplier,
        PartnerKind.customer => l10n.partnerKindCustomer,
        PartnerKind.both => l10n.partnerKindBoth,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(partner.name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusPill(
                          tone: StatusTone.info,
                          label: _kindLabel(l10n),
                          dense: true,
                        ),
                      ],
                    ),
                    // Our code for it, and its code for us (0112).
                    if ((partner.code ?? '').isNotEmpty || partner.theirCodeForUs != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((partner.code ?? '').isNotEmpty) l10n.pcOurCodeShort(partner.code!),
                          if (partner.theirCodeForUs != null) l10n.pcTheirCodeShort(partner.theirCodeForUs!),
                        ].join(' · '),
                        key: ValueKey('partner-codes-${partner.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
                      ),
                    ],
                    if (partner.contactName != null &&
                        partner.contactName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(partner.contactName!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                    if (partner.phone != null && partner.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(partner.phone!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: onToggleStatus,
                child: StatusPill(
                  tone: partner.isActive ? StatusTone.success : StatusTone.neutral,
                  label: partner.isActive ? l10n.productActive : l10n.productInactive,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for creating or editing one trading partner.
class _PartnerFormSheet extends ConsumerStatefulWidget {
  const _PartnerFormSheet({this.partner});

  final TradingPartner? partner;

  @override
  ConsumerState<_PartnerFormSheet> createState() => _PartnerFormSheetState();
}

class _PartnerFormSheetState extends ConsumerState<_PartnerFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.partner?.name ?? '');
  late final TextEditingController _code =
      TextEditingController(text: widget.partner?.code ?? '');
  late final TextEditingController _theirCode =
      TextEditingController(text: widget.partner?.theirCodeForUs ?? '');
  late final TextEditingController _contactName =
      TextEditingController(text: widget.partner?.contactName ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.partner?.phone ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.partner?.email ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.partner?.address ?? '');
  late final TextEditingController _paymentTerms =
      TextEditingController(text: widget.partner?.paymentTerms ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.partner?.notes ?? '');
  late PartnerKind _kind = widget.partner?.kind ?? PartnerKind.supplier;
  late String _country = widget.partner?.countryCode ?? 'JP';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.partner != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _theirCode.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _paymentTerms.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l10n.partnerValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(tradingPartnerRepositoryProvider);
    String? errorMessage;
    if (_isEdit) {
      final result = await repo.update(
        id: widget.partner!.id,
        name: _name.text.trim(),
        kind: _kind,
        contactName: _contactName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        paymentTerms: _paymentTerms.text.trim(),
        notes: _notes.text.trim(),
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
      if (errorMessage == null && _country != widget.partner!.countryCode) {
        final c = await repo.setCountry(widget.partner!.id, _country);
        c.when(success: (_) {}, failure: (f) => errorMessage = f.message);
      }
      // Our code for it and its code for us (0112).
      if (errorMessage == null &&
          (_code.text.trim() != (widget.partner!.code ?? '') ||
              _theirCode.text.trim() != (widget.partner!.theirCodeForUs ?? ''))) {
        final c = await repo.setCodes(widget.partner!.id,
            code: _code.text.trim(), theirCodeForUs: _theirCode.text.trim());
        c.when(success: (_) {}, failure: (f) => errorMessage = f.message);
      }
    } else {
      final result = await repo.create(
        name: _name.text.trim(),
        kind: _kind,
        code: _code.text.trim(),
        contactName: _contactName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        paymentTerms: _paymentTerms.text.trim(),
        notes: _notes.text.trim(),
      );
      int? createdId;
      result.when(success: (id) => createdId = id, failure: (f) => errorMessage = f.message);
      if (createdId != null && _country != 'JP') {
        final c = await repo.setCountry(createdId!, _country);
        c.when(success: (_) {}, failure: (f) => errorMessage = f.message);
      }
      if (createdId != null && _theirCode.text.trim().isNotEmpty) {
        final c = await repo.setCodes(createdId!, theirCodeForUs: _theirCode.text.trim());
        c.when(success: (_) {}, failure: (f) => errorMessage = f.message);
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = errorMessage == null
          ? null
          : humanizeApiErrorMessage(l10n, errorMessage!);
    });
    if (errorMessage == null) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? l10n.partnerEditTitle : l10n.partnerNewTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<PartnerKind>(
              segments: [
                ButtonSegment(
                    value: PartnerKind.supplier, label: Text(l10n.partnerKindSupplier)),
                ButtonSegment(
                    value: PartnerKind.customer, label: Text(l10n.partnerKindCustomer)),
                ButtonSegment(value: PartnerKind.both, label: Text(l10n.partnerKindBoth)),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.partnerName),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Which country (0102): orders from customers in CN are "orders
            // from China" on the sales dashboard.
            DropdownButtonFormField<String>(
              key: const ValueKey('partner-country'),
              initialValue: _country,
              decoration: InputDecoration(labelText: l10n.partnerCountry),
              items: [
                for (final c in {'JP', 'CN', _country})
                  DropdownMenuItem(value: c, child: Text(countryLabel(l10n, c))),
              ],
              onChanged: (v) => setState(() => _country = v ?? _country),
            ),
            // Our code for the company: numbered by our rule when left
            // empty, and changeable later (0112).
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('partner-code'),
              controller: _code,
              decoration: InputDecoration(
                labelText: l10n.pcOurCode,
                helperText: _isEdit ? null : l10n.pcAutoHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('partner-their-code'),
              controller: _theirCode,
              decoration: InputDecoration(labelText: l10n.pcTheirCode, helperText: l10n.pcTheirCodeHint),
            ),
            if (_isEdit && widget.partner!.vendorCodes > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              _VendorCodes(partnerId: widget.partner!.id),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _contactName,
              decoration: InputDecoration(labelText: l10n.partnerContactName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.partnerPhone),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.partnerEmail),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: l10n.partnerAddress),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _paymentTerms,
              decoration: InputDecoration(labelText: l10n.partnerPaymentTerms),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.partnerNotes),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.minTouch,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.partnerSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A company's codes for its own suppliers, and the makers we learned they
/// stand for (0112).
class _VendorCodes extends ConsumerWidget {
  const _VendorCodes({required this.partnerId});

  final int partnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final codes = ref.watch(partnerVendorCodesProvider(partnerId)).valueOrNull ?? const <PartnerVendorCode>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.pcVendorCodesTitle, style: theme.textTheme.titleSmall),
      Text(l10n.pcVendorCodesHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: AppSpacing.xs),
      for (final c in codes)
        Padding(
          key: ValueKey('partner-vendor-${c.code}'),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 72, child: Text(c.code, style: const TextStyle(fontFamily: AppFonts.mono))),
            Expanded(child: Text(c.makerName ?? c.rawMaker ?? '—')),
          ]),
        ),
    ]);
  }
}

/// How our codes for companies are numbered, per kind (0112).
class PartnerCodeRulesDialog extends ConsumerStatefulWidget {
  const PartnerCodeRulesDialog({super.key});

  @override
  ConsumerState<PartnerCodeRulesDialog> createState() => _PartnerCodeRulesDialogState();
}

class _PartnerCodeRulesDialogState extends ConsumerState<PartnerCodeRulesDialog> {
  final Map<PartnerKind, (TextEditingController, TextEditingController, TextEditingController)> _c = {};
  List<PartnerCodeFormat>? _formats;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final (a, b, c) in _c.values) {
      a.dispose();
      b.dispose();
      c.dispose();
    }
    super.dispose();
  }

  void _fill(List<PartnerCodeFormat> formats) {
    for (final f in formats) {
      final t = _c[f.kind];
      if (t == null) {
        _c[f.kind] = (
          TextEditingController(text: f.prefix),
          TextEditingController(text: '${f.digits}'),
          TextEditingController(text: '${f.nextNumber}'),
        );
      } else {
        t.$1.text = f.prefix;
        t.$2.text = '${f.digits}';
        t.$3.text = '${f.nextNumber}';
      }
    }
    _formats = formats;
  }

  Future<void> _load() async {
    final r = await ref.read(tradingPartnerRepositoryProvider).codeFormats();
    if (!mounted) return;
    setState(() => r.when(success: _fill, failure: (f) => _message = f.message));
  }

  static String _preview(String prefix, String digits, String next) {
    final d = int.tryParse(digits) ?? 5;
    final n = int.tryParse(next) ?? 1;
    return '$prefix${'$n'.padLeft(d, '0')}';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(tradingPartnerRepositoryProvider);
    setState(() => _busy = true);
    String? error;
    List<PartnerCodeFormat>? latest;
    for (final f in _formats ?? const <PartnerCodeFormat>[]) {
      final (p, d, n) = _c[f.kind]!;
      final prefix = p.text.trim();
      final digits = int.tryParse(d.text.trim()) ?? f.digits;
      final next = int.tryParse(n.text.trim()) ?? f.nextNumber;
      if (prefix == f.prefix && digits == f.digits && next == f.nextNumber) continue;
      final r = await repo.saveCodeFormat(f.kind, prefix: prefix, digits: digits, nextNumber: next);
      r.when(success: (v) => latest = v, failure: (e) => error = e.message);
      if (error != null) break;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (latest != null) _fill(latest!);
      _message = error == null ? l10n.pcRulesSaved : humanizeApiErrorMessage(l10n, error!);
    });
  }

  Future<void> _issue() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final r = await ref.read(tradingPartnerRepositoryProvider).issueMissingCodes();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.when(success: (n) => l10n.pcIssued(n), failure: (f) => humanizeApiErrorMessage(l10n, f.message));
    });
    await _load();
  }

  String _kindLabel(AppLocalizations l10n, PartnerKind k) => switch (k) {
        PartnerKind.supplier => l10n.partnerKindSupplier,
        PartnerKind.customer => l10n.partnerKindCustomer,
        PartnerKind.both => l10n.partnerKindBoth,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formats = _formats;
    return AlertDialog(
      title: Text(l10n.pcRulesTitle),
      content: SizedBox(
        width: 520,
        child: formats == null
            ? (_message == null ? const LinearProgressIndicator() : Text(_message!))
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.pcRulesHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  for (final f in formats) ...[
                    Text(_kindLabel(l10n, f.kind), style: theme.textTheme.titleSmall),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          key: ValueKey('pc-prefix-${f.kind.wire}'),
                          controller: _c[f.kind]!.$1,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.pcPrefix, isDense: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          key: ValueKey('pc-digits-${f.kind.wire}'),
                          controller: _c[f.kind]!.$2,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.pcDigits, isDense: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          key: ValueKey('pc-next-${f.kind.wire}'),
                          controller: _c[f.kind]!.$3,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.pcNext, isDense: true),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.md),
                      child: Text(
                        l10n.pcNextCode(_preview(_c[f.kind]!.$1.text.trim(), _c[f.kind]!.$2.text, _c[f.kind]!.$3.text)),
                        key: ValueKey('pc-preview-${f.kind.wire}'),
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono),
                      ),
                    ),
                  ],
                  if (_message != null) Text(_message!, key: const ValueKey('pc-message')),
                ]),
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('pc-issue'),
          onPressed: _busy || formats == null ? null : _issue,
          child: Text(l10n.pcIssueMissing),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        FilledButton(
          key: const ValueKey('pc-save'),
          onPressed: _busy || formats == null ? null : _save,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
