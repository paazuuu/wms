import '../../../l10n/app_localizations.dart';
import '../domain/notation.dart';

/// What a column holds, in words: the name chosen in the field library
/// (0112) when there is one ([custom], field key → name), else ours.
String columnFieldLabel(AppLocalizations l10n, ColumnField? f, [Map<String, String> custom = const {}]) =>
    (f == null ? null : custom[f.wire]) ?? _builtInFieldLabel(l10n, f);

String _builtInFieldLabel(AppLocalizations l10n, ColumnField? f) => switch (f) {
      ColumnField.jan => l10n.ntFieldJan,
      ColumnField.maker => l10n.ntFieldMaker,
      ColumnField.productName => l10n.ntFieldName,
      ColumnField.productCode => l10n.ntFieldCode,
      ColumnField.nameCode => l10n.ntFieldNameCode,
      ColumnField.quantity => l10n.ntFieldQuantity,
      ColumnField.caseQuantity => l10n.ntFieldCaseQuantity,
      ColumnField.cases => l10n.ntFieldCases,
      ColumnField.unitPrice => l10n.ntFieldUnitPrice,
      ColumnField.listPrice => l10n.ntFieldListPrice,
      ColumnField.discountRate => l10n.ntFieldDiscountRate,
      ColumnField.amount => l10n.ntFieldAmount,
      ColumnField.unit => l10n.ntFieldUnit,
      ColumnField.supplierCode => l10n.ntFieldSupplierCode,
      ColumnField.upstreamCode => l10n.ntFieldUpstreamCode,
      ColumnField.customerCode => l10n.ntFieldCustomerCode,
      ColumnField.spec => l10n.ntFieldSpec,
      ColumnField.taxRate => l10n.ntFieldTaxRate,
      ColumnField.orderDate => l10n.ntFieldDate,
      ColumnField.ignore => l10n.ntFieldIgnore,
      ColumnField.attr => l10n.ntFieldAttr,
      null => l10n.ntFieldUnknown,
    };

/// How a column's meaning was decided.
String columnSourceLabel(AppLocalizations l10n, String? s) => switch (s) {
      'partner' => l10n.ntSourcePartner,
      'global' => l10n.ntSourceGlobal,
      'contains' => l10n.ntSourceContains,
      'values' => l10n.ntSourceValues,
      'ai' => l10n.ntSourceAi,
      'override' => l10n.ntSourceOverride,
      _ => l10n.ntSourceNone,
    };

/// The dictionary's four fields, by the library's names when chosen.
String dialectFieldLabel(AppLocalizations l10n, String field, [Map<String, String> custom = const {}]) =>
    switch (field) {
      'jan' => custom['jan'] ?? l10n.ntFieldJan,
      'maker' => custom['maker'] ?? l10n.ntFieldMaker,
      'name' => custom['product_name'] ?? l10n.ntFieldName,
      'code' => custom['product_code'] ?? l10n.ntFieldCode,
      _ => field,
    };

/// A problem a reading flagged, in words.
String flagLabel(AppLocalizations l10n, String flag) {
  final parts = flag.split(':');
  return switch (parts.first) {
    'unresolved' => l10n.ntFlagUnresolved,
    'jan_check' => l10n.ntFlagJanCheck,
    'jan_exponent' => l10n.ntFlagJanExponent,
    'no_jan' => l10n.ntFlagNoJan,
    'no_maker' => l10n.ntFlagNoMaker,
    'no_quantity' => l10n.ntFlagNoQuantity,
    'amount_mismatch' => l10n.ntFlagAmount,
    'ai_disagree' => parts.length > 1
        ? l10n.ntFlagAiDisagreeOn(_comparedLabel(l10n, parts[1]))
        : l10n.ntFlagAiDisagree,
    'split_disagree' => l10n.ntFlagSplitDisagree,
    'split_single' => l10n.ntFlagSplitSingle,
    'split_failed' => l10n.ntFlagSplitFailed,
    'added_by_check' => l10n.ntFlagAdded,
    'dropped_by_check' => l10n.ntFlagDropped,
    'not_verified' => l10n.ntFlagNotVerified,
    'qty_from_cases' => l10n.ntFlagQtyFromCases,
    _ => flag,
  };
}

String _comparedLabel(AppLocalizations l10n, String key) => switch (key) {
      'raw_jan_code' => l10n.ntFieldJan,
      'maker' => l10n.ntFieldMaker,
      'product_name' => l10n.ntFieldName,
      'product_code' => l10n.ntFieldCode,
      'planned_quantity' => l10n.ntFieldQuantity,
      'unit_price' => l10n.ntFieldUnitPrice,
      'list_price' => l10n.ntFieldListPrice,
      'unit' => l10n.ntFieldUnit,
      'amount' => l10n.ntFieldAmount,
      _ => key,
    };

String alternativeLabel(AppLocalizations l10n, String key) => _comparedLabel(l10n, key);

/// How a line was matched to our product.
String matchedByLabel(AppLocalizations l10n, String? m) => switch (m) {
      'jan' => l10n.ntMatchJan,
      'dialect_jan' || 'dialect_code' || 'dialect_name' => l10n.ntMatchDialect,
      'sku' => l10n.ntMatchSku,
      'name' => l10n.ntMatchName,
      'manual' => l10n.ntMatchManual,
      'registered' => l10n.ntMatchRegistered,
      _ => l10n.ntMatchNone,
    };
