import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/api/api_result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product.dart';
import '../application/stock_adjustment_providers.dart';
import '../domain/adjustment_type.dart';

/// Localized label for a stock-adjustment reason category.
String adjustmentTypeLabel(AppLocalizations l10n, AdjustmentType type) {
  switch (type) {
    case AdjustmentType.manual:
      return l10n.adjustTypeManual;
    case AdjustmentType.count:
      return l10n.adjustTypeCount;
    case AdjustmentType.damage:
      return l10n.adjustTypeDamage;
    case AdjustmentType.returned:
      return l10n.adjustTypeReturn;
    case AdjustmentType.transfer:
      return l10n.adjustTypeTransfer;
  }
}

/// Step two of a stock adjustment: choose add vs. remove, a quantity, a reason
/// category, and optional notes, then book it against the selected product.
class StockAdjustmentFormScreen extends ConsumerStatefulWidget {
  const StockAdjustmentFormScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockAdjustmentFormScreen> createState() =>
      _StockAdjustmentFormScreenState();
}

class _StockAdjustmentFormScreenState
    extends ConsumerState<StockAdjustmentFormScreen> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isAdd = true;
  AdjustmentType _type = AdjustmentType.manual;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Rebuild the "on hand after" preview whenever the quantity changes.
    _quantityController.addListener(_onQuantityChanged);
  }

  void _onQuantityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityChanged);
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _magnitude {
    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) return null;
    return qty;
  }

  /// Signed delta previewed to the user and sent to the API.
  int? get _signedQuantity {
    final magnitude = _magnitude;
    if (magnitude == null) return null;
    return _isAdd ? magnitude : -magnitude;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final signed = _signedQuantity;
    if (signed == null) {
      _notify(l10n.enterQtyPositive);
      return;
    }
    final current = widget.product.displayStock;
    if (!_isAdd && current + signed < 0) {
      _notify(l10n.cannotRemoveOnly(-signed, current));
      return;
    }

    setState(() => _submitting = true);
    final repository = ref.read(stockAdjustmentRepositoryProvider);
    final result = await repository.create(
      productId: widget.product.id,
      quantity: signed,
      type: _type.wire,
      reason: _reasonController.text,
      notes: _notesController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case ApiSuccess(:final data):
        ref.invalidate(productDetailProvider(widget.product.id));
        _notify(AppLocalizations.of(context).stockUpdatedTo(data.quantityAfter));
        Navigator.of(context).pop();
      case ApiFailure(:final message):
        _notify(message);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    final current = product.displayStock;
    final signed = _signedQuantity;
    final resulting = signed == null ? null : current + signed;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featStockAdjustment)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _ProductHeader(product: product),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.adjustAdd),
                      icon: const Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.adjustRemove),
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                  selected: {_isAdd},
                  onSelectionChanged: (s) => setState(() => _isAdd = s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.quantity,
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<AdjustmentType>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: l10n.reasonType,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final t in AdjustmentType.values)
                      DropdownMenuItem(
                          value: t, child: Text(adjustmentTypeLabel(l10n, t))),
                  ],
                  onChanged: (t) =>
                      setState(() => _type = t ?? AdjustmentType.manual),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.reasonOptional,
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.notesOptional,
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (resulting != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.onHandAfter,
                            style: theme.textTheme.bodyMedium),
                        Text(
                          '$current → $resulting',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'FiraCode',
                            fontWeight: FontWeight.w600,
                            color: _isAdd ? scheme.primary : scheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isAdd ? Icons.add : Icons.remove),
                      label: Text(
                        _submitting
                            ? l10n.saving
                            : _isAdd
                                ? l10n.addStock
                                : l10n.removeStock,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              product.sku,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFamily: 'FiraCode',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StatusPill(
              tone: StatusTone.neutral,
              label: AppLocalizations.of(context)
                  .onHandCount(product.displayStock),
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
