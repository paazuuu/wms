import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/locations/domain/location.dart';

void main() {
  group('Location.fromJson', () {
    test('maps a fully populated payload', () {
      const json = {
        'id': 7,
        'name': 'Receiving Bay A',
        'code': 'RB-A',
        'description': 'Primary inbound staging',
        'aisle': 'A',
        'shelf': '12',
        'bin': '3',
        'full_location': 'A-12-3',
        'is_active': true,
        'products_count': 5,
      };

      final location = Location.fromJson(json);

      expect(location.id, 7);
      expect(location.name, 'Receiving Bay A');
      expect(location.code, 'RB-A');
      expect(location.description, 'Primary inbound staging');
      expect(location.aisle, 'A');
      expect(location.shelf, '12');
      expect(location.bin, '3');
      expect(location.fullLocation, 'A-12-3');
      expect(location.isActive, true);
      expect(location.productsCount, 5);
    });

    test('defaults name to empty and isActive to true when absent', () {
      const json = {'id': 1};

      final location = Location.fromJson(json);

      expect(location.name, '');
      expect(location.isActive, true);
      expect(location.code, isNull);
      expect(location.productsCount, isNull);
    });

    test('coerces a numeric string products_count', () {
      const json = {'id': 2, 'name': 'Zone B', 'products_count': '12'};

      final location = Location.fromJson(json);

      expect(location.productsCount, 12);
    });

    test('displayCode prefers full_location, then code, then name', () {
      expect(
        const Location(id: 1, name: 'N', code: 'C', fullLocation: 'A-1-2')
            .displayCode,
        'A-1-2',
      );
      expect(
        const Location(id: 1, name: 'N', code: 'C').displayCode,
        'C',
      );
      expect(
        const Location(id: 1, name: 'N').displayCode,
        'N',
      );
    });
  });
}
