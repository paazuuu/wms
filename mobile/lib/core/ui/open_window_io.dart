import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

import 'open_window.dart' show HtmlTab;

/// No windows of our own in the phone and desktop apps: the caller opens the
/// screen in place.
bool openAppWindow(String hashPath) => false;

/// No tabs either: the caller offers the file to save instead.
HtmlTab? openHtmlTab() => null;

/// A page elsewhere (a maker's catalog, 国税庁の公表サイト) opens in the
/// phone's browser. False for what is not a web address, so the caller
/// offers to copy it.
bool openExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return false;
  unawaited(launchUrl(uri, mode: LaunchMode.externalApplication).catchError((Object _) => false));
  return true;
}
