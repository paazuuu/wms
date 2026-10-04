import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/company/application/company_providers.dart';
import 'package:wms_mobile/features/company/domain/company_profile.dart';
import 'package:wms_mobile/features/company/presentation/company_profile_screen.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/evidence/application/evidence_providers.dart';
import 'package:wms_mobile/features/evidence/domain/import_document.dart';
import 'package:wms_mobile/features/evidence/presentation/evidence_screen.dart';

import '../../support/harness.dart';

ImportDocument _doc(int id, EvidencePurpose p, String file, {String? supplier, int? plan, String? ref}) =>
    ImportDocument(
      id: id,
      purpose: p,
      fileName: file,
      storagePath: '2026/10/$id.pdf',
      uploadedAt: DateTime(2026, 10, 4, 9, 30),
      supplierName: supplier,
      docNumber: 'D-$id',
      lineCount: 3,
      byteSize: 2048,
      deliveryPlanId: plan,
      referenceNo: ref,
      uploadedByName: '倉庫 太郎',
    );

void main() {
  group('自社情報 (0131)', () {
    testWidgets('unset: says so, offers what documents were addressed to, and saves', (tester) async {
      final repo = FakeCompanyRepository(
        suggested: const [OwnNameSuggestion(name: '株式会社サンプル文具', count: 4)],
      );
      await pumpApp(tester, const CompanyProfileScreen(), overrides: [
        companyRepositoryProvider.overrideWithValue(repo),
        companyCanEditProvider.overrideWithValue(true),
      ]);
      expect(find.byKey(const ValueKey('cp-unset')), findsOneWidget);
      expect(find.text('株式会社サンプル文具'), findsOneWidget);
      expect(find.text('4件'), findsOneWidget);

      await tester.ensureVisible(find.text('社名にする'));
      await tester.tap(find.text('社名にする'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('cp-name'))).controller!.text, '株式会社サンプル文具');
      await tester.enterText(find.byKey(const ValueKey('cp-aliases')), 'サンプル文具\n大阪支店');
      await tester.enterText(find.byKey(const ValueKey('cp-reg')), 'T1111111111111');
      await tester.ensureVisible(find.byKey(const ValueKey('cp-save')));
      await tester.tap(find.byKey(const ValueKey('cp-save')));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.name, '株式会社サンプル文具');
      expect(repo.saved.single.aliases, ['サンプル文具', '大阪支店']);
      expect(repo.saved.single.registrationNumber, 'T1111111111111');
      expect(find.text('自社情報を保存しました'), findsOneWidget);
    });

    testWidgets('without user.manage it is read only', (tester) async {
      final repo = FakeCompanyRepository(profile: const CompanyProfile(name: '株式会社サンプル文具'));
      await pumpApp(tester, const CompanyProfileScreen(), overrides: [
        companyRepositoryProvider.overrideWithValue(repo),
        companyCanEditProvider.overrideWithValue(false),
      ]);
      expect(find.byKey(const ValueKey('cp-unset')), findsNothing);
      expect(find.text('変更するにはユーザー管理の権限が必要です'), findsOneWidget);
      expect(find.byKey(const ValueKey('cp-save')), findsNothing);
      final name = tester.widget<TextField>(find.byKey(const ValueKey('cp-name')));
      expect(name.enabled, isFalse);
      expect(name.controller!.text, '株式会社サンプル文具');
    });
  });

  group('アップロード履歴 (0132)', () {
    testWidgets('lists kept files, filters by purpose, and searches', (tester) async {
      final repo = FakeEvidenceRepository([
        _doc(1, EvidencePurpose.plan, '納品書_1004.pdf', supplier: '株式会社新東光通商', plan: 7, ref: 'SKT-00012'),
        _doc(2, EvidencePurpose.quote, '見積_文具.xlsx', supplier: 'アケボノクラウン株式会社'),
      ]);
      await pumpApp(tester, const EvidenceScreen(), overrides: [
        evidenceRepositoryProvider.overrideWithValue(repo),
      ]);
      expect(find.text('納品書_1004.pdf'), findsOneWidget);
      expect(find.text('見積_文具.xlsx'), findsOneWidget);
      expect(find.text('登録済み SKT-00012'), findsOneWidget);
      expect(find.text('読み取りのみ（未登録）'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ev-purpose-quote')));
      await tester.pumpAndSettle();
      expect(repo.lastPurpose, EvidencePurpose.quote);
      expect(find.text('納品書_1004.pdf'), findsNothing);
      expect(find.text('見積_文具.xlsx'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ev-all')));
      await tester.enterText(find.byKey(const ValueKey('ev-search')), '新東光');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.lastSearch, '新東光');
      expect(find.text('納品書_1004.pdf'), findsOneWidget);
      expect(find.text('見積_文具.xlsx'), findsNothing);
    });

    testWidgets('nothing kept yet', (tester) async {
      await pumpApp(tester, const EvidenceScreen());
      expect(find.text('保管されたファイルはまだありません'), findsOneWidget);
    });
  });

  test('the preview carries the kept file, the addressee and the other companies (0132)', () {
    final p = ImportPreview.fromJson({
      'source': 'pdf_text',
      'line_count': 1,
      'total_quantity': 5,
      'lines': const [],
      'document_id': 42,
      'header': {
        'supplier_name': '株式会社新東光通商',
        'addressee': '株式会社サンプル文具',
        'supplier_candidates': ['株式会社新東光通商', 'アケボノクラウン株式会社', ''],
      },
    });
    expect(p.documentId, 42);
    expect(p.addressee, '株式会社サンプル文具');
    expect(p.supplierCandidates, ['株式会社新東光通商', 'アケボノクラウン株式会社']);
    final c = PlanCommit(deliveryNumber: 'D-1', lines: const [], documentId: p.documentId).toJson();
    expect(c['document_id'], 42);
    expect(const PlanCommit(deliveryNumber: 'D-1', lines: []).toJson().containsKey('document_id'), isFalse);
  });
}
