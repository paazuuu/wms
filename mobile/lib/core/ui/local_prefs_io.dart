final _kept = <String, String>{};

/// Outside a browser: kept for the run only.
String? readLocalPref(String key) => _kept[key];

void writeLocalPref(String key, String? value) => value == null ? _kept.remove(key) : _kept[key] = value;
