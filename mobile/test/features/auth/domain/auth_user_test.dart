import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';

void main() {
  group('AuthUser permission checks (UI spec §37)', () {
    const user =
        AuthUser(id: '1', email: 'a@test.com', permissions: ['pick.confirm']);
    const noPermissions = AuthUser(id: '2', email: 'b@test.com');

    test('hasPermission is exact', () {
      expect(user.hasPermission('pick.confirm'), isTrue);
      expect(user.hasPermission('putaway.confirm'), isFalse);
    });

    test('hasAnyPermission matches if any one code is held', () {
      expect(user.hasAnyPermission(['putaway.confirm', 'pick.confirm']), isTrue);
      expect(user.hasAnyPermission(['putaway.confirm', 'ship.complete']), isFalse);
    });

    test('an empty requirement is always satisfied, held or not', () {
      expect(user.hasAnyPermission(const []), isTrue);
      expect(noPermissions.hasAnyPermission(const []), isTrue);
    });

    test('fromGoTrue carries roles and permissions from my_access()', () {
      final parsed = AuthUser.fromGoTrue(
        const {'id': 'u1', 'email': 'a@test.com'},
        roles: const ['picker'],
        permissions: const ['pick.confirm'],
      );

      expect(parsed.roles, ['picker']);
      expect(parsed.permissions, ['pick.confirm']);
    });

    test('copyWith replaces permissions independently of roles', () {
      final updated = user.copyWith(permissions: ['ship.complete']);

      expect(updated.permissions, ['ship.complete']);
      expect(updated.roles, user.roles);
    });
  });
}
