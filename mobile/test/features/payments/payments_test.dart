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

Map<String, dynamic> _payment(int id, {bool paid = false, Map<String, dynamic>? payee, String? source, List<Map<String, dynamic>> proofs = const []}) => {
      'id': id, 'day': '2026-07-01', 'document_date': '2026-07-01', 'status': 'awaiting_inspection',
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
          if (range is MonthPayments || r['paid'] != true) Payment.fromJson(r),
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

  test('会計 is a group of its own: 支払い and 税理士用ファイル', () {
    final groups = buildFeatureCatalog();
    final accounting = groups.firstWhere((g) => g.id == 'accounting');
    expect(accounting.entries.map((e) => e.id), ['payments', 'tax_files']);
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
    expect(text('pay-summary'), '2件 · 未払い 2件 · 未払い合計 ¥17,600');
    expect(text('pay-amount-5'), '¥8,800');
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
    // Paid now: off the unpaid list.
    expect(find.byKey(const ValueKey('pay-card-5')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pay-by-month')));
    await tester.pumpAndSettle();
    expect(text('pay-month'), '2026年7月分');
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

  testWidgets("an invoice with no 振込先 takes the supplier's, written by hand", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Repo([_payment(6)]);
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
    expect(repo.calls.single, 'account 7 サンプル銀行 中央支店 7654321');
    expect(tester.widget<Text>(find.byKey(const ValueKey('pay-bank-6'))).data, 'サンプル銀行 中央支店');
    expect(find.text('仕入先に登録した口座'), findsOneWidget);
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
