import '../../../core/api/api_result.dart';
import '../../../core/offline/pending_sync.dart';
import '../domain/bulk_inspection.dart';
import '../domain/delivery_note.dart';
import '../domain/held_stock.dart';
import '../domain/inspection.dart';
import 'inspection_repository.dart';

/// No HTTP answer at all: the network, not the server, said no.
bool isOfflineFailure(ApiFailure f) => f.statusCode == null;

/// Inspection on a weak connection (spec §58).
///
/// Reads go to the server and their copy is kept on the device; when the
/// server cannot be reached, the kept copy is shown. The field writes an
/// inspector makes — counts, scans, ticks, a line's finding — are queued
/// when offline and applied to the kept copy, so the screen moves on as if
/// they had been saved; [flush] sends them in order once the network is back.
/// What the server then refuses is kept aside for a person, not retried.
///
/// Anything that settles stock (completing an inspection, passing lines in
/// bulk, disposing held goods) is never queued: it needs the server's answer
/// there and then, and fails with a clear "offline" message instead.
class OfflineInspectionRepository implements InspectionRepository {
  OfflineInspectionRepository(this._inner, this._sync);

  final InspectionRepository _inner;
  final PendingSyncController _sync;
  bool _flushing = false;

  static String showKey(int id) => 'inspection_show:$id';
  static String listKey(String? status, int? warehouseId) => 'inspection_list:${status ?? ''}:${warehouseId ?? ''}';

  /// Hands the raw server reads to the cache (wired into [InspectionRepositoryImpl]).
  static void Function(String key, Object? raw) cacheWriter(PendingSyncController sync) =>
      (key, raw) => sync.putCache(key, raw);

  @override
  Future<ApiResult<List<Inspection>>> list({String? status, int? warehouseId}) async {
    final r = await _inner.list(status: status, warehouseId: warehouseId);
    if (r is ApiFailure<List<Inspection>> && isOfflineFailure(r)) {
      _sync.setOffline(true);
      final raw = await _sync.getCache(listKey(status, warehouseId));
      if (raw is List) {
        return ApiSuccess([for (final e in raw) if (e is Map) Inspection.fromJson(e.cast<String, dynamic>())]);
      }
      return r;
    }
    if (r is ApiSuccess) _sync.setOffline(false);
    return r;
  }

  @override
  Future<ApiResult<Inspection>> show(int id) async {
    final r = await _inner.show(id);
    if (r is ApiFailure<Inspection> && isOfflineFailure(r)) {
      _sync.setOffline(true);
      final raw = await _sync.getCache(showKey(id));
      if (raw is Map) return ApiSuccess(Inspection.fromJson(raw.cast<String, dynamic>()));
      return r;
    }
    if (r is ApiSuccess) _sync.setOffline(false);
    return r;
  }

  /// The kept copy of the inspection [itemId] belongs to, and the item in it.
  Future<(String, Map<String, dynamic>, Map<String, dynamic>)?> _cachedItem(int itemId, {int? inspectionId}) async {
    final keys = <String>[
      if (inspectionId != null) showKey(inspectionId),
      for (final e in _sync.cachedEntries('inspection_show:')) e.key,
    ];
    for (final k in keys) {
      final raw = await _sync.getCache(k);
      if (raw is! Map) continue;
      final ins = raw.cast<String, dynamic>();
      for (final it in (ins['items'] as List? ?? const [])) {
        if (it is Map && '${it['id']}' == '$itemId') return (k, ins, it.cast<String, dynamic>());
      }
    }
    return null;
  }

  int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Future<ApiResult<InspectionCount>> recordCount(int itemId, int quantity, {InspectionCountMode mode = InspectionCountMode.set}) async {
    final r = await _inner.recordCount(itemId, quantity, mode: mode);
    if (r is! ApiFailure<InspectionCount> || !isOfflineFailure(r)) {
      if (r is ApiSuccess) _sync.setOffline(false);
      return r;
    }
    await _sync.enqueue('inspection_count', {'item_id': itemId, 'quantity': quantity, 'mode': mode.wire});
    // Show the count as it will be once sent.
    final hit = await _cachedItem(itemId);
    var counted = quantity;
    var received = 0;
    if (hit != null) {
      final (key, ins, item) = hit;
      final before = item['counted_quantity'] == null ? null : _int(item['counted_quantity']);
      received = _int(item['actual_quantity']);
      switch (mode) {
        case InspectionCountMode.set:
          item['counted_quantity'] = quantity;
        case InspectionCountMode.add:
          item['counted_quantity'] = (before ?? 0) + quantity;
        case InspectionCountMode.check:
          item['counted_quantity'] = item['note_quantity'] ?? item['actual_quantity'];
        case InspectionCountMode.clear:
          item['counted_quantity'] = null;
        case InspectionCountMode.sample:
          item['sampled_quantity'] = _int(item['sampled_quantity']) + quantity;
      }
      counted = item['counted_quantity'] == null ? 0 : _int(item['counted_quantity']);
      await _sync.putCache(key, ins);
    }
    return ApiSuccess(InspectionCount(itemId: itemId, counted: counted, received: received));
  }

  @override
  Future<ApiResult<Inspection>> saveItem(int inspectionId, int itemId, InspectionFinding finding) async {
    final r = await _inner.saveItem(inspectionId, itemId, finding);
    if (r is! ApiFailure<Inspection> || !isOfflineFailure(r)) {
      if (r is ApiSuccess) _sync.setOffline(false);
      return r;
    }
    final hit = await _cachedItem(itemId, inspectionId: inspectionId);
    if (hit == null) return r; // nothing on the device to show it against
    await _sync.enqueue('inspection_item', {'inspection_id': inspectionId, 'item_id': itemId, 'finding': finding.toJson()});
    final (key, ins, item) = hit;
    item
      ..addAll(finding.toJson()..remove('hold'))
      ..['result'] = finding.hold
          ? 'HOLD'
          : finding.failedQuantity > 0
              ? (finding.passedQuantity > 0 ? 'PARTIAL' : 'FAIL')
              : 'PASS';
    await _sync.putCache(key, ins);
    return ApiSuccess(Inspection.fromJson(ins));
  }

  /// Sends the queue in order. Stops at the first op the network still
  /// cannot carry; an op the server refuses is set aside with its reason.
  /// Returns how many were sent.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    await _sync.ready;
    _sync.setSyncing(true);
    var sent = 0;
    try {
      for (final op in [..._sync.ops]) {
        final ApiResult<Object?> r = switch (op.kind) {
          'inspection_count' => await _inner.recordCount(
              _int(op.payload['item_id']),
              _int(op.payload['quantity']),
              mode: InspectionCountMode.values.firstWhere((m) => m.wire == op.payload['mode'], orElse: () => InspectionCountMode.set),
            ),
          'inspection_item' => await _inner.saveItem(
              _int(op.payload['inspection_id']),
              _int(op.payload['item_id']),
              _findingFrom((op.payload['finding'] as Map? ?? const {}).cast<String, dynamic>()),
            ),
          _ => const ApiFailure<Object?>(message: 'unknown pending operation', statusCode: 400),
        };
        if (r is ApiFailure) {
          if (isOfflineFailure(r)) {
            await _sync.stillOffline(op);
            return sent;
          }
          await _sync.refused(op, r.message);
        } else {
          await _sync.done(op);
          sent++;
        }
      }
      _sync.setOffline(false);
      return sent;
    } finally {
      _flushing = false;
      _sync.setSyncing(false, finished: true);
    }
  }

  InspectionFinding _findingFrom(Map<String, dynamic> j) => InspectionFinding(
        passedQuantity: _int(j['passed_quantity']),
        failedQuantity: _int(j['failed_quantity']),
        lot: j['lot'] as String?,
        serial: j['serial'] as String?,
        expiry: j['expiry'] as String?,
        packagingCondition: j['packaging_condition'] as String?,
        productCondition: j['product_condition'] as String?,
        labelOk: j['label_ok'] as bool?,
        note: j['note'] as String?,
        hold: j['hold'] == true,
      );

  // Everything else goes straight through: it needs the server now.
  @override
  Future<ApiResult<Inspection>> start(int reconciliationId) => _inner.start(reconciliationId);

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId, {String? note, String? failStatus}) =>
      _inner.complete(inspectionId, note: note, failStatus: failStatus);

  @override
  Future<ApiResult<List<HeldStock>>> heldStock({int? warehouseId, String? status}) =>
      _inner.heldStock(warehouseId: warehouseId, status: status);

  @override
  Future<ApiResult<List<OpenInspectionLine>>> openLines({int? warehouseId}) => _inner.openLines(warehouseId: warehouseId);

  @override
  Future<ApiResult<BulkPassResult>> passItems(List<int> itemIds, {String? note}) => _inner.passItems(itemIds, note: note);

  @override
  Future<ApiResult<DeliveryNoteApplyResult>> applyDeliveryNote(int inspectionId, List<DeliveryNoteLine> lines) =>
      _inner.applyDeliveryNote(inspectionId, lines);

  @override
  Future<ApiResult<bool>> reportWrongItem(int inspectionId, String janCode, {int quantity = 1, String? note}) =>
      _inner.reportWrongItem(inspectionId, janCode, quantity: quantity, note: note);

  @override
  Future<ApiResult<bool>> convertItem(int itemId, int productId, {bool remember = true}) =>
      _inner.convertItem(itemId, productId, remember: remember);

  @override
  Future<ApiResult<DispositionResult>> dispose(HeldStock row, HeldDisposition action, {required int quantity, String? note}) =>
      _inner.dispose(row, action, quantity: quantity, note: note);
}
