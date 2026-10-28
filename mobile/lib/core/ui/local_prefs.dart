import 'local_prefs_io.dart' if (dart.library.js_interop) 'local_prefs_web.dart' as impl;

/// A small setting kept in this browser (localStorage): a list's column
/// widths and the like. Null when there is none, or nowhere to keep it.
String? readLocalPref(String key) => impl.readLocalPref(key);

void writeLocalPref(String key, String? value) => impl.writeLocalPref(key, value);
