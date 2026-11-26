import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/invoice_registration/data/invoice_registration_repository.dart';
import 'package:wms_mobile/features/invoice_registration/domain/invoice_registration.dart';
import 'package:wms_mobile/features/invoice_registration/presentation/invoice_registration_widgets.dart';

import '../../support/fake_invoice_registration_repository.dart';
import '../../support/harness.dart';

const _valid = 'T1111111111111';
const _revoked = 'T2222222222222';

final _known = {
  _valid: InvoiceRegistration(
    number: _valid,
    status: RegStatus.valid,
    name: 'テスト商事株式会社',
    kind: 'corporation',
    address: '大阪府大阪市中央区テスト1-2-3',
    registrationDate: DateTime(2023, 10, 1),
    checkedAt: DateTime(2026, 11, 26),
  ),
  _revoked: InvoiceRegistration(number: _revoked, status: RegStatus.revoked, disposalDate: DateTime(2025, 4, 1)),
};

void main() {
  test('登録番号 in its one form; company names compared without 株式会社 and widths', () {
    expect(normalizeRegNo('ｔ１２３４－５６７８－９０１２３'), 'T1234567890123');
    expect(normalizeRegNo('1234567890123'), 'T1234567890123');
    expect(normalizeRegNo('T123'), isNull);
    expect(sameCompany('㈱テスト商事', 'テスト商事株式会社'), isTrue);
    expect(sameCompany('テスト商事株式会社 大阪支店', 'テスト商事株式会社'), isTrue);
    expect(sameCompany('テスト物産株式会社', 'テスト商事株式会社'), isFalse);
  });

  testWidgets('beside an invoice: registered under the same name, or a name that differs', (tester) async {
    final repo = FakeInvoiceRegistrationRepository(known: _known, configured: true);
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(children: [
          InvoiceRegistrationBadge(number: 'T-1111111111111', company: '㈱テスト商事'),
          InvoiceRegistrationBadge(number: _revoked, company: 'テスト物産'),
        ]),
      ),
      overrides: [invoiceRegistrationRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.pumpAndSettle();
    expect(find.text('国税庁に登録あり：テスト商事株式会社'), findsOneWidget);
    expect(find.text('請求書の会社名と一致'), findsOneWidget);
    expect(find.text('登録が取り消されています（2025/04/01）'), findsOneWidget);
    // Asked again on a tap.
    await tester.tap(find.byKey(const ValueKey('ir-refresh-$_valid')));
    await tester.pumpAndSettle();
    expect(repo.asked.where((a) => a.$2), hasLength(1));
  });

  testWidgets('a name that differs from the registered one is warned of', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: InvoiceRegistrationBadge(number: _valid, company: 'テスト物産株式会社')),
      overrides: [
        invoiceRegistrationRepositoryProvider.overrideWithValue(FakeInvoiceRegistrationRepository(known: _known, configured: true)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('請求書の会社名「テスト物産株式会社」と登録の名前が違います'), findsOneWidget);
  });

  testWidgets('without the アプリケーションID: says so, and offers 国税庁の公表サイト', (tester) async {
    await pumpApp(tester, const Scaffold(body: InvoiceRegistrationBadge(number: _valid)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ir-unset-$_valid')), findsOneWidget);
    expect(find.byKey(const ValueKey('ir-site-$_valid')), findsOneWidget);
  });

  testWidgets('by hand: several numbers, each answered; what is not one is said', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(builder: (context) => TextButton(onPressed: () => showInvoiceCheckDialog(context), child: const Text('open'))),
      overrides: [
        invoiceRegistrationRepositoryProvider.overrideWithValue(FakeInvoiceRegistrationRepository(known: _known, configured: true)),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ir-input')), '$_valid\nT3333333333333, 12345');
    await tester.tap(find.byKey(const ValueKey('ir-check')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ir-result-$_valid')), findsOneWidget);
    expect(find.text('所在地: 大阪府大阪市中央区テスト1-2-3'), findsOneWidget);
    expect(find.textContaining('国税庁に登録がありません'), findsOneWidget);
    expect(find.text('登録番号の形ではありません（T＋13桁）: 12345'), findsOneWidget);
    expect(find.textContaining('国税庁によって保証されたものではない'), findsOneWidget);
  });

  testWidgets('the アプリケーションID: set, never shown back, cleared', (tester) async {
    final repo = FakeInvoiceRegistrationRepository();
    await pumpApp(tester, const Scaffold(body: SingleChildScrollView(child: NtaKeyCard())),
        overrides: [invoiceRegistrationRepositoryProvider.overrideWithValue(repo)]);
    await tester.pumpAndSettle();
    expect(find.text('未設定'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ir-key-field')), 'APP-ID-TEST');
    await tester.tap(find.byKey(const ValueKey('ir-key-save')));
    await tester.pumpAndSettle();
    expect(repo.keys, ['APP-ID-TEST']);
    expect(find.text('設定済み（2026/11/26・テスト管理者）'), findsOneWidget);
    expect(find.text('APP-ID-TEST'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ir-key-clear')));
    await tester.pumpAndSettle();
    expect(repo.keys.last, '');
  });
}
