import 'package:dio/dio.dart';

import '../domain/ocr_provider.dart';
import '../domain/ocr_line.dart';
import '../domain/vision_ocr_parser.dart';
import 'delivery_note_scanner.dart';

/// Sends the delivery-note photo to the backend's cloud vision OCR (Gemini by
/// default) and returns the extracted lines. The model's API key stays on the
/// server — the client only uploads the image and names a preferred provider —
/// so no secret ships in the app.
class RemoteDeliveryNoteScanner implements DeliveryNoteScanner {
  RemoteDeliveryNoteScanner(this._dio, {this.provider = kDefaultOcrProvider});

  final Dio _dio;
  final OcrProvider provider;

  @override
  Future<List<OcrLine>> scan(String imagePath) async {
    final form = FormData();
    form.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    form.fields.add(MapEntry('provider', provider.wire));

    final response = await _dio.post('/ocr-delivery-note', data: form);
    final data = response.data;
    if (data is Map<String, dynamic>) return parseVisionOcrResponse(data);
    return const [];
  }

  @override
  Future<void> dispose() async {}
}

/// Tries the cloud vision OCR first and, only on a network/transport error,
/// falls back to the on-device engine — so the assist keeps working offline
/// while preferring the far more accurate cloud read when connected.
class FallbackDeliveryNoteScanner implements DeliveryNoteScanner {
  FallbackDeliveryNoteScanner({required this.primary, required this.fallback});

  final DeliveryNoteScanner primary;
  final DeliveryNoteScanner fallback;

  @override
  Future<List<OcrLine>> scan(String imagePath) async {
    try {
      return await primary.scan(imagePath);
    } on DioException {
      return fallback.scan(imagePath);
    }
  }

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await fallback.dispose();
  }
}
