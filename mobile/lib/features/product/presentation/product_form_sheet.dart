import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/barcode_resolver.dart';
import '../../../core/scan/scan_context.dart';
import '../../../core/scan/barcode_scan_screen.dart';
import '../../../core/scan/scan_resolution.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'product_labels.dart';

/// Bottom sheet for creating or editing one product. The JAN code is fixed
/// once created — `update_product` never touches it — so it's read-only
/// (shown, not editable) when [product] is non-null.
class ProductFormSheet extends ConsumerStatefulWidget {
  const ProductFormSheet({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormSheet> createState() => ProductFormSheetState();
}

class ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  late final TextEditingController _jan =
      TextEditingController(text: widget.product?.janCode ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _category =
      TextEditingController(text: widget.product?.category ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.product?.price == null
          ? ''
          : widget.product!.price!.toStringAsFixed(0));
  late final TextEditingController _sku =
      TextEditingController(text: widget.product?.sku ?? '');
  late TrackingMode _tracking =
      widget.product?.trackingMode ?? TrackingMode.untracked;
  bool _busy = false;
  String? _error;
  String? _scanWarning;

  bool get _isEdit => widget.product != null;

  // Barcode input before manual keying (§35): a new product's JAN is almost
  // always read straight off the item in hand, not typed digit by digit.
  //
  // The scan is then resolved through §26's one resolver, so keying a code that
  // already belongs to something is caught here rather than by a unique-index
  // error after the operator has filled the rest of the form in.
  Future<void> _scanJan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() {
      _jan.text = code;
      _scanWarning = null;
    });

    // A product form is not a floor step: nothing here is the wrong kind of
    // scan, so the context is `lookup` and everything is fair game (§26).
    final result = await ref
        .read(barcodeResolverProvider)
        .resolve(code, context: ScanContext.lookup);
    if (!mounted) return;
    result.when(
      success: (hit) {
        // Only a product hit matters here. A location or serial label in the JAN
        // field is a mis-scan the server will reject on its own, and guessing at
        // what the operator meant would be worse than letting them look.
        if (hit.kind != ScanKind.product) return;
        if (hit.productId == widget.product?.id) return;
        setState(() => _scanWarning = AppLocalizations.of(context)
            .productScanAlreadyUsed(hit.name ?? hit.janCode ?? code));
      },
      // A failed lookup must not block data entry: the create call is still the
      // authority on whether this code can be used.
      failure: (_) {},
    );
  }

  @override
  void dispose() {
    _jan.dispose();
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _sku.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_jan.text.trim().isEmpty || _name.text.trim().isEmpty) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final category = _category.text.trim().isEmpty ? null : _category.text.trim();
    final price = double.tryParse(_price.text.trim());
    // Empty means "clear it", which is why this is sent as '' and not as null —
    // null tells `set_product_identity` to leave the field alone (0065).
    final sku = _sku.text.trim();
    final repo = ref.read(productRepositoryProvider);

    String? errorMessage;
    int? productId = widget.product?.id;
    if (_isEdit) {
      final result = await repo.update(
        id: widget.product!.id,
        name: _name.text.trim(),
        category: category,
        price: price,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    } else {
      final result = await repo.create(
        janCode: _jan.text.trim(),
        name: _name.text.trim(),
        category: category,
        price: price,
      );
      result.when(
          success: (id) => productId = id,
          failure: (f) => errorMessage = f.message);
    }

    // Identity is a second call because it is a second decision (0057): the SKU
    // and the tracking mode go through `set_product_identity`, which refuses a
    // mode that contradicts lots or serials already recorded. Only sent when
    // something actually changed, so editing a name never risks that refusal.
    final identityChanged = sku != (widget.product?.sku ?? '') ||
        _tracking != (widget.product?.trackingMode ?? TrackingMode.untracked);
    if (errorMessage == null && productId != null && identityChanged) {
      final result = await repo.setIdentity(
        id: productId!,
        sku: sku,
        trackingMode: _tracking,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
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
              _isEdit ? l10n.productEditTitle : l10n.productNewTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _jan,
              readOnly: _isEdit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.productJanCode,
                suffixIcon: _isEdit
                    ? null
                    : IconButton(
                        tooltip: l10n.scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        onPressed: _scanJan,
                      ),
              ),
            ),
            if (_scanWarning != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: theme.colorScheme.tertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(_scanWarning!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.tertiary)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.productName),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _sku,
              decoration: InputDecoration(
                labelText: l10n.productSku,
                helperText: l10n.productSkuHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // What must be recorded when this product arrives. Changing it is
            // refused by the server once lots or serials exist (§37-15), so the
            // failure surfaces in the same error line as everything else.
            DropdownButtonFormField<TrackingMode>(
              initialValue: _tracking,
              decoration: InputDecoration(labelText: l10n.productTracking),
              items: [
                for (final mode in TrackingMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(trackingModeLabel(l10n, mode)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (mode) => setState(
                      () => _tracking = mode ?? TrackingMode.untracked),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _category,
              decoration: InputDecoration(labelText: l10n.productCategory),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(labelText: l10n.productPrice),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
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
                    : Text(l10n.productSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
