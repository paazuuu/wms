import '../../../l10n/app_localizations.dart';
import '../../master_import/domain/master_import.dart' show MasterLine;
import '../../notation/domain/notation.dart' show ColumnField;
import '../../notation/presentation/notation_labels.dart';
import '../../outbound_file/domain/outbound_plan.dart';
import '../../outbound_file/domain/outbound_sheet.dart';
import '../../outbound_file/presentation/outbound_file_screen.dart' show outboundColumnLabel;
import '../../qc/domain/inspection.dart' show normalizeJan;
import '../../stock_import/domain/stock_file.dart';
import '../domain/reading_audit.dart';

/// 読み取り検査 from a reading: what the reader flagged, what a person
/// corrected on 読み取り結果の確認, what was left out, and what the system's
/// own remedies covered — each in words, for the people improving the reader.

/// The reader's flags, by what they mean here.
const _missingFlags = {'no_jan', 'no_quantity'};
const _ambiguousFlags = {'ai_disagree', 'split_disagree', 'jan_restore_mismatch', 'jan_code_mismatch'};
const _remedyFlags = {'jan_by_code', 'jan_restored', 'qty_from_amount', 'qty_from_cases'};

/// Said on every row, or a person's own marks: nothing to learn from.
const _quietFlags = {'no_maker', humanCheckedFlag, humanCorrectedFlag, humanRemovedFlag};

/// A row's fields as read, by key.
typedef _Values = Map<String, String>;

_Values _valuesOf(ReadRow r) => {
      'jan': normalizeJan(r.jan) ?? r.jan.trim(),
      'quantity': r.quantity.replaceAll(RegExp(r'[,，\s]'), ''),
      'name': r.name.trim(),
      'maker': r.maker.trim(),
      'code': r.code.trim(),
      'class_code': r.ledger.classCode.trim(),
    };

_Values _valuesOfLine(MasterLine l) => {
      'jan': l.jan,
      'quantity': l.quantity.replaceAll(RegExp(r'[,，\s]'), ''),
      'name': l.supplierName.trim(),
      'maker': l.maker.trim(),
      'code': (l.productCode.isNotEmpty ? l.productCode : l.supplierCode).trim(),
      'class_code': '${l.ledger['class_code'] ?? ''}'.trim(),
    };

String _summary(_Values v) =>
    [v['jan'], v['code'], v['name'], v['quantity']].where((s) => s != null && s.isNotEmpty).join(' / ');

/// A field in words.
String auditFieldLabel(AppLocalizations l10n, String key) => switch (key) {
      'jan' => l10n.ntFieldJan,
      'quantity' => l10n.ntFieldQuantity,
      'name' => l10n.ntFieldName,
      'maker' => l10n.ntFieldMaker,
      'code' => l10n.ntFieldCode,
      'class_code' => l10n.lgClassCode,
      'amount' => l10n.ntFieldAmount,
      'heading' => l10n.raFieldHeading,
      'rows' => l10n.raFieldRows,
      'line' => l10n.raFieldLine,
      'file' => l10n.raFieldFile,
      _ => alternativeLabel(l10n, key),
    };

/// The field a flag is about.
String _fieldOfFlag(String flag) {
  final parts = flag.split(':');
  final head = parts.first;
  if (head == 'ai_disagree' && parts.length > 1) {
    return switch (parts[1]) {
      'raw_jan_code' => 'jan',
      'planned_quantity' => 'quantity',
      'product_name' => 'name',
      'product_code' => 'code',
      _ => parts[1],
    };
  }
  if (head.startsWith('jan') || head == 'no_jan') return 'jan';
  if (head.startsWith('qty') || head == 'no_quantity') return 'quantity';
  if (head == 'amount_mismatch' || head == 'total_mismatch') return 'amount';
  if (head.startsWith('split')) return 'rows';
  return 'line';
}

/// Another reading's key as the reader names it (product_code …) → ours.
String _fieldOfAlternative(String key) => switch (key) {
      'raw_jan_code' || 'jan_code' => 'jan',
      'planned_quantity' => 'quantity',
      'product_name' => 'name',
      'product_code' || 'code_product' => 'code',
      _ => key,
    };

/// What a remedy did, in words.
String _remedyText(AppLocalizations l10n, String flag, _Values v) {
  final parts = flag.split(':');
  return switch (parts.first) {
    'jan_by_code' => l10n.raRemedyJanByCode(janSourceLabel(l10n, parts.length > 1 ? parts[1] : ''), v['jan'] ?? ''),
    'jan_restored' => l10n.raRemedyJanRestored(v['jan'] ?? ''),
    'qty_from_amount' => l10n.raRemedyQtyFromAmount(v['quantity'] ?? ''),
    'qty_from_cases' => l10n.raRemedyQtyFromCases(v['quantity'] ?? ''),
    _ => flagLabel(l10n, flag),
  };
}

/// One row's items: its flags, its other readings and — once a person has
/// checked it — what they changed.
List<AuditIssue> _rowIssues(
  AppLocalizations l10n, {
  required int lineNo,
  required List<String> flags,
  required _Values read,
  Map<String, String> alternatives = const {},
  _Values? checked,
  bool removed = false,
}) {
  final out = <AuditIssue>[];
  final handled = <String>{};
  String shown(String key, _Values v) => (v[key] ?? '').isEmpty ? l10n.raEmptyValue : v[key]!;
  final alts = {for (final e in alternatives.entries) _fieldOfAlternative(e.key): e.value};

  for (final f in flags) {
    final head = f.split(':').first;
    if (_quietFlags.contains(f) || _quietFlags.contains(head)) continue;
    final field = _fieldOfFlag(f);
    final label = auditFieldLabel(l10n, field);
    // A JAN found by the 品番 says the JAN was not printed: covered.
    if (head == 'no_jan' && flags.any((x) => x.startsWith('jan_by_code'))) continue;
    if (_remedyFlags.contains(head)) {
      out.add(AuditIssue(
        kind: AuditKind.remedied,
        field: label,
        lineNo: lineNo,
        detail: head == 'jan_by_code' ? l10n.raJanNotPrinted : flagLabel(l10n, f),
        remedy: _remedyText(l10n, f, read),
      ));
    } else if (_missingFlags.contains(head)) {
      final filled = checked == null ? '' : (checked[field] ?? '');
      handled.add(field);
      out.add(AuditIssue(
        kind: AuditKind.missing,
        field: label,
        lineNo: lineNo,
        detail: flagLabel(l10n, f),
        remedy: filled.isNotEmpty && filled != read[field] ? l10n.raHumanFilled(filled) : null,
      ));
    } else if (_ambiguousFlags.contains(head)) {
      final other = alts.remove(field);
      out.add(AuditIssue(
        kind: AuditKind.ambiguous,
        field: label,
        lineNo: lineNo,
        detail: other != null
            ? '${flagLabel(l10n, f)}　${l10n.raCandidates(shown(field, read), other)}'
            : '${flagLabel(l10n, f)}　${l10n.raReadAs(shown(field, read))}',
      ));
    } else {
      out.add(AuditIssue(
        kind: AuditKind.doubt,
        field: label,
        lineNo: lineNo,
        detail: read.containsKey(field)
            ? '${flagLabel(l10n, f)}　${l10n.raReadAs(shown(field, read))}'
            : flagLabel(l10n, f),
      ));
    }
  }
  for (final e in alts.entries) {
    if (e.value == read[e.key]) continue;
    out.add(AuditIssue(
      kind: AuditKind.ambiguous,
      field: auditFieldLabel(l10n, e.key),
      lineNo: lineNo,
      detail: l10n.raCandidates(shown(e.key, read), e.value),
    ));
  }
  if (removed) {
    out.add(AuditIssue(
      kind: AuditKind.misread,
      field: auditFieldLabel(l10n, 'line'),
      lineNo: lineNo,
      detail: l10n.raRemovedRow(_summary(read)),
    ));
    return out;
  }
  if (checked != null) {
    for (final key in const ['jan', 'quantity', 'name', 'maker', 'code', 'class_code']) {
      if (handled.contains(key)) continue;
      final a = read[key] ?? '', b = checked[key] ?? '';
      if (a == b) continue;
      out.add(a.isEmpty
          ? AuditIssue(
              kind: AuditKind.missing,
              field: auditFieldLabel(l10n, key),
              lineNo: lineNo,
              detail: l10n.raNotRead,
              remedy: l10n.raHumanFilled(b))
          : AuditIssue(
              kind: AuditKind.misread,
              field: auditFieldLabel(l10n, key),
              lineNo: lineNo,
              detail: b.isEmpty ? l10n.raHumanCleared(a) : l10n.raCorrected(a, b)));
    }
  }
  return out;
}

/// What stayed wrong and so did not go in.
List<AuditIssue> _leftOut(AppLocalizations l10n, List<StockFileProblem> problems) => [
      for (final p in problems)
        if (p.code != 'not_item')
          AuditIssue(
            kind: AuditKind.unresolved,
            field: auditFieldLabel(l10n, p.code == 'no_jan' ? 'jan' : 'quantity'),
            lineNo: p.lineNo,
            detail: p.code == 'no_jan'
                ? l10n.raLeftNoJan(p.value ?? l10n.raEmptyValue)
                : l10n.raLeftBadQuantity(p.value ?? l10n.raEmptyValue),
          ),
    ];

/// A stock reading (発注, 予定外の入荷): [read] as the reader gave it,
/// [checked] as a person left it on 読み取り結果の確認 (null: not checked),
/// [problems] what stayed wrong. [sheet] adds a sheet's headings.
ReadingAudit auditOfStockRead(
  AppLocalizations l10n, {
  required String id,
  required AuditSource source,
  required String fileName,
  required bool byAi,
  required List<ReadRow> read,
  List<ReadRow>? checked,
  List<StockFileProblem> problems = const [],
  Map<int, Map<String, String>> alternatives = const {},
  StockSheet? sheet,
  String? supplier,
  DateTime? at,
}) {
  final issues = <AuditIssue>[];
  if (sheet != null) issues.addAll(_headingIssues(l10n, sheet));
  final after = {for (final r in checked ?? const <ReadRow>[]) r.lineNo: r};
  final readNos = {for (final r in read) r.lineNo};
  for (final r in read) {
    final c = checked == null ? null : after[r.lineNo];
    issues.addAll(_rowIssues(
      l10n,
      lineNo: r.lineNo,
      flags: r.flags,
      read: _valuesOf(r),
      alternatives: alternatives[r.lineNo] ?? const {},
      checked: c == null ? null : _valuesOf(c),
      removed: checked != null && (c == null || (c.humanRemoved && !r.humanRemoved)),
    ));
  }
  for (final c in checked ?? const <ReadRow>[]) {
    if (readNos.contains(c.lineNo) || c.humanRemoved) continue;
    issues.add(AuditIssue(
      kind: AuditKind.missing,
      field: auditFieldLabel(l10n, 'line'),
      lineNo: c.lineNo,
      detail: l10n.raAddedRow(_summary(_valuesOf(c))),
    ));
  }
  issues.addAll(_leftOut(l10n, problems));
  return ReadingAudit(
    id: id,
    at: at ?? DateTime.now(),
    source: source,
    fileName: fileName,
    byAi: byAi,
    supplier: (supplier ?? '').trim().isEmpty ? null : supplier!.trim(),
    lineCount: read.length,
    issues: issues,
  );
}

/// A sheet's headings: those the app did not know and the server placed
/// (covered), and those nobody placed (the column not read).
List<AuditIssue> _headingIssues(AppLocalizations l10n, StockSheet sheet) {
  String field(String wire) => columnFieldLabel(l10n, ColumnField.values.where((f) => f.wire == wire).firstOrNull);
  final judged = {for (final m in sheet.meanings) m.index};
  return [
    for (final m in sheet.usedMeanings)
      AuditIssue(
        kind: AuditKind.remedied,
        field: auditFieldLabel(l10n, 'heading'),
        detail: l10n.raHeadingUnknown(m.header),
        remedy: l10n.sfHeadingMeaning(m.header, field(m.field), columnSourceLabel(l10n, m.source)),
      ),
    for (final i in sheet.unplaced)
      if (!judged.contains(i) && i < sheet.headings.length && sheet.headings[i].isNotEmpty)
        AuditIssue(
          kind: AuditKind.missing,
          field: auditFieldLabel(l10n, 'heading'),
          detail: l10n.raHeadingNotPlaced(sheet.headings[i]),
        ),
  ];
}

/// A reading that gave nothing: the file could not be read, or the AI not
/// used.
ReadingAudit auditOfFailure(
  AppLocalizations l10n, {
  required String id,
  required AuditSource source,
  required String fileName,
  required bool byAi,
  required String reason,
  DateTime? at,
}) =>
    ReadingAudit(
      id: id,
      at: at ?? DateTime.now(),
      source: source,
      fileName: fileName,
      byAi: byAi,
      issues: [
        AuditIssue(kind: AuditKind.unresolved, field: auditFieldLabel(l10n, 'file'), detail: l10n.raNotReadAtAll(reason)),
      ],
    );

/// A shipping list (出庫): [aiLines] when the AI read it (a PDF, a photo),
/// [sheet] as read, [plan] once its rows were matched to products.
ReadingAudit auditOfOutbound(
  AppLocalizations l10n, {
  required String id,
  required String fileName,
  required bool byAi,
  OutboundSheet? sheet,
  List<MasterLine> aiLines = const [],
  List<OutboundPlanLine> plan = const [],
  DateTime? at,
}) {
  final issues = <AuditIssue>[];
  // The AI's lines are the sheet's rows from row 2 (row 1 is the headings).
  for (final l in aiLines) {
    issues.addAll(_rowIssues(l10n,
        lineNo: l.lineNo + 1, flags: l.flags, read: _valuesOfLine(l), alternatives: l.alternatives));
  }
  if (sheet != null) {
    if (!sheet.columns.containsKey(OutboundColumn.quantity)) {
      issues.add(AuditIssue(
        kind: AuditKind.unresolved,
        field: auditFieldLabel(l10n, 'heading'),
        detail: l10n.raNoColumn(outboundColumnLabel(l10n, OutboundColumn.quantity)),
      ));
    }
    if (!sheet.columns.containsKey(OutboundColumn.jan) && !sheet.columns.containsKey(OutboundColumn.code)) {
      issues.add(AuditIssue(
        kind: AuditKind.unresolved,
        field: auditFieldLabel(l10n, 'heading'),
        detail: l10n.raNoColumn(
            '${outboundColumnLabel(l10n, OutboundColumn.jan)}／${outboundColumnLabel(l10n, OutboundColumn.code)}'),
      ));
    }
    if (sheet.janGuessed) {
      final c = sheet.columns[OutboundColumn.jan];
      issues.add(AuditIssue(
        kind: AuditKind.remedied,
        field: auditFieldLabel(l10n, 'heading'),
        detail: l10n.raJanHeadingMissing,
        remedy: l10n.raJanColumnGuessed(c == null ? '' : '#${c + 1}'),
      ));
    }
    for (final s in sheet.skipped) {
      issues.add(AuditIssue(
        kind: AuditKind.doubt,
        field: auditFieldLabel(l10n, 'line'),
        lineNo: s.rowNo,
        detail: l10n.raSkippedRow(s.text),
      ));
    }
  }
  final planned = {for (final p in plan) p.row.rowNo: p};
  for (final row in sheet?.usable ?? false ? sheet!.rows : const <OutboundRow>[]) {
    final p = planned[row.rowNo];
    if (row.janInvalid) {
      issues.add(AuditIssue(
        kind: p?.found ?? false ? AuditKind.remedied : AuditKind.misread,
        field: auditFieldLabel(l10n, 'jan'),
        lineNo: row.rowNo,
        detail: l10n.raJanInvalid(row.janRaw.trim()),
        remedy: p?.found ?? false ? l10n.raFoundByCode(row.code ?? '') : null,
      ));
    }
    if (row.quantity == null) {
      issues.add(AuditIssue(
        kind: AuditKind.missing,
        field: auditFieldLabel(l10n, 'quantity'),
        lineNo: row.rowNo,
        detail: l10n.raNotRead,
      ));
    }
    switch (p?.status) {
      case OutboundStatus.unknownJan:
        issues.add(AuditIssue(
          kind: AuditKind.doubt,
          field: auditFieldLabel(l10n, 'jan'),
          lineNo: row.rowNo,
          detail: l10n.raJanUnknown(row.jan),
        ));
      case OutboundStatus.noJan when !row.janInvalid:
        issues.add(AuditIssue(
          kind: AuditKind.unresolved,
          field: auditFieldLabel(l10n, 'jan'),
          lineNo: row.rowNo,
          detail: l10n.raNoJanNoCode(row.code ?? l10n.raEmptyValue),
        ));
      case OutboundStatus.several:
        issues.add(AuditIssue(
          kind: AuditKind.ambiguous,
          field: auditFieldLabel(l10n, 'code'),
          lineNo: row.rowNo,
          detail: l10n.raSeveralProducts(row.code ?? ''),
        ));
      default:
        break;
    }
  }
  return ReadingAudit(
    id: id,
    at: at ?? DateTime.now(),
    source: AuditSource.outbound,
    fileName: fileName,
    byAi: byAi,
    lineCount: sheet?.rows.length ?? aiLines.length,
    issues: issues,
  );
}

// ---------------------------------------------------------------------------
// Words and Markdown.

String auditKindLabel(AppLocalizations l10n, AuditKind k) => switch (k) {
      AuditKind.missing => l10n.raKindMissing,
      AuditKind.misread => l10n.raKindMisread,
      AuditKind.ambiguous => l10n.raKindAmbiguous,
      AuditKind.remedied => l10n.raKindRemedied,
      AuditKind.unresolved => l10n.raKindUnresolved,
      AuditKind.doubt => l10n.raKindDoubt,
    };

String auditSourceLabel(AppLocalizations l10n, AuditSource s) => switch (s) {
      AuditSource.stockFile => l10n.raScreenStock,
      AuditSource.unplanned => l10n.raScreenUnplanned,
      AuditSource.outbound => l10n.raScreenOutbound,
    };

String _two(int n) => n.toString().padLeft(2, '0');

String auditTime(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// One item as a sentence: 「行3 JAN: … → 対処: …」.
String auditIssueText(AppLocalizations l10n, AuditIssue i) {
  final where = i.lineNo == null ? i.field : '${l10n.raLine(i.lineNo!)} ${i.field}';
  final remedy = i.remedy == null ? '' : '　${l10n.raRemedy(i.remedy!)}';
  return '$where: ${i.detail}$remedy';
}

String _md(String s) => s.replaceAll('\n', ' ').replaceAllMapped(RegExp(r'([\\`*_\[\]<>|#])'), (m) => '\\${m[1]}');

/// One reading as Markdown; [level] is its title's heading level.
String auditToMarkdown(AppLocalizations l10n, ReadingAudit a, {int level = 1}) {
  final h = '#' * level;
  final b = StringBuffer()
    ..writeln('$h ${_md(a.fileName)}')
    ..writeln()
    ..writeln('- ${l10n.raMdDate}: ${auditTime(a.at)}')
    ..writeln('- ${l10n.raMdScreen}: ${auditSourceLabel(l10n, a.source)}')
    ..writeln('- ${l10n.raMdReadBy}: ${a.byAi ? l10n.raByAi : l10n.raBySheet}');
  if (a.supplier != null) b.writeln('- ${l10n.raMdSupplier}: ${_md(a.supplier!)}');
  if (a.byName != null) b.writeln('- ${_md(l10n.raBy(a.byName!))}');
  b
    ..writeln('- ${l10n.raMdLines}: ${a.lineCount}')
    ..writeln('- ${l10n.raMdIssues}: ${a.counts.map((c) => l10n.raKindCount(auditKindLabel(l10n, c.$1), c.$2)).join('、')}');
  for (final (kind, _) in a.counts) {
    b
      ..writeln()
      ..writeln('$h# ${auditKindLabel(l10n, kind)}')
      ..writeln();
    for (final i in a.issues.where((i) => i.kind == kind)) {
      final where = i.lineNo == null ? i.field : '${l10n.raLine(i.lineNo!)} ${i.field}';
      b.writeln('- **${_md(where)}**: ${_md(i.detail)}');
      if (i.remedy != null) b.writeln('  - ${l10n.raMdRemedy}: ${_md(i.remedy!)}');
    }
  }
  return b.toString();
}

/// Several readings in one file, newest first.
String auditsToMarkdown(AppLocalizations l10n, List<ReadingAudit> list, {DateTime? now}) {
  final b = StringBuffer()
    ..writeln('# ${l10n.raMdAllTitle(list.length)}')
    ..writeln()
    ..writeln('- ${l10n.raMdExported}: ${auditTime(now ?? DateTime.now())}');
  final total = <AuditKind, int>{};
  for (final a in list) {
    for (final (k, n) in a.counts) {
      total[k] = (total[k] ?? 0) + n;
    }
  }
  b.writeln('- ${l10n.raMdIssues}: ${[
    for (final k in AuditKind.values)
      if ((total[k] ?? 0) > 0) l10n.raKindCount(auditKindLabel(l10n, k), total[k]!),
  ].join('、')}');
  for (final a in list) {
    b
      ..writeln()
      ..write(auditToMarkdown(l10n, a, level: 2));
  }
  return b.toString();
}

/// A file name for the Markdown: 読み取り検査_20261121_1403.md.
String auditFileName(AppLocalizations l10n, DateTime t, [String? file]) {
  final l = t.toLocal();
  final stamp = '${l.year}${_two(l.month)}${_two(l.day)}_${_two(l.hour)}${_two(l.minute)}';
  final base = file == null ? '' : '_${file.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')}';
  return '${l10n.featReadingAudit}_$stamp$base.md';
}
