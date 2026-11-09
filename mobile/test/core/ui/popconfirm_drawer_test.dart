import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/edit_drawer.dart';
import 'package:wms_mobile/core/ui/popconfirm.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('popconfirm opens beside the button and answers OK, cancel or Esc', (tester) async {
    PopconfirmAnchor.install();
    final answers = <bool>[];
    await pumpApp(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 60),
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('remove'),
                onPressed: () async => answers.add(await showPopconfirm(context,
                    title: 'このメモを外しますか？', message: '添付も外れます', okLabel: '外す', danger: true)),
                child: const Text('外す…'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('popconfirm')), findsOneWidget);
    expect(find.text('このメモを外しますか？'), findsOneWidget);
    expect(find.text('添付も外れます'), findsOneWidget);
    // Beside the button, not in the middle of the screen.
    final button = tester.getRect(find.byKey(const ValueKey('remove')));
    final pop = tester.getRect(find.byKey(const ValueKey('popconfirm')));
    expect(pop.top, greaterThan(button.top));
    expect(pop.top, lessThan(button.bottom + 40));
    expect(pop.left, lessThan(button.right));

    await tester.tap(find.byKey(const ValueKey('popconfirm-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('popconfirm-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(answers, [true, false, false]);
    expect(find.byKey(const ValueKey('popconfirm')), findsNothing);
  });

  testWidgets('an edit drawer slides in from the right, keeps the page beside it and returns its value', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? got = 'unset';
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('edit'),
            onPressed: () async => got = await showEditDrawer<String>(
              context,
              builder: (c) => EditDrawer(
                title: const Text('出荷先カード'),
                content: const TextField(key: ValueKey('name')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('キャンセル')),
                  FilledButton(key: const ValueKey('save'), onPressed: () => Navigator.pop(c, 'saved'), child: const Text('保存')),
                ],
              ),
            ),
            child: const Text('編集'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('edit')));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(const ValueKey('edit-drawer')));
    expect(panel.right, 1400);
    expect(panel.width, 520);
    expect(panel.height, 900);
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();
    expect(got, 'saved');

    // A click on the page beside it does not close it.
    await tester.tap(find.byKey(const ValueKey('edit')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 450));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-drawer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.pumpAndSettle();

    // Esc and the close button leave without a value.
    await tester.tap(find.byKey(const ValueKey('edit')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(got, isNull);
    got = 'unset';
    await tester.tap(find.byKey(const ValueKey('edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-drawer-close')));
    await tester.pumpAndSettle();
    expect(got, isNull);
    expect(find.byKey(const ValueKey('edit-drawer')), findsNothing);
  });
}
