import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/audit/domain/audit_entry.dart';

void main() {
  group('AuditEntry (0040: actor_name/actor_email)', () {
    test('fromJson carries the resolved actor alongside the raw uuid', () {
      final entry = AuditEntry.fromJson(const {
        'id': 1,
        'event_type': 'transfer.approved',
        'actor_user_id': 'a1b2',
        'actor_name': 'テスト太郎',
        'actor_email': 'taro@example.com',
      });

      expect(entry.actorUserId, 'a1b2');
      expect(entry.actorName, 'テスト太郎');
      expect(entry.actorEmail, 'taro@example.com');
    });

    test('actorDisplay prefers the name, falls back to email, then null', () {
      const withName = AuditEntry(
          id: 1, eventType: 'x', actorName: 'テスト太郎', actorEmail: 'a@b.com');
      const emailOnly = AuditEntry(id: 2, eventType: 'x', actorEmail: 'a@b.com');
      const neither = AuditEntry(id: 3, eventType: 'x');

      expect(withName.actorDisplay, 'テスト太郎');
      expect(emailOnly.actorDisplay, 'a@b.com');
      expect(neither.actorDisplay, isNull);
    });

    test('a null actor in the JSON stays null, not "system" or ""', () {
      final entry = AuditEntry.fromJson(const {
        'id': 1,
        'event_type': 'shipment.autopacked',
        'actor_user_id': null,
        'actor_name': null,
        'actor_email': null,
      });

      expect(entry.actorUserId, isNull);
      expect(entry.actorDisplay, isNull);
    });
  });
}
