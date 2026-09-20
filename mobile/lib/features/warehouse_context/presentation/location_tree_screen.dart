import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../application/warehouse_providers.dart';
import '../domain/location.dart';

/// Localized name for a location type (§8, 0062). A type this build does not
/// know shows as its own code rather than as a blank.
String locationTypeLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'STORAGE' => l10n.locTypeStorage,
      'PICKING' => l10n.locTypePicking,
      'RECEIVING' => l10n.locTypeReceiving,
      'QC' => l10n.locTypeQc,
      'PACKING' => l10n.locTypePacking,
      'SHIPPING' => l10n.locTypeShipping,
      'QUARANTINE' => l10n.locTypeQuarantine,
      'DAMAGED' => l10n.locTypeDamaged,
      'RETURN' => l10n.locTypeReturn,
      'TRANSIT' => l10n.locTypeTransit,
      'VIRTUAL' => l10n.locTypeVirtual,
      _ => code,
    };

/// The warehouse as a tree (§7): zone, aisle, rack, shelf, bin — however deep
/// the building actually goes — with what each location is for (§8).
///
/// Per warehouse, because a location belongs to a building. Zones and bins
/// appear here automatically (the database syncs them into the tree), so the add
/// button is for the nodes that have no bin behind them: an aisle, a rack, a
/// virtual RECEIVING area.
class LocationTreeScreen extends ConsumerWidget {
  const LocationTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final warehouseId = ref.watch(activeWarehouseIdProvider);
    final showInactive = ref.watch(showInactiveLocationsProvider);

    if (warehouseId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.locationsTitle)),
        body: EmptyStateView(
          icon: Icons.warehouse_outlined,
          title: l10n.locationsNoWarehouse,
          message: l10n.locationsEmptyBody,
        ),
      );
    }

    final async = ref.watch(locationTreeProvider(warehouseId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locationsTitle),
        actions: [
          IconButton(
            tooltip: l10n.locationShowInactive,
            icon: Icon(showInactive
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => ref
                .read(showInactiveLocationsProvider.notifier)
                .update((v) => !v),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref, warehouseId),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => LoadingView(message: l10n.loading),
        error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(locationTreeProvider(warehouseId)),
        ),
        data: (roots) {
          if (roots.isEmpty) {
            return EmptyStateView(
              icon: Icons.account_tree_outlined,
              title: l10n.locationsEmpty,
              message: l10n.locationsEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(locationTreeProvider(warehouseId)),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final root in roots)
                  _LocationNode(
                    location: root,
                    warehouseId: warehouseId,
                    depth: 0,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    int warehouseId, {
    Location? location,
    String? parentCode,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocationFormSheet(
        warehouseId: warehouseId,
        location: location,
        parentCode: parentCode,
      ),
    );
    if (saved == true) ref.invalidate(locationTreeProvider(warehouseId));
  }
}

/// One node and, expanded, its subtree. An `ExpansionTile` per level rather than
/// a flattened list with indentation, so collapsing a zone collapses the whole
/// zone — which is what someone looking for one aisle in a large warehouse
/// actually wants.
class _LocationNode extends ConsumerWidget {
  const _LocationNode({
    required this.location,
    required this.warehouseId,
    required this.depth,
  });

  final Location location;
  final int warehouseId;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nf = NumberFormat.decimalPattern();

    final subtitle = [
      locationTypeLabel(l10n, location.locationType),
      if (location.name != null) location.name!,
      if (location.onHand != null) l10n.locationOnHand(nf.format(location.onHand)),
    ].join(' · ');

    final title = Row(
      children: [
        Expanded(
          child: Text(location.code,
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: location.isActive ? null : scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (!location.isActive)
          StatusPill(
              tone: StatusTone.neutral,
              label: l10n.locationInactive,
              dense: true),
        if (location.quarantine)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: StatusPill(
                tone: StatusTone.warning,
                label: l10n.locationQuarantine,
                dense: true),
          ),
        if (location.isVirtual)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: StatusPill(
                tone: StatusTone.info,
                label: l10n.locationVirtual,
                dense: true),
          ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.locationAdd,
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => LocationTreeScreen._openForm(
            context,
            ref,
            warehouseId,
            parentCode: location.code,
          ),
        ),
        IconButton(
          tooltip: l10n.productEdit,
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => LocationTreeScreen._openForm(
            context,
            ref,
            warehouseId,
            location: location,
          ),
        ),
      ],
    );

    if (!location.hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: depth * AppSpacing.lg),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            location.isBin ? Icons.inventory_2_outlined : Icons.place_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          title: title,
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: actions,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * AppSpacing.lg),
      child: ExpansionTile(
        initiallyExpanded: depth == 0,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(Icons.folder_outlined,
            size: 20, color: scheme.onSurfaceVariant),
        title: title,
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: actions,
        children: [
          for (final child in location.children)
            _LocationNode(
              location: child,
              warehouseId: warehouseId,
              depth: 1,
            ),
        ],
      ),
    );
  }
}

/// Create or edit one location. The flags are left to the type unless the
/// operator says otherwise, which is §8's whole point — picking "RECEIVING"
/// should not mean answering five more questions.
class _LocationFormSheet extends ConsumerStatefulWidget {
  const _LocationFormSheet({
    required this.warehouseId,
    this.location,
    this.parentCode,
  });

  final int warehouseId;
  final Location? location;
  final String? parentCode;

  @override
  ConsumerState<_LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends ConsumerState<_LocationFormSheet> {
  late final TextEditingController _code =
      TextEditingController(text: widget.location?.code ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.location?.name ?? '');
  late final TextEditingController _barcode =
      TextEditingController(text: widget.location?.barcode ?? '');
  late final TextEditingController _parent =
      TextEditingController(text: widget.parentCode ?? '');
  late String _type = widget.location?.locationType ?? 'STORAGE';
  late bool _active = widget.location?.isActive ?? true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.location != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _barcode.dispose();
    _parent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_isEdit && _code.text.trim().isEmpty) {
      setState(() => _error = l10n.productValidationRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(locationRepositoryProvider);
    final name = _name.text.trim().isEmpty ? null : _name.text.trim();
    final barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim();
    final parent = _parent.text.trim().isEmpty ? null : _parent.text.trim();

    String? errorMessage;
    if (_isEdit) {
      final result = await repo.update(
        locationId: widget.location!.id,
        name: name,
        locationType: _type,
        parentCode: parent,
        barcode: barcode,
        isActive: _active,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    } else {
      final result = await repo.create(
        warehouseId: widget.warehouseId,
        code: _code.text.trim(),
        name: name,
        locationType: _type,
        parentCode: parent,
        barcode: barcode,
      );
      result.when(success: (_) {}, failure: (f) => errorMessage = f.message);
    }

    if (!mounted) return;
    if (errorMessage == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      // A duplicate code, a parent in another warehouse, or a cycle are all
      // refused server-side and worth reading as they came.
      _error = humanizeApiErrorMessage(l10n, errorMessage!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final types = ref.watch(locationTypesProvider);

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
            Text(_isEdit ? l10n.productEdit : l10n.locationAdd,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _code,
              // The code is the handle every scan and every parent reference
              // uses, so it is fixed once created.
              readOnly: _isEdit,
              decoration: InputDecoration(labelText: l10n.locationCode),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.locationName),
            ),
            const SizedBox(height: AppSpacing.lg),
            types.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('$e', style: TextStyle(color: theme.colorScheme.error)),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.locationType),
                items: [
                  for (final t in list)
                    DropdownMenuItem(
                        value: t.code,
                        child: Text(locationTypeLabel(l10n, t.code))),
                ],
                onChanged:
                    _busy ? null : (v) => setState(() => _type = v ?? 'STORAGE'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _parent,
              decoration: InputDecoration(labelText: l10n.locationParent),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _barcode,
              decoration: InputDecoration(labelText: l10n.locationBarcode),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: Text(l10n.locationInactive),
                onChanged: _busy ? null : (v) => setState(() => _active = v),
              ),
            ],
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
