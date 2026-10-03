import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/selectable_app.dart';

/// The app wraps its pages from `MaterialApp.builder`, above the Navigator.
Widget _app(Widget home) => MaterialApp(
      builder: (context, child) => SelectableApp(child: child ?? const SizedBox.shrink()),
      home: home,
    );

void main() {
  testWidgets('pages under the app builder are selectable, without errors', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: Text('4901681233922'))));
    expect(tester.takeException(), isNull);
    expect(find.byType(SelectionArea), findsOneWidget);
    // Never a Tab stop: the browser focusing the window at start-up looks
    // for the first one before the page is laid out.
    expect(tester.widget<SelectionArea>(find.byType(SelectionArea)).focusNode!.skipTraversal, isTrue);
    expect(find.text('4901681233922'), findsOneWidget);

    // Selecting text opens its handles in the app's own overlay.
    await tester.longPress(find.text('4901681233922'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new page and a rebuilt app still show through', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (context, child) => SelectableApp(child: child!),
      home: const Scaffold(body: Text('first')),
    ));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('second'))));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    // The app rebuilt with another home (a locale or theme change does this).
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: SelectableApp(child: Column(children: [const Text('banner'), Expanded(child: child!)])),
      ),
      home: const Scaffold(body: Text('first')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('banner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
