import 'package:equatable/equatable.dart';

int? _asIntOrNull(dynamic v) => v == null
    ? null
    : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'.replaceAll(RegExp(r'\D'), ''))));

String? _asText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// One line of a supplier's delivery note, as the OCR read it (0101).
class DeliveryNoteLine extends Equatable {
  const DeliveryNoteLine({this.janCode, this.productCode, this.productName, this.quantity});

  final String? janCode;
  final String? productCode;
  final String? productName;
  final int? quantity;

  String get label => productName ?? productCode ?? janCode ?? '—';

  Map<String, dynamic> toJson() => {
        'jan_code': janCode ?? '',
        'product_code': productCode ?? '',
        'product_name': productName ?? '',
        if (quantity != null) 'quantity': quantity,
      };

  factory DeliveryNoteLine.fromJson(Map<String, dynamic> json) => DeliveryNoteLine(
        janCode: _asText(json['jan_code']),
        productCode: _asText(json['product_code']),
        productName: _asText(json['product_name']),
        quantity: _asIntOrNull(json['quantity']),
      );

  @override
  List<Object?> get props => [janCode, productCode, productName, quantity];
}

/// The OCR response's lines, any with something to match on.
List<DeliveryNoteLine> parseDeliveryNoteLines(dynamic body) {
  final data = body is Map ? (body['data'] is Map ? body['data'] : body) : null;
  final raw = data is Map ? data['lines'] : null;
  if (raw is! List) return const [];
  return [
    for (final e in raw.whereType<Map>())
      DeliveryNoteLine.fromJson(e.cast<String, dynamic>()),
  ].where((l) => l.janCode != null || l.productCode != null || l.productName != null).toList();
}

/// What `apply_delivery_note` matched (0101).
class DeliveryNoteApplyResult extends Equatable {
  const DeliveryNoteApplyResult({this.matched = 0, this.unmatched = const []});

  final int matched;

  /// Lines no inspection line answered — a wrong item, or a code nobody has
  /// registered for this supplier yet.
  final List<DeliveryNoteLine> unmatched;

  factory DeliveryNoteApplyResult.fromJson(Map<String, dynamic> json) => DeliveryNoteApplyResult(
        matched: (json['matched'] as List?)?.length ?? 0,
        unmatched: [
          for (final e in (json['unmatched'] as List? ?? const []).whereType<Map>())
            DeliveryNoteLine.fromJson(e.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [matched, unmatched];
}
