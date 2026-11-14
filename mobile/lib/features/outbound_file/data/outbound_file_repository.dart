import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';
import '../../outbound/domain/outbound.dart' show ShipDestination;

/// The bucket shipping lists are kept in (0188): <warehouse id>/<file>.
const outboundFileBucket = 'outbound-files';

int? _ni(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
int _i(Object? v) => _ni(v) ?? 0;
double? _nd(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
String? _s(Object? v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty ? null : t;
}

DateTime? _day(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String outboundDayWire(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// How a row's product was found (0188).
enum OutboundMatchedBy {
  jan,
  barcode,
  code,
  picked,
  several,
  none;

  static OutboundMatchedBy fromWire(String? v) =>
      OutboundMatchedBy.values.firstWhere((e) => e.name == v, orElse: () => OutboundMatchedBy.none);

  bool get found => this == jan || this == barcode || this == code || this == picked;
}

class OutboundCandidate extends Equatable {
  const OutboundCandidate({required this.productId, required this.jan, required this.name, this.maker, this.sku});

  final int productId;
  final String jan;
  final String name;
  final String? maker;
  final String? sku;

  factory OutboundCandidate.fromJson(Map<String, dynamic> j) => OutboundCandidate(
        productId: _i(j['product_id']),
        jan: '${j['jan'] ?? ''}',
        name: '${j['name'] ?? ''}',
        maker: _s(j['maker']),
        sku: _s(j['sku']),
      );

  @override
  List<Object?> get props => [productId, jan];
}

/// The product found for one row (outbound_match), its stock in the
/// warehouse, its weight and last 仕入れ値.
class OutboundMatch extends Equatable {
  const OutboundMatch({
    required this.matchedBy,
    this.productId,
    this.jan,
    this.name,
    this.maker,
    this.sku,
    this.unitWeightG,
    this.onHand,
    this.kept,
    this.lastPrice,
    this.lastPriceDay,
    this.candidates = const [],
  });

  static const none = OutboundMatch(matchedBy: OutboundMatchedBy.none);

  final OutboundMatchedBy matchedBy;
  final int? productId;
  final String? jan;
  final String? name;
  final String? maker;
  final String? sku;
  final double? unitWeightG;
  final int? onHand;

  /// What the 出庫予定 already registered keep of it there (0201).
  final int? kept;

  /// What is left to ship: in stock less what is kept; null with no product.
  int? get free => onHand == null ? null : (onHand! - (kept ?? 0) < 0 ? 0 : onHand! - (kept ?? 0));

  final double? lastPrice;
  final DateTime? lastPriceDay;
  final List<OutboundCandidate> candidates;

  factory OutboundMatch.fromJson(Map<String, dynamic> j) => OutboundMatch(
        matchedBy: OutboundMatchedBy.fromWire(_s(j['matched_by'])),
        productId: _ni(j['product_id']),
        jan: _s(j['jan']),
        name: _s(j['name']),
        maker: _s(j['maker']),
        sku: _s(j['sku']),
        unitWeightG: _nd(j['unit_weight_g']),
        onHand: _ni(j['on_hand']),
        kept: _ni(j['kept']),
        lastPrice: _nd(j['last_price']),
        lastPriceDay: _day(j['last_price_day']),
        candidates: [
          for (final c in (j['candidates'] as List? ?? const []).whereType<Map>())
            OutboundCandidate.fromJson(c.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [matchedBy, productId, onHand, kept, lastPrice, candidates];
}

/// One row to post (outbound_file_post).
class OutboundPostLine {
  const OutboundPostLine({
    required this.rowNo,
    required this.action,
    this.productId,
    this.jan,
    this.productName,
    this.maker,
    this.code,
    this.supplier,
    this.quantity,
    this.unitPrice,
    this.unitPriceTax,
    this.taxRate,
    this.listPrice,
    this.amount,
    this.orderNumber,
    this.arrival,
    this.orderDate,
    this.matchedBy,
    this.raw = const {},
  });

  final int rowNo;

  /// ship / record / skip.
  final String action;
  final int? productId;
  final String? jan;
  final String? productName;
  final String? maker;
  final String? code;
  final String? supplier;
  final int? quantity;
  final double? unitPrice;
  final double? unitPriceTax;
  final double? taxRate;
  final double? listPrice;
  final double? amount;
  final String? orderNumber;
  final String? arrival;
  final String? orderDate;
  final String? matchedBy;
  final Map<String, String> raw;

  Map<String, dynamic> toJson() => {
        'row_no': rowNo,
        'action': action,
        'product_id': productId,
        'jan': jan,
        'product_name': productName,
        'maker': maker,
        'code': code,
        'supplier': supplier,
        'quantity': quantity,
        'unit_price': unitPrice,
        'unit_price_tax': unitPriceTax,
        'tax_rate': taxRate,
        'list_price': listPrice,
        'amount': amount,
        'order_number': orderNumber,
        'arrival': arrival,
        'order_date': orderDate,
        'matched_by': matchedBy,
        'raw': raw,
      };
}

/// One posted list, as the 出庫カレンダー shows it.
class OutboundFileSummary extends Equatable {
  const OutboundFileSummary({
    required this.id,
    required this.warehouseId,
    required this.shippedOn,
    required this.fileName,
    this.warehouseName,
    this.storagePath,
    this.readPath,
    this.contentType,
    this.sheetName,
    this.destination,
    this.note,
    this.lineCount = 0,
    this.quantityTotal = 0,
    this.shippedTotal = 0,
    this.shortTotal = 0,
    this.amountTotal,
    this.weightG,
    this.createdAt,
    this.createdByName,
    this.undoneAt,
    this.kind = 'stock',
    this.principal,
    this.feeJpy,
    this.destinationId,
    this.shipTo,
    this.status = 'shipped',
    this.plannedOn,
    this.dateUndecided = false,
    this.currency,
    this.fxCnyJpy,
    this.packCartonCount,
    this.packCartonKg,
    this.packMaterialKg,
    this.autoShipped = false,
    this.autoHoldAt,
    this.autoHoldShort,
  });

  /// Recorded as shipped by the night run, the day after its day (0201).
  final bool autoShipped;

  /// The night run found it short and left it planned (0201): when, and by
  /// how many.
  final DateTime? autoHoldAt;
  final int? autoHoldShort;

  /// Its day has passed and it has not shipped: something to see to.
  bool overdue(DateTime today) =>
      planned && !proxy && !dateUndecided && shippedOn.isBefore(DateTime(today.year, today.month, today.day));

  /// The gross-weight estimate's own numbers (0199), null while 未定: how
  /// many cartons, one empty carton's weight, the packing material in all.
  final int? packCartonCount;
  final double? packCartonKg;
  final double? packMaterialKg;

  /// The warehouse it ships from may still be changed (0199): nothing has
  /// left stock yet.
  bool get warehouseMovable => !undone && (planned || proxy);

  /// A planned list with no day yet (出庫日 未定, 0197): [shippedOn] means
  /// nothing until one is set.
  final bool dateUndecided;

  /// The list's main currency (JPY, CNY …) and the rate 1 CNY in JPY, if
  /// given (0197).
  final String? currency;
  final double? fxCnyJpy;

  /// 未定: a planned list, or a 在庫外出荷 (0198), with no day yet.
  bool get undecided => (planned || proxy) && dateUndecided;

  /// 'planned' (出庫予定: nothing out of stock yet, 0191) or 'shipped'.
  final String status;

  /// The day it was planned for.
  final DateTime? plannedOn;

  bool get planned => status == 'planned' && undoneAt == null;

  /// The 出荷先カード it went to (0190), and the card as it was then.
  final int? destinationId;
  final ShipDestination? shipTo;

  final int id;

  /// 'stock' (taken out of stock, 0188) or 'proxy' (代理出荷: a record, 0189).
  final String kind;

  /// 代理出荷's 依頼元: on whose behalf it was shipped.
  final String? principal;

  /// What was paid for this list's shipping (委託手数料, 0213): for 在庫外出荷,
  /// the other company's fee.
  final double? feeJpy;

  bool get proxy => kind == 'proxy';
  final int warehouseId;
  final String? warehouseName;
  final DateTime shippedOn;
  final String fileName;
  final String? storagePath;

  /// What was read from the file, kept as Excel beside it (0208).
  final String? readPath;
  final String? contentType;
  final String? sheetName;
  final String? destination;
  final String? note;
  final int lineCount;
  final int quantityTotal;
  final int shippedTotal;
  final int shortTotal;
  final double? amountTotal;
  final double? weightG;
  final DateTime? createdAt;
  final String? createdByName;
  final DateTime? undoneAt;

  bool get undone => undoneAt != null;

  String get mime => (contentType ?? '').isNotEmpty ? contentType! : mimeTypeFor(fileName);

  factory OutboundFileSummary.fromJson(Map<String, dynamic> j) => OutboundFileSummary(
        id: _i(j['id']),
        warehouseId: _i(j['warehouse_id']),
        warehouseName: _s(j['warehouse_name']),
        shippedOn: _day(j['shipped_on']) ?? DateTime(2000),
        fileName: '${j['file_name'] ?? ''}',
        storagePath: _s(j['storage_path']),
        readPath: _s(j['read_path']),
        contentType: _s(j['content_type']),
        sheetName: _s(j['sheet_name']),
        destination: _s(j['destination']),
        note: _s(j['note']),
        lineCount: _i(j['line_count']),
        quantityTotal: _i(j['quantity_total']),
        shippedTotal: _i(j['shipped_total']),
        shortTotal: _i(j['short_total']),
        amountTotal: _nd(j['amount_total']),
        weightG: _nd(j['weight_g']),
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        createdByName: _s(j['created_by_name']),
        undoneAt: DateTime.tryParse('${j['undone_at'] ?? ''}')?.toLocal(),
        kind: _s(j['kind']) ?? 'stock',
        principal: _s(j['principal']),
        feeJpy: _nd(j['fee_jpy']),
        destinationId: _ni(j['destination_id']),
        status: _s(j['status']) ?? 'shipped',
        plannedOn: _day(j['planned_on']),
        dateUndecided: j['date_undecided'] == true,
        currency: _s(j['currency']),
        fxCnyJpy: _nd(j['fx_cny_jpy']),
        packCartonCount: _ni(j['pack_carton_count']),
        packCartonKg: _nd(j['pack_carton_kg']),
        packMaterialKg: _nd(j['pack_material_kg']),
        autoShipped: j['auto_shipped'] == true,
        autoHoldAt: DateTime.tryParse('${j['auto_hold_at'] ?? ''}')?.toLocal(),
        autoHoldShort: _ni(j['auto_hold_short']),
        shipTo: j['ship_to'] is Map ? ShipDestination.fromJson((j['ship_to'] as Map).cast<String, dynamic>()) : null,
      );

  @override
  List<Object?> get props => [
        id, kind, status, shippedOn, dateUndecided, fileName, lineCount, shippedTotal, shortTotal, undoneAt, warehouseId,
        packCartonCount, packCartonKg, packMaterialKg, autoShipped, autoHoldAt,
      ];
}

/// One row of a posted list.
class OutboundFileLine extends Equatable {
  const OutboundFileLine({
    required this.id,
    required this.rowNo,
    required this.action,
    this.jan,
    this.productId,
    this.productName,
    this.maker,
    this.code,
    this.supplier,
    this.quantity = 0,
    this.shippedQuantity = 0,
    this.shortQuantity = 0,
    this.unitPrice,
    this.unitPriceTax,
    this.amount,
    this.orderNumber,
    this.arrival,
    this.matchedBy,
    this.onHandBefore,
    this.onHandAfter,
    this.unitWeightG,
    this.currency = 'JPY',
    this.currencySource,
  });

  final int id;
  final int rowNo;
  final String action;
  final String? jan;
  final int? productId;
  final String? productName;
  final String? maker;
  final String? code;
  final String? supplier;
  final int quantity;
  final int shippedQuantity;
  final int shortQuantity;
  final double? unitPrice;
  final double? unitPriceTax;
  final double? amount;
  final String? orderNumber;
  final String? arrival;
  final String? matchedBy;
  final int? onHandBefore;
  final int? onHandAfter;
  final double? unitWeightG;

  /// The currency of its prices (JPY, CNY …) and how it was decided:
  /// 'file', 'ai' or 'manual' (0197).
  final String currency;
  final String? currencySource;

  double? get weightG => unitWeightG == null ? null : unitWeightG! * (action == 'ship' ? shippedQuantity : quantity);

  factory OutboundFileLine.fromJson(Map<String, dynamic> j) => OutboundFileLine(
        id: _i(j['id']),
        rowNo: _i(j['row_no']),
        action: '${j['action'] ?? 'ship'}',
        jan: _s(j['jan']),
        productId: _ni(j['product_id']),
        productName: _s(j['product_name']),
        maker: _s(j['maker']),
        code: _s(j['code']),
        supplier: _s(j['supplier']),
        quantity: _i(j['quantity']),
        shippedQuantity: _i(j['shipped_quantity']),
        shortQuantity: _i(j['short_quantity']),
        unitPrice: _nd(j['unit_price']),
        unitPriceTax: _nd(j['unit_price_tax']),
        amount: _nd(j['amount']),
        orderNumber: _s(j['order_number']),
        arrival: _s(j['arrival']),
        matchedBy: _s(j['matched_by']),
        onHandBefore: _ni(j['on_hand_before']),
        onHandAfter: _ni(j['on_hand_after']),
        unitWeightG: _nd(j['unit_weight_g']),
        currency: _s(j['currency']) ?? 'JPY',
        currencySource: _s(j['currency_source']),
      );

  @override
  List<Object?> get props => [id, rowNo, action, productId, quantity, shippedQuantity, shortQuantity];
}

/// A product a planned list needs, against what is there for it (0201):
/// in stock, kept by the lists ahead of it, free, and short.
class OutboundShortage extends Equatable {
  const OutboundShortage({
    required this.needed,
    required this.onHand,
    required this.keptAhead,
    required this.free,
    required this.short,
    this.jan,
    this.productId,
    this.name,
  });

  final String? jan;
  final int? productId;
  final String? name;
  final int needed;
  final int onHand;
  final int keptAhead;
  final int free;
  final int short;

  factory OutboundShortage.fromJson(Map<String, dynamic> j) => OutboundShortage(
        jan: _s(j['jan']),
        productId: _ni(j['product_id']),
        name: _s(j['name']),
        needed: _i(j['needed']),
        onHand: _i(j['on_hand']),
        keptAhead: _i(j['kept_ahead']),
        free: _i(j['free']),
        short: _i(j['short']),
      );

  @override
  List<Object?> get props => [jan, needed, onHand, keptAhead, free, short];
}

class OutboundFileDetail extends Equatable {
  const OutboundFileDetail({
    required this.file,
    required this.lines,
    this.undoneByName,
    this.shippedByName,
    this.shippedAt,
    this.shortage = const [],
  });

  /// A planned list's products against the stock (0201); empty otherwise.
  final List<OutboundShortage> shortage;

  /// Those it cannot have in full now: the night run will not ship it.
  List<OutboundShortage> get short => [for (final s in shortage) if (s.short > 0) s];

  final OutboundFileSummary file;
  final List<OutboundFileLine> lines;
  final String? undoneByName;

  /// Who recorded that the goods left (出庫した, 0200), and when.
  final String? shippedByName;
  final DateTime? shippedAt;

  factory OutboundFileDetail.fromJson(Map<String, dynamic> j) => OutboundFileDetail(
        file: OutboundFileSummary.fromJson(j),
        undoneByName: _s(j['undone_by_name']),
        shippedByName: _s(j['shipped_by_name']),
        shippedAt: DateTime.tryParse('${j['shipped_at'] ?? ''}')?.toLocal(),
        shortage: [
          for (final e in ((j['shortage'] is Map ? (j['shortage'] as Map)['products'] : null) as List? ?? const [])
              .whereType<Map>())
            OutboundShortage.fromJson(e.cast<String, dynamic>()),
        ],
        lines: [
          for (final l in (j['lines'] as List? ?? const []).whereType<Map>()) OutboundFileLine.fromJson(l.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [file, lines];
}

/// 出荷リストで出庫 (0188).
abstract class OutboundFileRepository {
  /// For each row ({jan, code, maker}), in order: its product.
  Future<ApiResult<List<OutboundMatch>>> match(List<Map<String, String?>> rows, int warehouseId);

  /// The file put in the bucket: its path.
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes);

  Future<ApiResult<int>> post({
    required int warehouseId,
    required DateTime shippedOn,
    required String fileName,
    required List<OutboundPostLine> lines,
    String? storagePath,
    int? byteSize,
    String? fingerprint,
    String? sheetName,
    String? destination,
    String? note,
    Map<String, String>? columns,
    bool allowDuplicate = false,
    bool proxy = false,
    String? principal,
    bool plan = false,
    int? destinationId,
  });

  /// The warehouse ships a planned list on [day]: how many went out.
  Future<ApiResult<int>> confirm(int id, DateTime day);

  /// A planned list moved to [day].
  Future<ApiResult<bool>> reschedule(int id, DateTime day);

  Future<ApiResult<List<OutboundFileSummary>>> list({required DateTime from, required DateTime to, int? warehouseId});

  Future<ApiResult<OutboundFileDetail>> detail(int id);

  /// What went out comes back: how many.
  Future<ApiResult<int>> undo(int id);

  /// The 出荷先カード a posted list went to (null: none), kept as it is now.
  Future<ApiResult<bool>> setDestination(int fileId, int? destinationId);

  /// 委託手数料 (0213): what was paid for this list's shipping, in yen.
  Future<ApiResult<bool>> setFee(int fileId, double? fee);

  Future<ApiResult<Uint8List>> fileBytes(String storagePath);

  /// The reading kept as Excel beside list [id]'s file (0208).
  Future<ApiResult<bool>> setReadPath(int id, String path);

  /// The planned lists with no day yet (出庫日 未定, 0197).
  Future<ApiResult<List<OutboundFileSummary>>> undecided({int? warehouseId});

  /// A planned list put back to 未定.
  Future<ApiResult<bool>> markUndecided(int id);

  /// Lists taken back while they had no day (0203): on no calendar, shown
  /// as 取り消し in the 出庫 tab.
  Future<ApiResult<List<OutboundFileSummary>>> cancelledUndated({int? warehouseId});

  /// Each row's currency ({row_no, currency, source}), the list's main one
  /// and the rate 1 CNY in JPY if known.
  Future<ApiResult<int>> setCurrency(int id, List<Map<String, dynamic>> lines, {String? currency, double? fxCnyJpy});

  /// The warehouse a list not yet shipped goes from (0199): false when it
  /// was that one already.
  Future<ApiResult<bool>> setWarehouse(int id, int warehouseId);

  /// A list not shipped yet put right row by row (0202): {line_id,
  /// quantity}, {line_id, action: skip|ship}, {add: true, product_id,
  /// quantity}. How many changes were made.
  Future<ApiResult<int>> editLines(int id, List<Map<String, dynamic>> edits);

  /// Its rows replaced by those read from another file (0202); the rows
  /// there were are kept on an archived copy, whose id comes back.
  Future<ApiResult<int>> replaceLines(
    int id, {
    required List<OutboundPostLine> lines,
    required String fileName,
    String? storagePath,
    int? byteSize,
    String? fingerprint,
    String? sheetName,
    Map<String, String>? columns,
  });

  /// A shipped list that did not leave after all: back to planned, 未定,
  /// its stock back (0201). How many came back.
  Future<ApiResult<int>> backToPlan(int id);

  /// The gross-weight estimate's numbers (0199); null puts one back to 未定.
  Future<ApiResult<bool>> setPackEstimate(int id, {int? cartonCount, double? cartonKg, double? materialKg});
}

class OutboundFileRepositoryImpl implements OutboundFileRepository {
  OutboundFileRepositoryImpl(this._rest, this._storage);

  final Dio _rest;
  final Dio _storage;

  dynamic _unwrap(dynamic d) => d is List && d.length == 1 && d.first is List ? d.first : d;

  @override
  Future<ApiResult<List<OutboundMatch>>> match(List<Map<String, String?>> rows, int warehouseId) async {
    try {
      final out = <OutboundMatch>[];
      // In pieces, so a long list does not time out.
      for (var i = 0; i < rows.length; i += 250) {
        final part = rows.sublist(i, i + 250 > rows.length ? rows.length : i + 250);
        final r = await _rest.post('/rpc/outbound_match', data: {'p_lines': part, 'p_warehouse_id': warehouseId});
        final d = _unwrap(r.data);
        out.addAll([for (final e in (d as List? ?? const []).whereType<Map>()) OutboundMatch.fromJson(e.cast<String, dynamic>())]);
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<List<OutboundMatch>>(e);
    }
  }

  @override
  Future<ApiResult<String>> upload(int warehouseId, String fileName, Uint8List bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path = '$warehouseId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    try {
      await _storage.post('/object/$outboundFileBucket/$path',
          data: bytes, options: Options(headers: {'Content-Type': mimeTypeFor(fileName)}));
      return ApiSuccess(path);
    } on DioException catch (e) {
      return mapDioError<String>(e);
    }
  }

  @override
  Future<ApiResult<int>> post({
    required int warehouseId,
    required DateTime shippedOn,
    required String fileName,
    required List<OutboundPostLine> lines,
    String? storagePath,
    int? byteSize,
    String? fingerprint,
    String? sheetName,
    String? destination,
    String? note,
    Map<String, String>? columns,
    bool allowDuplicate = false,
    bool proxy = false,
    String? principal,
    bool plan = false,
    int? destinationId,
  }) async {
    try {
      // 在庫外出荷 (0189) is kept as a record; 出庫予定 (0191) waits for the
      // warehouse; the other is taken out of stock now, with its 出荷先カード
      // in the same step (0210: no card, no 出庫済み).
      final now = !proxy && !plan;
      final rpc = proxy
          ? 'proxy_shipment_post'
          : plan
              ? 'outbound_file_plan'
              : (destinationId != null ? 'outbound_file_post_to' : 'outbound_file_post');
      final r = await _rest.post('/rpc/$rpc', data: {
        if (proxy) 'p_principal': principal,
        if (now && destinationId != null) 'p_destination_id': destinationId,
        'p_warehouse_id': warehouseId,
        'p_shipped_on': outboundDayWire(shippedOn),
        'p_file_name': fileName,
        'p_lines': [for (final l in lines) l.toJson()],
        'p_storage_path': storagePath,
        'p_content_type': mimeTypeFor(fileName),
        'p_byte_size': byteSize,
        'p_fingerprint': fingerprint,
        'p_sheet_name': sheetName,
        'p_destination': destination,
        'p_note': note,
        'p_columns': columns,
        'p_allow_duplicate': allowDuplicate,
      });
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<List<OutboundFileSummary>>> list({required DateTime from, required DateTime to, int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/outbound_files_list', data: {
        'p_from': outboundDayWire(from),
        'p_to': outboundDayWire(to),
        'p_warehouse_id': warehouseId,
      });
      final d = _unwrap(r.data);
      return ApiSuccess([
        for (final e in (d as List? ?? const []).whereType<Map>()) OutboundFileSummary.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<OutboundFileSummary>>(e);
    }
  }

  @override
  Future<ApiResult<OutboundFileDetail>> detail(int id) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_detail', data: {'p_id': id});
      return ApiSuccess(OutboundFileDetail.fromJson((r.data as Map).cast<String, dynamic>()));
    } on DioException catch (e) {
      return mapDioError<OutboundFileDetail>(e);
    }
  }

  @override
  Future<ApiResult<int>> undo(int id) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_undo', data: {'p_id': id});
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<int>> confirm(int id, DateTime day) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_confirm', data: {'p_id': id, 'p_shipped_on': outboundDayWire(day)});
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> reschedule(int id, DateTime day) async {
    try {
      await _rest.post('/rpc/outbound_file_reschedule', data: {'p_id': id, 'p_day': outboundDayWire(day)});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setFee(int fileId, double? fee) async {
    try {
      await _rest.post('/rpc/outbound_file_set_fee', data: {'p_id': fileId, 'p_fee': fee});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setDestination(int fileId, int? destinationId) async {
    try {
      await _rest.post('/rpc/outbound_file_set_destination', data: {'p_id': fileId, 'p_destination_id': destinationId});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<List<OutboundFileSummary>>> undecided({int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/outbound_files_undecided', data: {'p_warehouse_id': warehouseId});
      final d = _unwrap(r.data);
      return ApiSuccess([
        for (final e in (d as List? ?? const []).whereType<Map>()) OutboundFileSummary.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<OutboundFileSummary>>(e);
    }
  }

  @override
  Future<ApiResult<List<OutboundFileSummary>>> cancelledUndated({int? warehouseId}) async {
    try {
      final r = await _rest.post('/rpc/outbound_files_cancelled_undated', data: {'p_warehouse_id': warehouseId});
      final d = _unwrap(r.data);
      return ApiSuccess([
        for (final e in (d as List? ?? const []).whereType<Map>()) OutboundFileSummary.fromJson(e.cast<String, dynamic>()),
      ]);
    } on DioException catch (e) {
      return mapDioError<List<OutboundFileSummary>>(e);
    }
  }

  @override
  Future<ApiResult<bool>> markUndecided(int id) async {
    try {
      await _rest.post('/rpc/outbound_file_mark_undecided', data: {'p_id': id});
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<int>> setCurrency(int id, List<Map<String, dynamic>> lines, {String? currency, double? fxCnyJpy}) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_set_currency',
          data: {'p_id': id, 'p_lines': lines, 'p_currency': currency, 'p_fx_cny_jpy': fxCnyJpy});
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<int>> editLines(int id, List<Map<String, dynamic>> edits) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_lines_edit', data: {'p_id': id, 'p_edits': edits});
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<int>> replaceLines(
    int id, {
    required List<OutboundPostLine> lines,
    required String fileName,
    String? storagePath,
    int? byteSize,
    String? fingerprint,
    String? sheetName,
    Map<String, String>? columns,
  }) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_replace_lines', data: {
        'p_id': id,
        'p_lines': [for (final l in lines) l.toJson()],
        'p_file_name': fileName,
        'p_storage_path': storagePath,
        'p_content_type': mimeTypeFor(fileName),
        'p_byte_size': byteSize,
        'p_fingerprint': fingerprint,
        'p_sheet_name': sheetName,
        'p_columns': columns,
      });
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<int>> backToPlan(int id) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_back_to_plan', data: {'p_id': id});
      return ApiSuccess(_i(r.data));
    } on DioException catch (e) {
      return mapDioError<int>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setWarehouse(int id, int warehouseId) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_set_warehouse', data: {'p_id': id, 'p_warehouse_id': warehouseId});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setPackEstimate(int id, {int? cartonCount, double? cartonKg, double? materialKg}) async {
    try {
      await _rest.post('/rpc/outbound_file_set_pack_estimate', data: {
        'p_id': id,
        'p_carton_count': cartonCount,
        'p_carton_kg': cartonKg,
        'p_material_kg': materialKg,
      });
      return const ApiSuccess(true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<bool>> setReadPath(int id, String path) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_set_read_path', data: {'p_id': id, 'p_path': path});
      return ApiSuccess(r.data == true);
    } on DioException catch (e) {
      return mapDioError<bool>(e);
    }
  }

  @override
  Future<ApiResult<Uint8List>> fileBytes(String storagePath) async {
    try {
      final r = await _storage.get<List<int>>('/object/authenticated/$outboundFileBucket/$storagePath',
          options: Options(responseType: ResponseType.bytes));
      return ApiSuccess(Uint8List.fromList(r.data ?? const []));
    } on DioException catch (e) {
      return mapDioError<Uint8List>(e);
    }
  }
}

final outboundFileRepositoryProvider = Provider<OutboundFileRepository>(
    (ref) => OutboundFileRepositoryImpl(ref.watch(restDioProvider), ref.watch(storageDioProvider)));

/// The lists shipped in a month (the 出庫カレンダー), for a warehouse or all.
typedef OutboundMonthAsk = ({int year, int month, int? warehouseId});

final outboundFilesProvider =
    FutureProvider.autoDispose.family<List<OutboundFileSummary>, OutboundMonthAsk>((ref, a) async {
  final r = await ref.watch(outboundFileRepositoryProvider).list(
        from: DateTime(a.year, a.month),
        to: DateTime(a.year, a.month + 1, 0),
        warehouseId: a.warehouseId,
      );
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final outboundFileDetailProvider = FutureProvider.autoDispose.family<OutboundFileDetail, int>((ref, id) async {
  final r = await ref.watch(outboundFileRepositoryProvider).detail(id);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

/// The planned lists with no day yet, for the active warehouse or all.
/// Lists taken back with no day (0203).
final outboundCancelledUndatedProvider =
    FutureProvider.autoDispose.family<List<OutboundFileSummary>, int?>((ref, warehouseId) async {
  final r = await ref.watch(outboundFileRepositoryProvider).cancelledUndated(warehouseId: warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});

final outboundUndecidedProvider = FutureProvider.autoDispose.family<List<OutboundFileSummary>, int?>((ref, warehouseId) async {
  final r = await ref.watch(outboundFileRepositoryProvider).undecided(warehouseId: warehouseId);
  return r.when(success: (d) => d, failure: (f) => throw Exception(f.message));
});
