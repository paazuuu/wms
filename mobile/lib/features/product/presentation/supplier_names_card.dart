import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../partners/application/trading_partner_providers.dart';
import '../../partners/domain/trading_partner.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import '../domain/supplier_product_name.dart';

/// What each supplier calls this product (0087). The same product carries a
/// different name — and often a code of the supplier's own — on every
/// supplier's catalogue and delivery note. Recording them here lets the
/// product be found by those words, and lets a supplier's delivery note be
/// matched to it even when the note's JAN is missing or not ours.
class SupplierNamesCard extends ConsumerWidget {
  const SupplierNamesCard({super.key, required this.product});

  final Product product;

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [SupplierProductName? current]) async {
    final l10n = AppLocalizations.of(context);
    final partnersResult = await ref.read(tradingPartnerRepositoryProvider).list();
    if (!context.mounted) return;
    final suppliers = partnersResult.when(
      success: (rows) => rows.where((p) => p.kind != PartnerKind.customer).toList(),
      failure: (_) => <TradingPartner>[],
    );
    if (suppliers.isEmpty && current == null) {
      _snack(context, l10n.supplierNameNoSuppliers, error: true);
      return;
    }
    final draft = await showDialog<_Draft>(
      context: context,
      builder: (_) => _SupplierNameDialog(suppliers: suppliers, current: current),
    );
    if (draft == null || !context.mounted) return;
    final result = await ref.read(productRepositoryProvider).setSupplierName(
          supplierId: draft.supplierId,
          productId: product.id,
          supplierName: draft.name,
          supplierCode: draft.code,
          note: draft.note,
        );
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(productSupplierNamesProvider(product.id));
        ref.invalidate(productListProvider);
        _snack(context, l10n.supplierNameSaved);
      },
      failure: (f) => _snack(context, humanizeApiErrorMessage(l10n, f.message), error: true),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, SupplierProductName n) async {
    final l10n = AppLocalizations.of(context);
    final id = n.id;
    if (id == null) return;
    final result = await ref.read(productRepositoryProvider).removeSupplierName(id);
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(productSupplierNamesProvider(product.id));
        ref.invalidate(productListProvider);
      },
      failure: (f) => _snack(context, humanizeApiErrorMessage(l10n, f.message), error: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = ref.watch(productSupplierNamesProvider(product.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.supplierNamesSection, style: theme.textTheme.titleSmall),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.supplierNameAdd),
                  onPressed: () => _edit(context, ref),
                ),
              ],
            ),
            Text(l10n.supplierNamesHint,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            ...names.when(
              loading: () => [const LinearProgressIndicator()],
              error: (e, _) => [Text('$e', style: TextStyle(color: scheme.error))],
              data: (rows) => rows.isEmpty
                  ? [
                      Text(l10n.supplierNamesEmpty,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ]
                  : [
                      for (final n in rows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(n.supplierName),
                          subtitle: Text([
                            n.supplierDisplayName,
                            if (n.supplierCode != null) l10n.supplierNameCodeLabel(n.supplierCode!),
                          ].join(' · ')),
                          onTap: () => _edit(context, ref, n),
                          trailing: IconButton(
                            tooltip: l10n.actionDelete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _remove(context, ref, n),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Draft {
  const _Draft({required this.supplierId, required this.name, this.code, this.note});

  final int supplierId;
  final String name;
  final String? code;
  final String? note;
}

class _SupplierNameDialog extends StatefulWidget {
  const _SupplierNameDialog({required this.suppliers, this.current});

  final List<TradingPartner> suppliers;
  final SupplierProductName? current;

  @override
  State<_SupplierNameDialog> createState() => _SupplierNameDialogState();
}

class _SupplierNameDialogState extends State<_SupplierNameDialog> {
  late int? _supplierId = widget.current?.supplierId ??
      (widget.suppliers.isEmpty ? null : widget.suppliers.first.id);
  late final _name = TextEditingController(text: widget.current?.supplierName ?? '');
  late final _code = TextEditingController(text: widget.current?.supplierCode ?? '');
  late final _note = TextEditingController(text: widget.current?.note ?? '');

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _trim(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.current != null;
    return AlertDialog(
      title: Text(editing ? l10n.supplierNameEdit : l10n.supplierNameAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editing)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.current!.supplierDisplayName),
              subtitle: Text(l10n.supplierNameSupplier),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _supplierId,
              decoration: InputDecoration(labelText: l10n.supplierNameSupplier),
              items: [
                for (final s in widget.suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
          TextField(
            key: const ValueKey('supplier-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.supplierNameName),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: const ValueKey('supplier-code'),
            controller: _code,
            decoration: InputDecoration(labelText: l10n.supplierNameCode),
          ),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.supplierNameNote),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _supplierId == null || _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    _Draft(
                      supplierId: _supplierId!,
                      name: _name.text.trim(),
                      code: _trim(_code),
                      note: _trim(_note),
                    ),
                  ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
