import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_result.dart';
import '../../l10n/app_localizations.dart';
import '../master_import/data/master_import_repository.dart';
import '../master_import/domain/master_import.dart';
import '../qc/domain/inspection.dart' show normalizeJan;

/// A delivery note (納品書) in hand, read by the AI (0178): what it lists —
/// JAN, name, maker, 品番 and how many — to see with the goods' pictures, or
/// to tick the lines of an inspection.
class NoteLine extends Equatable {
  const NoteLine({required this.lineNo, required this.jan, this.name = '', this.maker = '', this.code = '', this.quantity, this.unit = ''});

  final int lineNo;

  /// The JAN as a number to match ('' when none could be read).
  final String jan;
  final String name;
  final String maker;
  final String code;
  final int? quantity;
  final String unit;

  factory NoteLine.of(MasterLine l) => NoteLine(
        lineNo: l.lineNo,
        jan: normalizeJan(l.janCode) ?? '',
        name: l.supplierName.isNotEmpty ? l.supplierName : l.name,
        maker: l.maker,
        code: l.productCode,
        quantity: int.tryParse(l.quantity.replaceAll(RegExp(r'[,，\s]'), '')),
        unit: l.unit,
      );

  @override
  List<Object?> get props => [lineNo, jan, name, maker, code, quantity, unit];
}

/// A note photographed or chosen: its name and bytes, or null.
typedef PickNote = Future<({String name, Uint8List bytes})?> Function({required bool camera});

Future<({String name, Uint8List bytes})?> _pick({required bool camera}) async {
  if (camera) {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, maxHeight: 2400, imageQuality: 85);
    if (shot == null) return null;
    final name = shot.name.isEmpty ? '納品書.jpg' : shot.name;
    return (name: name, bytes: await shot.readAsBytes());
  }
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
  );
  final f = r?.files.firstOrNull;
  if (f?.bytes == null) return null;
  return (name: f!.name, bytes: f.bytes!);
}

/// Overridden in tests so nothing reaches for the camera.
final deliveryNotePickerProvider = Provider<PickNote>((_) => _pick);

/// The note read by the AI and kept as evidence (purpose ocr): its lines
/// with a JAN or a name.
Future<ApiResult<List<NoteLine>>> readDeliveryNote(WidgetRef ref, String fileName, Uint8List bytes) async =>
    switch (await readDeliveryNoteKept(ref, fileName, bytes)) {
      ApiSuccess(:final data) => ApiSuccess(data.lines),
      ApiFailure(:final message) => ApiFailure(message: message),
    };

/// A note as read: its lines, the id of the copy kept (to keep it with an
/// inspection), and who it is from and its date, as printed.
typedef NoteRead = ({List<NoteLine> lines, int? documentId, String? supplier, String? date});

/// The same, with the id of the copy kept and the note's header.
Future<ApiResult<NoteRead>> readDeliveryNoteKept(
    WidgetRef ref, String fileName, Uint8List bytes) async {
  final r = await ref.read(masterImportRepositoryProvider).read(fileName, bytes, keepRows: true, purpose: 'ocr');
  return switch (r) {
    ApiSuccess(:final data) => ApiSuccess((
        lines: [
          for (final l in data.lines)
            if (l.janCode.trim().isNotEmpty || l.supplierName.trim().isNotEmpty || l.productCode.trim().isNotEmpty)
              NoteLine.of(l),
        ],
        documentId: data.documentId,
        supplier: data.supplierName,
        date: data.docDate,
      )),
    ApiFailure(:final message) => ApiFailure(message: message),
  };
}

/// Asks: photograph the note, or choose its file.
Future<bool?> askCameraOrFile(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: const ValueKey('dn-pick-camera'),
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.dnTakePhoto),
          onTap: () => Navigator.pop(c, true),
        ),
        ListTile(
          key: const ValueKey('dn-pick-file'),
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(l10n.dnChooseFile),
          onTap: () => Navigator.pop(c, false),
        ),
      ]),
    ),
  );
}
