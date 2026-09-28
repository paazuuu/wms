import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/documents/application/documents_providers.dart';
import 'package:wms_mobile/features/documents/domain/documents.dart';
import 'package:wms_mobile/features/documents/presentation/document_exceptions_screen.dart';
import 'package:wms_mobile/features/documents/presentation/document_match_screen.dart';
import 'package:wms_mobile/features/documents/presentation/documents_labels.dart';
import 'package:wms_mobile/features/documents/presentation/invoice_editor_screen.dart';

import '../../support/harness.dart';

const _match = DocumentMatch(
  purchaseOrderId: 5,
  poNumber: 'PO-0005',
  supplierId: 1,
  supplierName: 'A商社',
  invoices: [DocRef(id: 31, number: 'INV-1', status: 'mismatch')],
  lines: [
    MatchLine(
      key: 'p1',
      productId: 1,
      janCode: '4901234567894',
      productName: 'ボールペン',
      ordered: 10,
      orderPrice: 100,
      invoiced: 10,
      invoicePrice: 105,
      delivered: 10,
      received: 8,
      inspected: 8,
      passed: 7,
      failed: 1,
      flags: ['invoice_price', 'short_delivery', 'defective'],
    ),
    MatchLine(key: 'p2', productId: 2, productName: '消しゴム', ordered: 5, invoiced: 5, delivered: 5, received: 5, inspected: 5, passed: 5),
  ],
  poAmount: 1500,
  invoiceLinesAmount: 1550,
  qtyTolerancePct: 0,
  priceTolerancePct: 0,
  status: MatchStatus.mismatch,
);

void main() {
  testWidgets('the match lays the four documents side by side and flags differences', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeDocumentsRepository(matchResult: _match, invoiceRows: [
      const SupplierInvoice(id: 31, invoiceNumber: 'INV-1', purchaseOrderId: 5, status: InvoiceStatus.mismatch, lineCount: 2, total: 1550),
    ]);
    await pumpApp(tester, const DocumentMatchScreen(purchaseOrderId: 5), overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
      documentsCanManageProvider.overrideWithValue(true),
    ]);

    expect(find.descendant(of: find.byKey(const ValueKey('doc-match-status')), matching: find.text('差異あり')), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-line-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-line-p2')), findsOneWidget);
    expect(find.text('請求単価が発注と違う'), findsOneWidget);
    expect(find.text('請求より受領が少ない'), findsOneWidget);
    expect(find.text('不良あり'), findsOneWidget);
    expect(find.textContaining('+¥50'), findsOneWidget);

    // Approving is a person's act, and updates the supply terms.
    await tester.tap(find.byKey(const ValueKey('doc-approve-31')));
    await tester.pumpAndSettle();
    expect(repo.statusCalls.single, (31, InvoiceStatus.approved));
    expect(find.text('承認しました（仕入条件2件を更新）'), findsOneWidget);

    // The supplier's tolerance.
    await tester.tap(find.byKey(const ValueKey('doc-tolerance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('doc-tol-qty')), '3');
    await tester.enterText(find.byKey(const ValueKey('doc-tol-price')), '5');
    await tester.tap(find.byKey(const ValueKey('doc-tol-save')));
    await tester.pumpAndSettle();
    expect(repo.lastTolerance, (1, 3.0, 5.0));
  });

  testWidgets('without the right, the invoice cannot be settled or added', (tester) async {
    final repo = FakeDocumentsRepository(matchResult: _match, invoiceRows: [
      const SupplierInvoice(id: 31, invoiceNumber: 'INV-1', purchaseOrderId: 5, status: InvoiceStatus.mismatch),
    ]);
    await pumpApp(tester, const DocumentMatchScreen(purchaseOrderId: 5), overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.byKey(const ValueKey('doc-approve-31')), findsNothing);
    expect(find.byKey(const ValueKey('doc-add-invoice')), findsNothing);
  });

  testWidgets('the exception queue shows only the differences, and opens the order', (tester) async {
    final repo = FakeDocumentsRepository(matchResult: _match, exceptionRows: const [
      DocumentException(purchaseOrderId: 5, kind: 'short_delivery', poNumber: 'PO-0005', supplierName: 'A商社', productName: 'ボールペン', invoiced: 10, received: 8),
      DocumentException(purchaseOrderId: 5, kind: 'invoice_price', poNumber: 'PO-0005', productName: 'ボールペン', orderPrice: 100, invoicePrice: 105),
    ]);
    await pumpApp(tester, const DocumentExceptionsScreen(), overrides: [
      documentsRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(find.text('要確認 2件'), findsOneWidget);
    expect(find.text('数量 -2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doc-exception-0')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentMatchScreen), findsOneWidget);
  });

  testWidgets('an invoice read from a file shows confidence and saves against the order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeDocumentsRepository(matchResult: _match);
    final delivery = FakeDeliveryRepository(
      const [],
      preview: const ImportPreview(
        source: 'pdf',
        lineCount: 2,
        totalQuantity: 15,
        docNumber: 'INV-77',
        docDate: '2026-09-30',
        verified: true,
        lines: [
          {'raw_jan_code': '4901234567894', 'product_id': 1, 'product_name': 'ボールペン', 'planned_quantity': 10, 'unit_price': 105, 'flags': <String>[]},
          {'raw_jan_code': '4901234567890', 'product_name': 'けしごむ', 'planned_quantity': 5, 'unit_price': 50, 'flags': ['jan_check', 'unresolved']},
        ],
      ),
    );
    await pumpApp(
      tester,
      InvoiceEditorScreen(
        purchaseOrderId: 5,
        pickFile: () async => PlatformFile(name: 'inv.pdf', size: 3, bytes: Uint8List.fromList([1, 2, 3])),
      ),
      overrides: [
        documentsRepositoryProvider.overrideWithValue(repo),
        deliveryRepositoryProvider.overrideWithValue(delivery),
      ],
    );

    // Nothing typed: the number is required.
    await tester.tap(find.byKey(const ValueKey('doc-save')));
    await tester.pumpAndSettle();
    expect(find.text('請求書番号を入力してください'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('doc-read')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doc-edit-line-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('doc-edit-line-1')), findsOneWidget);
    expect(find.text('自動候補'), findsOneWidget);
    expect(find.text('要確認'), findsOneWidget);

    // A person corrects the second line's JAN: it is no longer an AI guess.
    await tester.tap(find.byKey(const ValueKey('doc-edit-line-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('doc-line-jan')), '4900000000019');
    await tester.tap(find.byKey(const ValueKey('doc-line-save')));
    await tester.pumpAndSettle();
    expect(find.text('要確認'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('doc-save')));
    await tester.pumpAndSettle();
    final saved = repo.lastSaved!;
    expect(saved.invoiceNumber, 'INV-77');
    expect(saved.invoiceDate, '2026-09-30');
    expect(saved.purchaseOrderId, 5);
    expect(saved.source, 'document');
    expect(saved.lines, hasLength(2));
    expect(saved.lines[0].confidence?['jan'], greaterThanOrEqualTo(0.95));
    expect(saved.lines[1].janCode, '4900000000019');
    expect(saved.lines[1].confidence, isNull);
  });
}
