import 'save_bytes.dart';
import 'dart:convert';
import 'dart:typed_data';


/// Builds a CSV document from [headers] + [rows] and saves it ([saveBytes]:
/// a download in the browser, the save dialog elsewhere). A UTF-8 BOM is prepended so Excel on Windows opens
/// Japanese text correctly instead of guessing the wrong encoding.
///
/// Returns the path/uri the file was saved to, or null if the user cancelled.
Future<String?> exportCsv({
  required String fileName,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final bytes = csvBytes(headers: headers, rows: rows);
  return saveBytes(fileName, bytes);
}

/// The CSV document as UTF-8 bytes with a leading BOM. Split out from
/// [exportCsv] so the formatting logic is testable without a file picker.
Uint8List csvBytes({
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_csvField).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(_csvField).join(','));
  }
  const bom = [0xEF, 0xBB, 0xBF];
  return Uint8List.fromList([...bom, ...utf8.encode(buffer.toString())]);
}

/// Quotes a field only when it needs it (contains a comma, quote or newline),
/// doubling embedded quotes per RFC 4180.
String _csvField(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(RegExp(r'[",\n\r]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
