import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_error_text.dart';
import '../../../core/api/api_result.dart';
import '../../../l10n/app_localizations.dart';
import '../../shipment/application/sender_profile_controller.dart';
import '../data/outbound_excel.dart';
import '../data/outbound_repository.dart';

/// Where a file goes: the save dialog (a download on the web), or a test's
/// list.
typedef SaveFile = Future<void> Function(String fileName, Uint8List bytes);

Future<void> saveWithPicker(String fileName, Uint8List bytes) async {
  await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
  );
}

/// Overridden in tests so nothing reaches for the platform.
final saveFileProvider = Provider<SaveFile>((_) => saveWithPicker);

void _snack(ScaffoldMessengerState m, String text) => m
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// One shipment's sheet — destination, sender and lines — as Excel, ready
/// to send to the other company. Works for any shipment.
Future<void> downloadShipmentSheet(BuildContext context, WidgetRef ref, int shipmentId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(outboundRepositoryProvider).sheet(shipmentId);
  switch (r) {
    case ApiSuccess(:final data):
      final bytes = buildShipmentSheetXlsx(
        number: data.shipmentNumber,
        to: data.shipTo,
        lines: data.lines,
        sender: ref.read(senderProfileControllerProvider),
        shipDate: data.shipDate,
        note: data.note,
        warehouseName: data.warehouseName,
        carrier: data.carrier,
        trackingNumber: data.trackingNumber,
      );
      await ref.read(saveFileProvider)(shipmentSheetFileName(data.shipmentNumber, data.shipTo?.name), bytes);
      _snack(messenger, l10n.obExcelSaved);
    case ApiFailure(:final message):
      _snack(messenger, humanizeApiErrorMessage(l10n, message));
  }
}

/// Every product's stock as Excel: [warehouseId], or every warehouse the
/// person may see when null.
Future<void> downloadStockList(BuildContext context, WidgetRef ref, {int? warehouseId, String? warehouseName}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref.read(outboundRepositoryProvider).stockExport(warehouseId: warehouseId);
  switch (r) {
    case ApiSuccess(:final data):
      final bytes = buildStockListXlsx(data, warehouseName: warehouseName);
      final day = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await ref.read(saveFileProvider)('在庫一覧_${warehouseName ?? '全倉庫'}_$day.xlsx'.replaceAll(RegExp(r'\s+'), '_'), bytes);
      _snack(messenger, l10n.obStockSaved(data.length));
    case ApiFailure(:final message):
      _snack(messenger, humanizeApiErrorMessage(l10n, message));
  }
}
