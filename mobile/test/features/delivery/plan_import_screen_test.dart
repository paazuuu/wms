import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/delivery/application/delivery_providers.dart';
import 'package:wms_mobile/features/delivery/data/delivery_repository.dart';
import 'package:wms_mobile/features/delivery/presentation/plan_import_screen.dart';

import '../../support/harness.dart';

PlatformFile _fakeFile() => PlatformFile(
      name: 'note.jpg',
      size: 3,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

ImportPreview _previewWith(List<Map<String, dynamic>> lines) => ImportPreview(
      source: 'gemini',
      lineCount: lines.length,
      totalQuantity: lines.fold(0, (s, l) => s + (l['planned_quantity'] as int)),
      lines: lines,
      deliveryNumber: 'ABC-123',
    );

Future<void> _openReview(
  WidgetTester tester,
  FakeDeliveryRepository repo,
) async {
  // The review step stacks header fields above the line-items section in a
  // plain ListView, which only builds what fits the surface (sliver lazy
  // building) — a tall surface keeps the lines section reachable by
  // find.text() without a manual scroll.
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await pumpApp(
    tester,
    PlanImportScreen(pickFile: () async => _fakeFile()),
    overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
  );

  await tester.tap(find.text('ファイルを選ぶ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('読み取る'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reads a file and shows the extracted lines editable',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    expect(find.text('ボールペン'), findsOneWidget);
    expect(find.text('×10'), findsOneWidget);
  });

  testWidgets('an empty read shows an explicit empty state, not nothing',
      (tester) async {
    final repo = FakeDeliveryRepository(const [], preview: _previewWith([]));

    await _openReview(tester, repo);

    expect(find.text('明細はまだありません。「行を追加」から入力できます。'), findsOneWidget);
  });

  testWidgets('editing a line changes what gets committed (§31 修正)',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.text('ボールペン'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '数量'), '7');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('×7'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines.single['planned_quantity'], 7);
  });

  testWidgets('deleting a line removes it from what gets committed',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
        {'jan_code': '4901234567895', 'product_name': 'ノート', 'planned_quantity': 5},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('ボールペン'), findsNothing);
    expect(find.text('ノート'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines, hasLength(1));
    expect(repo.lastCommit!.lines.single['jan_code'], '4901234567895');
  });

  testWidgets('adding a line includes it in what gets committed',
      (tester) async {
    final repo = FakeDeliveryRepository(const [], preview: _previewWith([]));

    await _openReview(tester, repo);

    await tester.tap(find.text('行を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'JANコード'), '4901234567896');
    await tester.enterText(find.widgetWithText(TextField, '商品名'), '消しゴム');
    await tester.enterText(find.widgetWithText(TextField, '数量'), '3');
    await tester.tap(find.widgetWithText(FilledButton, '行を追加').last);
    await tester.pumpAndSettle();

    expect(find.text('消しゴム'), findsOneWidget);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines.single['jan_code'], '4901234567896');
  });

  testWidgets('splitting a line produces two rows that still sum to the original',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 10},
      ]),
    );

    await _openReview(tester, repo);

    await tester.tap(find.byIcon(Icons.call_split));
    await tester.pumpAndSettle();

    expect(find.text('ボールペン'), findsNWidgets(2));
    expect(find.text('×5'), findsNWidgets(2));

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    final lines = repo.lastCommit!.lines;
    expect(lines, hasLength(2));
    expect(
      lines.fold<int>(0, (s, l) => s + (l['planned_quantity'] as int)),
      10,
    );
  });

  testWidgets('merging duplicate JANs combines their quantities',
      (tester) async {
    final repo = FakeDeliveryRepository(
      const [],
      preview: _previewWith([
        {'jan_code': '4901234567894', 'product_name': 'ボールペン', 'planned_quantity': 4},
        {'jan_code': '4901234567894', 'product_name': '', 'planned_quantity': 6},
      ]),
    );

    await _openReview(tester, repo);

    expect(find.text('同じJANをまとめる'), findsOneWidget);
    await tester.tap(find.text('同じJANをまとめる'));
    await tester.pumpAndSettle();

    expect(find.text('×10'), findsOneWidget);
    expect(find.text('同じJANをまとめる'), findsNothing);

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(repo.lastCommit!.lines, hasLength(1));
    expect(repo.lastCommit!.lines.single['planned_quantity'], 10);
  });
}
