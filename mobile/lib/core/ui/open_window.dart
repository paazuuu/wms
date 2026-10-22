import 'open_window_io.dart' if (dart.library.js_interop) 'open_window_web.dart' as impl;

/// Opens this app at [hashPath] (e.g. `/import-view/12`) in a new browser
/// window, to keep beside the one in use. False where there are no windows
/// (the desktop and phone builds), so the caller opens it in place instead.
bool openAppWindow(String hashPath) => impl.openAppWindow(hashPath);
