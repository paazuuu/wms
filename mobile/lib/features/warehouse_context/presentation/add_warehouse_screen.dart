import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

/// Add-warehouse wizard (spec §4.2, §49): the minimum a warehouse needs, plus an
/// opt-out toggle for seeding the starter bins so the staged flows have
/// somewhere to land. Creating a warehouse is the entry point of the whole
/// chain (context → zones/bins → users → inventory → operations).
class AddWarehouseScreen extends ConsumerStatefulWidget {
  const AddWarehouseScreen({super.key});

  @override
  ConsumerState<AddWarehouseScreen> createState() => _AddWarehouseScreenState();
}

class _AddWarehouseScreenState extends ConsumerState<AddWarehouseScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _receivingBin = TextEditingController(text: 'STAGE-01');
  final _shippingBin = TextEditingController(text: 'SHIP-01');

  String _timezone = 'Asia/Tokyo';
  bool _isActive = true;
  // Locations are opt-in (spec §7): a warehouse keeps a single balance unless
  // the operator says it is managed by shelf. Bins only matter once it is on.
  bool _usesLocations = false;
  bool _defaultBins = false;
  bool _saving = false;

  static const _timezones = <String>[
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Seoul',
    'Asia/Singapore',
    'UTC',
  ];

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _receivingBin.dispose();
    _shippingBin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final result = await ref.read(warehouseRepositoryProvider).create(
          NewWarehouse(
            code: _code.text.trim().toUpperCase(),
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            timezone: _timezone,
            isActive: _isActive,
            usesLocations: _usesLocations,
            createDefaultBins: _usesLocations && _defaultBins,
            receivingBin:
                _usesLocations && _defaultBins ? _receivingBin.text.trim() : null,
            shippingBin:
                _usesLocations && _defaultBins ? _shippingBin.text.trim() : null,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (warehouse) {
        // Refresh the picker and make the new warehouse the active context.
        ref.invalidate(warehouseOverviewProvider);
        ref.read(activeWarehouseIdProvider.notifier).state = warehouse.id;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(l10n.whCreated(warehouse.name))));
        Navigator.of(context).pop(warehouse);
      },
      failure: (f) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(f.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.whAddTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.whFieldName,
                prefixIcon: const Icon(Icons.warehouse_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.whNameRequired : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                labelText: l10n.whFieldCode,
                prefixIcon: const Icon(Icons.tag),
                helperText: 'MAIN, KOBE, OSAKA…',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.whCodeRequired : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _address,
              decoration: InputDecoration(
                labelText: l10n.whFieldAddress,
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.whFieldPhone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              decoration: InputDecoration(
                labelText: l10n.whFieldTimezone,
                prefixIcon: const Icon(Icons.schedule_outlined),
              ),
              items: [
                for (final tz in _timezones)
                  DropdownMenuItem(value: tz, child: Text(tz)),
              ],
              onChanged: (v) => setState(() => _timezone = v ?? 'Asia/Tokyo'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text(l10n.whFieldActive),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            SwitchListTile(
              value: _usesLocations,
              onChanged: (v) => setState(() {
                _usesLocations = v;
                if (!v) _defaultBins = false;
              }),
              title: Text(l10n.whFieldUsesLocations),
              subtitle: Text(l10n.whFieldUsesLocationsHelp),
              contentPadding: EdgeInsets.zero,
            ),
            if (_usesLocations)
              SwitchListTile(
                value: _defaultBins,
                onChanged: (v) => setState(() => _defaultBins = v),
                title: Text(l10n.whFieldDefaultBins),
                subtitle: Text(l10n.whFieldDefaultBinsHelp),
                contentPadding: EdgeInsets.zero,
              ),
            if (_usesLocations && _defaultBins) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _receivingBin,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.whFieldReceivingBin,
                  prefixIcon: const Icon(Icons.move_to_inbox_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _shippingBin,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.whFieldShippingBin,
                  prefixIcon: const Icon(Icons.outbox_outlined),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: AppSpacing.minTouch,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_saving ? l10n.working : l10n.whAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
