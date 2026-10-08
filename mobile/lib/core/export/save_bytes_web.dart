import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A browser download: the bytes as a blob, clicked through a hidden link.
Future<String?> saveBytes(String fileName, Uint8List bytes, {required String mimeType}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  // Give the browser a moment to start the download before letting go.
  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return fileName;
}
