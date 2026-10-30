import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock_import/domain/stock_ledger.dart' show keepYears;
import '../../stock_import/presentation/import_view_screen.dart' show openReadingTable;
import '../data/tax_files_repository.dart';
import '../data/tax_workbook.dart';
import '../domain/tax_purchases.dart';

/// Saves the workbook (tests stand in for the browser's download).
final taxFileSaverProvider = Provider<Future<void> Function(String name, Uint8List bytes)>(
    (ref) => (name, bytes) async => saveBytes(name, bytes));

/// 税理士用ファイル (0168): each month's purchases, as they stand now — the
/// invoices taken into stock, with 税抜・消費税・税込 by rate and the
/// supplier's 登録番号 — as an Excel for the accountant, and with every
/// invoice's original in one ZIP. Made from the records each time, so a
/// month is always up to date: a file taken in, corrected or taken back
/// changes it. Kept 7 years from the document's date.
class TaxFilesScreen extends ConsumerStatefulWidget {
  const TaxFilesScreen({super.key, this.initialYear});

  final int? initialYear;

  @override
  ConsumerState<TaxFilesScreen> createState() => _TaxFilesScreenState();
}

class _TaxFilesScreenState extends ConsumerState<TaxFilesScreen> {
  late int _year = widget.initialYear ?? DateTime.now().year;
  DateTime? _busyMonth;

  String _base(TaxMonth m) => '${m.month.year}-${m.month.month.toString().padLeft(2, '0')}_仕入一覧';

  Future<void> _excel(TaxMonth m) async {
    final user = ref.read(authControllerProvider).user;
    final bytes = buildTaxWorkbook(m, madeBy: user?.name ?? user?.email);
    await ref.read(taxFileSaverProvider)('${_base(m)}.xlsx', bytes);
  }

  Future<void> _zip(TaxMonth m) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyMonth = m.month);
    final repo = ref.read(taxFilesRepositoryProvider);
    final originals = <int, Uint8List>{};
    for (final p in m.purchases) {
      final r = await repo.original(p);
      if (r case ApiSuccess(:final data)) originals[p.importId] = data;
    }
    if (!mounted) return;
    final user = ref.read(authControllerProvider).user;
    final zip = buildTaxZip(m, buildTaxWorkbook(m, madeBy: user?.name ?? user?.email), originals);
    await ref.read(taxFileSaverProvider)('${_base(m)}_証拠.zip', zip);
    if (!mounted) return;
    setState(() => _busyMonth = null);
    final missing = m.purchases.length - originals.length;
    messenger.showSnackBar(SnackBar(
        content: Text(missing == 0 ? l10n.txZipDone(originals.length) : l10n.txZipMissing(originals.length, missing))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final now = DateTime.now().year;
    final may = ref.watch(canViewPurchaseBooksProvider);
    final async = may ? ref.watch(taxMonthsProvider(_year)) : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.featTaxFiles)),
      body: !may
          ? Center(child: Text(l10n.txNoPermission, key: const ValueKey('tx-no-permission')))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.txIntro(keepYears), style: muted),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.xs, children: [
                  for (var y = now; y >= now - keepYears; y--)
                    ChoiceChip(
                      key: ValueKey('tx-year-$y'),
                      label: Text(l10n.txYear(y)),
                      selected: _year == y,
                      onSelected: (_) => setState(() => _year = y),
                    ),
                ]),
                const SizedBox(height: AppSpacing.md),
                ...async!.when(
                  loading: () => const [LoadingView()],
                  error: (e, _) => [
                    ErrorStateView(
                        message: humanizeApiErrorMessage(l10n, '$e'), onRetry: () => ref.invalidate(taxMonthsProvider(_year))),
                  ],
                  data: (months) => months.isEmpty
                      ? [Text(l10n.txNone(_year), key: const ValueKey('tx-none'))]
                      : [
                          for (final m in months)
                            _MonthCard(
                              month: m,
                              busy: _busyMonth == m.month,
                              onExcel: () => _excel(m),
                              onZip: () => _zip(m),
                            ),
                        ],
                ),
              ],
            ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.busy, required this.onExcel, required this.onZip});

  final TaxMonth month;
  final bool busy;
  final VoidCallback onExcel;
  final VoidCallback onZip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final yen = NumberFormat.decimalPattern();
    final m = month;
    final key = '${m.month.year}-${m.month.month}';
    return Card(
      key: ValueKey('tx-month-$key'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l10n.txMonth(m.month.year, m.month.month), style: theme.textTheme.titleMedium)),
            if (m.doubtful > 0)
              Chip(
                key: ValueKey('tx-doubt-$key'),
                label: Text(l10n.txDoubtful(m.doubtful)),
                backgroundColor: theme.colorScheme.errorContainer,
                visualDensity: VisualDensity.compact,
              ),
          ]),
          Text(
            l10n.txTotals(m.purchases.length, yen.format(m.net.round()), yen.format(m.tax.round()), yen.format(m.gross.round())),
            key: ValueKey('tx-totals-$key'),
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              if (m.updatedAt case final u?) l10n.txUpdated(DateFormat('y/MM/dd HH:mm').format(u)),
              l10n.txKeptTill(DateFormat('y/MM/dd').format(m.keptTill)),
            ].join(' · '),
            style: muted,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Each invoice, to look at before it goes (and open as read).
          for (final p in m.purchases)
            _InvoiceRow(purchase: p),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
            FilledButton.icon(
              key: ValueKey('tx-excel-$key'),
              onPressed: busy ? null : onExcel,
              icon: const Icon(Icons.table_view_outlined, size: 18),
              label: Text(l10n.txExcel),
            ),
            OutlinedButton.icon(
              key: ValueKey('tx-zip-$key'),
              onPressed: busy ? null : onZip,
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_zip_outlined, size: 18),
              label: Text(l10n.txZip),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _InvoiceRow extends ConsumerWidget {
  const _InvoiceRow({required this.purchase});

  final TaxPurchase purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final yen = NumberFormat.decimalPattern();
    final p = purchase;
    final doubts = p.doubts;
    return InkWell(
      key: ValueKey('tx-invoice-${p.importId}'),
      onTap: () => openReadingTable(context, ref, p.importId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(doubts.isEmpty ? Icons.description_outlined : Icons.warning_amber_rounded,
              size: 18, color: doubts.isEmpty ? null : theme.colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('MM/dd').format(p.day)}  ${p.supplierName ?? l10n.txNoSupplier}',
                  style: theme.textTheme.bodyMedium),
              Text(
                [
                  l10n.txInvoiceFigures(yen.format(p.net.round()), yen.format(p.tax.round()), yen.format(p.gross.round())),
                  p.registrationNumber ?? l10n.txNoRegistration,
                  p.paid ? l10n.calPaid : l10n.calUnpaid,
                  for (final d in doubts) _doubtText(l10n, d),
                ].join(' · '),
                key: ValueKey('tx-invoice-figures-${p.importId}'),
                style: theme.textTheme.bodySmall?.copyWith(color: doubts.isEmpty ? null : theme.colorScheme.error),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _doubtText(AppLocalizations l10n, String code) => switch (code) {
        'no_registration' => l10n.txDoubtRegistration,
        'totals' => l10n.txDoubtTotals,
        'no_amounts' => l10n.txDoubtAmounts,
        'no_date' => l10n.txDoubtDate,
        'duplicate' => l10n.txDoubtDuplicate(purchase.sameAs ?? 0),
        _ => code,
      };
}
