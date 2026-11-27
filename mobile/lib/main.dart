import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/errors/error_reporter.dart';
import 'core/router/app_router.dart' show goRouterProvider;
import 'core/ui/local_prefs.dart' show initLocalPrefs;
import 'features/delivery/application/delivery_providers.dart' show restDioProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Settings kept on the phone (column widths and the like) read before the
  // first screen; a browser keeps them itself.
  await initLocalPrefs();
  final container = ProviderContainer();
  // エラーログ (0227): what goes wrong is kept on the server, as the
  // signed-in person (nothing is kept before sign-in).
  installErrorReporting();
  ErrorReporter.instance.sender = (report) async {
    final r = await container.read(restDioProvider).post('/rpc/app_error_log', data: {'p': report});
    return r.data == true;
  };
  ErrorReporter.instance.place = () => container.read(goRouterProvider).routerDelegate.currentConfiguration.uri.path;
  runApp(UncontrolledProviderScope(container: container, child: const WmsApp()));
}
