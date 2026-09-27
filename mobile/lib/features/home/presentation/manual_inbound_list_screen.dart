import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/scan/scan_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../warehouse_context/application/warehouse_providers.dart';
import '../application/role_dashboard_providers.dart';

/// Writes an inbound list by hand when the supplier sent none (0102): what is
/// coming, how many, and when, so the inspection has something to check
/// against. Scanning the same JAN again adds to its line.
class ManualInboundListScreen extends ConsumerStatefulWidget {
  const ManualInboundListScreen({super.key});

  @override
  ConsumerState<ManualInboundListScreen> createState() => _ManualInboundListScreenState();
}

class _Line {
  _Line(this.jan, int quantity) : quantity = TextEditingController(text: '$quantity');

  final String jan;
  final TextEditingController quantity;

  int get value => int.tryParse(quantity.text.trim()) ?? 0;
}

class _ManualInboundListScreenState extends ConsumerState<ManualInboundListScreen> {
  final _supplier = TextEditingController();
  final _lines = <_Line>[];
  DateTime? _expectedOn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _supplier.dispose();
    for (final l in _lines) {
      l.quantity.dispose();
    }
    super.dispose();
  }

  void _addJan(String raw) {
    final l10n = AppLocalizations.of(context);
    final jan = raw.replaceAll(RegExp(r'\D'), '');
    if (jan.length != 8 && jan.length != 13) {
      setState(() => _error = l10n.manualListBadJan);
      return;
    }
    setState(() {
      _error = null;
      final i = _lines.indexWhere((l) => l.jan == jan);
      if (i >= 0) {
        final line = _lines[i];
        line.quantity.text = '${line.value + 1}';
      } else {
        _lines.add(_Line(jan, 1));
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Goods ordered today arrive later, so the future is the point.
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedOn ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expectedOn = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.read(activeWarehouseIdProvider);
    if (warehouseId == null) {
      setState(() => _error = l10n.manualListNoWarehouse);
      return;
    }
    final lines = [
      for (final l in _lines)
        if (l.value > 0) (janCode: l.jan, quantity: l.value),
    ];
    if (lines.isEmpty) {
      setState(() => _error = l10n.manualListEmpty);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(roleDashboardRepositoryProvider).createManualInboundList(
          warehouseId: warehouseId,
          lines: lines,
          supplierName: _supplier.text,
          expectedOn: _expectedOn,
        );
    if (!mounted) return;
    r.when(
      success: (number) {
        ref.invalidate(inboundScheduleProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.manualListCreated(number))));
        Navigator.of(context).pop(number);
      },
      failure: (f) => setState(() {
        _busy = false;
        _error = humanizeApiErrorMessage(l10n, f.message);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualListTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          TextField(
            key: const ValueKey('manual-list-supplier'),
            controller: _supplier,
            decoration: InputDecoration(labelText: l10n.manualListSupplier),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            key: const ValueKey('manual-list-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.manualListExpected),
            subtitle: Text(_expectedOn == null
                ? l10n.manualListNoDate
                : DateFormat('yyyy-MM-dd').format(_expectedOn!)),
            trailing: _expectedOn == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _expectedOn = null),
                  ),
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          ScanField(
            key: const ValueKey('manual-list-scan'),
            hintText: l10n.manualListScanHint,
            autofocusOnWide: true,
            onSubmitted: _addJan,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(l10n.manualListEmpty,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          for (final line in _lines)
            Card(
              key: ValueKey('manual-line-${line.jan}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(child: Text(line.jan, style: theme.textTheme.titleSmall)),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: ValueKey('manual-qty-${line.jan}'),
                        controller: line.quantity,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: InputDecoration(labelText: l10n.manualListQuantity),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _lines.remove(line);
                        line.quantity.dispose();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            key: const ValueKey('manual-list-save'),
            onPressed: _busy || _lines.isEmpty ? null : _save,
            icon: const Icon(Icons.playlist_add_check),
            label: Text(l10n.manualListSave),
          ),
        ],
      ),
    );
  }
}
