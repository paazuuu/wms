import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ui/reading_swarm.dart';

Widget _app({bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: const Scaffold(body: ReadingSwarm()),
      ),
    );

String _time(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('reading-swarm-time'))).data!;

void main() {
  testWidgets('while the AI reads: the swarm goes over the page and the time counts up', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byKey(const ValueKey('reading-swarm')), findsOneWidget);
    expect(_time(tester), '0:00');
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(_time(tester), '0:02');
    // Gone with the reading: no ticker left running.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });

  testWidgets('less motion asked for: a still picture', (tester) async {
    await tester.pumpWidget(_app(still: true));
    await tester.pump(const Duration(seconds: 3));
    expect(_time(tester), '0:00');
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
