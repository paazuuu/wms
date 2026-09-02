import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/delivery_note_parser.dart';
import '../domain/ocr_line.dart';

/// Reads a delivery-note photo and returns the JANs found on it. Kept behind an
/// interface so the pure parsing logic can be tested without the ML Kit engine
/// and so the assist can be swapped or stubbed on unsupported platforms.
abstract class DeliveryNoteScanner {
  /// Recognizes text in the image at [imagePath] and extracts JAN candidates.
  Future<List<OcrLine>> scan(String imagePath);

  /// Releases native resources. Safe to call more than once.
  Future<void> dispose();
}

/// On-device OCR via Google ML Kit, using the Japanese script model so the
/// mixed Japanese/Latin delivery note is recognized. Runs entirely offline.
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
