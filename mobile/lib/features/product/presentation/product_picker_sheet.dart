import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';

/// Picks one of our products — to tie a trading company's way of writing a
/// line to it (0105). Opens on a search for [initialQuery] (how the company
/// wrote it) and pops the chosen [Product].
class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({super.key, this.initialQuery = '', this.title, this.subtitle});

  final String initialQuery;
  final String? title;

  /// Shown faded under the title: the company's writing being matched.
  final String? subtitle;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  late final _search = TextEditingController(text: widget.initialQuery);
  bool _loading = false;
  String? _error;
  List<Product> _hits = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ref.read(productRepositoryProvider).list(search: q.isEmpty ? null : q);
    if (!mounted) return;
    setState(() {
      _loading = false;
      r.when(success: (rows) => _hits = rows, failure: (f) => _error = f.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title ?? l10n.productPickerTitle, style: theme.textTheme.titleMedium),
              if (widget.subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(widget.subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('product-picker-search'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.qcConvertSearch,
                ),
                onSubmitted: (_) => _find(),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(humanizeApiErrorMessage(l10n, _error!), style: TextStyle(color: scheme.error)),
              Expanded(
                child: _hits.isEmpty && !_loading
                    ? Center(child: Text(l10n.qcConvertNone))
                    : ListView(
                        children: [
                          for (final p in _hits)
                            ListTile(
                              key: ValueKey('product-picker-${p.id}'),
                              title: Text(p.name),
                              subtitle: Text([
                                p.janCode,
                                if (p.sku != null) l10n.qcOwnSku(p.sku!),
                                if (p.maker != null) p.maker!,
                              ].join(' · ')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(context, p),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
