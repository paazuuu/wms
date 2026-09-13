import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../delivery/application/delivery_providers.dart';
import '../data/attachment_repository.dart';
import '../domain/attachment.dart';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return AttachmentRepositoryImpl(
    restDio: ref.watch(restDioProvider),
    storageDio: ref.watch(storageDioProvider),
    bucket: AppConfig.attachmentsBucket,
  );
});

typedef AttachmentEntityKey = ({String entityType, String entityId});

/// Attachments recorded against one entity, newest first.
final attachmentListProvider = FutureProvider.autoDispose
    .family<List<Attachment>, AttachmentEntityKey>((ref, key) async {
  final result = await ref
      .watch(attachmentRepositoryProvider)
      .list(key.entityType, key.entityId);
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// A signed URL to view one attachment — the bucket is private, so every
/// display needs a fresh, time-limited link rather than a public URL.
final attachmentSignedUrlProvider =
    FutureProvider.autoDispose.family<String, Attachment>((ref, attachment) async {
  final result = await ref
      .watch(attachmentRepositoryProvider)
      .signedUrl(attachment.storagePath);
  return result.when(
    success: (url) => url,
    failure: (f) => throw Exception(f.message),
  );
});
