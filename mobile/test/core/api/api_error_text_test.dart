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

    test('a second close of an inspection is explained (0095)', () {
      expect(humanizeApiErrorMessage(ja, 'inspection 10 is already completed'),
          'この検品はすでに完了しています。画面を開き直して最新の結果を確認してください。');
      expect(
          humanizeApiErrorMessage(
              ja, 'inspection 10 is already completed and can no longer change'),
          'この検品はすでに完了しています。画面を開き直して最新の結果を確認してください。');
    });

    test('a parcel for a receipt whose inspection closed is explained (0097)', () {
      expect(
        humanizeApiErrorMessage(ja,
            'the inspection of receipt 31 is closed; receive these goods as a new receipt for this delivery'),
        'この入荷の検品はすでに完了しています。追加の商品は、同じ入荷予定の新しい入荷として照合してください。',
      );
    });

    test('cancelling an inspected receipt is explained (0096)', () {
      expect(
        humanizeApiErrorMessage(ja,
            'receipt 31 has a completed inspection, so its goods have already moved on and it cannot be cancelled — correct the stock with an adjustment instead'),
        '検品が完了した入荷は取り消せません。在庫を直す場合は在庫調整を使ってください。',
      );
    });
  });
}
