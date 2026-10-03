import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../product_library/application/product_library_providers.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';

/// Deletes [product] after asking (0119), and says so. A product that stock,
/// an order or a document has named cannot be deleted: the person is offered
/// to deactivate it instead, which keeps its history readable.
///
/// Resolves to true when the product is gone.
Future<bool> confirmDeleteProduct(BuildContext context, WidgetRef ref, Product product) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.productDeleteQ),
      content: Text(l10n.productDeleteBody(product.name, product.janCode)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.actionCancel)),
        FilledButton(
          key: const ValueKey('product-delete-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.productDeleteAction),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final r = await ref.read(productRepositoryProvider).delete(product.id);
  if (!context.mounted) return false;
  switch (r) {
    case ApiSuccess():
      ref.invalidate(productListProvider);
      ref.invalidate(productLibraryProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.productDeleted(product.name))));
      return true;
    case ApiFailure(:final message) when message.contains('product is in use'):
      if (!product.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.productDeleteInUse)));
        return false;
      }
      final deactivate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.productDeleteInUseTitle),
          content: Text(l10n.productDeleteInUse),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.actionCancel)),
            FilledButton(
              key: const ValueKey('product-delete-deactivate'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.productDeactivateAction),
            ),
          ],
        ),
      );
      if (deactivate == true && context.mounted) {
        final s = await ref.read(productRepositoryProvider).setStatus(product.id, 'inactive');
        if (s case ApiSuccess()) ref.invalidate(productListProvider);
      }
      return false;
    case ApiFailure(:final message):
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message.contains('delete_product') ? l10n.productDeleteNotReady : humanizeApiErrorMessage(l10n, message)),
      ));
      return false;
  }
}
