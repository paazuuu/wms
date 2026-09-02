import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/delivery_note_parser.dart';
import '../domain/ocr_line.dart';
import 'delivery_note_scanner.dart';

/// On-device OCR via Google ML Kit, using the Japanese script model so the
/// mixed Japanese/Latin note is recognized. Runs entirely offline and serves as
/// the fallback when the cloud vision OCR is unreachable. It only recovers JANs
/// (no product names/quantities), so counts fall back to the planned quantity.
class MlKitDeliveryNoteScanner implements DeliveryNoteScanner {
  MlKitDeliveryNoteScanner()
      : _recognizer =
            TextRecognizer(script: TextRecognitionScript.japanese);

  final TextRecognizer _recognizer;

  @override
  Future<List<OcrLine>> scan(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    final textLines = <String>[
      for (final block in recognized.blocks)
        for (final line in block.lines) line.text,
    ];
    return parseDeliveryNoteText(textLines);
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
