import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/outbound/presentation/outbound_downloads.dart' show saveFileProvider;
import 'package:wms_mobile/features/outbound_file/domain/outbound_sheet.dart';
import 'package:wms_mobile/features/reading_audit/data/reading_audit_repository.dart';
import 'package:wms_mobile/features/reading_audit/domain/reading_audit.dart';
import 'package:wms_mobile/features/reading_audit/presentation/reading_audit_builder.dart';
import 'package:wms_mobile/features/reading_audit/presentation/reading_audit_screen.dart';
import 'package:wms_mobile/features/stock_import/domain/stock_file.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

import '../../support/fake_reading_audit_repository.dart';
import '../../support/harness.dart';

const _jan1 = '4909999000014';
const _jan2 = '4909999000021';

final _at = DateTime(2026, 11, 21, 14, 3);

ReadingAudit _sample(String id, {AuditSource source = AuditSource.stockFile, List<AuditIssue>? issues}) => ReadingAudit(
      id: id,
      at: _at,
      source: source,
      fileName: '請求書_$id.pdf',
      byAi: true,
      supplier: 'テスト商事',
      lineCount: 3,
      issues: issues ??
          const [
            AuditIssue(kind: AuditKind.missing, field: 'JAN', lineNo: 2, detail: 'JANが読めない'),
            AuditIssue(kind: AuditKind.remedied, field: 'JAN', lineNo: 3, detail: '印字なし', remedy: 'カタログから補った'),
          ],
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));

  group('builder', () {
    test('a sheet: headings the server placed are covered, the rest not read; rows left out are not covered', () {
      final rows = [
        ['JANコード', '商品名称', '数量', '謎の列'],
        [_jan1, 'テストペン', '3', 'x'],
        ['', 'テストノート', '2', 'y'],
        [_jan2, 'テスト消しゴム', 'たくさん', 'z'],
      ];
      final sheet = parseStockRows(rows, meanings: const [
        HeadingMeaning(index: 1, header: '商品名称', field: 'product_name'),
      ]);
      final a = auditOfStockRead(l10n,
          id: 'a', source: AuditSource.stockFile, fileName: '在庫.xlsx', byAi: false,
          read: sheet.read, problems: sheet.problems, sheet: sheet, at: _at);
      final text = [for (final i in a.issues) '${i.kind.name}|${i.lineNo}|${i.field}|${i.detail}|${i.remedy}'];
      expect(text, contains(allOf(startsWith('remedied|null|見出し'), contains('商品名称'))));
      expect(text, contains(allOf(startsWith('missing|null|見出し'), contains('謎の列'))));
      expect(text.where((t) => t.startsWith('unresolved|')), hasLength(2));
      expect(text, contains(allOf(startsWith('unresolved|4|数量'), contains('たくさん'))));
    });

    test('a check: corrected, filled, removed and added rows each said so', () {
      const read = [
        ReadRow(lineNo: 1, jan: _jan1, name: 'ペン', quantity: '100'),
        ReadRow(lineNo: 2, name: 'ノート', quantity: '2', flags: ['no_jan']),
        ReadRow(lineNo: 3, jan: _jan2, name: '合計', quantity: '102'),
      ];
      const checked = [
        ReadRow(lineNo: 1, jan: _jan1, name: 'ペン', quantity: '10', flags: [humanCorrectedFlag]),
        ReadRow(lineNo: 2, jan: _jan2, name: 'ノート', quantity: '2', flags: [humanCorrectedFlag]),
        ReadRow(lineNo: 3, jan: _jan2, name: '合計', quantity: '102', flags: [humanRemovedFlag]),
        ReadRow(lineNo: 4, jan: '4909999000038', name: '消しゴム', quantity: '1'),
      ];
      final a = auditOfStockRead(l10n,
          id: 'b', source: AuditSource.unplanned, fileName: '納品書.jpg', byAi: true, read: read, checked: checked, at: _at);
      final byKind = {
        for (final k in AuditKind.values) k: [for (final i in a.issues) if (i.kind == k) auditIssueText(l10n, i)],
      };
      expect(byKind[AuditKind.misread], hasLength(2));
      expect(byKind[AuditKind.misread]!.first, '1行目 数量: 読み取り「100」→ 人が「10」に修正');
      expect(byKind[AuditKind.misread]!.last, contains('3行目 行: 人がこの行を取り込みから外した'));
      // The JAN not read, filled in by a person: said once, with what they wrote.
      expect(byKind[AuditKind.missing], [
        contains('2行目 JAN'),
        contains('4行目 行: 読み取れなかった行を人が追加'),
      ]);
      expect(byKind[AuditKind.missing]!.first, contains('対処: 人が「$_jan2」を入力'));
    });

    test('a failure is one item for the whole file', () {
      final a = auditOfFailure(l10n,
          id: 'c', source: AuditSource.outbound, fileName: '明細.pdf', byAi: true, reason: 'AIの上限', at: _at);
      expect(a.issues.single.kind, AuditKind.unresolved);
      expect(auditIssueText(l10n, a.issues.single), 'ファイル全体: 読み取れなかった: AIの上限');
    });

    test('a shipping list: missing columns, a guessed JAN column, rows skipped or with a bad JAN', () {
      final a = auditOfOutbound(l10n,
          id: 'd',
          fileName: '出荷.xlsx',
          byAi: false,
          at: _at,
          sheet: const OutboundSheet(
            sheetName: 'S',
            headerRow: 0,
            headings: ['品名', 'コード', '数量'],
            columns: {OutboundColumn.jan: 1, OutboundColumn.quantity: 2},
            janGuessed: true,
            rows: [
              OutboundRow(rowNo: 2, jan: _jan1, janRaw: _jan1, quantity: 1),
              OutboundRow(rowNo: 3, janRaw: '12-34', quantity: 2),
              OutboundRow(rowNo: 4, jan: _jan2, janRaw: _jan2),
            ],
            skipped: [(rowNo: 5, text: '合計 3')],
          ));
      final t = [for (final i in a.issues) '${i.kind.name} ${auditIssueText(l10n, i)}'];
      expect(t, contains(allOf(startsWith('remedied 見出し'), contains('2列目'))));
      expect(t, contains(startsWith('doubt 5行目 行: 数量・JAN・品番が無いため読まなかった行: 合計 3')));
      expect(t, contains(startsWith('misread 3行目 JAN: JAN欄「12-34」')));
      expect(t, contains(startsWith('missing 4行目 数量')));
    });

    test('Markdown: one reading by kind, with its remedies; several under one title', () {
      final md = auditToMarkdown(l10n, _sample('x'));
      expect(md, startsWith('# 請求書\\_x.pdf\n'));
      expect(md, contains('- 画面: 発注（ファイル取込）'));
      expect(md, contains('- 仕入先: テスト商事'));
      expect(md, contains('- 指摘: 読み取れなかった 1件、対処できた 1件'));
      expect(md, contains('## 読み取れなかった\n\n- **2行目 JAN**: JANが読めない'));
      expect(md, contains('- **3行目 JAN**: 印字なし\n  - 対処: カタログから補った'));
      final all = auditsToMarkdown(l10n, [_sample('x'), _sample('y')], now: _at);
      expect(all, startsWith('# 読み取り検査（2件）'));
      expect(all, contains('- 指摘: 読み取れなかった 2件、対処できた 2件'));
      expect(all, contains('## 請求書\\_y.pdf'));
      expect(all, contains('### 対処できた'));
      expect(auditFileName(l10n, _at, '請求書 11月.pdf'), '読み取り検査_20261121_1403_請求書_11月.md');
    });
  });

  group('recorder', () {
    test('kept on the server in order: read, then checked; the file uploaded once; nothing kept for a clean reading', () async {
      final repo = FakeReadingAuditRepository();
      final rec = ReadingAuditRecorder(repo);
      final bytes = Uint8List.fromList([37, 80, 68, 70]);
      // Two in a row, as a list is read and then matched.
      unawaited(rec.keep(_sample('1'), bytes: bytes));
      await rec.keep(_sample('1', issues: const [AuditIssue(kind: AuditKind.doubt, field: 'JAN', detail: '要確認')]),
          bytes: bytes);
      expect(repo.kept.single.issues.single.kind, AuditKind.doubt);
      expect(repo.files.values.single.$1, '請求書_1.pdf');
      await rec.keep(_sample('2', issues: const []), bytes: bytes);
      expect(repo.kept.map((a) => a.id), ['1']);
      // Taken out of the list, it stays out.
      await repo.remove([repo.kept.single.serverId!]);
      await rec.keep(_sample('1'));
      expect(repo.kept, isEmpty);
    });

    test('as the server lists it', () {
      final a = ReadingAudit.fromServer(const {
        'id': 7, 'client_id': 'abc', 'read_at': '2026-11-21T05:03:00Z', 'source': 'outbound', 'file_name': '明細.pdf',
        'by_ai': true, 'line_count': 4, 'storage_path': '7/1-x.pdf', 'byte_size': 2048, 'created_by_name': '倉庫 太郎',
        'issues': [
          {'kind': 'misread', 'field': '数量', 'line': 3, 'detail': 'x'},
        ],
      });
      expect((a.id, a.serverId, a.source, a.filePath, a.fileSize, a.byName), ('abc', 7, AuditSource.outbound, '7/1-x.pdf', 2048, '倉庫 太郎'));
      expect(a.issues.single.lineNo, 3);
      expect(a.toSave()['client_id'], 'abc');
      expect(auditToMarkdown(l10n, a), contains('- 読み取った人: 倉庫 太郎'));
    });
  });

  testWidgets('the screen: a list of files, filtered, opened as sentences, saved as Markdown, the file downloaded, removed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <(String, Uint8List)>[];
    final repo = FakeReadingAuditRepository([
      _sample('a'),
      _sample('b',
          source: AuditSource.outbound,
          issues: const [AuditIssue(kind: AuditKind.ambiguous, field: '数量', lineNo: 4, detail: '候補「2」／「20」')]),
    ]);
    final bId = repo.kept.firstWhere((a) => a.id == 'b').serverId!;
    await repo.attach(bId, '請求書_b.pdf', Uint8List.fromList([1, 2, 3]));
    await pumpApp(tester, const ReadingAuditScreen(), overrides: [
      readingAuditRepositoryProvider.overrideWithValue(repo),
      saveFileProvider.overrideWithValue((n, b) async => saved.add((n, b))),
    ]);
    expect(find.text('2件 / 全2件'), findsOneWidget);
    expect(find.text('読み取れなかった 1件'), findsOneWidget);

    // Found by name.
    await tester.enterText(find.byKey(const ValueKey('ra-search')), '_b');
    await tester.pump();
    expect(find.byKey(const ValueKey('ra-a')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('ra-search')), '');
    await tester.pump();

    // Only what had several readings.
    await tester.tap(find.byKey(const ValueKey('ra-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('候補が複数').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ra-a')), findsNothing);
    expect(find.byKey(const ValueKey('ra-b')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ra-tile-b')));
    await tester.pumpAndSettle();
    expect(find.text('・4行目 数量: 候補「2」／「20」'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ra-save-b')));
    await tester.pumpAndSettle();
    expect(saved.last.$1, endsWith('_請求書_b.md'));
    expect(utf8.decode(saved.last.$2), contains('## 候補が複数'));
    // The file itself, as it was read.
    await tester.tap(find.byKey(const ValueKey('ra-file-b')));
    await tester.pumpAndSettle();
    expect(saved.last.$1, '請求書_b.pdf');
    expect(saved.last.$2, [1, 2, 3]);

    // All that is shown, in one file.
    await tester.tap(find.byKey(const ValueKey('ra-save-all')));
    await tester.pumpAndSettle();
    final all = utf8.decode(saved.last.$2);
    expect(all, startsWith('# 読み取り検査（1件）'));
    expect(all, isNot(contains('請求書\\_a.pdf')));

    // Removed: the one shown, after asking.
    await tester.tap(find.byKey(const ValueKey('ra-remove-shown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ra-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.removedIds, {bId});
    expect(find.byKey(const ValueKey('ra-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ra-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべての種類').last);
    await tester.pumpAndSettle();
    expect(find.text('1件 / 全1件'), findsOneWidget);
    // One by one too.
    await tester.tap(find.byKey(const ValueKey('ra-tile-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ra-remove-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ra-remove-ok')));
    await tester.pumpAndSettle();
    expect(repo.kept, isEmpty);
    expect(find.byKey(const ValueKey('ra-empty')), findsOneWidget);
  });

  test('in システム管理, for the system administrator', () {
    final e = buildFeatureCatalog().firstWhere((g) => g.id == 'management').entries.firstWhere((e) => e.id == 'reading_audit');
    expect(e.label(l10n), '読み取り検査');
    expect(e.visibleFor(const ['user.manage']), isTrue);
    expect(e.visibleFor(const ['inventory.adjust']), isFalse);
  });
}
