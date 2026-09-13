import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
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
    final nextStatus = partner.isActive ? 'inactive' : 'active';
    final result = await ref
        .read(tradingPartnerRepositoryProvider)
        .setStatus(partner.id, nextStatus);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(tradingPartnerListProvider),
      failure: (f) => _snackError(context, f.message),
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
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.partner != null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
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
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = errorMessage;
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
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _code,
                decoration: InputDecoration(labelText: l10n.partnerCode),
              ),
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
