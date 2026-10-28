import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:printing/printing.dart';

import 'pdf_text.dart' show PdfTextReader;

// pdf.js is the one the printing package loads (window.pdfjsLib); these
// helpers read a document's text with where each run sits.
const _helpers = r'''
window.__wmsPdfOpen = async function (bytes) {
  if (window.__wmsPdfDoc) { try { await window.__wmsPdfDoc.destroy(); } catch (e) {} }
  window.__wmsPdfDoc = await pdfjsLib.getDocument({ data: bytes }).promise;
  return window.__wmsPdfDoc.numPages;
};
window.__wmsPdfPage = async function (n) {
  const page = await window.__wmsPdfDoc.getPage(n);
  const vp = page.getViewport({ scale: 1 });
  const tc = await page.getTextContent();
  const out = [];
  for (const it of tc.items) {
    if (!it.str || !it.str.trim()) continue;
    const t = it.transform;
    out.push([Math.round(t[4] * 10) / 10, Math.round((vp.height - t[5]) * 10) / 10,
              Math.round((it.width || 0) * 10) / 10, it.str]);
  }
  page.cleanup();
  return JSON.stringify(out);
};
window.__wmsPdfClose = async function () {
  if (window.__wmsPdfDoc) { try { await window.__wmsPdfDoc.destroy(); } catch (e) {} window.__wmsPdfDoc = null; }
};
window.__wmsSha256 = async function (bytes) {
  const d = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return Array.from(d).map(function (b) { return b.toString(16).padStart(2, '0'); }).join('');
};
''';

class _WebPdfText implements PdfTextReader {
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    // Loads pdf.js the way the rest of the app has it.
    await Printing.info();
    globalContext.callMethod('eval'.toJS, _helpers.toJS);
    _ready = true;
  }

  @override
  Future<int> open(Uint8List bytes) async {
    await _ensure();
    // A copy: pdf.js takes the buffer it is given.
    final n =
        await globalContext.callMethod<JSPromise<JSNumber>>('__wmsPdfOpen'.toJS, Uint8List.fromList(bytes).toJS).toDart;
    return n.toDartInt;
  }

  @override
  Future<List<List<Object>>> page(int n) async {
    final s = await globalContext.callMethod<JSPromise<JSString>>('__wmsPdfPage'.toJS, n.toJS).toDart;
    return [for (final r in jsonDecode(s.toDart) as List) (r as List).cast<Object>()];
  }

  @override
  Future<String> sha256(Uint8List bytes) async {
    await _ensure();
    final s =
        await globalContext.callMethod<JSPromise<JSString>>('__wmsSha256'.toJS, Uint8List.fromList(bytes).toJS).toDart;
    return s.toDart;
  }

  @override
  Future<void> close() async {
    if (!_ready) return;
    await globalContext.callMethod<JSPromise<JSAny?>>('__wmsPdfClose'.toJS).toDart;
  }
}

PdfTextReader? pdfTextReader() => _WebPdfText();
