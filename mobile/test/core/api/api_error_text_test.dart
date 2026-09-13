import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_error_text.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('humanizeApiErrorMessage (UI spec §34)', () {
    test('a bare "not permitted" RPC error becomes a friendly message', () {
      expect(
        humanizeApiErrorMessage(ja, 'not permitted: purchase_order.manage required'),
        'この操作を行う権限がありません。',
      );
    });

    test('still matches when a repository rethrows it as an Exception', () {
      expect(
        humanizeApiErrorMessage(
            en, 'Exception: not permitted: user.manage required'),
        "You don't have permission to do that.",
      );
    });

    test('an unrelated error passes through unchanged', () {
      const raw = 'No connection to the server.';
      expect(humanizeApiErrorMessage(ja, raw), raw);
    });

    test('a business-rule exception is not mistaken for a permission error',
        () {
      const raw = 'user 4 has not signed in yet';
      expect(humanizeApiErrorMessage(ja, raw), raw);
    });
  });
}
