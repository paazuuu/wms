import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/ai/ai_health.dart';
import 'package:wms_mobile/core/ai/ai_health_screen.dart';
import 'package:wms_mobile/core/api/api_result.dart';

import '../support/harness.dart';

Map<String, dynamic> _health({String overall = 'good', String? blocking, List<Map<String, dynamic>> errors = const []}) => {
      'overall': overall,
      'blocking': blocking,
      'measures': [
        {'key': 'availability', 'value': 0.99, 'good': 0.98, 'warn': 0.9, 'higher_is_better': true, 'verdict': 'good'},
        {'key': 'latency_p95', 'value': 7660, 'good': 20000, 'warn': 45000, 'higher_is_better': false, 'verdict': 'good'},
        {'key': 'agreement', 'value': 0.8, 'good': 0.9, 'warn': 0.75, 'higher_is_better': true, 'verdict': 'warn'},
        {'key': 'totals_match', 'value': null, 'good': 0.9, 'warn': 0.7, 'higher_is_better': true, 'verdict': 'unknown'},
      ],
      'calls': {'total': 100, 'ok': 99, 'failed': 1, 'input_tokens': 120000, 'output_tokens': 8000},
      'documents': {'files': 12, 'ai_files': 4},
      'errors_by_kind': {'overload': 1},
      'recent_errors': errors,
    };

class _FakeAiHealthRepository implements AiHealthRepository {
  _FakeAiHealthRepository(this.json, {this.pingResult});

  final Map<String, dynamic> json;
  final AiPingResult? pingResult;
  final List<int> asked = [];
  int pings = 0;

  @override
  Future<ApiResult<AiHealth>> health(int hours) async {
    asked.add(hours);
    return ApiSuccess(AiHealth.fromJson(json));
  }

  @override
  Future<ApiResult<AiPingResult>> ping() async {
    pings++;
    return ApiSuccess(pingResult ?? const AiPingResult(ok: true, model: 'gemini-x', latencyMs: 812));
  }
}

void main() {
  test('the health answer is read, measures and errors included', () {
    final h = AiHealth.fromJson(_health(errors: [
      {'called_at': '2026-10-04T10:00:00Z', 'error_kind': 'overload', 'http_status': 503, 'task': 'extract', 'error': 'busy'},
    ]));
    expect(h.overall, AiVerdict.good);
    expect(h.measures.map((m) => m.verdict).toList(),
        [AiVerdict.good, AiVerdict.good, AiVerdict.warn, AiVerdict.unknown]);
    expect([h.total, h.ok, h.failed, h.files, h.aiFiles], [100, 99, 1, 12, 4]);
    expect(h.recentErrors.single.status, 503);
    expect(aiMeasureValue(h.measures[0], h.measures[0].value), '99.0%');
    expect(aiMeasureValue(h.measures[1], h.measures[1].value), '7.7 s');
  });

  testWidgets('verdict, formulas, thresholds and the connection test', (tester) async {
    final repo = _FakeAiHealthRepository(_health(overall: 'warn'));
    await pumpApp(tester, const AiHealthScreen(), overrides: [aiHealthRepositoryProvider.overrideWithValue(repo)]);
    expect(repo.asked, [168]);
    expect(find.text('注意'), findsWidgets);
    expect(find.byKey(const ValueKey('ah-measure-agreement')), findsOneWidget);
    expect(find.textContaining('1 −（2回の読み取りで食い違った行'), findsOneWidget);
    expect(find.text('正常 98.0% 以上・注意 90.0% 以上・それ未満は異常'), findsOneWidget);
    expect(find.text('この期間のエラーはありません'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ah-ping')));
    await tester.pumpAndSettle();
    expect(repo.pings, 1);
    expect(find.text('接続OK（812 ms・gemini-x）'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ah-period-24')));
    await tester.pumpAndSettle();
    expect(repo.asked.last, 24);
  });

  testWidgets('a refused key says what to do', (tester) async {
    final repo = _FakeAiHealthRepository(
      _health(overall: 'bad', blocking: 'auth', errors: [
        {'called_at': '2026-10-04T10:00:00Z', 'error_kind': 'auth', 'http_status': 400, 'task': 'ping', 'error': 'API key not valid'},
      ]),
      pingResult: const AiPingResult(ok: false, model: 'gemini-x', latencyMs: 300, errorKind: 'auth'),
    );
    await pumpApp(tester, const AiHealthScreen(), overrides: [aiHealthRepositoryProvider.overrideWithValue(repo)]);
    expect(find.text('異常'), findsOneWidget);
    expect(find.byKey(const ValueKey('ah-blocking')), findsOneWidget);
    expect(find.textContaining('キー拒否'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ah-ping')));
    await tester.pumpAndSettle();
    expect(find.text('接続できません: キー拒否'), findsOneWidget);
  });
}
