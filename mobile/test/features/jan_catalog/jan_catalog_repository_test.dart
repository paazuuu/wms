import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/jan_catalog/data/jan_catalog_repository.dart';

import '../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter, String base) {
  final dio = Dio(BaseOptions(baseUrl: base));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  test('a catalog read 40 pages a call until it is done, told how far', () async {
    final calls = <String>[];
    var step = 0;
    final functions = _dio(FakeHttpClientAdapter((o) {
      calls.add(o.path);
      if (o.path == '/jan-catalog/sync') {
        return jsonResponseBody({
          'data': {'id': 7, 'url': 'u', 'next_page': 0}
        }, 200);
      }
      step++;
      expect((o.data as Map)['catalog_id'], 7);
      return step < 3
          ? jsonResponseBody({
              'data': {'done': false, 'catalog_id': 7, 'page': step * 40, 'pages': 100}
            }, 200)
          : jsonResponseBody({
              'data': {
                'done': true,
                'page': 100,
                'pages': 100,
                'catalog': {'id': 7, 'url': 'u', 'name': 'テスト総合カタログ', 'entry_count': 812, 'pages_read': 100},
              }
            }, 200);
    }), 'https://x.test/functions/v1');
    final repo = JanCatalogRepositoryImpl(
        functions, _dio(FakeHttpClientAdapter((o) => jsonResponseBody([], 200)), 'https://x.test/rest/v1'));
    final seen = <(int, int)>[];
    final r = await repo.sync('u', onProgress: (p, n) => seen.add((p, n)));
    expect(calls, ['/jan-catalog/sync', '/jan-catalog/step', '/jan-catalog/step', '/jan-catalog/step']);
    expect(seen, [(40, 100), (80, 100), (100, 100)]);
    expect((r as ApiSuccess<JanCatalog>).data.entryCount, 812);
  });

  test('a catalog read to its end with no JAN in it: said so', () async {
    final functions = _dio(FakeHttpClientAdapter((o) {
      if (o.path == '/jan-catalog/sync') {
        return jsonResponseBody({
          'data': {'id': 8, 'url': 'u'}
        }, 200);
      }
      return jsonResponseBody({
        'data': {
          'done': true,
          'page': 3,
          'pages': 3,
          'catalog': {'id': 8, 'url': 'u', 'entry_count': 0},
        }
      }, 200);
    }), 'https://x.test/functions/v1');
    final repo = JanCatalogRepositoryImpl(
        functions, _dio(FakeHttpClientAdapter((o) => jsonResponseBody([], 200)), 'https://x.test/rest/v1'));
    final r = await repo.sync('u');
    expect((r as ApiFailure).message, 'jan_catalog_empty');
  });
}
