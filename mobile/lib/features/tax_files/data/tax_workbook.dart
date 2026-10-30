import 'dart:typed_data';

import 'dart:convert' show Utf8Encoder;

import 'package:archive/archive.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/export/xlsx.dart';
import '../domain/tax_purchases.dart';

final _d = DateFormat('yyyy/MM/dd');
final _dt = DateFormat('yyyy/MM/dd HH:mm');

/// The evidence file's name inside the month's ZIP (and in the Excel):
/// 20260901_新東光通商株式会社_取込18.pdf.
String evidenceFileName(TaxPurchase p) {
  final ext = RegExp(r'\.[A-Za-z0-9]{2,5}$').firstMatch(p.evidenceName ?? p.originalName ?? '')?.group(0) ?? '.pdf';
  final supplier = (p.supplierName ?? '仕入先不明').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '');
  return '${DateFormat('yyyyMMdd').format(p.day)}_${supplier}_取込${p.importId}$ext';
}

String _doubt(String code) => switch (code) {
      'no_registration' => '登録番号なし（適格請求書か確認）',
      'totals' => '書類の合計と計算が合わない',
      'no_amounts' => '金額が読めていない',
      'no_date' => '書類の日付が読めず取込日で計上',
      'duplicate' => '同じ請求書が二重に取り込まれています（片方を取り消してください）',
      _ => code,
    };

/// 税理士用ファイル (0168): one month's purchases as a workbook.
///  * 請求書一覧 — one invoice a row: date, supplier, 登録番号, 税抜・消費税
///    by rate (10% / 8%), 税抜・消費税・税込, the document's own total, paid,
///    the evidence file and its SHA-256, kept until.
///  * 明細 — every line: product, quantity, unit price, rate, 税抜 and the
///    tax and 税込 for reference.
///  * 仕入先別 — per supplier.
///  * 説明 — the month, when made, and how the tax is worked out.
Uint8List buildTaxWorkbook(TaxMonth m, {DateTime? now, String? madeBy}) {
  final made = now ?? DateTime.now();
  final title = '${m.month.year}年${m.month.month}月分 仕入一覧';
  double r0(double v) => v.roundToDouble();

  final invoices = <List<Object?>>[];
  final flagged = <(int, int)>{};
  for (final (i, p) in m.purchases.indexed) {
    final br = p.byRate;
    final t10 = br[10], t8 = br[8], t0 = br[0];
    final doubts = p.doubts;
    invoices.add([
      _d.format(p.day),
      p.supplierName ?? '',
      p.registrationNumber ?? '',
      p.qualified ? '○' : '',
      p.docNumber ?? '',
      t10 == null ? null : r0(t10.net),
      t10?.tax,
      t8 == null ? null : r0(t8.net),
      t8?.tax,
      t0 == null ? null : r0(t0.net),
      r0(p.net),
      r0(p.tax),
      r0(p.gross),
      p.docTotal,
      switch (p.agrees) { true => '一致', false => '不一致', null => '' },
      p.paid ? '振込済' : '未払い',
      evidenceFileName(p),
      p.importId,
      p.sha256 ?? '',
      _d.format(p.keptTill),
      [p.note ?? '', for (final d in doubts) d == 'duplicate' ? '取込 #${p.sameAs} と同じ請求書（二重取込・片方を取り消してください）' : _doubt(d)].where((x) => x.isNotEmpty).join(' / '),
    ]);
    if (!p.qualified) flagged.add((i, 2));
    if (p.agrees == false) flagged.addAll({(i, 12), (i, 13), (i, 14)});
    if (doubts.isNotEmpty) flagged.add((i, 20));
  }
  double sum(int rate, bool tax) =>
      m.purchases.fold(0, (s, p) => s + (tax ? (p.byRate[rate]?.tax ?? 0) : (p.byRate[rate]?.net ?? 0)));

  final lines = <List<Object?>>[];
  for (final p in m.purchases) {
    for (final l in p.taxLines) {
      lines.add([
        _d.format(p.day),
        p.supplierName ?? '',
        p.docNumber ?? '',
        l.row.lineNo,
        l.row.maker,
        l.row.name,
        l.row.code,
        l.row.jan,
        l.quantity,
        l.row.ledger.unit,
        l.unitNet,
        l.unitGross,
        '${l.rate}%',
        r0(l.net),
        r0(l.tax),
        r0(l.gross),
        p.importId,
      ]);
    }
  }

  final bySupplier = <String, ({String reg, int count, double net, double tax})>{};
  for (final p in m.purchases) {
    final k = p.supplierName ?? '仕入先不明';
    final was = bySupplier[k];
    bySupplier[k] = (
      reg: (was?.reg ?? '').isNotEmpty ? was!.reg : (p.registrationNumber ?? ''),
      count: (was?.count ?? 0) + 1,
      net: (was?.net ?? 0) + p.net,
      tax: (was?.tax ?? 0) + p.tax,
    );
  }

  return buildXlsxBook([
    XlsxSheet(
      name: '請求書一覧',
      top: [
        [title],
        ['作成', _dt.format(made), if (madeBy != null) madeBy],
      ],
      headers: const [
        '日付', '仕入先', '登録番号', '適格請求書', '請求書番号',
        '10%対象 税抜', '10% 消費税', '8%対象 税抜', '8% 消費税', '非課税・対象外',
        '税抜合計', '消費税合計', '税込合計', '書類の合計(税込)', '照合', '支払', '証拠ファイル', '取込番号', 'SHA-256',
        '保存期限', '備考・要確認',
      ],
      rows: invoices,
      flagged: flagged,
      widths: const [11, 26, 17, 8, 14, 13, 11, 13, 11, 12, 13, 12, 13, 14, 8, 8, 40, 8, 20, 11, 40],
      bottom: [
        [
          '合計（${m.purchases.length}件）', '', '', '', '',
          r0(sum(10, false)), sum(10, true), r0(sum(8, false)), sum(8, true), r0(sum(0, false)),
          r0(m.net), r0(m.tax), r0(m.gross),
        ],
      ],
    ),
    XlsxSheet(
      name: '明細',
      top: [
        [title],
      ],
      headers: const [
        '日付', '仕入先', '請求書番号', '行', 'メーカー', '商品名', '品番', 'JAN', '数量', '単位',
        '単価(税抜)', '単価(税込)', '税率', '税抜金額', '消費税(参考)', '税込金額(参考)', '取込番号',
      ],
      rows: lines,
      widths: const [11, 24, 14, 5, 14, 30, 16, 15, 8, 6, 10, 10, 6, 12, 11, 12, 8],
    ),
    XlsxSheet(
      name: '仕入先別',
      top: [
        [title],
      ],
      headers: const ['仕入先', '登録番号', '件数', '税抜', '消費税', '税込'],
      rows: [
        for (final e in bySupplier.entries)
          [e.key, e.value.reg, e.value.count, r0(e.value.net), r0(e.value.tax), r0(e.value.net + e.value.tax)],
      ],
      widths: const [30, 17, 6, 14, 12, 14],
      bottom: [
        ['合計', '', m.purchases.length, r0(m.net), r0(m.tax), r0(m.gross)],
      ],
    ),
    XlsxSheet(
      name: '説明',
      headers: const ['項目', '内容'],
      rows: [
        ['対象', title],
        ['作成日時', _dt.format(made)],
        ['件数', '${m.purchases.length}件（要確認 ${m.doubtful}件）'],
        ['計上月', '書類の日付の月。日付が読めなかった書類は取り込んだ日の月'],
        ['対象の取込', '「ファイルから在庫登録」で取り込んだ請求書・納品書（取り消したものは除く。検品待ちも含む）'],
        ['金額', '税抜は書類の単価・金額のとおり。税込の単価しかない行は税率で税抜に戻して計算'],
        ['消費税', '1枚の請求書・税率ごとに1回計算し、1円未満切り捨て（書類に消費税額があり税率が1つのときは書類の額）'],
        ['明細の消費税', '行ごとの消費税・税込は参考値（合計とは端数で差が出ることがあります）'],
        ['税率', '書類に税率がない行は10%。8%（軽減税率）・非課税は書類の記載から判断'],
        ['証拠', '各請求書の元ファイル（ZIPに「証拠ファイル」の名前で同梱）。SHA-256で改ざんがないことを確認できます'],
        ['保存期限', '書類の日付から7年（この月の分は ${_d.format(m.keptTill)} まで）'],
        ['輸出の還付申請', '仕入税額控除の確認用に、登録番号・税率別の消費税額を載せています'],
      ],
      widths: const [16, 90],
    ),
  ]);
}

/// The month's file and every invoice it lists, in one ZIP: the workbook
/// at the top, the originals in 証拠/ under the names the workbook gives.
/// [originals] by import id; one missing is listed in 不足.txt.
Uint8List buildTaxZip(TaxMonth m, Uint8List workbook, Map<int, Uint8List> originals) {
  final base = '${m.month.year}-${m.month.month.toString().padLeft(2, '0')}_仕入一覧';
  final a = Archive()..add(ArchiveFile('$base.xlsx', workbook.length, workbook));
  final missing = <String>[];
  for (final p in m.purchases) {
    final bytes = originals[p.importId];
    if (bytes == null) {
      missing.add('${evidenceFileName(p)}（取込${p.importId}）');
      continue;
    }
    a.add(ArchiveFile('証拠/${evidenceFileName(p)}', bytes.length, bytes));
  }
  if (missing.isNotEmpty) {
    final text = '元ファイルを取得できなかった請求書:\n${missing.join('\n')}\n';
    final b = Uint8List.fromList(_utf8(text));
    a.add(ArchiveFile('不足.txt', b.length, b));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}

List<int> _utf8(String s) => const Utf8Encoder().convert(s);
