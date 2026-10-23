import 'open_window_io.dart' if (dart.library.js_interop) 'open_window_web.dart' as impl;

/// Opens this app at [hashPath] (e.g. `/import-view/12`) in a new browser
/// window, to keep beside the one in use. False where there are no windows
/// (the desktop and phone builds), so the caller opens it in place instead.
bool openAppWindow(String hashPath) => impl.openAppWindow(hashPath);

/// A browser tab opened for a page of our own (not the app).
abstract class HtmlTab {
  /// Shows [html] in the tab.
  void show(String html);

  /// Closes the tab (when there turned out to be nothing to show).
  void close();
}

/// A new, empty browser tab — to be called straight from the click, before
/// anything is awaited, or the browser blocks it as a pop-up. Null where
/// there are no tabs, or when the browser blocked it: the caller then offers
/// the file to download instead.
HtmlTab? openHtmlTab() => impl.openHtmlTab();
