import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/scan/scan_session.dart';

void main() {
  final t0 = DateTime(2026, 9, 13, 10, 0, 0);

  group('ScanSession', () {
    test('accepts a new code and records it in the history', () {
      final session = ScanSession();

      final event = session.register('4901234567894', t0);

      expect(event.outcome, ScanOutcome.accepted);
      expect(event.message, isNull);
      expect(session.acceptedCount, 1);
      expect(session.last?.code, '4901234567894');
    });

    test('suppresses the same code inside the duplicate window', () {
      final session = ScanSession(duplicateWindow: const Duration(seconds: 3));

      session.register('4901234567894', t0);
      final again =
          session.register('4901234567894', t0.add(const Duration(seconds: 2)));

      expect(again.outcome, ScanOutcome.duplicate);
      // Still recorded — an ignored scan the operator can see is very different
      // from one that vanished.
      expect(session.history, hasLength(2));
      expect(session.acceptedCount, 1);
    });

    test('accepts the same code again once the window has passed', () {
      final session = ScanSession(duplicateWindow: const Duration(seconds: 3));

      session.register('4901234567894', t0);
      final later =
          session.register('4901234567894', t0.add(const Duration(seconds: 4)));

      expect(later.outcome, ScanOutcome.accepted);
      expect(session.acceptedCount, 2);
    });

    test('a different code is never a duplicate of the previous one', () {
      final session = ScanSession();

      session.register('4901234567894', t0);
      final other =
          session.register('4901234567895', t0.add(const Duration(seconds: 1)));

      expect(other.outcome, ScanOutcome.accepted);
    });

    test('trims whitespace so a wedge scanner\'s padding is not a new code', () {
      final session = ScanSession();

      session.register('4901234567894', t0);
      final padded = session
          .register('  4901234567894 ', t0.add(const Duration(seconds: 1)));

      expect(padded.outcome, ScanOutcome.duplicate);
      expect(padded.code, '4901234567894');
    });

    test('a rejected scan carries its reason and opens no duplicate window', () {
      final session = ScanSession();

      final rejected = session.register('9999999999999', t0,
          rejectionMessage: '別の商品です');
      // The operator fixes whatever was wrong and scans the same label again —
      // that must not be swallowed as a duplicate.
      final retry = session.register('9999999999999',
          t0.add(const Duration(milliseconds: 400)));

      expect(rejected.outcome, ScanOutcome.rejected);
      expect(rejected.message, '別の商品です');
      expect(retry.outcome, ScanOutcome.accepted);
      expect(session.acceptedCount, 1);
    });

    test('history is newest first and capped at historyLimit', () {
      final session = ScanSession(historyLimit: 3);

      for (var i = 0; i < 5; i++) {
        session.register('code-$i', t0.add(Duration(seconds: i)));
      }

      expect(session.history, hasLength(3));
      expect(session.history.map((e) => e.code), ['code-4', 'code-3', 'code-2']);
    });

    test('allowRepeats clears the windows but keeps the history', () {
      final session = ScanSession();

      session.register('4901234567894', t0);
      session.allowRepeats();
      final again = session.register(
          '4901234567894', t0.add(const Duration(milliseconds: 100)));

      expect(again.outcome, ScanOutcome.accepted);
      expect(session.history, hasLength(2));
    });

    test('clear empties everything', () {
      final session = ScanSession();
      session.register('4901234567894', t0);

      session.clear();

      expect(session.history, isEmpty);
      expect(session.last, isNull);
      expect(session.acceptedCount, 0);
    });
  });
}
