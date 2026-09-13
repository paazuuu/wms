import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// A stored file linked to some entity (spec §32, 0031) — inspections today,
/// shaped (`entity_type`/`entity_id`, not an FK) to attach to other entities
/// later without a schema redesign.
class Attachment extends Equatable {
  const Attachment({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.storagePath,
    this.contentType,
    this.createdAt,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String storagePath;
  final String? contentType;
  final DateTime? createdAt;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: _asInt(json['id']),
        entityType: (json['entity_type'] ?? '').toString(),
        entityId: (json['entity_id'] ?? '').toString(),
        storagePath: (json['storage_path'] ?? '').toString(),
        contentType: json['content_type'] as String?,
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      );

  @override
  List<Object?> get props => [id, entityType, entityId, storagePath];
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
