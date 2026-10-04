import 'package:equatable/equatable.dart';

/// Our own company (0131): the names it goes by and its 登録番号, so a
/// document's addressee (us) is told from its issuer (the supplier).
class CompanyProfile extends Equatable {
  const CompanyProfile({
    required this.name,
    this.nameKana,
    this.nameEn,
    this.aliases = const [],
    this.registrationNumber,
    this.postalCode,
    this.address,
    this.phone,
    this.fax,
    this.email,
  });

  /// The placeholder the company row was created with.
  static const placeholder = '自社';

  final String name;
  final String? nameKana;
  final String? nameEn;
  final List<String> aliases;
  final String? registrationNumber;
  final String? postalCode;
  final String? address;
  final String? phone;
  final String? fax;
  final String? email;

  /// Still the placeholder: nothing tells the reader who we are by name.
  bool get isUnset => name.trim().isEmpty || name.trim() == placeholder;

  factory CompanyProfile.fromJson(Map<String, dynamic> j) {
    String? s(Object? v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    return CompanyProfile(
      name: s(j['name']) ?? '',
      nameKana: s(j['name_kana']),
      nameEn: s(j['name_en']),
      aliases: [for (final a in (j['aliases'] as List? ?? const [])) if (s(a) != null) s(a)!],
      registrationNumber: s(j['registration_number']),
      postalCode: s(j['postal_code']),
      address: s(j['address']),
      phone: s(j['phone']),
      fax: s(j['fax']),
      email: s(j['email']),
    );
  }

  /// Every field, for `set_company_profile`: a blank one clears it.
  Map<String, dynamic> toJson() => {
        'name': name,
        'name_kana': nameKana,
        'name_en': nameEn,
        'aliases': aliases,
        'registration_number': registrationNumber,
        'postal_code': postalCode,
        'address': address,
        'phone': phone,
        'fax': fax,
        'email': email,
      };

  @override
  List<Object?> get props =>
      [name, nameKana, nameEn, aliases, registrationNumber, postalCode, address, phone, fax, email];
}

/// A company our documents were addressed to (〇〇御中), and how often (0132).
class OwnNameSuggestion extends Equatable {
  const OwnNameSuggestion({required this.name, required this.count});

  final String name;
  final int count;

  factory OwnNameSuggestion.fromJson(Map<String, dynamic> j) => OwnNameSuggestion(
        name: '${j['name'] ?? ''}',
        count: j['count'] is num ? (j['count'] as num).toInt() : int.tryParse('${j['count']}') ?? 0,
      );

  @override
  List<Object?> get props => [name, count];
}
