import 'package:web/web.dart' as web;

/// The browser, as it calls itself.
String clientInfo() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}

/// The screen open (the address after #), without anything after '?'.
String placeNow() {
  try {
    final hash = web.window.location.hash;
    final q = hash.indexOf('?');
    return q < 0 ? hash : hash.substring(0, q);
  } catch (_) {
    return '';
  }
}
