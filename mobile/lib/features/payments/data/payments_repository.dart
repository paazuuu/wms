import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../auth/application/auth_controller.dart';
import '../../delivery/application/delivery_providers.dart' show deliveryDioProvider, restDioProvider, storageDioProvider;
import '../domain/payment.dart';

/// The private bucket the transfer proofs are kept in (0171).
const paymentProofBucket = 'payment-proofs';

/// Which payments are listed: every unpaid one, or a month's.
sealed class PaymentsRange {
  const PaymentsRange();
}

class UnpaidPayments extends PaymentsRange {
  const UnpaidPayments();

  @override
  bool operator ==(Object other) => other is UnpaidPayments;

  @override
  int get hashCode => 0;
}

class MonthPayments extends PaymentsRange {
  const MonthPayments(this.year, this.month);

  final int year;
  final int month;

  @override
  bool operator ==(Object other) => other is MonthPayments && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

abstract class PaymentsRepository {
  Future<ApiResult<List<Payment>>> list(PaymentsRange range);

  /// The import's own 支払い済 (the same as on 取込の詳細).
  Future<ApiResult<bool>> setPaid(int importId, bool paid);

  /// A proof of the transfer, kept under the import.
  Future<ApiResult<bool>> addProof(int importId, String fileName, Uint8List bytes);

  /// Taken off the list (the file is kept).
  Future<ApiResult<bool>> removeProof(int proofId);

  Future<ApiResult<Uint8List>> proofBytes(PaymentProof proof);

  /// The supplier's 振込先, used when an invoice prints none.
  Future<ApiResult<bool>> setSupplierAccount(int supplierId, Payee? payee);

  /// The invoice read again by the AI for its 振込先 and totals, kept with
  /// it (0172). Null when it prints none.
  Future<ApiResult<Payee?>> readPayee(int importId);
}

String contentTypeOf(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

class PaymentsRepositoryImpl implements PaymentsRepository {
  PaymentsRepositoryImpl(this._rest, this._storage, this._functions);

  final Dio _rest;
  final Dio _storage;
  final Dio _functions;

  @override
  Future<ApiResult<Payee?>> readPayee(int importId) async {
    try {
      final r = await _functions.post(
        '/import-plan',
        data: {'mode': 'read_payee', 'import_id': importId},
        options: Options(contentType: Headers.jsonContentType, receiveTimeout: const Duration(seconds: 150)),
      );
      final data = ((r.data as Map)['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      return ApiSuccess(Payee.fromJson(data['payee']));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ApiResult<List<Payment>>> list(PaymentsRange range) async {
    try {
      final r = await _rest.post('/rpc/payments_list', data: switch (range) {
        UnpaidPayments() => {'p_from': null, 'p_to': null, 'p_unpaid_only': true},
        MonthPayments(:final year, :final month) => {
            'p_from': _day(DateTime(year, month)),
            'p_to': _day(DateTime(year, month + 1, 0)),
            'p_unpaid_only': false,
          },
      });
      final raw = r.data is List && (r.data as List).length == 1 && (r.data as List).first is List ? (r.data as List).first : r.data;
      return ApiSuccess([
        for (final e in (raw as List? ?? const []).whereType<Map>()) Payment.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> setPaid(int importId, bool paid) async {
    try {
      await _rest.post('/rpc/stock_file_import_update', data: {
        'p_id': importId,
        'p_patch': {'paid': paid},
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> addProof(int importId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$importId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final type = contentTypeOf(fileName);
    try {
      await _storage.post('/object/$paymentProofBucket/$path', data: bytes, options: Options(headers: {'Content-Type': type}));
      await _rest.post('/rpc/add_payment_proof', data: {
        'p_import_id': importId,
        'p_path': path,
        'p_name': fileName,
        'p_type': type,
        'p_size': bytes.length,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> removeProof(int proofId) async {
    try {
      final r = await _rest.post('/rpc/remove_payment_proof', data: {'p_id': proofId});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> proofBytes(PaymentProof proof) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$paymentProofBucket/${proof.path}',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }

  @override
  Future<ApiResult<bool>> setSupplierAccount(int supplierId, Payee? payee) async {
    try {
      await _rest.post('/rpc/set_supplier_bank_account', data: {'p_supplier_id': supplierId, 'p_account': payee?.toJson()});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError(e);
    }
  }
}

final paymentsRepositoryProvider =
    Provider<PaymentsRepository>((ref) => PaymentsRepositoryImpl(
        ref.watch(restDioProvider), ref.watch(storageDioProvider), ref.watch(deliveryDioProvider)));

final paymentsProvider = FutureProvider.autoDispose.family<List<Payment>, PaymentsRange>((ref, range) async {
  final r = await ref.watch(paymentsRepositoryProvider).list(range);
  return switch (r) {
    ApiSuccess(:final data) => data,
    ApiFailure(:final message) => throw Exception(message),
  };
});

/// Who records payments (支払い済, proofs, 振込先): as for 支払い済 on an import.
final canRecordPaymentsProvider =
    Provider<bool>((ref) => ref.watch(authControllerProvider).user?.hasPermission('inventory.adjust') ?? false);
