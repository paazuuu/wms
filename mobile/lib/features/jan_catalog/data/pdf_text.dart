import 'dart:typed_data';

import 'pdf_text_io.dart' if (dart.library.js_interop) 'pdf_text_web.dart' as impl;

/// A PDF's text read in the browser (pdf.js), page by page, each run as
/// [x, y down the page, width, text] — what the jan-catalog function places
/// JANs and weights by. A catalog of 300 pages is too big to send whole.
abstract class PdfTextReader {
  /// Opens [bytes]; how many pages it has.
  Future<int> open(Uint8List bytes);

  /// Page [n] (from 1): its runs of text.
  Future<List<List<Object>>> page(int n);

  /// SHA-256 of [bytes], as hex: the same file read twice is one catalog.
  Future<String> sha256(Uint8List bytes);

  Future<void> close();
}

/// Null where there is no pdf.js (the phone and desktop builds): a PDF
/// catalog is read from a PC's browser.
PdfTextReader? pdfTextReader() => impl.pdfTextReader();
