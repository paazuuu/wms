import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/partners/data/trading_partner_repository.dart';
import 'package:wms_mobile/features/partners/domain/trading_partner.dart';

import '../../../support/fake_http_adapter.dart';

Dio _dio(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x.test/rest/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('TradingPartnerRepositoryImpl', () {
    test('list() posts the kind/search/status filter to list_trading_partners',
        () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody([
          {
            'id': 1,
            'name': 'テスト商事株式会社',
            'kind': 'both',
            'code': 'TST01',
            'status': 'active',
          }
        ], 200);
      });
      final repo = TradingPartnerRepositoryImpl(_dio(adapter));

      final result = await repo.list(
          kind: PartnerKind.customer, search: 'テスト', status: 'active');

      expect(captured.path, '/rpc/list_trading_partners');
      final body = captured.data as Map;
      expect(body['p_kind'], 'customer');
      expect(body['p_search'], 'テスト');
      expect(body['p_status'], 'active');
      result.when(
        success: (partners) {
          expect(partners, hasLength(1));
          expect(partners.single.name, 'テスト商事株式会社');
          expect(partners.single.kind, PartnerKind.both);
        },
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('create() posts every field to create_trading_partner', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(7, 200);
      });
      final repo = TradingPartnerRepositoryImpl(_dio(adapter));

      final result = await repo.create(
        name: 'テスト商事株式会社',
        kind: PartnerKind.supplier,
        code: 'TST01',
        contactName: '山田太郎',
        phone: '03-1234-5678',
        email: 'yamada@example.com',
      );

      expect(captured.path, '/rpc/create_trading_partner');
      final body = captured.data as Map;
      expect(body['p_name'], 'テスト商事株式会社');
      expect(body['p_kind'], 'supplier');
      expect(body['p_code'], 'TST01');
      expect(body['p_contact_name'], '山田太郎');
      expect(body['p_phone'], '03-1234-5678');
      expect(body['p_email'], 'yamada@example.com');
      result.when(
        success: (id) => expect(id, 7),
        failure: (f) => fail('expected success, got $f'),
      );
    });

    test('setStatus() posts id/status to set_trading_partner_status', () async {
      late RequestOptions captured;
      final adapter = FakeHttpClientAdapter((options) {
        captured = options;
        return jsonResponseBody(true, 200);
      });
      final repo = TradingPartnerRepositoryImpl(_dio(adapter));

      final result = await repo.setStatus(7, 'inactive');

      expect(captured.path, '/rpc/set_trading_partner_status');
      final body = captured.data as Map;
      expect(body['p_id'], 7);
      expect(body['p_status'], 'inactive');
      result.when(
        success: (ok) => expect(ok, isTrue),
        failure: (f) => fail('expected success, got $f'),
      );
    });
  });
}
