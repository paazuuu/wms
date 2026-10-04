import 'package:equatable/equatable.dart';

/// What an uploaded file was for (0132).
enum EvidencePurpose {
  plan('plan'),
  shipment('shipment'),
  training('training'),
  quote('quote'),
  priceBook('price_book'),
  library('library'),
  ocr('ocr');

  const EvidencePurpose(this.wire);
  final String wire;

  static EvidencePurpose fromWire(String? v) =>
      values.firstWhere((p) => p.wire == v, orElse: () => EvidencePurpose.plan);
}

/// One uploaded file kept as evidence (0132): what it was, who sent it in,
/// what it was read as, and the plan it became.
class ImportDocument extends Equatable {
  const ImportDocument({
    required this.id,
    required this.purpose,
    required this.fileName,
    required this.storagePath,
    required this.uploadedAt,
    this.contentType,
    this.byteSize,
    this.source,
    this.supplierName,
    this.registrationNumber,
    this.docNumber,
    this.docDate,
    this.lineCount,
    this.deliveryPlanId,
    this.shipmentPlanId,
    this.referenceNo,
    this.uploadedByName,
    this.committedAt,
  });

  final int id;
  final EvidencePurpose purpose;
  final String fileName;
  final String storagePath;
  final DateTime uploadedAt;
  final String? contentType;
  final int? byteSize;
  final String? source;
  final String? supplierName;
  final String? registrationNumber;
  final String? docNumber;
  final String? docDate;
  final int? lineCount;
  final int? deliveryPlanId;
  final int? shipmentPlanId;
  final String? referenceNo;
  final String? uploadedByName;
  final DateTime? committedAt;

  bool get committed => deliveryPlanId != null || shipmentPlanId != null;

  factory ImportDocument.fromJson(Map<String, dynamic> j) {
    String? s(Object? v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    int? n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    return ImportDocument(
      id: n(j['id']) ?? 0,
      purpose: EvidencePurpose.fromWire(s(j['purpose'])),
      fileName: s(j['file_name']) ?? '',
      storagePath: s(j['storage_path']) ?? '',
      uploadedAt: DateTime.tryParse('${j['uploaded_at']}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      contentType: s(j['content_type']),
      byteSize: n(j['byte_size']),
      source: s(j['source']),
      supplierName: s(j['supplier_name']),
      registrationNumber: s(j['registration_number']),
      docNumber: s(j['doc_number']),
      docDate: s(j['doc_date']),
      lineCount: n(j['line_count']),
      deliveryPlanId: n(j['delivery_plan_id']),
      shipmentPlanId: n(j['shipment_plan_id']),
      referenceNo: s(j['reference_no']),
      uploadedByName: s(j['uploaded_by_name']),
      committedAt: DateTime.tryParse('${j['committed_at'] ?? ''}')?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [id, purpose, fileName, storagePath, uploadedAt, deliveryPlanId, shipmentPlanId];
}
