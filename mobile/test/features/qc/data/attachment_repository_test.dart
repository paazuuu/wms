import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/data/attachment_repository.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(String baseUrl, FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('AttachmentRepositoryImpl', () {
    test('list() filters the polymorphic table by entity', () async {
      late RequestOptions captured;
      final restAdapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'entity_type': 'inspection',
            'entity_id': '42',
            'storage_path': 'inspection/42/a.jpg',
            'content_type': 'image/jpeg',
            'created_at': '2026-01-01T00:00:00Z',
          }
        ], 200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', restAdapter),
        storageDio: _dio('https://x.test/storage/v1', FakeHttpClientAdapter(
            (_) => jsonResponseBody({}, 200))),
        bucket: 'inspection-attachments',
      );

      final result = await repo.list('inspection', '42');

      expect(captured.path, '/attachments');
      expect(captured.queryParameters['entity_type'], 'eq.inspection');
      expect(captured.queryParameters['entity_id'], 'eq.42');
      result.when(
        success: (attachments) {
          expect(attachments, hasLength(1));
          expect(attachments.single.id, 1);
          expect(attachments.single.storagePath, 'inspection/42/a.jpg');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('upload() writes bytes to Storage then records the metadata row',
        () async {
      RequestOptions? storageRequest;
      Uint8List? storageBytes;
      RequestOptions? rpcRequest;

      final storageAdapter = FakeHttpClientAdapter((options) {
        storageRequest = options;
        storageBytes = options.data is Uint8List
            ? options.data as Uint8List
            : Uint8List.fromList((options.data as List).cast<int>());
        return jsonResponseBody({'Key': 'inspection-attachments/x'}, 200);
      });
      final restAdapter = FakeHttpClientAdapter((options) {
        rpcRequest = options;
        return jsonResponseBody(7, 200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', restAdapter),
        storageDio: _dio('https://x.test/storage/v1', storageAdapter),
        bucket: 'inspection-attachments',
      );

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = await repo.upload(
        entityType: 'inspection',
        entityId: '42',
        bytes: bytes,
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
      );

      expect(storageRequest!.path, startsWith('/object/inspection-attachments/inspection/42/'));
      expect(storageRequest!.path, endsWith('_photo.jpg'));
      expect(storageRequest!.headers['Content-Type'], 'image/jpeg');
      expect(storageBytes, bytes);

      expect(rpcRequest!.path, '/rpc/record_attachment');
      final body = rpcRequest!.data as Map;
      expect(body['p_entity_type'], 'inspection');
      expect(body['p_entity_id'], '42');
      expect(body['p_content_type'], 'image/jpeg');
      expect(body['p_storage_path'], startsWith('inspection/42/'));

      result.when(
        success: (attachment) {
          expect(attachment.id, 7);
          expect(attachment.entityType, 'inspection');
          expect(attachment.storagePath, body['p_storage_path']);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('signedUrl() resolves a relative signed path against the storage base',
        () async {
      RequestOptions? captured;
      final storageAdapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(
            {'signedURL': '/object/sign/inspection-attachments/a.jpg?token=abc'},
            200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', FakeHttpClientAdapter(
            (_) => jsonResponseBody({}, 200))),
        storageDio: _dio('https://x.test/storage/v1', storageAdapter),
        bucket: 'inspection-attachments',
      );

      final result = await repo.signedUrl('a.jpg');

      expect(captured!.path, '/object/sign/inspection-attachments/a.jpg');
      result.when(
        success: (url) => expect(url,
            'https://x.test/storage/v1/object/sign/inspection-attachments/a.jpg?token=abc'),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
