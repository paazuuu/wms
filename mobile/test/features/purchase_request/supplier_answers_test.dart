import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import 'package:wms_mobile/features/purchase_request/data/supplier_answer_repository.dart';
import 'package:wms_mobile/features/purchase_request/presentation/purchase_requests_screen.dart';
import 'package:wms_mobile/features/record_notes/presentation/record_notes_panel.dart' show noteFilePickerProvider;

import '../../support/fake_supplier_answer_repository.dart';
import '../../support/harness.dart';

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '購買', permissions: permissions)));

void main() {
  testWidgets('仕入先回答: a supplier\'s answer kept with its file, opened on the spot and downloaded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeSupplierAnswerRepository();
    final saved = <(String, Uint8List)>[];
    final csv = Uint8List.fromList(utf8.encode('JAN,数量,回答\n4909999000014,100,12月中旬\n'));
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [
      _signedIn(['purchase_order.manage']),
      supplierAnswerRepositoryProvider.overrideWithValue(repo),
      noteFilePickerProvider.overrideWithValue(() async => [(name: '回答_テスト商事.csv', bytes: csv)]),
      saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    await tester.tap(find.byKey(const ValueKey('wl-tab-answers')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sa-empty')), findsOneWidget);
    // The answers have their own button, not the new-list one.
    expect(find.byKey(const ValueKey('pr-new')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sa-add')));
    await tester.pumpAndSettle();
    // A supplier is needed.
    await tester.tap(find.byKey(const ValueKey('sa-save')));
    await tester.pumpAndSettle();
    expect(find.text('仕入先を入力してください'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sa-supplier')), 'テスト商事');
    await tester.enterText(find.byKey(const ValueKey('sa-title')), '12月の在庫回答');
    await tester.enterText(find.byKey(const ValueKey('sa-note')), 'BL系は12月中旬に100本');
    await tester.tap(find.byKey(const ValueKey('sa-pick-files')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sa-picked-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sa-save')));
    await tester.pumpAndSettle();

    expect(repo.saved.single.supplierName, 'テスト商事');
    expect(repo.saved.single.toJson()['title'], '12月の在庫回答');
    final a = repo.answers.single;
    expect(a.files.single.name, '回答_テスト商事.csv');
    expect(find.text('BL系は12月中旬に100本'), findsOneWidget);

    // Opened on the spot: the file as it is.
    await tester.tap(find.byKey(ValueKey('sa-file-${a.files.single.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sa-view')), findsOneWidget);
    expect(find.text('12月中旬'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('sa-view-download')));
    await tester.pumpAndSettle();
    expect(saved.single.$1, '回答_テスト商事.csv');
    expect(utf8.decode(saved.single.$2), contains('12月中旬'));
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // Found again by what it says.
    await tester.enterText(find.byKey(const ValueKey('sa-search')), '在庫回答');
    await tester.pump();
    expect(find.byKey(ValueKey('sa-answer-${a.id}')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sa-search')), '別の会社');
    await tester.pump();
    expect(find.byKey(ValueKey('sa-answer-${a.id}')), findsNothing);
  });

  testWidgets('without the right to edit, the answers are only looked at', (tester) async {
    final repo = FakeSupplierAnswerRepository([
      SupplierAnswer(id: 1, supplierName: 'テスト商事', answeredOn: DateTime(2026, 11, 18), title: '在庫回答'),
    ]);
    await pumpApp(tester, const PurchaseRequestsScreen(), overrides: [
      _signedIn(['purchase_order.view']),
      supplierAnswerRepositoryProvider.overrideWithValue(repo),
    ]);
    await tester.tap(find.byKey(const ValueKey('wl-tab-answers')));
    await tester.pumpAndSettle();
    expect(find.text('テスト商事'), findsOneWidget);
    expect(find.text('回答 2026/11/18'), findsOneWidget);
    expect(find.byKey(const ValueKey('sa-add')), findsNothing);
    expect(find.byKey(const ValueKey('sa-edit-1')), findsNothing);
  });
}
