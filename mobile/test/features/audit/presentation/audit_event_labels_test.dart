import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/audit/presentation/audit_event_labels.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

/// Every `log_audit(...)` event code in the schema as of 0040 — kept here as
/// data so this test can assert the map has not silently fallen behind a new
/// migration's event type.
const _allKnownEvents = [
  'ai.analysis_completed', 'ai.confirmed', 'ai.rejected',
  'attachment.uploaded',
  'count.cancelled', 'count.completed', 'count.started',
  'inspection.confirmed', 'inspection.started',
  'inventory.adjusted',
  'partner.created', 'partner.updated',
  'pick_list.cancelled', 'pick_list.completed', 'pick_list.started',
  'product.created', 'product.updated',
  'purchase_order.approved', 'purchase_order.cancelled',
  'purchase_order.completed', 'purchase_order.created',
  'purchase_order.rejected', 'purchase_order.submitted',
  'putaway.confirmed',
  'receiving.cancelled', 'receiving.confirmed',
  'report.deleted', 'report.saved',
  'sales_order.approved', 'sales_order.cancelled', 'sales_order.completed',
  'sales_order.created', 'sales_order.rejected', 'sales_order.submitted',
  'shipment.autopacked', 'shipment.cancelled', 'shipment.completed',
  'shipment.logistics_set',
  'transfer.approved', 'transfer.cancelled', 'transfer.created',
  'transfer.picking_started', 'transfer.received',
  'transfer.receiving_started', 'transfer.rejected', 'transfer.shipped',
  'transfer.submitted',
  'user.role_assigned', 'user.role_revoked', 'user.warehouse_assigned',
  'user.warehouse_revoked',
  'work_order.cancelled', 'work_order.completed', 'work_order.created',
  'work_order.started',
];

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  group('AuditEventLabels (UI spec §29)', () {
    test('every known event code resolves to a real phrase, not raw', () {
      for (final code in _allKnownEvents) {
        final label = AuditEventLabels.of(ja, code);
        expect(label, isNot(code),
            reason: '$code fell through to the raw-code fallback');
        expect(label, isNot(contains('.')),
            reason: '$code produced a code-shaped label: $label');
      }
    });

    test('a spot check reads naturally in all three languages', () {
      expect(AuditEventLabels.of(ja, 'purchase_order.approved'), '発注を承認');
      expect(AuditEventLabels.of(en, 'purchase_order.approved'),
          'Purchase order approved');
      expect(AuditEventLabels.of(zh, 'purchase_order.approved'), '采购单已批准');
    });

    test('an unrecognised code still renders — never crashes, never hides',
        () {
      expect(AuditEventLabels.of(ja, 'brand_new.thing_happened'),
          'brand new thing happened');
      expect(AuditEventLabels.of(ja, ''), '');
    });
  });
}
