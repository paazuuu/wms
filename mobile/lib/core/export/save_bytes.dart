import 'dart:typed_data';

import 'save_bytes_io.dart' if (dart.library.js_interop) 'save_bytes_web.dart' as impl;

/// Saves [bytes] as [fileName]: a download in the browser, the system's save
/// dialog elsewhere. One place for every "download" in the app — the
/// file_picker in use has no save dialog on the web, so asking it there
/// fails and nothing is saved.
///
/// Returns where it went (a path), the file name for a browser download, or
/// null when the person cancelled the dialog.
Future<String?> saveBytes(String fileName, Uint8List bytes, {String? mimeType}) =>
    impl.saveBytes(fileName, bytes, mimeType: mimeType ?? mimeTypeFor(fileName));

/// The type a browser should be told a file is, by its extension.
String mimeTypeFor(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xls' => 'application/vnd.ms-excel',
    'csv' => 'text/csv;charset=utf-8',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'json' => 'application/json',
    'txt' => 'text/plain;charset=utf-8',
    _ => 'application/octet-stream',
  };
}
