import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/reconciliation.dart';

/// Records one parcel of a receiving line — §12's Receipt Item (0067).
///
/// The fields are what a parcel *is*: how many, on which lot, expiring when, or
/// which serial, and where it was put. Everything except the quantity is optional,
/// because a receiver who has only a quantity should not be blocked from
/// recording it — that is the whole reason the server posts an unattributed
/// remainder rather than demanding parcels.
///
/// The one status offered is DAMAGED, and only as a checkbox. A named status can
/// only make a parcel *more* restricted (0072), so offering a picker would mostly
/// offer choices the server refuses; the case that actually happens on a dock is
/// "this carton arrived wet".
class ParcelSheet extends StatefulWidget {
  const ParcelSheet({
    super.key,
    required this.janCode,
    required this.productName,
    this.remaining,
  });

  final String janCode;
  final String productName;

  /// How much of the line is not yet attributed to a parcel, prefilled as the
  /// quantity. Null when the line has no count yet.
  final int? remaining;

  @override
  State<ParcelSheet> createState() => _ParcelSheetState();
}

class _ParcelSheetState extends State<ParcelSheet> {
  late final TextEditingController _quantity =
      TextEditingController(text: '${widget.remaining ?? 1}');
  final _lot = TextEditingController();
  final _serial = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  DateTime? _expiry;
  bool _damaged = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _lot.dispose();
    _serial.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      // A receipt can carry an expiry already past — that is an exception worth
      // recording, not an impossible date to refuse.
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    final serial = _serial.text.trim();
    if (quantity <= 0) {
      setState(() => _error = l10n.parcelQuantityRequired);
      return;
    }
    // The server enforces this too; catching it here keeps it a form message.
    if (serial.isNotEmpty && quantity != 1) {
      setState(() => _error = l10n.parcelSerialIsOne);
      return;
    }
    Navigator.of(context).pop(ReceivedParcel(
      quantity: quantity,
      lotCode: _lot.text.trim().isEmpty ? null : _lot.text.trim(),
      expiry: _expiry,
      serialNumber: serial.isEmpty ? null : serial,
      locationCode:
          _location.text.trim().isEmpty ? null : _location.text.trim(),
      statusCode: _damaged ? 'DAMAGED' : null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.parcelAddTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.productName.isEmpty ? widget.janCode : widget.productName,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.parcelQuantity,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _lot,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.parcelLot,
                hintText: l10n.parcelLotHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.parcelExpiry,
                  border: const OutlineInputBorder(),
                  suffixIcon: _expiry == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiry = null),
                        ),
                ),
                child: Text(
                  _expiry == null
                      ? l10n.parcelExpiryNone
                      : '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.parcelSerial,
                helperText: l10n.parcelSerialHelp,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _location,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.parcelLocation,
                hintText: l10n.parcelLocationHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              value: _damaged,
              onChanged: (v) => setState(() => _damaged = v ?? false),
              title: Text(l10n.parcelDamaged),
              subtitle: Text(l10n.parcelDamagedHelp),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.parcelNote,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.parcelAdd),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
