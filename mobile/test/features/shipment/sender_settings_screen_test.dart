import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/shipment/presentation/sender_settings_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('live preview reflects what is typed', (tester) async {
    await pumpApp(tester, const SenderSettingsScreen());

    // Type a company name into the first field (会社名).
    await tester.enterText(find.byType(TextField).first, 'テスト商会');
    await tester.pumpAndSettle();

    // Scroll the preview card into view (it is the last item in the list).
    await tester.scrollUntilVisible(
      find.text('印刷プレビュー'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // The typed company name shows in the print preview.
    expect(find.text('テスト商会'), findsWidgets);
    expect(find.text('差出人が未設定です。'), findsNothing);
  });
}
