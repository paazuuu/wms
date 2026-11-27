import 'package:web/web.dart' as web;

/// The browser's localStorage needs no start.
Future<void> initLocalPrefs() async {}

String? readLocalPref(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeLocalPref(String key, String? value) {
  try {
    if (value == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
    }
  } catch (_) {
    // A private window, storage off: the widths last for this visit only.
  }
}
