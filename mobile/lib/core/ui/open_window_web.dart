import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'open_window.dart' show HtmlTab;

bool openAppWindow(String hashPath) {
  final here = Uri.base;
  final url = '${here.origin}${here.path}#$hashPath';
  web.window.open(url, '_blank', 'popup=yes,width=1400,height=900');
  return true;
}

class _Tab implements HtmlTab {
  _Tab(this._w);

  final web.Window _w;

  @override
  void show(String html) {
    final blob = web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html;charset=utf-8'));
    _w.location.href = web.URL.createObjectURL(blob);
  }

  @override
  void close() => _w.close();
}

HtmlTab? openHtmlTab() {
  final w = web.window.open('', '_blank');
  return w == null ? null : _Tab(w);
}

bool openExternalUrl(String url) {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https') return false;
  // With noopener the browser gives no window back; the tab opens all the same.
  web.window.open(url, '_blank', 'noopener');
  return true;
}
