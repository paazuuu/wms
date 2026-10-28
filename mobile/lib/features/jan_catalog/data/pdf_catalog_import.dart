import 'dart:typed_data';

import '../../../core/api/api_result.dart';
import 'jan_catalog_repository.dart';
import 'pdf_text.dart';

/// How far a PDF catalog has been read.
typedef PdfImportProgress = ({int page, int pages, int entries, int weights});

/// Pages sent to the server at once, and the most runs of text in one send.
const pdfPagesAtOnce = 10;
const pdfItemsAtOnce = 60000;

/// A PDF catalog read page by page in the browser and its text sent on, a
/// few pages at a time; the catalog as it came to, or why not.
Future<ApiResult<JanCatalog>> importPdfCatalog({
  required JanCatalogRepository repo,
  required PdfTextReader reader,
  required Uint8List bytes,
  required String fileName,
  String? name,
  String? maker,
  String? url,
  void Function(PdfImportProgress)? onProgress,
}) async {
  try {
    final pages = await reader.open(bytes);
    final hash = await reader.sha256(bytes);
    final start = await repo.pdfStart(PdfCatalogStart(
      sha256: hash,
      fileName: fileName,
      pageCount: pages,
      name: (name ?? '').trim().isEmpty ? fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '') : name,
      maker: maker,
      url: url,
    ));
    final int id;
    switch (start) {
      case ApiSuccess(:final data):
        id = data.id;
      case ApiFailure(:final message, :final statusCode):
        return ApiFailure(message: message, statusCode: statusCode);
    }
    var entries = 0, weights = 0;
    var batch = <PdfPageText>[];
    var items = 0;
    Future<ApiFailure<JanCatalog>?> send() async {
      if (batch.isEmpty) return null;
      final r = await repo.pdfPages(id, batch);
      batch = [];
      items = 0;
      switch (r) {
        case ApiSuccess(:final data):
          entries += data.entries;
          weights += data.weights;
          return null;
        case ApiFailure(:final message, :final statusCode):
          return ApiFailure(message: message, statusCode: statusCode);
      }
    }

    for (var n = 1; n <= pages; n++) {
      final runs = await reader.page(n);
      if (runs.isNotEmpty) {
        batch.add(PdfPageText(index: n, items: runs));
        items += runs.length;
      }
      if (batch.length >= pdfPagesAtOnce || items >= pdfItemsAtOnce) {
        if (await send() case final f?) return f;
      }
      onProgress?.call((page: n, pages: pages, entries: entries, weights: weights));
    }
    if (await send() case final f?) return f;
    onProgress?.call((page: pages, pages: pages, entries: entries, weights: weights));
    return await repo.pdfFinish(id, pages);
  } catch (e) {
    return ApiFailure(message: 'pdf_unreadable: $e');
  } finally {
    await reader.close();
  }
}
