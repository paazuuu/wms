import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/invoice_registration/data/invoice_registration_repository.dart';
import 'package:wms_mobile/features/invoice_registration/domain/invoice_registration.dart';

/// 国税庁 in memory (0229): the registrations it knows; the key set or not.
class FakeInvoiceRegistrationRepository implements InvoiceRegistrationRepository {
  FakeInvoiceRegistrationRepository({this.known = const {}, this.configured = false});

  final Map<String, InvoiceRegistration> known;
  bool configured;
  final asked = <(List<String>, bool)>[];
  final keys = <String>[];

  @override
  Future<ApiResult<InvoiceCheck>> check(List<String> numbers, {bool refresh = false}) async {
    asked.add((numbers, refresh));
    final good = [for (final n in numbers) if (normalizeRegNo(n) != null) normalizeRegNo(n)!];
    return ApiSuccess(InvoiceCheck(
      configured: configured,
      results: [
        for (final n in good)
          if (configured) known[n] ?? InvoiceRegistration(number: n, status: RegStatus.notFound),
      ],
      bad: [for (final n in numbers) if (normalizeRegNo(n) == null) n],
    ));
  }

  @override
  Future<ApiResult<NtaKeyStatus>> keyStatus() async =>
      ApiSuccess((set: configured, updatedAt: configured ? DateTime(2026, 11, 26) : null, updatedBy: configured ? 'テスト管理者' : null));

  @override
  Future<ApiResult<bool>> setKey(String value) async {
    keys.add(value);
    configured = value.isNotEmpty;
    return const ApiSuccess(true);
  }
}
