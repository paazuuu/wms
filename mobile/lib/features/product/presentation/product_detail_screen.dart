import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import '../domain/product_lot.dart';
import '../domain/warehouse_product.dart';
import 'product_facts.dart';
import 'product_form_sheet.dart';
import 'product_labels.dart';

/// Everything Phase A gave one product, on one screen: its codes (0057), its
/// units (0059), its lots and serials (0060), and how this warehouse handles it
/// (0063).
///
/// Sections rather than tabs, because an operator opening this is usually
/// checking one specific thing and scrolling is cheaper than guessing which tab
/// holds it. The lot and serial sections appear only when the tracking mode says
/// they can exist — an UNTRACKED product showing an empty "Lots" card would
/// invite someone to look for a button that is not there.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  void _snack(BuildContext context, String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.error : null,
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.productDetailTitle)),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(productListProvider),
        ),
        data: (products) {
          // Read out of the list the caller already has rather than fetching one
          // product: `list_products` is the only read that returns the barcodes
          // and units, so a single-product fetch would mean a second RPC that
          // answers the same question.
          final product =
              products.where((p) => p.id == productId).firstOrNull;
          if (product == null) {
            return EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: l10n.productsEmpty,
              message: l10n.productsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productListProvider);
              ref.invalidate(productLotsProvider(productId));
              ref.invalidate(productSerialsProvider(productId));
              ref.invalidate(warehouseProductProvider(productId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _Header(product: product),
                const SizedBox(height: AppSpacing.md),
                _BarcodesCard(product: product, onMessage: _snack),
                const SizedBox(height: AppSpacing.md),
                _UnitsCard(product: product, onMessage: _snack),
                if (product.trackingMode.tracksLot) ...[
                  const SizedBox(height: AppSpacing.md),
                  _LotsCard(productId: productId),
                ],
                if (product.trackingMode.tracksSerial) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SerialsCard(productId: productId),
                ],
                const SizedBox(height: AppSpacing.md),
                _WarehouseSettingsCard(product: product, onMessage: _snack),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Name, codes, status and the fact chips the list screen shows too — so the
/// detail opens on the same summary the operator tapped.
class _Header extends ConsumerWidget {
  const _Header({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(product.name, style: theme.textTheme.titleMedium),
                ),
                StatusPill(
                  tone: product.isActive
                      ? StatusTone.success
                      : StatusTone.neutral,
                  label:
                      product.isActive ? l10n.productActive : l10n.productInactive,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              product.sku == null
                  ? product.janCode
                  : '${product.janCode} · ${product.sku}',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: AppFonts.mono, color: scheme.onSurfaceVariant),
            ),
            if (product.category != null) ...[
              const SizedBox(height: 2),
              Text(product.category!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: AppSpacing.sm),
            ProductFacts(product: product),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.productEdit),
                onPressed: () async {
                  final saved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ProductFormSheet(product: product),
                  );
                  if (saved == true) ref.invalidate(productListProvider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled card with an optional trailing action — the shape every section on
/// this screen uses, so they read as one list rather than four designs.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.action,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _Notify = void Function(BuildContext context, String message,
    {bool error});

/// The codes that reach this product (0057). Adding one can name a unit, which
/// is what makes a case code mean twelve pieces without anyone typing 12.
class _BarcodesCard extends ConsumerWidget {
  const _BarcodesCard({required this.product, required this.onMessage});

  final Product product;
  final _Notify onMessage;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BarcodeSheet(product: product),
    );
    if (added == true) ref.invalidate(productListProvider);
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, ProductBarcode barcode) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productBarcodeRemoveQ),
        content: Text(l10n.productBarcodeRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result =
        await ref.read(productRepositoryProvider).removeBarcode(barcode.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(productListProvider),
      failure: (f) => onMessage(
          context, humanizeApiErrorMessage(l10n, f.message), error: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _Section(
      title: l10n.productBarcodesSection,
      action: TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.productBarcodeAdd),
        onPressed: () => _add(context, ref),
      ),
      children: [
        if (product.barcodes.isEmpty)
          Text(l10n.productBarcodeEmpty,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        for (final barcode in product.barcodes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(barcode.barcode,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontFamily: AppFonts.mono)),
                      Text(
                        barcode.uom == null
                            ? barcode.barcodeType
                            : '${barcode.barcodeType} · '
                                '${l10n.productBarcodeQtyPerScan('${barcode.quantityPerScan} ${barcode.uom}')}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (barcode.isPrimary)
                  StatusPill(
                      tone: StatusTone.info,
                      label: l10n.productBarcodePrimary,
                      dense: true)
                else
                  IconButton(
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _remove(context, ref, barcode),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Register another code. The unit is optional and that choice is the point: with
/// a unit, `quantity_per_scan` comes from the product's conversion (0059) and the
/// two can never drift; without one, the code counts one.
class _BarcodeSheet extends ConsumerStatefulWidget {
  const _BarcodeSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_BarcodeSheet> createState() => _BarcodeSheetState();
}

class _BarcodeSheetState extends ConsumerState<_BarcodeSheet> {
  final _code = TextEditingController();
  String _type = 'JAN';
  String? _uom;
  bool _busy = false;
  String? _error;

  static const _types = [
    'JAN', 'EAN', 'UPC', 'ITF', 'CODE128', 'QR', 'SKU', 'CASE', 'PALLET', 'OTHER'
  ];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_code.text.trim().isEmpty) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(productRepositoryProvider).addBarcode(
          productId: widget.product.id,
          barcode: _code.text.trim(),
          barcodeType: _type,
          uomCode: _uom,
        );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _busy = false;
        // The server refuses a code that belongs to another product, and a unit
        // the product has no conversion for — both are worth reading verbatim.
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Only units this product actually has a conversion for: naming any other
    // one is refused by the derive trigger, so it is not offered.
    final units = widget.product.uoms.map((u) => u.code).toList();

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
            Text(l10n.productBarcodeAdd, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _code,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.scanOrTypeBarcode),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.productBarcodeType),
              items: [
                for (final t in _types)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _type = v ?? 'JAN'),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String?>(
              initialValue: _uom,
              decoration: InputDecoration(labelText: l10n.productBarcodeUnit),
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text(l10n.productSerialFilterAll)),
                for (final code in units)
                  DropdownMenuItem<String?>(value: code, child: Text(code)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _uom = v),
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
                    : Text(l10n.productSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The base unit and the pack sizes defined against it (0059).
class _UnitsCard extends ConsumerWidget {
  const _UnitsCard({required this.product, required this.onMessage});

  final Product product;
  final _Notify onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = product.baseUom;

    return _Section(
      title: l10n.productUnitsSection,
      action: TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.productUnitAdd),
        onPressed: () async {
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _UomSheet(product: product),
          );
          if (saved == true) ref.invalidate(productListProvider);
        },
      ),
      children: [
        for (final uom in product.uoms)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text('${uom.code} — ${uom.name}',
                      style: theme.textTheme.bodyMedium),
                ),
                if (uom.isBase)
                  StatusPill(
                      tone: StatusTone.neutral,
                      label: l10n.productUnitBase,
                      dense: true)
                else
                  Text(
                    '${formatFactor(uom.conversionFactor)} ${base?.name ?? ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppFonts.mono,
                        color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Define or correct one pack size. Correcting it re-derives every barcode that
/// names the unit (0059), which is why this is an upsert and not an insert.
class _UomSheet extends ConsumerStatefulWidget {
  const _UomSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_UomSheet> createState() => _UomSheetState();
}

class _UomSheetState extends ConsumerState<_UomSheet> {
  final _factor = TextEditingController();
  String? _code;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _factor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final factor = double.tryParse(_factor.text.trim());
    if (_code == null || factor == null || factor <= 0) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(productRepositoryProvider).setUom(
          productId: widget.product.id,
          uomCode: _code!,
          conversionFactor: factor,
        );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _busy = false;
        // The base unit is 1 by definition, and a fractional factor on a unit a
        // barcode uses is refused because the ledger is integer (0059).
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vocabulary = ref.watch(uomVocabularyProvider);

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
            Text(l10n.productUnitAdd, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            vocabulary.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e',
                  style: TextStyle(color: theme.colorScheme.error)),
              data: (uoms) => DropdownButtonFormField<String>(
                initialValue: _code,
                decoration: InputDecoration(labelText: l10n.productUnitsSection),
                items: [
                  for (final u in uoms)
                    DropdownMenuItem(
                        value: u.code, child: Text('${u.code} — ${u.name}')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _code = v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _factor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.productUnitFactor,
                helperText: widget.product.baseUom?.name,
              ),
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
                    : Text(l10n.productSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lots, soonest expiry first, with how long each has left. Read-only here: a
/// lot is created by receiving the goods, not by editing a master record (0060).
class _LotsCard extends ConsumerWidget {
  const _LotsCard({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(productLotsProvider(productId));
    final df = DateFormat('yyyy-MM-dd');

    return _Section(
      title: l10n.productLotsSection,
      children: [
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.error)),
          data: (lots) {
            if (lots.isEmpty) {
              return Text(l10n.productLotsEmpty,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final lot in lots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lot.lotCode,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontFamily: AppFonts.mono)),
                              Text(
                                [
                                  if (lot.expiryDate != null)
                                    l10n.productLotExpiryOn(
                                        df.format(lot.expiryDate!)),
                                  if (lot.supplierName != null)
                                    lot.supplierName!,
                                  if (lot.serialCount > 0)
                                    l10n.productLotSerialCount(lot.serialCount),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (lot.isExpired)
                          StatusPill(
                              tone: StatusTone.danger,
                              label: l10n.productLotExpired,
                              dense: true)
                        else if (lot.daysToExpiry != null)
                          StatusPill(
                            tone: lot.expiresWithin(30)
                                ? StatusTone.warning
                                : StatusTone.neutral,
                            label: l10n.productLotDaysLeft(lot.daysToExpiry!),
                            dense: true,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Serial numbers with a status filter. IN_STOCK/SHIPPED follow the normal
/// receiving/shipping flow on their own; RETURNED, SCRAPPED and HOLD do not —
/// those are the exception path `set_serial_status` (0060) exists for, and
/// the edit action below is the only way to reach it.
class _SerialsCard extends ConsumerWidget {
  const _SerialsCard({required this.productId});

  final int productId;

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, ProductSerial serial) async {
    final l10n = AppLocalizations.of(context);
    final draft = await showDialog<_SerialStatusDraft>(
      context: context,
      builder: (_) => _SerialStatusDialog(serial: serial),
    );
    if (draft == null) return;

    final result = await ref.read(productRepositoryProvider).setSerialStatus(
          serialId: serial.id,
          status: draft.status,
          note: draft.note,
        );
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(productSerialsProvider(productId)),
      failure: (f) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(humanizeApiErrorMessage(l10n, f.message)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filter = ref.watch(serialStatusFilterProvider);
    final async = ref.watch(productSerialsProvider(productId));

    return _Section(
      title: l10n.productSerialsSection,
      trailing: DropdownButton<String?>(
        value: filter,
        underline: const SizedBox.shrink(),
        isDense: true,
        items: [
          DropdownMenuItem<String?>(
              value: null, child: Text(l10n.productSerialFilterAll)),
          for (final status in const [
            'IN_STOCK',
            'SHIPPED',
            'RETURNED',
            'SCRAPPED',
            'HOLD'
          ])
            DropdownMenuItem<String?>(
                value: status, child: Text(serialStatusLabel(l10n, status))),
        ],
        onChanged: (v) =>
            ref.read(serialStatusFilterProvider.notifier).state = v,
      ),
      children: [
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          data: (serials) {
            if (serials.isEmpty) {
              return Text(l10n.productSerialsEmpty,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final serial in serials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(serial.serialNumber,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontFamily: AppFonts.mono)),
                              if (serial.lotCode != null)
                                Text(
                                    l10n.stockPositionLot(serial.lotCode!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        StatusPill(
                          tone: serial.isInStock
                              ? StatusTone.success
                              : StatusTone.neutral,
                          label: serialStatusLabel(l10n, serial.status),
                          dense: true,
                        ),
                        IconButton(
                          tooltip: l10n.productSerialChangeStatus,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _changeStatus(context, ref, serial),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SerialStatusDraft {
  const _SerialStatusDraft(this.status, this.note);
  final String status;
  final String? note;
}

/// Edit dialog for `set_serial_status` (0060). A real `StatefulWidget` owning
/// its own controller — the same shape `_RenameDialog` (shipment) uses, for
/// the same reason: a controller the caller disposes right after `showDialog`
/// returns can still be referenced by the pop transition.
class _SerialStatusDialog extends StatefulWidget {
  const _SerialStatusDialog({required this.serial});

  final ProductSerial serial;

  @override
  State<_SerialStatusDialog> createState() => _SerialStatusDialogState();
}

class _SerialStatusDialogState extends State<_SerialStatusDialog> {
  late String _status = widget.serial.status;
  late final TextEditingController _note =
      TextEditingController(text: widget.serial.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.serial.serialNumber),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: l10n.productSerialStatus),
            items: [
              for (final status in const [
                'IN_STOCK',
                'SHIPPED',
                'RETURNED',
                'SCRAPPED',
                'HOLD'
              ])
                DropdownMenuItem(
                    value: status, child: Text(serialStatusLabel(l10n, status))),
            ],
            onChanged: (v) => setState(() => _status = v ?? widget.serial.status),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.productSerialNote),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _SerialStatusDraft(
                _status, _note.text.trim().isEmpty ? null : _note.text.trim()),
          ),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

/// §22: how *this* warehouse handles the product. Absent by default, because
/// most products need no special handling and a screenful of nulls would say
/// less than one line admitting there is nothing set.
class _WarehouseSettingsCard extends ConsumerWidget {
  const _WarehouseSettingsCard(
      {required this.product, required this.onMessage});

  final Product product;
  final _Notify onMessage;

  Future<void> _clear(BuildContext context, WidgetRef ref, int warehouseId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.whpClearQ),
        content: Text(l10n.whpClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await ref.read(productRepositoryProvider)
        .clearWarehouseProduct(warehouseId: warehouseId, productId: product.id);
    if (!context.mounted) return;
    result.when(
      success: (_) => ref.invalidate(warehouseProductProvider(product.id)),
      failure: (f) => onMessage(
          context, humanizeApiErrorMessage(l10n, f.message), error: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warehouseId = ref.watch(activeWarehouseIdProvider);

    if (warehouseId == null) {
      return _Section(
        title: l10n.whpSection,
        children: [
          Text(l10n.whpNoWarehouse,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      );
    }

    final async = ref.watch(warehouseProductProvider(product.id));
    return _Section(
      title: l10n.whpSection,
      action: TextButton.icon(
        icon: const Icon(Icons.tune_outlined, size: 18),
        label: Text(l10n.whpEdit),
        onPressed: () async {
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _WarehouseProductSheet(
              productId: product.id,
              warehouseId: warehouseId,
              current: async.valueOrNull,
            ),
          );
          if (saved == true) {
            ref.invalidate(warehouseProductProvider(product.id));
          }
        },
      ),
      trailing: async.valueOrNull == null
          ? null
          : IconButton(
              tooltip: l10n.whpClear,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _clear(context, ref, warehouseId),
            ),
      children: [
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          data: (settings) {
            if (settings == null) {
              return Text(l10n.whpNone,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant));
            }
            final nf = NumberFormat.decimalPattern();
            Widget row(String label, String value) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                      Text(value, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.defaultLocationCode != null)
                  row(l10n.whpDefaultLocation, settings.defaultLocationCode!),
                if (settings.minStock != null)
                  row(l10n.whpMinStock, nf.format(settings.minStock)),
                if (settings.reorderPoint != null)
                  row(l10n.whpReorderPoint, nf.format(settings.reorderPoint)),
                if (settings.maxStock != null)
                  row(l10n.whpMaxStock, nf.format(settings.maxStock)),
                row(l10n.whpPickPriority, '${settings.pickPriority}'),
                row(l10n.whpPutawayRule,
                    putawayRuleLabel(l10n, settings.putawayRule)),
                if (settings.preferredSupplierName != null)
                  row(l10n.whpSupplier, settings.preferredSupplierName!),
                if (settings.leadTimeDays != null)
                  row(l10n.whpLeadTime, '${settings.leadTimeDays}'),
                // Live numbers beside the policy, because a reorder point only
                // means something next to what is actually on the shelf.
                row(l10n.stockOnHandUnit, nf.format(settings.onHand)),
                row(l10n.stockAvailable, nf.format(settings.available)),
                if (settings.needsReorder) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.trending_down,
                          size: 16, color: scheme.tertiary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(l10n.whpNeedsReorder,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.tertiary)),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The per-warehouse settings form. Every field is optional and an untouched one
/// is sent as null, which the RPC reads as "leave it alone" — so this sheet can
/// be used to change one number without knowing the rest.
class _WarehouseProductSheet extends ConsumerStatefulWidget {
  const _WarehouseProductSheet({
    required this.productId,
    required this.warehouseId,
    this.current,
  });

  final int productId;
  final int warehouseId;
  final WarehouseProduct? current;

  @override
  ConsumerState<_WarehouseProductSheet> createState() =>
      _WarehouseProductSheetState();
}

class _WarehouseProductSheetState
    extends ConsumerState<_WarehouseProductSheet> {
  late final TextEditingController _location =
      TextEditingController(text: widget.current?.defaultLocationCode ?? '');
  late final TextEditingController _min = TextEditingController(
      text: widget.current?.minStock?.toString() ?? '');
  late final TextEditingController _reorder = TextEditingController(
      text: widget.current?.reorderPoint?.toString() ?? '');
  late final TextEditingController _max = TextEditingController(
      text: widget.current?.maxStock?.toString() ?? '');
  late final TextEditingController _priority = TextEditingController(
      text: (widget.current?.pickPriority ?? 100).toString());
  late final TextEditingController _leadTime = TextEditingController(
      text: widget.current?.leadTimeDays?.toString() ?? '');
  late String _rule = widget.current?.putawayRule ?? 'MANUAL';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _location.dispose();
    _min.dispose();
    _reorder.dispose();
    _max.dispose();
    _priority.dispose();
    _leadTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(productRepositoryProvider).setWarehouseProduct(
              warehouseId: widget.warehouseId,
              productId: widget.productId,
              // Sent even when empty: '' clears the location, which is the one
              // field that needs a way to say "no default any more" (0063).
              defaultLocationCode: _location.text.trim(),
              minStock: int.tryParse(_min.text.trim()),
              reorderPoint: int.tryParse(_reorder.text.trim()),
              maxStock: int.tryParse(_max.text.trim()),
              pickPriority: int.tryParse(_priority.text.trim()),
              putawayRule: _rule,
              leadTimeDays: int.tryParse(_leadTime.text.trim()),
            );
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _busy = false;
        // `max < min`, a reorder point outside the two, or a location that is
        // not in this warehouse are all refused server-side.
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget number(TextEditingController c, String label) => TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        );

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
            Text(l10n.whpSection, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _location,
              decoration: InputDecoration(
                labelText: l10n.whpDefaultLocation,
                helperText: l10n.whpDefaultLocationHint,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            number(_min, l10n.whpMinStock),
            const SizedBox(height: AppSpacing.lg),
            number(_reorder, l10n.whpReorderPoint),
            const SizedBox(height: AppSpacing.lg),
            number(_max, l10n.whpMaxStock),
            const SizedBox(height: AppSpacing.lg),
            number(_priority, l10n.whpPickPriority),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _rule,
              decoration: InputDecoration(labelText: l10n.whpPutawayRule),
              items: [
                for (final rule in const [
                  'MANUAL',
                  'FIXED',
                  'CONSOLIDATE',
                  'NEAREST_EMPTY'
                ])
                  DropdownMenuItem(
                      value: rule, child: Text(putawayRuleLabel(l10n, rule))),
              ],
              onChanged:
                  _busy ? null : (v) => setState(() => _rule = v ?? 'MANUAL'),
            ),
            const SizedBox(height: AppSpacing.lg),
            number(_leadTime, l10n.whpLeadTime),
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
                    : Text(l10n.productSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
