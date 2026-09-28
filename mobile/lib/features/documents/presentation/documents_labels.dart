import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/documents.dart';

/// Registering and settling invoices needs purchase_order.manage/approve.
final documentsCanManageProvider = Provider<bool>((ref) {
  final p = ref.watch(authControllerProvider).user?.permissions ?? const <String>[];
  return p.contains('purchase_order.manage') || p.contains('purchase_order.approve');
});

String docFlagLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'not_ordered' => l10n.docFlagNotOrdered,
      'not_invoiced' => l10n.docFlagNotInvoiced,
      'invoice_qty' => l10n.docFlagInvoiceQty,
      'invoice_price' => l10n.docFlagInvoicePrice,
      'short_delivery' => l10n.docFlagShortDelivery,
      'inspect_short' => l10n.docFlagInspectShort,
      'defective' => l10n.docFlagDefective,
      _ => kind,
    };

StatusTone docFlagTone(String kind) => switch (kind) {
      'defective' || 'short_delivery' || 'invoice_price' => StatusTone.danger,
      _ => StatusTone.warning,
    };

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus s) => switch (s) {
      InvoiceStatus.open => l10n.docInvoiceOpen,
      InvoiceStatus.matched => l10n.docInvoiceMatched,
      InvoiceStatus.mismatch => l10n.docInvoiceMismatch,
      InvoiceStatus.approved => l10n.docInvoiceApproved,
      InvoiceStatus.voided => l10n.docInvoiceVoid,
    };

StatusTone invoiceStatusTone(InvoiceStatus s) => switch (s) {
      InvoiceStatus.matched || InvoiceStatus.approved => StatusTone.success,
      InvoiceStatus.mismatch => StatusTone.danger,
      InvoiceStatus.voided => StatusTone.neutral,
      InvoiceStatus.open => StatusTone.info,
    };

String matchStatusLabel(AppLocalizations l10n, MatchStatus s) => switch (s) {
      MatchStatus.match => l10n.docMatchOk,
      MatchStatus.mismatch => l10n.docMatchMismatch,
      MatchStatus.pending => l10n.docMatchPending,
    };

StatusTone matchStatusTone(MatchStatus s) => switch (s) {
      MatchStatus.match => StatusTone.success,
      MatchStatus.mismatch => StatusTone.danger,
      MatchStatus.pending => StatusTone.info,
    };

String docNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class DocFlagChips extends StatelessWidget {
  const DocFlagChips({super.key, required this.flags});

  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (final f in flags) StatusPill(tone: docFlagTone(f), label: docFlagLabel(l10n, f), dense: true),
    ]);
  }
}
