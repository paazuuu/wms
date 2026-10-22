import 'package:web/web.dart' as web;

bool openAppWindow(String hashPath) {
  final here = Uri.base;
  final url = '${here.origin}${here.path}#$hashPath';
  web.window.open(url, '_blank', 'popup=yes,width=1400,height=900');
  return true;
}
