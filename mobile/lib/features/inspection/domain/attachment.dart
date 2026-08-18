import 'package:equatable/equatable.dart';

class Attachment extends Equatable {
  const Attachment({
    required this.id,
    required this.category,
    required this.mimeType,
    required this.originalName,
    required this.url,
    this.kind,
    this.thumbnailUrl,
    this.sizeBytes,
  });

  final int id;

  /// image | pdf | office | video | audio | other
  final String category;
  final String mimeType;
  final String originalName;
  final String url;
  final String? kind;
  final String? thumbnailUrl;
  final int? sizeBytes;

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as int,
      category: json['category'] as String? ?? 'other',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      originalName: json['original_name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      kind: json['kind'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      sizeBytes: json['size_bytes'] as int?,
    );
  }

  bool get isImage => category == 'image';

  @override
  List<Object?> get props => [id, category, url];
}
