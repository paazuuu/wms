import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/suppliers/domain/supplier.dart';

void main() {
  group('Supplier.fromJson', () {
    test('maps a fully populated payload', () {
      const json = {
        'id': 3,
        'name': 'Acme Supply Co',
        'code': 'ACME',
        'contact_name': 'Jane Doe',
        'email': 'jane@acme.test',
        'phone': '+1-555-0100',
        'full_address': '1 Main St, Springfield, IL 62704, US',
        'website': 'https://acme.test',
        'payment_terms': 'Net 30',
        'currency': 'USD',
        'notes': 'Preferred vendor',
        'is_active': true,
        'products_count': 8,
      };

      final supplier = Supplier.fromJson(json);

      expect(supplier.id, 3);
      expect(supplier.name, 'Acme Supply Co');
      expect(supplier.code, 'ACME');
      expect(supplier.contactName, 'Jane Doe');
      expect(supplier.email, 'jane@acme.test');
      expect(supplier.phone, '+1-555-0100');
      expect(supplier.fullAddress, '1 Main St, Springfield, IL 62704, US');
      expect(supplier.website, 'https://acme.test');
      expect(supplier.paymentTerms, 'Net 30');
      expect(supplier.currency, 'USD');
      expect(supplier.notes, 'Preferred vendor');
      expect(supplier.isActive, true);
      expect(supplier.productsCount, 8);
    });

    test('defaults name to empty and isActive to true when absent', () {
      const json = {'id': 1};

      final supplier = Supplier.fromJson(json);

      expect(supplier.name, '');
      expect(supplier.isActive, true);
      expect(supplier.email, isNull);
      expect(supplier.productsCount, isNull);
    });

    test('coerces a numeric string products_count', () {
      const json = {'id': 2, 'name': 'Beta', 'products_count': '15'};

      final supplier = Supplier.fromJson(json);

      expect(supplier.productsCount, 15);
    });

    test('displayCode prefers code, then falls back to name', () {
      expect(
        const Supplier(id: 1, name: 'Acme', code: 'ACME').displayCode,
        'ACME',
      );
      expect(
        const Supplier(id: 1, name: 'Acme').displayCode,
        'Acme',
      );
    });
  });
}
