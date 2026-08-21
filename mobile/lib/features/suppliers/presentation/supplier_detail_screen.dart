import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/supplier_providers.dart';
import '../domain/supplier.dart';
import 'supplier_status_ui.dart';

/// Read-only supplier detail: identity, contact channels, and commercial terms.
class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final int supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplier = ref.watch(supplierDetailProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Supplier')),
      body: supplier.when(
        data: (s) => _SupplierBody(supplier: s),
        loading: () => const LoadingView(message: 'Loading supplier…'),
        error: (error, _) => ErrorStateView(
          message: '$error',
          onRetry: () => ref.invalidate(supplierDetailProvider(supplierId)),
        ),
      ),
    );
  }
}

class _SupplierBody extends StatelessWidget {
  const _SupplierBody({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = SupplierStatusUi.of(AppLocalizations.of(context), supplier);
    final count = supplier.productsCount;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusAvatar(tone: status.tone, icon: status.icon),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            supplier.displayCode,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFamily: 'FiraCode',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusPill(
                      tone: status.tone,
                      label: status.label,
                      icon: status.icon,
                    ),
                    if (count != null)
                      StatusPill(
                        tone: StatusTone.info,
                        label: '$count ${count == 1 ? 'product' : 'products'}',
                        icon: Icons.inventory_2_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Contact',
                  value: supplier.contactName ?? '—',
                ),
                _InfoRow(label: 'Email', value: supplier.email ?? '—'),
                _InfoRow(label: 'Phone', value: supplier.phone ?? '—'),
                _InfoRow(label: 'Website', value: supplier.website ?? '—'),
                _InfoRow(label: 'Address', value: supplier.fullAddress ?? '—'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Payment terms',
                  value: supplier.paymentTerms ?? '—',
                ),
                _InfoRow(label: 'Currency', value: supplier.currency ?? '—'),
                _InfoRow(
                  label: 'Products',
                  value: count != null ? '$count' : '—',
                ),
                _InfoRow(
                  label: 'Status',
                  value: supplier.isActive ? 'Active' : 'Inactive',
                ),
              ],
            ),
          ),
        ),
        if (supplier.notes != null && supplier.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(supplier.notes!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
