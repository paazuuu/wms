import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/product/application/product_providers.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/shelf_notes/data/shelf_notes_repository.dart';
import 'package:wms_mobile/features/shelf_notes/presentation/shelf_notes_screen.dart';

import '../../support/fake_marks_and_notes.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('棚メモ: written freely, found again by place, note or the product (0167)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notes = FakeShelfNotesRepository([
      const ShelfNote(id: 1, productId: 7, location: 'A棚 上段', body: '・特注品はここ', createdByName: '倉庫'),
      const ShelfNote(id: 2, location: '奥の青い箱', body: '・割れ物', createdByName: '倉庫'),
    ]);
    await pumpApp(tester, const ShelfNotesScreen(), overrides: [
      authControllerProvider.overrideWith((ref) => fakeAuthControllerFor(
          const AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: ['putaway.confirm', 'product.view']))),
      shelfNotesRepositoryProvider.overrideWithValue(notes),
      productRepositoryProvider.overrideWithValue(FakeProductRepository(products: const [
        Product(id: 7, janCode: '4909999000014', name: 'テストペン 青', sku: 'TP-05L', maker: 'テスト文具'),
      ])),
    ]);
    expect(find.byKey(const ValueKey('sn-note-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sn-note-2')), findsOneWidget);
    // By the product's 品番, which the note does not say.
    await tester.enterText(find.byKey(const ValueKey('sn-search')), 'TP-05');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sn-note-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sn-note-2')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('sn-search')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sn-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sn-location')), 'B棚');
    await tester.enterText(find.byKey(const ValueKey('sn-body')), '・展示品を下段に');
    await tester.tap(find.byKey(const ValueKey('sn-save')));
    await tester.pumpAndSettle();
    expect(notes.notes.first.location, 'B棚');
    expect(find.text('・展示品を下段に'), findsOneWidget);

    // Taken off the list.
    await tester.tap(find.byKey(const ValueKey('sn-note-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sn-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sn-note-2')), findsNothing);
  });
}
