import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/reports/data/report_repository.dart';
import 'package:wms_mobile/features/reports/domain/report.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('ReportRepositoryImpl', () {
    test('run() posts source/filters/limit to run_report', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody({
          'source': 'stock_movements',
          'rows': [
            {'id': 1, 'jan_code': '4988601001053', 'quantity': 7},
          ],
        }, 200);
      });
      final repo = ReportRepositoryImpl(_dio(adapter));

      final result = await repo.run(
        ReportSource.stockMovements,
        filters: {'warehouse_id': 1, 'jan_code': '4988601001053'},
        limit: 100,
      );

      expect(captured.path, '/rpc/run_report');
      final body = captured.data as Map;
      expect(body['p_source'], 'stock_movements');
      expect(body['p_limit'], 100);
      expect((body['p_filters'] as Map)['warehouse_id'], 1);
      result.when(
        success: (r) {
          expect(r.source, ReportSource.stockMovements);
          expect(r.rows, hasLength(1));
          expect(r.rows.single['jan_code'], '4988601001053');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('save() posts name/source/filters to save_report_definition', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(9, 200);
      });
      final repo = ReportRepositoryImpl(_dio(adapter));

      final result = await repo.save(
        name: 'テストレポート',
        source: ReportSource.purchaseOrders,
        filters: {'status': 'DRAFT'},
      );

      expect(captured.path, '/rpc/save_report_definition');
      final body = captured.data as Map;
      expect(body['p_name'], 'テストレポート');
      expect(body['p_source'], 'purchase_orders');
      expect((body['p_filters'] as Map)['status'], 'DRAFT');
      result.when(
        success: (id) => expect(id, 9),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('listSaved() parses list_report_definitions rows', () async {
      final adapter = FakeHttpClientAdapter((options) {
        expect(options.path, '/rpc/list_report_definitions');
        return jsonResponseBody([
          {
            'id': 1,
            'name': 'テストレポート',
            'source': 'work_orders',
            'filters': {'status': 'DRAFT'},
          }
        ], 200);
      });
      final repo = ReportRepositoryImpl(_dio(adapter));

      final result = await repo.listSaved();

      result.when(
        success: (defs) {
          expect(defs, hasLength(1));
          expect(defs.single.name, 'テストレポート');
          expect(defs.single.source, ReportSource.workOrders);
          expect(defs.single.filters['status'], 'DRAFT');
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
