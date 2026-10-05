import 'dart:convert';

import 'package:equatable/equatable.dart';

/// 仕入先ファイル起点の入荷 (0134–0136): an expected receipt, its actual
/// receipts (分納), the inspection of each, and the files behind them.

String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

int _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

int? _nn(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

DateTime? _date(Object? v) {
  final t = _s(v);
  if (t == null) return null;
  final d = DateTime.tryParse(t);
  return d == null ? null : (t.length <= 10 ? d : d.toLocal());
}

List<Map<String, dynamic>> _list(Object? v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) Map<String, dynamic>.from(e),
    ];

/// `yyyy-MM-dd` for a calendar day, as the database takes it.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Where an expected receipt stands (delivery_plans.receipt_state).
enum ReceiptState {
  draft('DRAFT'),
  expected('EXPECTED'),
  partiallyReceived('PARTIALLY_RECEIVED'),
  received('RECEIVED'),
  overReceived('OVER_RECEIVED'),
  closed('CLOSED'),
  cancelled('CANCELLED'),
  onHold('ON_HOLD');

  const ReceiptState(this.wire);
  final String wire;

  static ReceiptState fromWire(String? v) =>
      ReceiptState.values.firstWhere((s) => s.wire == v, orElse: () => ReceiptState.expected);

  /// Still waiting for goods.
  bool get open => this == expected || this == partiallyReceived;
}

/// What the supplier sent. An invoice never counts as goods received (§11).
enum DocumentType {
  purchaseConfirmation('purchase_confirmation'),
  deliverySchedule('delivery_schedule'),
  deliveryNote('delivery_note'),
  invoice('invoice'),
  other('other');

  const DocumentType(this.wire);
  final String wire;

  static DocumentType? fromWire(String? v) {
    for (final t in DocumentType.values) {
      if (t.wire == v) return t;
    }
    return null;
  }

  /// The same reading of a file name as `guess_document_type` (0134).
  static DocumentType? guess(String? fileName) {
    final n = (fileName ?? '').toLowerCase();
    if (n.isEmpty) return null;
    if (RegExp(r'請求|invoice').hasMatch(n)) return invoice;
    if (RegExp(r'注文請書|注文確認|発注確認|受注確認|注文書|ご注文|order ?confirm|purchase ?order').hasMatch(n)) {
      return purchaseConfirmation;
    }
    if (RegExp(r'納品予定|入荷予定|出荷予定|出荷案内|納期|予定表|schedule|eta').hasMatch(n)) return deliverySchedule;
    if (RegExp(r'納品書|納品|送り状|delivery|packing').hasMatch(n)) return deliveryNote;
    return null;
  }
}

/// A plan the same file or the same document number already became (§23).
class InboundDuplicate extends Equatable {
  const InboundDuplicate({
    required this.planId,
    required this.deliveryNumber,
    this.referenceNo,
    this.docNumber,
    this.supplierName,
    this.expectedArrivalDate,
    this.receiptState = ReceiptState.expected,
    this.reasons = const [],
  });

  final int planId;
  final String deliveryNumber;
  final String? referenceNo;
  final String? docNumber;
  final String? supplierName;
  final DateTime? expectedArrivalDate;
  final ReceiptState receiptState;

  /// same_file / same_number.
  final List<String> reasons;

  bool get sameFile => reasons.contains('same_file');

  factory InboundDuplicate.fromJson(Map<String, dynamic> j) => InboundDuplicate(
        planId: _n(j['plan_id']),
        deliveryNumber: _s(j['delivery_number']) ?? '',
        referenceNo: _s(j['reference_no']),
        docNumber: _s(j['doc_number']),
        supplierName: _s(j['supplier_name']),
        expectedArrivalDate: _date(j['expected_arrival_date']),
        receiptState: ReceiptState.fromWire(_s(j['receipt_state'])),
        reasons: [for (final r in (j['reasons'] as List? ?? const [])) '$r'],
      );

  @override
  List<Object?> get props => [planId, reasons];
}

/// One line that brought more than the plan still expected.
class OverReceiptLine extends Equatable {
  const OverReceiptLine({
    required this.janCode,
    this.productName,
    required this.planned,
    required this.received,
    required this.arriving,
    required this.remaining,
    required this.over,
  });

  final String janCode;
  final String? productName;
  final int planned;
  final int received;
  final int arriving;
  final int remaining;
  final int over;

  factory OverReceiptLine.fromJson(Map<String, dynamic> j) => OverReceiptLine(
        janCode: _s(j['jan_code']) ?? '',
        productName: _s(j['product_name']),
        planned: _n(j['planned']),
        received: _n(j['received']),
        arriving: _n(j['arriving']),
        remaining: _n(j['remaining']),
        over: _n(j['over']),
      );

  @override
  List<Object?> get props => [janCode, planned, received, arriving, over];
}

/// The lines in a refusal that says `OVER_RECEIPT [...]`, or null when the
/// message is anything else.
List<OverReceiptLine>? parseOverReceipt(String? message) {
  final m = RegExp(r'OVER_RECEIPT\s*(\[.*\])', dotAll: true).firstMatch(message ?? '');
  if (m == null) return null;
  try {
    final list = jsonDecode(m.group(1)!) as List;
    return [for (final e in list) if (e is Map) OverReceiptLine.fromJson(Map<String, dynamic>.from(e))];
  } catch (_) {
    return null;
  }
}

/// What to do with more than was expected.
enum OverReceiptChoice {
  /// Receive everything (receiving.over_accept).
  accept('accept'),

  /// Receive only what was still expected.
  cap('cap'),

  /// Receive everything, the excess on HOLD until someone decides.
  hold('hold');

  const OverReceiptChoice(this.wire);
  final String wire;
}

/// What receive_delivery answered.
class ReceiveOutcome extends Equatable {
  const ReceiveOutcome({
    required this.reconciliationId,
    required this.planId,
    required this.receiptState,
    this.arrivedOn,
    this.inspectionId,
    this.scheduledInspectionDate,
    this.over = const [],
  });

  final int reconciliationId;
  final int planId;
  final ReceiptState receiptState;
  final DateTime? arrivedOn;
  final int? inspectionId;
  final DateTime? scheduledInspectionDate;
  final List<OverReceiptLine> over;

  factory ReceiveOutcome.fromJson(Map<String, dynamic> j) => ReceiveOutcome(
        reconciliationId: _n(j['reconciliation_id']),
        planId: _n(j['plan_id']),
        receiptState: ReceiptState.fromWire(_s(j['receipt_state'])),
        arrivedOn: _date(j['arrived_on']),
        inspectionId: _nn(j['inspection_id']),
        scheduledInspectionDate: _date(j['scheduled_inspection_date']),
        over: [for (final e in _list(j['over'])) OverReceiptLine.fromJson(e)],
      );

  @override
  List<Object?> get props => [reconciliationId, receiptState, inspectionId];
}

/// One line of an expected receipt: 予定 / 入荷済 / 残.
class ExpectedLine extends Equatable {
  const ExpectedLine({
    required this.id,
    required this.janCode,
    this.productId,
    required this.productName,
    this.supplierProductName,
    this.productCode,
    this.maker,
    required this.planned,
    required this.received,
    required this.remaining,
    required this.over,
    required this.state,
  });

  final int id;
  final String janCode;
  final int? productId;
  final String productName;
  final String? supplierProductName;
  final String? productCode;
  final String? maker;
  final int planned;
  final int received;
  final int remaining;
  final int over;
  final ReceiptState state;

  factory ExpectedLine.fromJson(Map<String, dynamic> j) => ExpectedLine(
        id: _n(j['id']),
        janCode: _s(j['jan_code']) ?? '',
        productId: _nn(j['product_id']),
        productName: _s(j['product_name']) ?? '',
        supplierProductName: _s(j['supplier_product_name']),
        productCode: _s(j['product_code']),
        maker: _s(j['maker']),
        planned: _n(j['planned']),
        received: _n(j['received']),
        remaining: _n(j['remaining']),
        over: _n(j['over']),
        state: ReceiptState.fromWire(_s(j['state'])),
      );

  @override
  List<Object?> get props => [id, planned, received];
}

/// The inspection of one actual receipt.
class ReceiptInspection extends Equatable {
  const ReceiptInspection({
    required this.id,
    required this.status,
    this.scheduledDate,
    this.startedAt,
    this.completedAt,
    this.passed = 0,
    this.failed = 0,
  });

  final int id;
  final String status;
  final DateTime? scheduledDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int passed;
  final int failed;

  bool get pending => status == 'PENDING';

  factory ReceiptInspection.fromJson(Map<String, dynamic> j) => ReceiptInspection(
        id: _n(j['id'] ?? j['inspection_id']),
        status: _s(j['status']) ?? 'PENDING',
        scheduledDate: _date(j['scheduled_date']),
        startedAt: _date(j['started_at']),
        completedAt: _date(j['completed_at']),
        passed: _n(j['passed']),
        failed: _n(j['failed']),
      );

  @override
  List<Object?> get props => [id, status, scheduledDate, startedAt, completedAt];
}

/// One delivery that arrived against the plan (第n回入荷).
class ActualReceipt extends Equatable {
  const ActualReceipt({
    required this.id,
    required this.seq,
    this.referenceNo,
    required this.status,
    this.arrivedOn,
    required this.units,
    this.lines = const [],
    this.inspection,
  });

  final int id;
  final int seq;
  final String? referenceNo;
  final String status;
  final DateTime? arrivedOn;
  final int units;
  final List<({String janCode, String productName, int quantity})> lines;
  final ReceiptInspection? inspection;

  bool get cancelled => status == 'cancelled';

  factory ActualReceipt.fromJson(Map<String, dynamic> j) => ActualReceipt(
        id: _n(j['id']),
        seq: _n(j['seq']),
        referenceNo: _s(j['reference_no']),
        status: _s(j['status']) ?? '',
        arrivedOn: _date(j['arrived_on']),
        units: _n(j['units']),
        lines: [
          for (final l in _list(j['lines']))
            (janCode: _s(l['jan_code']) ?? '', productName: _s(l['product_name']) ?? '', quantity: _n(l['quantity'])),
        ],
        inspection: j['inspection'] is Map
            ? ReceiptInspection.fromJson(Map<String, dynamic>.from(j['inspection'] as Map))
            : null,
      );

  @override
  List<Object?> get props => [id, status, arrivedOn, units, inspection];
}

/// One entry of the plan's history (§25).
class InboundEvent extends Equatable {
  const InboundEvent({required this.at, required this.event, this.details = const {}, this.actor});

  final DateTime at;
  final String event;
  final Map<String, dynamic> details;
  final String? actor;

  factory InboundEvent.fromJson(Map<String, dynamic> j) => InboundEvent(
        at: _date(j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        event: _s(j['event']) ?? '',
        details: j['details'] is Map ? Map<String, dynamic>.from(j['details'] as Map) : const {},
        actor: _s(j['actor']),
      );

  @override
  List<Object?> get props => [at, event, details];
}

/// An expected receipt with everything that happened to it.
class ExpectedReceipt extends Equatable {
  const ExpectedReceipt({
    required this.id,
    required this.deliveryNumber,
    this.referenceNo,
    this.docNumber,
    this.supplierId,
    this.supplierName,
    this.warehouseName,
    this.expectedArrivalDate,
    this.scheduledInspectionDate,
    this.documentType,
    required this.receiptState,
    this.onHold = false,
    this.today,
    this.lines = const [],
    this.receipts = const [],
    this.documents = const [],
    this.history = const [],
  });

  final int id;
  final String deliveryNumber;
  final String? referenceNo;
  final String? docNumber;
  final int? supplierId;
  final String? supplierName;
  final String? warehouseName;
  final DateTime? expectedArrivalDate;
  final DateTime? scheduledInspectionDate;
  final DocumentType? documentType;
  final ReceiptState receiptState;
  final bool onHold;
  final DateTime? today;
  final List<ExpectedLine> lines;
  final List<ActualReceipt> receipts;

  /// Raw rows, in the shape `ImportDocument.fromJson` reads.
  final List<Map<String, dynamic>> documents;
  final List<InboundEvent> history;

  int get planned => lines.fold(0, (s, l) => s + l.planned);
  int get received => lines.fold(0, (s, l) => s + l.received);
  int get remaining => lines.fold(0, (s, l) => s + l.remaining);

  factory ExpectedReceipt.fromJson(Map<String, dynamic> j) {
    final p = j['plan'] is Map ? Map<String, dynamic>.from(j['plan'] as Map) : const <String, dynamic>{};
    return ExpectedReceipt(
      id: _n(p['id']),
      deliveryNumber: _s(p['delivery_number']) ?? '',
      referenceNo: _s(p['reference_no']),
      docNumber: _s(p['doc_number']),
      supplierId: _nn(p['supplier_id']),
      supplierName: _s(p['supplier_name']),
      warehouseName: _s(p['warehouse_name']),
      expectedArrivalDate: _date(p['expected_arrival_date']),
      scheduledInspectionDate: _date(p['scheduled_inspection_date']),
      documentType: DocumentType.fromWire(_s(p['document_type'])),
      receiptState: ReceiptState.fromWire(_s(p['receipt_state'])),
      onHold: p['on_hold'] == true,
      today: _date(p['today']),
      lines: [for (final e in _list(j['lines'])) ExpectedLine.fromJson(e)],
      receipts: [for (final e in _list(j['receipts'])) ActualReceipt.fromJson(e)],
      documents: _list(j['documents']),
      history: [for (final e in _list(j['history'])) InboundEvent.fromJson(e)],
    );
  }

  @override
  List<Object?> get props =>
      [id, expectedArrivalDate, scheduledInspectionDate, documentType, receiptState, onHold, lines, receipts, history];
}

/// 今日の入荷 (§28).
class InboundToday extends Equatable {
  const InboundToday({
    this.dueToday = 0,
    this.overdue = 0,
    this.undated = 0,
    this.awaitingInspection = 0,
    this.inspectionDueToday = 0,
    this.putawayWaiting = 0,
    this.plans = const [],
  });

  final int dueToday;
  final int overdue;
  final int undated;
  final int awaitingInspection;
  final int inspectionDueToday;
  final int putawayWaiting;
  final List<({int id, String deliveryNumber, String? supplierName, DateTime? expected, ReceiptState state, int remaining})>
      plans;

  factory InboundToday.fromJson(Map<String, dynamic> j) => InboundToday(
        dueToday: _n(j['due_today']),
        overdue: _n(j['overdue']),
        undated: _n(j['undated']),
        awaitingInspection: _n(j['awaiting_inspection']),
        inspectionDueToday: _n(j['inspection_due_today']),
        putawayWaiting: _n(j['putaway_waiting']),
        plans: [
          for (final p in _list(j['plans']))
            (
              id: _n(p['id']),
              deliveryNumber: _s(p['delivery_number']) ?? '',
              supplierName: _s(p['supplier_name']),
              expected: _date(p['expected_arrival_date']),
              state: ReceiptState.fromWire(_s(p['receipt_state'])),
              remaining: _n(p['remaining']),
            ),
        ],
      );

  @override
  List<Object?> get props => [dueToday, overdue, undated, awaitingInspection, inspectionDueToday, putawayWaiting, plans];
}

/// A product that may be the one a line means (§44).
class MatchCandidate extends Equatable {
  const MatchCandidate({
    required this.productId,
    required this.name,
    this.nameEn,
    this.sku,
    this.janCode,
    this.maker,
    required this.score,
    this.reasons = const [],
  });

  final int productId;
  final String name;
  final String? nameEn;
  final String? sku;
  final String? janCode;
  final String? maker;

  /// 0..1.
  final double score;

  /// supplier_code / jan / supplier_jan / sku / model_in_name / name.
  final List<String> reasons;

  int get percent => (score * 100).round();

  factory MatchCandidate.fromJson(Map<String, dynamic> j) => MatchCandidate(
        productId: _n(j['product_id']),
        name: _s(j['name']) ?? '',
        nameEn: _s(j['name_en']),
        sku: _s(j['sku']),
        janCode: _s(j['jan_code']),
        maker: _s(j['maker']),
        score: _d(j['score']),
        reasons: [for (final r in (j['reasons'] as List? ?? const [])) '$r'],
      );

  @override
  List<Object?> get props => [productId, score];
}

/// How sure a line's tie to one of our products is, from how it was made.
/// Null when the line is not tied.
int? matchPercent(String? matchedBy) => switch (matchedBy) {
      null || '' => null,
      'manual' || 'registered' => 100,
      'jan' || 'jan_restored' => 99,
      'dialect_jan' => 98,
      'dialect_code' => 97,
      'sku' => 95,
      'dialect_name' => 93,
      'name' => 90,
      _ => 85,
    };

/// Below this a tie is shown as needing a look.
const kConfidentMatch = 95;

/// Everything that came in for one product.
class ProductInboundHistory extends Equatable {
  const ProductInboundHistory({
    this.expected = const [],
    this.receipts = const [],
    this.documents = const [],
    this.supplierNames = const [],
    this.aliases = const [],
  });

  final List<Map<String, dynamic>> expected;
  final List<Map<String, dynamic>> receipts;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> supplierNames;
  final List<Map<String, dynamic>> aliases;

  bool get isEmpty =>
      expected.isEmpty && receipts.isEmpty && documents.isEmpty && supplierNames.isEmpty && aliases.isEmpty;

  factory ProductInboundHistory.fromJson(Map<String, dynamic> j) => ProductInboundHistory(
        expected: _list(j['expected']),
        receipts: _list(j['receipts']),
        documents: _list(j['documents']),
        supplierNames: _list(j['supplier_names']),
        aliases: _list(j['aliases']),
      );

  @override
  List<Object?> get props => [expected, receipts, documents, supplierNames, aliases];
}
