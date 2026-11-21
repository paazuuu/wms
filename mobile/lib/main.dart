import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/errors/error_reporter.dart';
import 'features/delivery/application/delivery_providers.dart' show restDioProvider;

void main() {
  final container = ProviderContainer();
  // エラーログ (0227): what goes wrong is kept on the server, as the
  // signed-in person (nothing is kept before sign-in).
  installErrorReporting();
  ErrorReporter.instance.sender = (report) async {
    final r = await container.read(restDioProvider).post('/rpc/app_error_log', data: {'p': report});
    return r.data == true;
  };
  runApp(UncontrolledProviderScope(container: container, child: const WmsApp()));
}
