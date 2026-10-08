import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBytes(String fileName, Uint8List bytes, {required String mimeType}) {
  final ext = fileName.contains('.') ? fileName.split('.').last : null;
  return FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: ext == null ? FileType.any : FileType.custom,
    allowedExtensions: ext == null ? null : [ext],
  );
}
