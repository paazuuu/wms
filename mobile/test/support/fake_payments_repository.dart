import 'dart:typed_data';

import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/payments/data/payments_repository.dart';
import 'package:wms_mobile/features/payments/domain/payment.dart';

/// Nothing to pay and nothing read: what screens that touch payments see in
/// tests unless a test gives its own. [askedPayee] records the AI asked for
/// a 振込先.
class FakePaymentsRepository implements PaymentsRepository {
  final askedPayee = <int>[];

  @override
  Future<ApiResult<List<Payment>>> list(PaymentsRange range) async => const ApiSuccess([]);

  @override
  Future<ApiResult<bool>> setPaid(int importId, bool paid) async => const ApiSuccess(true);

  @override
  Future<ApiResult<bool>> addProof(int importId, String fileName, Uint8List bytes) async => const ApiSuccess(true);

  @override
  Future<ApiResult<bool>> removeProof(int proofId) async => const ApiSuccess(true);

  @override
  Future<ApiResult<Uint8List>> proofBytes(PaymentProof proof) async => ApiSuccess(Uint8List(0));

  @override
  Future<ApiResult<bool>> setSupplierAccount(int supplierId, Payee? payee) async => const ApiSuccess(true);

  @override
  Future<ApiResult<Payee?>> readPayee(int importId) async {
    askedPayee.add(importId);
    return const ApiSuccess(null);
  }
}
