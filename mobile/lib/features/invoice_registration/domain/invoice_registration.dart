import 'package:equatable/equatable.dart';

/// 登録番号の確認 (0229): what 国税庁の適格請求書発行事業者公表システム says of
/// an invoice's 登録番号.

/// "T1234567890123" from what an invoice or a person wrote — full-width,
/// spaces, hyphens, a missing T; null when it is not 13 digits.
String? normalizeRegNo(String? s) {
  if (s == null) return null;
  final b = StringBuffer();
  for (final c in s.trim().runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  final t = b.toString().toUpperCase().replaceAll(RegExp(r'[\s\-‐－ー_]'), '');
  final m = RegExp(r'^T?(\d{13})$').firstMatch(t);
  return m == null ? null : 'T${m[1]}';
}

/// A company name as it can be compared: no 株式会社 and the like, no spaces
/// or punctuation, one width, one case.
String companyKey(String? s) {
  final b = StringBuffer();
  for (final c in (s ?? '').runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : (c == 0x3000 ? 0x20 : c));
  }
  return b
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'株式会社|有限会社|合同会社|合資会社|合名会社|一般社団法人|一般財団法人|\(株\)|\(有\)|\(同\)|㈱|㈲'), '')
      .replaceAll(RegExp(r"[\s・.,、。'" '"' r"’()（）\-‐－ー]"), '');
}

/// The same company, by name (one name holding the other counts: a shop
/// name, a branch).
bool sameCompany(String? a, String? b) {
  final x = companyKey(a), y = companyKey(b);
  if (x.isEmpty || y.isEmpty) return false;
  return x == y || ((x.length < y.length ? x.length : y.length) >= 3 && (x.contains(y) || y.contains(x)));
}

enum RegStatus { valid, notFound, revoked, expired }

class InvoiceRegistration extends Equatable {
  const InvoiceRegistration({
    required this.number,
    required this.status,
    this.name,
    this.tradeName,
    this.address,
    this.kind,
    this.registrationDate,
    this.disposalDate,
    this.expireDate,
    this.checkedAt,
  });

  final String number;
  final RegStatus status;
  final String? name;
  final String? tradeName;
  final String? address;

  /// individual or corporation.
  final String? kind;
  final DateTime? registrationDate;
  final DateTime? disposalDate;
  final DateTime? expireDate;
  final DateTime? checkedAt;

  factory InvoiceRegistration.fromJson(Map<String, dynamic> j) {
    DateTime? d(Object? v) => DateTime.tryParse('${v ?? ''}');
    return InvoiceRegistration(
      number: '${j['number'] ?? ''}',
      status: switch ('${j['status']}') {
        'valid' => RegStatus.valid,
        'revoked' => RegStatus.revoked,
        'expired' => RegStatus.expired,
        _ => RegStatus.notFound,
      },
      name: j['name']?.toString(),
      tradeName: j['trade_name']?.toString(),
      address: j['address']?.toString(),
      kind: j['kind']?.toString(),
      registrationDate: d(j['registration_date']),
      disposalDate: d(j['disposal_date']),
      expireDate: d(j['expire_date']),
      checkedAt: d(j['checked_at'])?.toLocal(),
    );
  }

  /// The invoice's company is this one (by the registered or trade name).
  bool names(String? company) => sameCompany(company, name) || sameCompany(company, tradeName);

  @override
  List<Object?> get props => [number, status, name, address, checkedAt];
}

/// What one check answered.
class InvoiceCheck extends Equatable {
  const InvoiceCheck({this.configured = false, this.failure, this.results = const [], this.bad = const []});

  /// The Web-API's アプリケーションID is set.
  final bool configured;

  /// Why 国税庁 could not be asked (nta_http_…, nta_unreachable).
  final String? failure;
  final List<InvoiceRegistration> results;

  /// What was given that is not a 登録番号.
  final List<String> bad;

  InvoiceRegistration? of(String number) => results.where((r) => r.number == number).firstOrNull;

  factory InvoiceCheck.fromJson(Map<String, dynamic> j) => InvoiceCheck(
        configured: j['configured'] == true,
        failure: j['failure']?.toString(),
        results: [
          for (final r in (j['results'] as List? ?? const []).whereType<Map>())
            InvoiceRegistration.fromJson(r.cast<String, dynamic>()),
        ],
        bad: [for (final b in (j['bad'] as List? ?? const [])) '$b'],
      );

  @override
  List<Object?> get props => [configured, failure, results, bad];
}
