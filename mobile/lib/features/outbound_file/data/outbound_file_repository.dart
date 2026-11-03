import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../../core/export/save_bytes.dart' show mimeTypeFor;
import '../../delivery/application/delivery_providers.dart';

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
        lastPrice: _nd(j['last_price']),
        lastPriceDay: _day(j['last_price_day']),
        candidates: [
          for (final c in (j['candidates'] as List? ?? const []).whereType<Map>())
            OutboundCandidate.fromJson(c.cast<String, dynamic>()),
        ],
      );

  @override
  List<Object?> get props => [matchedBy, productId, onHand, lastPrice, candidates];
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
  });

  final int id;
  final int warehouseId;
  final String? warehouseName;
  final DateTime shippedOn;
  final String fileName;
  final String? storagePath;
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
      );

  @override
  List<Object?> get props => [id, shippedOn, fileName, lineCount, shippedTotal, shortTotal, undoneAt];
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
      );

  @override
  List<Object?> get props => [id, rowNo, action, productId, quantity, shippedQuantity, shortQuantity];
}

class OutboundFileDetail extends Equatable {
  const OutboundFileDetail({required this.file, required this.lines, this.undoneByName});

  final OutboundFileSummary file;
  final List<OutboundFileLine> lines;
  final String? undoneByName;

  factory OutboundFileDetail.fromJson(Map<String, dynamic> j) => OutboundFileDetail(
        file: OutboundFileSummary.fromJson(j),
        undoneByName: _s(j['undone_by_name']),
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
  });

  Future<ApiResult<List<OutboundFileSummary>>> list({required DateTime from, required DateTime to, int? warehouseId});

  Future<ApiResult<OutboundFileDetail>> detail(int id);

  /// What went out comes back: how many.
  Future<ApiResult<int>> undo(int id);

  Future<ApiResult<Uint8List>> fileBytes(String storagePath);
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
  }) async {
    try {
      final r = await _rest.post('/rpc/outbound_file_post', data: {
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
