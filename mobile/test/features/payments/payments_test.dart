import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/payments/data/payments_repository.dart';
import 'package:wms_mobile/features/payments/domain/payment.dart';
import 'package:wms_mobile/features/payments/presentation/payments_screen.dart';
import 'package:wms_mobile/features/tax_files/data/tax_files_repository.dart';
import 'package:wms_mobile/features/tax_files/domain/tax_purchases.dart';

import '../../support/harness.dart';

Map<String, dynamic> _payment(int id,
        {bool paid = false,
        Map<String, dynamic>? payee,
        String? source,
        List<Map<String, dynamic>> proofs = const [],
        String status = 'awaiting_inspection',
        Map<String, dynamic>? steps,
        List<Map<String, dynamic>> sameAs = const []}) =>
    {
      'id': id, 'day': '2026-07-01', 'document_date': '2026-07-01', 'status': status,
      'created_at': '2026-07-02T01:00:00Z', 'created_by_name': '倉庫',
      'steps': steps ?? {'read': 2, 'checked': 2, 'lines': 1, 'in_library': 1, 'named': 1, 'weighed': 0, 'inspected': 0},
      'same_as': sameAs,
      'original_name': '請求書$id.pdf', 'original_path': 'imports/$id/original.pdf', 'paid': paid,
      if (paid) 'paid_at': '2026-10-30T01:00:00Z', if (paid) 'paid_by_name': '経理',
      'read_lines': [
        {'line_no': 1, 'jan': '4909999000014', 'name': 'テストペン', 'quantity': '100', 'unit_price': '80', 'amount': '8000'},
      ],
      'supplier_id': 7, 'supplier_display_name': 'テスト商事株式会社',
      'payee': payee, 'payee_source': source,
      'proofs': proofs,
      'document': {
        'id': id + 100, 'supplier_name': 'テスト商事株式会社', 'registration_number': 'T9999999999999', 'doc_number': 'INV-$id',
        'storage_path': '2026/10/$id.pdf', 'file_name': '請求書$id.pdf', 'sha256': 'abc$id',
        'totals': {'doc_subtotal': 8000, 'doc_tax': 800, 'doc_total': 8800},
      },
    };

class _Repo implements PaymentsRepository {
  _Repo(this.rows);

  final List<Map<String, dynamic>> rows;
  final calls = <String>[];

  @override
  Future<ApiResult<List<Payment>>> list(PaymentsRange range) async => ApiSuccess([
        for (final r in rows)
          Payment.fromJson(r),
      ]);

  @override
  Future<ApiResult<bool>> setPaid(int importId, bool paid) async {
    calls.add('paid $importId $paid');
    rows.firstWhere((r) => r['id'] == importId)['paid'] = paid;
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> addProof(int importId, String fileName, Uint8List bytes) async {
    calls.add('proof $importId $fileName');
    final r = rows.firstWhere((r) => r['id'] == importId);
    r['proofs'] = [
      ...(r['proofs'] as List),
      {'id': 90, 'storage_path': '$importId/x-$fileName', 'file_name': fileName, 'content_type': 'image/png'},
    ];
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<bool>> removeProof(int proofId) async {
    calls.add('remove $proofId');
    for (final r in rows) {
      r['proofs'] = [for (final p in r['proofs'] as List) if ((p as Map)['id'] != proofId) p];
    }
    return const ApiSuccess(true);
  }

  @override
  Future<ApiResult<Uint8List>> proofBytes(PaymentProof proof) async => ApiSuccess(Uint8List.fromList([1, 2, 3]));

  final askedPayee = <int>[];
  Payee? payeeToFind;

  @override
  Future<ApiResult<Payee?>> readPayee(int importId) async {
    askedPayee.add(importId);
    final found = payeeToFind;
    if (found != null) {
      rows.firstWhere((r) => r['id'] == importId)
        ..['payee'] = found.toJson()
        ..['payee_source'] = 'invoice';
    }
    return ApiSuccess(found);
  }

  @override
  Future<ApiResult<bool>> setSupplierAccount(int supplierId, Payee? payee) async {
    calls.add('account $supplierId ${payee?.line}');
    for (final r in rows) {
      if (r['payee'] == null) {
        r['payee'] = payee?.toJson();
        r['payee_source'] = 'supplier';
      }
    }
    return const ApiSuccess(true);
  }
}

class _Tax implements TaxFilesRepository {
  @override
  Future<ApiResult<List<TaxPurchase>>> purchases(DateTime from, DateTime to) async => const ApiSuccess([]);

  @override
  Future<ApiResult<Uint8List>> original(TaxPurchase p) async => ApiSuccess(Uint8List.fromList([p.importId]));
}

const _clerk = AuthUser(id: 'u1', email: 'a@b.test', name: '経理', permissions: ['inventory.adjust', 'report.view']);

void main() {
  test('a payment reads its 振込先, amount and proofs', () {
    final p = Payment.fromJson(_payment(5,
        payee: {'bank': 'テスト銀行', 'branch': 'テスト支店', 'account_type': '当座', 'account_number': '1234567'},
        source: 'invoice',
        proofs: [{'id': 1, 'storage_path': '5/a.png', 'file_name': 'a.png', 'content_type': 'image/png'}]));
    expect(p.payee!.line, 'テスト銀行 テスト支店 当座 1234567');
    expect(p.payeeSource, PayeeSource.invoice);
    expect(p.amount, 8800);
    expect(p.supplierName, 'テスト商事株式会社');
    expect(p.proofs.single.isImage, isTrue);
    expect(Payment.fromJson(_payment(6)).payee, isNull);
    expect(contentTypeOf('完了.PDF'), 'application/pdf');
  });

  test('会計 holds 税理士用ファイル; 発注 is the stock file import, under 商品', () {
    final groups = buildFeatureCatalog();
    final accounting = groups.firstWhere((g) => g.id == 'accounting');
    expect(accounting.entries.where((e) => e.inMenu).map((e) => e.id), ['tax_files']);
    final products = groups.firstWhere((g) => g.id == 'products_master');
    final order = products.entries.firstWhere((e) => e.id == 'stock_file_import');
    expect(order.icon, Icons.add_shopping_cart_outlined);
    expect(order.inMenu, isTrue);
    // The purchase orders are no longer in the menu (their address stays).
    expect(groups.expand((g) => g.entries).firstWhere((e) => e.id == 'purchase_orders').inMenu, isFalse);
    // Between 商品 and 現場作業.
    expect(groups.map((g) => g.id).take(3), ['products_master', 'accounting', 'field_operations']);
    expect(groups.where((g) => g.id != 'accounting').expand((g) => g.entries).map((e) => e.id), isNot(contains('tax_files')));
  });

  testWidgets('支払い: the 振込先, the invoice, 支払い済, and a proof that marks it paid', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _payment(5, payee: {'bank': 'テスト銀行', 'branch': 'テスト支店', 'account_type': '当座', 'account_number': '1234567'}, source: 'invoice'),
      _payment(6),
    ]);
    final saved = <String>[];
    await pumpApp(tester, PaymentsScreen(today: DateTime(2026, 7, 15)), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(repo),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
      paymentProofPickerProvider.overrideWithValue(() async => (name: '振込完了.png', bytes: Uint8List.fromList([1]))),
      paymentFileSaverProvider.overrideWithValue((name, bytes) async => saved.add(name)),
    ]);

    String text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    Future<void> open(int id) async {
      if (find.byKey(ValueKey('pay-paid-$id')).evaluate().isEmpty) {
        await tester.tap(find.byKey(ValueKey('pay-toggle-$id')));
        await tester.pumpAndSettle();
      }
    }

    expect(text('pay-summary'), '2件 · 未払い 2件 · 未払い合計 ¥17,600');
    expect(text('pay-amount-5'), '¥8,800');
    // Two orders: folded to a line and a bar of steps, opened one by one.
    expect(find.byKey(const ValueKey('pay-paid-5')), findsNothing);
    await open(5);
    await open(6);
    expect(text('pay-bank-5'), 'テスト銀行 テスト支店');
    expect(text('pay-account-5'), '当座 1234567');
    expect(find.text('請求書から読み取り'), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-no-payee-6')), findsOneWidget);

    // The invoice itself.
    await tester.tap(find.byKey(const ValueKey('pay-invoice-5')));
    await tester.pumpAndSettle();
    expect(saved, ['請求書5.pdf']);

    // A proof added: kept, and the payment marked paid.
    await tester.tap(find.byKey(const ValueKey('pay-add-proof-5')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['proof 5 振込完了.png', 'paid 5 true']);
    expect(find.text('振込完了.png を追加し、支払い済にしました'), findsOneWidget);
    // Paid, and the inspection still to come: the order stays, open.
    expect(find.byKey(const ValueKey('pay-card-5')), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('pay-paid-5'))).value, isTrue);
    // The proof downloaded again, to check it.
    await tester.tap(find.byKey(const ValueKey('pay-proof-download-90')));
    await tester.pumpAndSettle();
    expect(saved.last, '振込完了.png');
    await tester.tap(find.byKey(const ValueKey('pay-by-month')));
    await tester.pumpAndSettle();
    expect(text('pay-month'), '2026年7月分');
    await open(5);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('pay-paid-5'))).value, isTrue);
    expect(find.byKey(const ValueKey('pay-proof-90')), findsOneWidget);

    // Unticked by hand: the same 支払い済 as the import's.
    await tester.tap(find.byKey(const ValueKey('pay-paid-5')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'paid 5 false');

    // The proof taken off (kept on record).
    await tester.tap(find.byKey(const ValueKey('pay-proof-remove-90')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-proof-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'remove 90');
    expect(find.byKey(const ValueKey('pay-proof-90')), findsNothing);
  });

  testWidgets('進行中 leaves out orders already through; the month shows them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, PaymentsScreen(today: DateTime(2026, 7, 15)), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(_Repo([
        _payment(7, status: 'stock_done', paid: true, payee: {'bank': 'テスト銀行'}, source: 'invoice',
            proofs: [{'id': 1, 'storage_path': '7/a.png', 'file_name': 'a.png'}]),
      ])),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    expect(find.byKey(const ValueKey('pay-none')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-by-month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-card-7')), findsOneWidget);
  });

  testWidgets("an invoice with no 振込先 takes the supplier's, written by hand", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([_payment(6)]);
    // Only the hand: the AI finds none.
    await pumpApp(tester, const PaymentsScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(repo),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    await tester.tap(find.byKey(const ValueKey('pay-edit-payee-6')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pay-f-bank')), 'サンプル銀行');
    await tester.enterText(find.byKey(const ValueKey('pay-f-branch')), '中央支店');
    await tester.enterText(find.byKey(const ValueKey('pay-f-number')), '7654321');
    await tester.tap(find.byKey(const ValueKey('pay-f-save')));
    await tester.pumpAndSettle();
    expect(repo.askedPayee, [6]);
    expect(repo.calls.single, 'account 7 サンプル銀行 中央支店 7654321');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pay-bank-6'))).data, 'サンプル銀行 中央支店');
    expect(find.text('仕入先に登録した口座'), findsOneWidget);
  });

  testWidgets("each order's steps on one line: done, under way, the one it is at, and the rest", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const PaymentsScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(_Repo([
        _payment(5, payee: {'bank': 'テスト銀行', 'account_number': '1234567'}, source: 'invoice',
            steps: {'read': 2, 'checked': 2, 'lines': 2, 'in_library': 2, 'named': 2, 'weighed': 1, 'inspected': 1}),
      ])),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    bool mark(String step, String state) => find.byKey(ValueKey('ord-mark-5-$step-$state')).evaluate().isNotEmpty;
    expect(mark('upload', 'done'), isTrue);
    expect(mark('check', 'done'), isTrue);
    expect(mark('library', 'done'), isTrue);
    expect(mark('ai', 'partial'), isTrue);
    expect(mark('stock', 'partial'), isTrue);
    expect(mark('payee', 'done'), isTrue);
    expect(mark('paid', 'todo'), isTrue);
    expect(mark('proof', 'todo'), isTrue);
    String text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(text('ord-detail-5-ai'), '商品名 2/2 · 重量 1/2');
    expect(text('ord-detail-5-stock'), '検品待ち（検品済み 1/2）');
    expect(text('ord-detail-5-payee'), '振込金額 ¥8,800（税込）');
    expect(text('ord-now-5'), '今: AIで商品名・重量を書き込み');
  });

  testWidgets('the same order twice: a warning on both, and paying the second asks first', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([
      _payment(19, paid: true, sameAs: [{'id': 20, 'day': '2026-07-01', 'paid': false, 'same_file': true, 'same_lines': true}]),
      _payment(20, sameAs: [{'id': 19, 'day': '2026-07-01', 'paid': true, 'same_file': true, 'same_lines': true, 'same_invoice': true}]),
    ]);
    await pumpApp(tester, const PaymentsScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(repo),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    // The warning shows on the folded card too.
    expect(find.byKey(const ValueKey('pay-twin-20')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pay-toggle-20')));
    await tester.pumpAndSettle();
    expect(find.text('注意: 取込 #19（2026/07/01・振込済）と同じファイル・同じ明細（JAN・数量）・同じ請求書番号・日付'), findsOneWidget);
    // Not paid unless it is said to be another order.
    await tester.tap(find.byKey(const ValueKey('pay-paid-20')));
    await tester.pumpAndSettle();
    expect(find.text('同じ注文が支払い済かもしれません'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('pay-paid-20')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-twin-ok')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['paid 20 true']);
  });

  testWidgets('an unpaid order with no 振込先 has the AI read its invoice, once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([_payment(31)])
      ..payeeToFind = const Payee(bank: 'テスト銀行', branch: 'テスト支店', accountType: '当座', accountNumber: '1234567');
    await pumpApp(tester, const PaymentsScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(_clerk)),
      paymentsRepositoryProvider.overrideWithValue(repo),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    await tester.pumpAndSettle();
    expect(repo.askedPayee, [31]);
    expect(tester.widget<Text>(find.byKey(const ValueKey('pay-bank-31'))).data, 'テスト銀行 テスト支店');
    // By hand too.
    await tester.tap(find.byKey(const ValueKey('pay-ai-payee-31')));
    await tester.pumpAndSettle();
    expect(repo.askedPayee, [31, 31]);
    expect(find.text('振込先を読み取りました: テスト銀行 テスト支店 当座 1234567'), findsOneWidget);
  });

  testWidgets('who only reads the books sees the payments but changes nothing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const PaymentsScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u2', email: 'c@d.test', name: '税理士', permissions: ['report.view']))),
      paymentsRepositoryProvider.overrideWithValue(_Repo([_payment(6)])),
      taxFilesRepositoryProvider.overrideWithValue(_Tax()),
    ]);
    expect(find.byKey(const ValueKey('pay-card-6')), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('pay-paid-6'))).onChanged, isNull);
    expect(find.byKey(const ValueKey('pay-add-proof-6')), findsNothing);
    expect(find.byKey(const ValueKey('pay-edit-payee-6')), findsNothing);
  });
}
