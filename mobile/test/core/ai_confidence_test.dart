import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ai/ai_confidence.dart';
import 'package:wms_mobile/core/ai/ai_settings_screen.dart';

import '../support/harness.dart';

void main() {
  group('confidence from reading flags', () {
    test('a clean, double-checked line is an automatic candidate', () {
      final c = lineConfidence(const []);
      expect(c.values.every((v) => v >= 0.95), isTrue);
      expect(confidenceBand(overallConfidence(c), const AiThresholds()), ConfidenceBand.auto);
    });

    test('each flag lowers only the fields it concerns', () {
      final c = lineConfidence(const ['ai_disagree:unit_price', 'jan_check']);
      expect(c['unit_price'], 0.6);
      expect(c['jan'], 0.4);
      expect(c['quantity'], 0.97);
      expect(confidenceBand(c['jan']!, const AiThresholds()), ConfidenceBand.human);
    });

    test('a spreadsheet is read, not recognised; an unchecked read is capped', () {
      expect(lineConfidence(const [], spreadsheet: true)['name'], 0.99);
      expect(lineConfidence(const [], verified: false)['name'], 0.85);
      expect(lineConfidence(const ['not_verified'])['amount'], 0.85);
      expect(lineConfidence(const [], hasJan: false).containsKey('jan'), isFalse);
      expect(lineConfidence(const [], hasProduct: false)['product'], 0.3);
    });

    test('the thresholds decide the band', () {
      const t = AiThresholds(auto: 0.9, review: 0.7);
      expect(confidenceBand(0.9, t), ConfidenceBand.auto);
      expect(confidenceBand(0.75, t), ConfidenceBand.review);
      expect(confidenceBand(0.69, t), ConfidenceBand.human);
      expect(AiThresholds.fromJson(const {'auto_threshold': 0.9, 'review_threshold': 0.7}), t);
    });
  });

  testWidgets('the settings screen moves the thresholds and previews the bands', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const AiSettingsScreen(), overrides: [
      aiThresholdsProvider.overrideWith((ref) async => const AiThresholds()),
    ]);
    expect(find.text('自動候補の下限: 95%'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byKey(const ValueKey('ai-save')));
    expect(save.onPressed, isNull);
    // 0.94 is "check recommended" at the defaults.
    expect(find.text('確認推奨'), findsWidgets);

    await tester.drag(find.byKey(const ValueKey('ai-auto')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.text('自動候補の下限: 95%'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('ai-save'))).onPressed, isNotNull);
  });

  test('the thresholds provider can be read in a container', () async {
    final c = ProviderContainer(overrides: [aiThresholdsProvider.overrideWith((ref) async => const AiThresholds(auto: 0.9))]);
    addTearDown(c.dispose);
    expect((await c.read(aiThresholdsProvider.future)).auto, 0.9);
  });
}
