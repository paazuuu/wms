import 'package:shared_preferences/shared_preferences.dart';

final _kept = <String, String>{};
SharedPreferences? _prefs;

/// The phone and desktop apps: what was kept on the device, read once at
/// start ([initLocalPrefs]) so a read is immediate; a write goes to the
/// device as well. Without it (a test), kept for the run only.
Future<void> initLocalPrefs() async {
  try {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    for (final k in p.getKeys()) {
      final v = p.get(k);
      if (v is String) _kept[k] = v;
    }
  } catch (_) {
    // Nowhere to keep them: for this run only.
  }
}

String? readLocalPref(String key) => _kept[key];

void writeLocalPref(String key, String? value) {
  if (value == null) {
    _kept.remove(key);
    _prefs?.remove(key);
  } else {
    _kept[key] = value;
    _prefs?.setString(key, value);
  }
}
