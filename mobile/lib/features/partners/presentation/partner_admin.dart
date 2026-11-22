import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../admin/data/card_erase_repository.dart';
import '../../admin/data/menu_visibility_repository.dart' show isSystemAdminProvider;

/// 取引先・価格台帳の仕入先カード: made, changed, switched on and off and
/// erased by the system administrator only (0228).
final canManagePartnersProvider = Provider<bool>((ref) => ref.watch(isSystemAdminProvider));

/// A table a partner is named in, in words.
String partnerTableLabel(AppLocalizations l10n, String table) => switch (table) {
      'delivery_plans' => l10n.caTDeliveryPlans,
      'delivery_reconciliations' => l10n.caTDeliveryReconciliations,
      'shipment_plans' => l10n.caTShipmentPlans,
      'purchase_orders' => l10n.caTPurchaseOrders,
      'sales_orders' => l10n.caTSalesOrders,
      'lots' => l10n.caTLots,
      'supplier_invoices' => l10n.caTSupplierInvoices,
      'master_imports' => l10n.caTMasterImports,
      'import_documents' => l10n.caTImportDocuments,
      'purchase_requests' => l10n.caTPurchaseRequests,
      'ship_destinations' => l10n.caTShipDestinations,
      'outbound_file_lines' => l10n.caTOutboundFileLines,
      'warehouse_products' => l10n.caTWarehouseProducts,
      'supplier_product_names' => l10n.caTSupplierProductNames,
      'price_book_terms' => l10n.caTPriceBookTerms,
      'purchase_price_entries' => l10n.caTPurchasePriceEntries,
      'column_aliases' => l10n.caTColumnAliases,
      'notation_dialects' => l10n.caTNotationDialects,
      'partner_vendor_codes' => l10n.caTPartnerVendorCodes,
      _ => table,
    };

String _counts(AppLocalizations l10n, Map<String, int> m) =>
    [for (final e in m.entries) l10n.caCount(partnerTableLabel(l10n, e.key), e.value)].join('、');

/// 完全に削除: what it would do, asked first; then erased for good. True
/// when it went.
Future<bool> erasePartnerFlow(BuildContext context, WidgetRef ref, int id) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(cardEraseRepositoryProvider);
  final checked = await repo.partnerCheck(id);
  if (!context.mounted) return false;
  final PartnerEraseCheck c;
  switch (checked) {
    case ApiSuccess(:final data):
      c = data;
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
      return false;
  }
  if (!c.canErase) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('pa-cannot-erase'),
        title: Text(l10n.caEraseTitle(c.name)),
        content: Text(c.placeholder ? l10n.caPlaceholder : l10n.caInUse(_counts(l10n, c.blockers))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
        ],
      ),
    );
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        key: const ValueKey('pa-erase-dialog'),
        title: Text(l10n.caEraseTitle(c.name)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.caEraseConfirm, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          if (c.detached.isNotEmpty) ...[const SizedBox(height: 8), Text(l10n.caEraseDetached(_counts(l10n, c.detached)))],
          if (c.erased.isNotEmpty) ...[const SizedBox(height: 8), Text(l10n.caEraseWith(_counts(l10n, c.erased)))],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(
            key: const ValueKey('pa-erase-ok'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.caErase),
          ),
        ],
      );
    },
  );
  if (ok != true) return false;
  final r = await repo.erase('partner', id);
  switch (r) {
    case ApiSuccess(:final data) when data:
      messenger.showSnackBar(SnackBar(content: Text(l10n.caErased(c.name))));
      return true;
    case ApiSuccess():
      return false;
    case ApiFailure(:final message):
      messenger.showSnackBar(SnackBar(content: Text(humanizeApiErrorMessage(l10n, message))));
      return false;
  }
}
