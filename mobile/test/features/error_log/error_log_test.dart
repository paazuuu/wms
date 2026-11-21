import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/errors/error_reporter.dart';
import 'package:wms_mobile/features/error_log/data/error_log_repository.dart';
import 'package:wms_mobile/features/error_log/presentation/error_log_screen.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import 'package:wms_mobile/l10n/app_localizations.dart';

import '../../support/fake_error_log_repository.dart';
import '../../support/harness.dart';

DioException _fail(String path, {int? status, Object? data, DioExceptionType type = DioExceptionType.badResponse}) {
  final o = RequestOptions(path: path, method: 'POST');
  return DioException(
    requestOptions: o,
    type: type,
    response: status == null ? null : Response(requestOptions: o, statusCode: status, data: data),
  );
}

class _Handler extends ErrorInterceptorHandler {
  int passed = 0;
  @override
  void next(DioException err) => passed++;
}

AppErrorEntry _entry(int id, String kind, String message, {int hoursAgo = 1, int times = 1, String? request}) =>
    AppErrorEntry(
      id: id,
      firstAt: DateTime.now().subtract(Duration(hours: hoursAgo + 1)),
      lastAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
      kind: kind,
      message: message,
      times: times,
      request: request,
      status: request == null ? null : 500,
      place: '#/stock-file-import',
      userName: 'テスト担当',
      detail: kind == 'flutter' ? '#0 build (package:wms/x.dart:10)' : null,
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));
  final reporter = ErrorReporter.instance;
  setUp(reporter.reset);
  tearDown(reporter.reset);

  group('reporting', () {
    test('a failed request is reported in the server\'s words — not a cancel, a 401 or the log\'s own call', () {
      final i = ErrorLogInterceptor();
      final h = _Handler();
      i.onError(
          _fail('/rpc/system_reset?x=1', status: 400, data: {
            'message': 'cannot do that',
            'details': 'a detail',
            'code': '0A000',
          }),
          h);
      i.onError(_fail('/rpc/x', status: 401, data: {'message': 'JWT expired'}), h);
      i.onError(_fail('/rpc/app_error_log', status: 500, data: {'message': 'down'}), h);
      i.onError(_fail('/rpc/y', type: DioExceptionType.cancel), h);
      i.onError(_fail('/object/x', type: DioExceptionType.connectionError), h);
      expect(h.passed, 5, reason: 'the error still reaches the caller');
      expect(reporter.made, hasLength(2));
      final first = reporter.made.first;
      expect((first['kind'], first['message'], first['request'], first['status']),
          ('api', 'cannot do that', 'POST /rpc/system_reset', 400));
      expect(first['detail'], 'a detail / 0A000');
      expect(reporter.made.last['request'], 'POST /object/x');
    });

    test('the same error within half a minute once; at most twenty a minute', () {
      for (var i = 0; i < 3; i++) {
        reporter.report('flutter', 'RenderFlex overflowed');
      }
      expect(reporter.made, hasLength(1));
      for (var i = 0; i < 40; i++) {
        reporter.report('uncaught', 'error $i');
      }
      expect(reporter.made, hasLength(20));
    });

    test('sent once a sender is set; kept and sent again when the server could not take it', () async {
      var up = false;
      final sent = <String>[];
      reporter.sender = (r) async {
        if (!up) return false;
        sent.add(r['message'] as String);
        return true;
      };
      reporter.report('api', 'first');
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);
      up = true;
      reporter.report('api', 'second');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(sent, ['first', 'second']);
    });
  });

  testWidgets('the screen: errors listed, filtered, opened, saved as Markdown and removed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <(String, Uint8List)>[];
    final repo = FakeErrorLogRepository([
      _entry(1, 'api', 'cannot do that', request: 'POST /rpc/system_reset', times: 3),
      _entry(2, 'flutter', 'A RenderFlex overflowed by 12 pixels', hoursAgo: 2),
      _entry(3, 'uncaught', 'Bad state: No element', hoursAgo: 24 * 20),
    ]);
    await pumpApp(tester, const ErrorLogScreen(), overrides: [
      errorLogRepositoryProvider.overrideWithValue(repo),
      saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    // The last week at first.
    expect(repo.askedDays.last, 7);
    expect(find.text('2件 / 全2件'), findsOneWidget);
    expect(find.byKey(const ValueKey('el-times-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('el-days')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべての期間').last);
    await tester.pumpAndSettle();
    expect(find.text('3件 / 全3件'), findsOneWidget);

    // Only the screen errors.
    await tester.tap(find.byKey(const ValueKey('el-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('画面').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('el-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('el-tile-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('el-detail-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('el-save-shown')));
    await tester.pumpAndSettle();
    final md = utf8.decode(saved.single.$2);
    expect(md, startsWith('# エラーログ（1件）'));
    expect(md, contains('A RenderFlex overflowed'));
    expect(md, contains('```\n#0 build'));

    // Searched; picked; removed.
    await tester.tap(find.byKey(const ValueKey('el-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべての種類').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('el-search')), 'system_reset');
    await tester.pump();
    expect(find.text('1件 / 全3件'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('el-search')), '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('el-pick-1')));
    await tester.pump();
    expect(find.text('1件を選択中'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('el-remove-picked')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('el-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.removedIds, [1]);
    expect(find.byKey(const ValueKey('el-1')), findsNothing);

    // Older than a week.
    await tester.tap(find.byKey(const ValueKey('el-remove-old')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('el-old-7')));
    await tester.pumpAndSettle();
    expect(find.textContaining('7日より前のエラーをすべて'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('el-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.removedOlderThan, 7);
    expect(repo.entries.map((e) => e.id), [2]);
  });

  test('in システム管理, for those who see the audit log or manage users', () {
    final e = buildFeatureCatalog().firstWhere((g) => g.id == 'management').entries.firstWhere((e) => e.id == 'error_log');
    expect(e.label(l10n), 'エラーログ');
    expect(e.visibleFor(const ['audit.view']), isTrue);
    expect(e.visibleFor(const ['inventory.adjust']), isFalse);
  });
}
