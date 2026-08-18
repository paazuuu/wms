import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/products/domain/product.dart';

void main() {
  group('Product.fromJson', () {
    test('parses the full ProductResource shape', () {
      final product = Product.fromJson(const {
        'id': 1,
        'sku': 'E2E-001',
        'name': 'E2E Test Product',
        'description': 'A sample',
        'price': '19.99',
        'selling_price': null,
        'currency': 'USD',
        'stock': 50,
        'total_stock': 50,
        'min_stock': 5,
        'barcode': '4901234500000',
        'is_active': true,
        'has_variants': false,
        'is_low_stock': false,
        'is_out_of_stock': false,
        'category': {'id': 3, 'name': 'Electronics'},
        'location': {'id': 7, 'name': 'A-01-01'},
        'thumbnail': null,
      });

      expect(product.id, 1);
      expect(product.sku, 'E2E-001');
      expect(product.name, 'E2E Test Product');
      expect(product.barcode, '4901234500000');
      expect(product.price, '19.99');
      expect(product.currency, 'USD');
      expect(product.displayStock, 50);
      expect(product.minStock, 5);
      expect(product.categoryName, 'Electronics');
      expect(product.locationName, 'A-01-01');
      expect(product.isLowStock, isFalse);
    });

    test('tolerates missing optional fields and null nested relations', () {
      final product = Product.fromJson(const {
        'id': 9,
        'sku': 'X',
        'name': 'Bare',
        'category': null,
        'location': null,
      });

      expect(product.id, 9);
      expect(product.barcode, isNull);
      expect(product.categoryName, isNull);
      expect(product.locationName, isNull);
      expect(product.displayStock, 0);
      expect(product.isActive, isTrue);
    });

    test('displayStock prefers total_stock then falls back to stock', () {
      final onlyStock = Product.fromJson(const {
        'id': 1,
        'sku': 'A',
        'name': 'A',
        'stock': 12,
      });
      expect(onlyStock.displayStock, 12);

      final both = Product.fromJson(const {
        'id': 2,
        'sku': 'B',
        'name': 'B',
        'stock': 3,
        'total_stock': 40,
      });
      expect(both.displayStock, 40);
    });

    test('coerces numeric price fields to strings', () {
      final product = Product.fromJson(const {
        'id': 1,
        'sku': 'A',
        'name': 'A',
        'price': 25,
      });
      expect(product.price, '25');
    });
  });
}
