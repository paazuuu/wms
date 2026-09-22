import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// What a file is. §29 asks for attachments on ten kinds of thing, and a
/// delivery note is not a damage photo — a receipt argument with a supplier turns
/// on being able to tell them apart.
enum AttachmentKind {
  photo('PHOTO'),
  deliveryNote('DELIVERY_NOTE'),
  qcImage('QC_IMAGE'),
  damage('DAMAGE'),
  document('DOCUMENT'),
  label('LABEL'),
  other('OTHER');

  const AttachmentKind(this.code);

  final String code;

  static AttachmentKind fromCode(dynamic value) {
    final code = (value ?? '').toString().toUpperCase();
    return AttachmentKind.values.firstWhere(
      (k) => k.code == code,
      orElse: () => AttachmentKind.other,
    );
  }
}

/// A stored file linked to some entity (§29, 0031 and 0070) — polymorphic on
/// (`entity_type`, `entity_id`) rather than an FK, with the set of things that
/// can be attached to held as data in `attachment_targets`.
class Attachment extends Equatable {
  const Attachment({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.storagePath,
    this.contentType,
    this.createdAt,
    this.kind = AttachmentKind.other,
    this.caption,
    this.byteSize,
    this.warehouseId,
    this.withdrawnAt,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String storagePath;
  final String? contentType;
  final DateTime? createdAt;
  final AttachmentKind kind;
  final String? caption;
  final int? byteSize;

  /// Null for a company-wide file (a product photo); set for one that belongs to
  /// a building, which is what lets RLS scope it.
  final int? warehouseId;

  /// Set once withdrawn. Attachments are withdrawn, not deleted: a photo that
  /// settled a claim has to stay findable (0070).
  final DateTime? withdrawnAt;

  bool get isWithdrawn => withdrawnAt != null;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        // `attachments_for` calls it attachment_id; a raw table row calls it id.
        id: _asInt(json['attachment_id'] ?? json['id']),
        entityType: (json['entity_type'] ?? '').toString(),
        entityId: (json['entity_id'] ?? '').toString(),
        storagePath: (json['storage_path'] ?? '').toString(),
        contentType: json['content_type'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        kind: AttachmentKind.fromCode(json['kind']),
        caption: (json['caption'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['caption'] as String).trim(),
        byteSize: json['byte_size'] == null ? null : _asInt(json['byte_size']),
        warehouseId:
            json['warehouse_id'] == null ? null : _asInt(json['warehouse_id']),
        withdrawnAt:
            DateTime.tryParse('${json['withdrawn_at'] ?? json['deleted_at']}')
                ?.toLocal(),
      );

  @override
  List<Object?> get props =>
      [id, entityType, entityId, storagePath, kind, withdrawnAt];
}

/// Best-guess MIME type from a picked file's name — image_picker doesn't
/// always surface one, and it's only needed here for Storage's content-type
/// header and later display.
String attachmentContentTypeForFileName(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}
