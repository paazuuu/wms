import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../domain/delivery_note.dart';

/// Reads the supplier's delivery note from a photo for inspection (0101):
/// every line the OCR found — JAN when printed, otherwise the supplier's code
/// and name — with its quantity. Unlike the receiving assist, lines without a
/// JAN are kept: the server matches them through the supplier's own names.
abstract class DeliveryNoteReader {
  Future<List<DeliveryNoteLine>> read(String imagePath, {int? deliveryPlanId});
}

class RemoteDeliveryNoteReader implements DeliveryNoteReader {
  RemoteDeliveryNoteReader(this._dio);

  final Dio _dio;

  @override
  Future<List<DeliveryNoteLine>> read(String imagePath, {int? deliveryPlanId}) async {
    final form = FormData();
    form.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    form.fields.add(const MapEntry('provider', 'gemini'));
    if (deliveryPlanId != null) {
      form.fields.add(MapEntry('plan_id', '$deliveryPlanId'));
    }
    final response = await _dio.post('/ocr-delivery-note', data: form);
    return parseDeliveryNoteLines(response.data);
  }
}

final deliveryNoteReaderProvider = Provider<DeliveryNoteReader>(
    (ref) => RemoteDeliveryNoteReader(ref.watch(deliveryDioProvider)));
