import 'package:equatable/equatable.dart';

/// 読み取り検査: what a file reading could not do, for improving the reader
/// later. Kept on the server apart from everything else (0224): not stock,
/// not products, not booked.

/// What kind of trouble an item was.
enum AuditKind {
  /// Something that should have been read was not (no JAN, no quantity, a
  /// heading not understood, a row a person had to add).
  missing,

  /// Read wrongly: a person corrected it, or took the row out.
  misread,

  /// More than one reading came up (two AI readings disagreed, another
  /// candidate for a 品番 or a quantity).
  ambiguous,

  /// Missing or doubtful, and one of the system's own remedies covered it
  /// (the JAN from the 品番, the quantity from the amount …).
  remedied,

  /// Nothing covered it: the row was left out, or the file not read.
  unresolved,

  /// Flagged by the reader as worth a look (a JAN check digit, a total
  /// that does not add up …).
  doubt;

  String get wire => name;

  static AuditKind fromWire(String? w) => values.where((k) => k.name == w).firstOrNull ?? doubt;
}

/// Which screen read the file.
enum AuditSource {
  /// 発注（ファイル取込）.
  stockFile('stock_file'),

  /// 予定外の入荷.
  unplanned('unplanned'),

  /// 出庫（ファイル取込）.
  outbound('outbound');

  const AuditSource(this.wire);
  final String wire;

  static AuditSource fromWire(String? w) => values.where((s) => s.wire == w).firstOrNull ?? stockFile;
}

/// One item: which field, on which row, what happened and — when the system
/// covered it — how.
class AuditIssue extends Equatable {
  const AuditIssue({required this.kind, required this.field, required this.detail, this.lineNo, this.remedy});

  final AuditKind kind;

  /// The field in words (JAN, 数量, 見出し …), as shown when it was kept.
  final String field;

  /// The row of the file (1 = the first), or null for the whole file.
  final int? lineNo;

  /// What happened, in words.
  final String detail;

  /// What covered it, in words; null when nothing did.
  final String? remedy;

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'field': field,
        if (lineNo != null) 'line': lineNo,
        'detail': detail,
        if (remedy != null) 'remedy': remedy,
      };

  factory AuditIssue.fromJson(Map<String, dynamic> j) => AuditIssue(
        kind: AuditKind.fromWire(j['kind']?.toString()),
        field: '${j['field'] ?? ''}',
        lineNo: (j['line'] as num?)?.toInt(),
        detail: '${j['detail'] ?? ''}',
        remedy: j['remedy']?.toString(),
      );

  @override
  List<Object?> get props => [kind, field, lineNo, detail, remedy];
}

/// One file's reading and what it could not do.
class ReadingAudit extends Equatable {
  const ReadingAudit({
    required this.id,
    required this.at,
    required this.source,
    required this.fileName,
    required this.byAi,
    this.supplier,
    this.lineCount = 0,
    this.issues = const [],
    this.serverId,
    this.filePath,
    this.contentType,
    this.fileSize,
    this.byName,
  });

  /// As kept on the server (0224); null before it is.
  final int? serverId;

  /// The file read, kept with it.
  final String? filePath;
  final String? contentType;
  final int? fileSize;

  /// Who read the file.
  final String? byName;

  /// The same reading keeps its id while it is checked and corrected, so it
  /// is kept once, as it ended.
  final String id;
  final DateTime at;
  final AuditSource source;
  final String fileName;

  /// Read by the AI (a PDF, a photo), not cell by cell.
  final bool byAi;
  final String? supplier;

  /// Rows read.
  final int lineCount;
  final List<AuditIssue> issues;

  int count(AuditKind k) => issues.where((i) => i.kind == k).length;

  /// The kinds it has, in [AuditKind] order, with how many.
  List<(AuditKind, int)> get counts => [
        for (final k in AuditKind.values)
          if (count(k) > 0) (k, count(k)),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'source': source.wire,
        'file': fileName,
        'by_ai': byAi,
        if (supplier != null) 'supplier': supplier,
        'lines': lineCount,
        'issues': [for (final i in issues) i.toJson()],
      };

  factory ReadingAudit.fromJson(Map<String, dynamic> j) => ReadingAudit(
        id: '${j['id'] ?? ''}',
        at: DateTime.tryParse('${j['at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        source: AuditSource.fromWire(j['source']?.toString()),
        fileName: '${j['file'] ?? ''}',
        byAi: j['by_ai'] == true,
        supplier: j['supplier']?.toString(),
        lineCount: (j['lines'] as num?)?.toInt() ?? 0,
        issues: [
          for (final i in (j['issues'] as List? ?? const []).whereType<Map>()) AuditIssue.fromJson(i.cast<String, dynamic>()),
        ],
      );

  /// What `reading_audit_save` takes.
  Map<String, dynamic> toSave() => {
        'client_id': id,
        'source': source.wire,
        'file_name': fileName,
        'by_ai': byAi,
        if (supplier != null) 'supplier': supplier,
        'line_count': lineCount,
        'issues': [for (final i in issues) i.toJson()],
      };

  /// A row of `reading_audits_list`.
  factory ReadingAudit.fromServer(Map<String, dynamic> j) => ReadingAudit(
        id: '${j['client_id'] ?? j['id'] ?? ''}',
        serverId: (j['id'] as num?)?.toInt(),
        at: (DateTime.tryParse('${j['read_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
        source: AuditSource.fromWire(j['source']?.toString()),
        fileName: '${j['file_name'] ?? ''}',
        byAi: j['by_ai'] == true,
        supplier: j['supplier']?.toString(),
        lineCount: (j['line_count'] as num?)?.toInt() ?? 0,
        issues: [
          for (final i in (j['issues'] as List? ?? const []).whereType<Map>()) AuditIssue.fromJson(i.cast<String, dynamic>()),
        ],
        filePath: j['storage_path']?.toString(),
        contentType: j['content_type']?.toString(),
        fileSize: (j['byte_size'] as num?)?.toInt(),
        byName: j['created_by_name']?.toString(),
      );

  @override
  List<Object?> get props => [id, at, source, fileName, byAi, supplier, lineCount, issues, serverId, filePath, byName];
}
