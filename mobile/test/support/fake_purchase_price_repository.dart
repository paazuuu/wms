import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/product/data/purchase_price_repository.dart';

/// 仕入れ値の履歴 (0187) in memory: [prices] for every product unless
/// [failWith] is set; what is recorded and withdrawn is kept.
class FakePurchasePriceRepository implements PurchasePriceRepository {
  FakePurchasePriceRepository({this.prices = const PurchasePrices(), this.failWith});

  PurchasePrices prices;
  String? failWith;
  final List<Map<String, Object?>> recorded = [];
  final List<int> withdrawn = [];

  @override
  Future<ApiResult<PurchasePrices>> forProduct(int productId) async =>
      failWith != null ? ApiFailure(message: failWith!) : ApiSuccess(prices);

  @override
  Future<ApiResult<int>> record({
    required int productId,
    required double unitPrice,
    required DateTime pricedOn,
    int? supplierId,
    String? supplierName,
    double taxRate = 10,
    int? quantity,
    String? note,
  }) async {
    recorded.add({
      'product_id': productId,
      'unit_price': unitPrice,
      'priced_on': pricedOn,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'tax_rate': taxRate,
      'quantity': quantity,
      'note': note,
    });
    return ApiSuccess(recorded.length);
  }

  @override
  Future<ApiResult<bool>> withdraw(int entryId) async {
    withdrawn.add(entryId);
    return const ApiSuccess(true);
  }
}
