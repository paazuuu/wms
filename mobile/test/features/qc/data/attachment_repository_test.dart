import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/qc/data/attachment_repository.dart';
import 'package:wms_mobile/features/qc/domain/attachment.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(String baseUrl, FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('AttachmentRepositoryImpl', () {
    test('list() reads through attachments_for, withdrawn rows excluded',
        () async {
      late RequestOptions captured;
      final restAdapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'attachment_id': 1,
            'entity_type': 'inspection',
            'entity_id': '42',
            'storage_path': 'inspection/42/a.jpg',
            'content_type': 'image/jpeg',
            'kind': 'QC_IMAGE',
            'caption': '破損箇所',
            'byte_size': 2048,
            'warehouse_id': 3,
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

      // The warehouse scoping and the withdrawn filter live on the server
      // (0070), so this is an RPC call, not a table read.
      expect(captured.path, '/rpc/attachments_for');
      final body = captured.data as Map;
      expect(body['p_entity_type'], 'inspection');
      expect(body['p_entity_id'], '42');
      expect(body['p_include_withdrawn'], isFalse);
      result.when(
        success: (attachments) {
          expect(attachments, hasLength(1));
          final a = attachments.single;
          // attachments_for names the key attachment_id, not id.
          expect(a.id, 1);
          expect(a.storagePath, 'inspection/42/a.jpg');
          expect(a.kind, AttachmentKind.qcImage);
          expect(a.caption, '破損箇所');
          expect(a.byteSize, 2048);
          expect(a.warehouseId, 3);
          expect(a.isWithdrawn, isFalse);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('list(includeWithdrawn: true) asks for the withdrawn ones too',
        () async {
      late RequestOptions captured;
      final restAdapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'attachment_id': 2,
            'entity_type': 'inspection',
            'entity_id': '42',
            'storage_path': 'inspection/42/b.jpg',
            'withdrawn_at': '2026-02-01T00:00:00Z',
          }
        ], 200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', restAdapter),
        storageDio: _dio('https://x.test/storage/v1', FakeHttpClientAdapter(
            (_) => jsonResponseBody({}, 200))),
        bucket: 'inspection-attachments',
      );

      final result = await repo.list('inspection', '42',
          includeWithdrawn: true);

      expect((captured.data as Map)['p_include_withdrawn'], isTrue);
      result.when(
        success: (attachments) {
          expect(attachments.single.isWithdrawn, isTrue);
          // No kind on the row: 0070's default, and an unknown code, both land
          // on `other` rather than throwing.
          expect(attachments.single.kind, AttachmentKind.other);
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

    test('upload() sends the kind, caption and byte size it was given',
        () async {
      RequestOptions? rpcRequest;
      final restAdapter = FakeHttpClientAdapter((options) {
        rpcRequest = options;
        return jsonResponseBody(11, 200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', restAdapter),
        storageDio: _dio('https://x.test/storage/v1', FakeHttpClientAdapter(
            (_) => jsonResponseBody({'Key': 'k'}, 200))),
        bucket: 'inspection-attachments',
      );

      final result = await repo.upload(
        entityType: 'reconciliation',
        entityId: '9',
        bytes: Uint8List.fromList(List.filled(120, 7)),
        fileName: 'note.jpg',
        contentType: 'image/jpeg',
        kind: AttachmentKind.deliveryNote,
        caption: '納品書',
        warehouseId: 3,
      );

      final body = rpcRequest!.data as Map;
      expect(body['p_kind'], 'DELIVERY_NOTE');
      expect(body['p_caption'], '納品書');
      // The client already knows the size, so the server never has to ask
      // Storage for it.
      expect(body['p_byte_size'], 120);
      expect(body['p_warehouse_id'], 3);

      result.when(
        success: (attachment) {
          expect(attachment.id, 11);
          expect(attachment.kind, AttachmentKind.deliveryNote);
          expect(attachment.caption, '納品書');
          expect(attachment.byteSize, 120);
          expect(attachment.warehouseId, 3);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('withdraw() calls the RPC rather than deleting the row', () async {
      RequestOptions? captured;
      final restAdapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = AttachmentRepositoryImpl(
        restDio: _dio('https://x.test/rest/v1', restAdapter),
        storageDio: _dio('https://x.test/storage/v1', FakeHttpClientAdapter(
            (_) => jsonResponseBody({}, 200))),
        bucket: 'inspection-attachments',
      );

      final result = await repo.withdraw(7, reason: '誤アップロード');

      expect(captured!.method, 'POST');
      expect(captured!.path, '/rpc/withdraw_attachment');
      expect((captured!.data as Map)['p_attachment_id'], 7);
      expect((captured!.data as Map)['p_reason'], '誤アップロード');
      result.when(
        success: (ok) => expect(ok, isTrue),
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
