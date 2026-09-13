import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/state_views.dart';

import '../../support/harness.dart';

void main() {
  testWidgets(
      'a raw "not permitted" RPC error renders as a friendly message (§34)',
      (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: ErrorStateView(
          message: 'Exception: not permitted: purchase_order.manage required',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('この操作を行う権限がありません。'), findsOneWidget);
    expect(find.textContaining('not permitted'), findsNothing);
  });

  testWidgets('an unrelated error message is shown as-is', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: ErrorStateView(
          message: 'No connection to the server.',
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('No connection to the server.'), findsOneWidget);
  });
}
