import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/data/delivery_note_scanner.dart';
import 'package:wms_mobile/features/delivery/data/remote_delivery_note_scanner.dart';
import 'package:wms_mobile/features/delivery/domain/ocr_line.dart';

class _StubScanner implements DeliveryNoteScanner {
  _StubScanner(this._result, {this.throwNetwork = false});

  final List<OcrLine> _result;
  final bool throwNetwork;
  int calls = 0;

  @override
  Future<List<OcrLine>> scan(String imagePath) async {
    calls++;
    if (throwNetwork) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/ocr/delivery-note'),
        reason: 'offline',
      );
    }
    return _result;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('uses the cloud result when the primary succeeds', () async {
    final primary = _StubScanner(const [OcrLine(janCode: '4902505632037')]);
    final fallback = _StubScanner(const []);
    final scanner =
        FallbackDeliveryNoteScanner(primary: primary, fallback: fallback);

    final result = await scanner.scan('/tmp/note.jpg');
    expect(result.single.janCode, '4902505632037');
    expect(primary.calls, 1);
    expect(fallback.calls, 0);
  });

  test('falls back to on-device OCR on a network error', () async {
    final primary = _StubScanner(const [], throwNetwork: true);
    final fallback = _StubScanner(const [OcrLine(janCode: '4901480241418')]);
    final scanner =
        FallbackDeliveryNoteScanner(primary: primary, fallback: fallback);

    final result = await scanner.scan('/tmp/note.jpg');
    expect(result.single.janCode, '4901480241418');
    expect(primary.calls, 1);
    expect(fallback.calls, 1);
  });
}
