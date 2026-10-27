import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ai/ai_limits_section.dart';
import 'package:wms_mobile/core/api/api_result.dart';

import '../support/harness.dart';

class _Repo implements AiLimitsRepository {
  AiLimits now = const AiLimits(callsToday: 12, documentsToday: 3);
  final saved = <AiLimits>[];

  @override
  Future<ApiResult<AiLimits>> load() async => ApiSuccess(now);

  @override
  Future<ApiResult<AiLimits>> save(AiLimits l) async {
    saved.add(l);
    now = l;
    return ApiSuccess(l);
  }
}

void main() {
  test('the settings as the server gives them, today\'s use in them', () {
    final l = AiLimits.fromJson(const {
      'document_model': 'gemini-3.8-flash', 'light_model': 'gemini-3.1-flash-lite',
      'daily_limit': 300, 'daily_document_limit': null, 'today': {'calls': 7, 'documents': 2},
    });
    expect(l.dailyDocumentLimit, isNull);
    expect([l.callsToday, l.documentsToday], [7, 2]);
  });

  testWidgets('the models and the daily limits are set, with today\'s use beside them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo();
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: AiLimitsSection())),
        overrides: [aiLimitsRepositoryProvider.overrideWithValue(repo)]);

    expect(find.text('gemini-3.8-flash（高精度）'), findsOneWidget);
    expect(find.text('今日 12回'), findsOneWidget);
    expect(find.text('今日 3回'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('ai-daily-limit')), '100');
    // Empty: no limit for documents.
    await tester.enterText(find.byKey(const ValueKey('ai-document-limit')), '');
    await tester.tap(find.byKey(const ValueKey('ai-limits-save')));
    await tester.pumpAndSettle();
    final s = repo.saved.single;
    expect([s.documentModel, s.lightModel], ['gemini-3.8-flash', 'gemini-3.1-flash-lite']);
    expect(s.dailyLimit, 100);
    expect(s.dailyDocumentLimit, isNull);
  });
}
