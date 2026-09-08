import 'dart:convert';

/// One print-ready line of the sender (差出人) block.
class SenderLine {
  const SenderLine(this.key, this.text);
  final String key;
  final String text;
}

/// The company's own sender details, saved as a default and toggled per print.
///
/// Each field can be blank; [disabled] holds the keys the operator turned off by
/// default (a field that is present but should not normally print). What
/// actually prints is chosen at print time, starting from [defaultEnabled].
class SenderProfile {
  const SenderProfile({
    this.companyName = '',
    this.postalCode = '',
    this.address = '',
    this.phone = '',
    this.fax = '',
    this.contact = '',
    this.registrationNumber = '',
    this.note = '',
    this.disabled = const {},
  });

  final String companyName;
  final String postalCode;
  final String address;
  final String phone;
  final String fax;
  final String contact;
  final String registrationNumber;
  final String note;

  /// Field keys the operator turned off by default.
  final Set<String> disabled;

  /// The field keys, in print order.
  static const fieldKeys = [
    'company',
    'postal',
    'address',
    'phone',
    'fax',
    'contact',
    'regno',
    'note',
  ];

  String valueOf(String key) => switch (key) {
        'company' => companyName,
        'postal' => postalCode,
        'address' => address,
        'phone' => phone,
        'fax' => fax,
        'contact' => contact,
        'regno' => registrationNumber,
        'note' => note,
        _ => '',
      };

  /// The print-ready text for a field (with its prefix, e.g. "TEL: …").
  String printText(String key) {
    final v = valueOf(key).trim();
    if (v.isEmpty) return '';
    return switch (key) {
      'postal' => '〒$v',
      'phone' => 'TEL: $v',
      'fax' => 'FAX: $v',
      'contact' => '担当: $v',
      'regno' => '登録番号: $v',
      _ => v,
    };
  }

  bool get isEmpty => fieldKeys.every((k) => valueOf(k).trim().isEmpty);

  /// Keys that have a value and are not turned off — the print dialog's default.
  Set<String> get defaultEnabled => {
        for (final k in fieldKeys)
          if (valueOf(k).trim().isNotEmpty && !disabled.contains(k)) k,
      };

  /// Print lines for the given keys (defaults to [defaultEnabled]).
  List<SenderLine> lines({Set<String>? only}) {
    final keys = only ?? defaultEnabled;
    final out = <SenderLine>[];
    for (final k in fieldKeys) {
      if (!keys.contains(k)) continue;
      final t = printText(k);
      if (t.isNotEmpty) out.add(SenderLine(k, t));
    }
    return out;
  }

  SenderProfile copyWith({
    String? companyName,
    String? postalCode,
    String? address,
    String? phone,
    String? fax,
    String? contact,
    String? registrationNumber,
    String? note,
    Set<String>? disabled,
  }) =>
      SenderProfile(
        companyName: companyName ?? this.companyName,
        postalCode: postalCode ?? this.postalCode,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        fax: fax ?? this.fax,
        contact: contact ?? this.contact,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        note: note ?? this.note,
        disabled: disabled ?? this.disabled,
      );

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'postal_code': postalCode,
        'address': address,
        'phone': phone,
        'fax': fax,
        'contact': contact,
        'registration_number': registrationNumber,
        'note': note,
        'disabled': disabled.toList(),
      };

  String encode() => jsonEncode(toJson());

  factory SenderProfile.fromJson(Map<String, dynamic> json) => SenderProfile(
        companyName: json['company_name'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        fax: json['fax'] as String? ?? '',
        contact: json['contact'] as String? ?? '',
        registrationNumber: json['registration_number'] as String? ?? '',
        note: json['note'] as String? ?? '',
        disabled: ((json['disabled'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );

  static SenderProfile decode(String raw) {
    try {
      return SenderProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SenderProfile();
    }
  }
}
