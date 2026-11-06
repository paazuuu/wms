import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// One row to frame in a PDF: its row number and the words it holds (品番,
/// JAN, name, quantity) to find it by.
typedef PdfMark = ({int i, List<String> texts});

/// The PDF as it came, with a red frame round each row not read (mark-pdf).
abstract class MarkedFileRepository {
  Future<ApiResult<({Uint8List bytes, int marked, int missing})>> markPdf(
      String fileName, Uint8List bytes, List<PdfMark> marks);
}

class MarkedFileRepositoryImpl implements MarkedFileRepository {
  MarkedFileRepositoryImpl(this._functions);

  final Dio _functions;

  @override
  Future<ApiResult<({Uint8List bytes, int marked, int missing})>> markPdf(
      String fileName, Uint8List bytes, List<PdfMark> marks) async {
    try {
      final r = await _functions.post<List<int>>(
        '/mark-pdf',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType('application', 'pdf')),
          'marks': jsonEncode([
            for (final m in marks) {'i': m.i, 'texts': m.texts},
          ]),
        }),
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 3)),
      );
      int count(String h) => int.tryParse(r.headers.value(h) ?? '') ?? 0;
      return ApiSuccess((
        bytes: Uint8List.fromList(r.data ?? const []),
        marked: count('x-marked'),
        missing: count('x-missing'),
      ));
    } on DioException catch (e) {
      return mapDioError<({Uint8List bytes, int marked, int missing})>(e);
    }
  }
}

final markedFileRepositoryProvider =
    Provider<MarkedFileRepository>((ref) => MarkedFileRepositoryImpl(ref.watch(deliveryDioProvider)));
