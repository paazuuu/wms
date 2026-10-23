import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/selectable_app.dart';

/// The app wraps its pages from `MaterialApp.builder`, above the Navigator.
Widget _app(Widget home) => MaterialApp(
      builder: (context, child) => SelectableApp(child: child ?? const SizedBox.shrink()),
      home: home,
    );

/// Drags the mouse along the middle of [text], then copies, and returns
/// what reached the clipboard.
Future<String?> _dragAndCopy(WidgetTester tester, Finder text) async {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  final r = tester.getRect(text);
  final g = await tester.startGesture(r.centerLeft + const Offset(1, 0), kind: PointerDeviceKind.mouse);
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(r.centerLeft + Offset(1 + i * (r.width - 2) / 10, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  return copied;
}

/// A long menu beside a page, the way the shell lays them out.
Widget _besideLongColumn() {
  Widget pane(Widget c) => SelectablePane(child: c);
  return _app(Scaffold(
    body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 200, child: pane(Column(children: [
        const Text('WMS'),
        Expanded(child: ListView(children: [
          for (var i = 0; i < 60; i++) ListTile(title: Text('menu $i'), onTap: () {}),
        ])),
      ]))),
      Expanded(child: pane(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ファイルから在庫登録'),
        Expanded(child: ListView(children: const [SizedBox(height: 100), Text('4909999000014 テストペン')])),
      ]))),
    ]),
  ));
}

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

  testWidgets('beside a long column, a drag copies what is under the mouse', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // In the browser, one area for the whole screen let the menu running
    // past the bottom take the press, and the page beside it copied nothing.
    // Each column its own area: the drag copies the text under the mouse.
    await tester.pumpWidget(_besideLongColumn());
    await tester.pumpAndSettle();
    expect(await _dragAndCopy(tester, find.text('4909999000014 テストペン')), '4909999000014 テストペン');
    expect(await _dragAndCopy(tester, find.text('menu 3')), 'menu 3');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
