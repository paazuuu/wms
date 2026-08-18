import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/warehouses/domain/warehouse.dart';

void main() {
  group('Warehouse.fromJson', () {
    test('maps a fully populated payload', () {
      const json = {
        'id': 4,
        'name': 'Central DC',
        'code': 'CDC',
        'description': 'Main distribution center',
        'address_line_1': '10 Dock Rd',
        'address_line_2': 'Unit 5',
        'city': 'Toronto',
        'province': 'ON',
        'postal_code': 'M5V 1A1',
        'country': 'CA',
        'phone': '+1-416-555-0100',
        'email': 'dc@central.test',
        'manager_name': 'Sam Lee',
        'timezone': 'America/Toronto',
        'currency': 'CAD',
        'is_default': true,
        'is_active': true,
        'priority': 5,
        'locations_count': 12,
        'users_count': 4,
      };

      final w = Warehouse.fromJson(json);

      expect(w.id, 4);
      expect(w.name, 'Central DC');
      expect(w.code, 'CDC');
      expect(w.city, 'Toronto');
      expect(w.managerName, 'Sam Lee');
      expect(w.isDefault, true);
      expect(w.isActive, true);
      expect(w.priority, 5);
      expect(w.locationsCount, 12);
      expect(w.usersCount, 4);
    });

    test('coerces integer booleans (0/1) from a raw model payload', () {
      const json = {
        'id': 1,
        'name': 'Legacy WH',
        'is_default': 0,
        'is_active': 1,
      };

      final w = Warehouse.fromJson(json);

      expect(w.isDefault, false);
      expect(w.isActive, true);
    });

    test('defaults name empty, isActive true, priority 0 when absent', () {
      const json = {'id': 2};

      final w = Warehouse.fromJson(json);

      expect(w.name, '');
      expect(w.isActive, true);
      expect(w.isDefault, false);
      expect(w.priority, 0);
      expect(w.locationsCount, isNull);
    });

    test('fullAddress joins only the present parts', () {
      const w = Warehouse(
        id: 1,
        name: 'WH',
        addressLine1: '10 Dock Rd',
        city: 'Toronto',
        province: 'ON',
        country: 'CA',
      );

      expect(w.fullAddress, '10 Dock Rd, Toronto, ON, CA');
    });

    test('displayCode prefers code, then falls back to name', () {
      expect(
        const Warehouse(id: 1, name: 'Central DC', code: 'CDC').displayCode,
        'CDC',
      );
      expect(const Warehouse(id: 1, name: 'Central DC').displayCode,
          'Central DC');
    });
  });
}
