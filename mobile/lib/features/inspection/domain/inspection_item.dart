import 'package:equatable/equatable.dart';

import 'attachment.dart';

enum MatchResult { pending, ok, ng }

MatchResult _parseResult(String? value) => switch (value) {
      'ok' => MatchResult.ok,
      'ng' => MatchResult.ng,
      _ => MatchResult.pending,
    };

class InspectionItem extends Equatable {
  const InspectionItem({
    required this.id,
    required this.inspectionId,
    required this.matchResult,
    this.productId,
    this.expectedBarcode,
    this.scannedBarcode,
    this.expectedQuantity = 0,
    this.actualQuantity = 0,
    this.expectedLot,
    this.lotNumber,
    this.ngReason,
    this.comment,
    this.attachments = const [],
  });

  final int id;
  final int inspectionId;
  final MatchResult matchResult;
  final int? productId;
  final String? expectedBarcode;
  final String? scannedBarcode;
  final int expectedQuantity;
  final int actualQuantity;
  final String? expectedLot;
  final String? lotNumber;
  final String? ngReason;
  final String? comment;
  final List<Attachment> attachments;

  factory InspectionItem.fromJson(Map<String, dynamic> json) {
    return InspectionItem(
      id: json['id'] as int,
      inspectionId: json['inspection_id'] as int,
      matchResult: _parseResult(json['match_result'] as String?),
      productId: json['product_id'] as int?,
      expectedBarcode: json['expected_barcode'] as String?,
      scannedBarcode: json['scanned_barcode'] as String?,
      expectedQuantity: json['expected_quantity'] as int? ?? 0,
      actualQuantity: json['actual_quantity'] as int? ?? 0,
      expectedLot: json['expected_lot'] as String?,
      lotNumber: json['lot_number'] as String?,
      ngReason: json['ng_reason'] as String?,
      comment: json['comment'] as String?,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, matchResult, actualQuantity, scannedBarcode];
}
