import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/inspection/data/inspection_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(dynamic data, {int status = 200}) => Response(
      data: data,
      statusCode: status,
      requestOptions: RequestOptions(path: '/'),
    );

void main() {
  late _MockDio dio;
  late InspectionRepositoryImpl repository;

  setUp(() {
    dio = _MockDio();
    repository = InspectionRepositoryImpl(dio);
  });

  test('list() maps the data array into Inspection models', () async {
    when(() => dio.get('/inspections',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => _response({
              'data': [
                {'id': 1, 'code': 'INS-000001', 'type': 'receiving', 'status': 'pending'},
                {'id': 2, 'code': 'INS-000002', 'type': 'shipping', 'status': 'passed'},
              ],
            }));

    final result = await repository.list();

    final data = (result as ApiSuccess).data;
    expect(data, hasLength(2));
    expect(data.first.code, 'INS-000001');
  });

  test('recordItem() surfaces a connection error as a null-status failure', () async {
    when(() => dio.post('/inspections/1/items', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/inspections/1/items'),
      type: DioExceptionType.connectionError,
    ));

    final result = await repository.recordItem(1, {'scanned_barcode': 'x'});

    expect(result, isA<ApiFailure>());
    expect((result as ApiFailure).statusCode, isNull);
  });

  test('recordItem() propagates Laravel validation errors with status', () async {
    when(() => dio.post('/inspections/1/items', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/inspections/1/items'),
      response: _response({
        'message': 'The given data was invalid.',
        'errors': {
          'actual_quantity': ['The actual quantity field is required.'],
        },
      }, status: 422),
    ));

    final result = await repository.recordItem(1, {});

    final failure = result as ApiFailure;
    expect(failure.statusCode, 422);
    expect(failure.errors?['actual_quantity'], isNotEmpty);
  });
}
