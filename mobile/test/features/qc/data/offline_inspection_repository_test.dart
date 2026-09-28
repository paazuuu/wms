import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/offline/pending_sync.dart';
import 'package:wms_mobile/features/qc/data/inspection_repository.dart';
import 'package:wms_mobile/features/qc/data/offline_inspection_repository.dart';
import 'package:wms_mobile/features/qc/domain/inspection.dart';

import '../../../support/harness.dart';

const _offline = ApiFailure<Never>(message: 'No connection to the server.');

/// An inner repository whose network can be switched off, and whose server
/// can refuse a given item.
class _Inner implements InspectionRepository {
  bool online = true;
  int? refuseItem;
  final List<String> calls = [];

  static Map<String, dynamic> raw() => {
        'id': 1,
        'status': 'PENDING',
        'items': [
          {'id': 11, 'jan_code': '4900000000011', 'product_name': 'A', 'expected_quantity': 10, 'actual_quantity': 10, 'note_quantity': 10},
          {'id': 12, 'jan_code': '4900000000012', 'product_name': 'B', 'expected_quantity': 5, 'actual_quantity': 5},
        ],
      };

  @override
  Future<ApiResult<Inspection>> show(int id) async =>
      online ? ApiSuccess(Inspection.fromJson(raw())) : const ApiFailure(message: 'No connection to the server.');

  @override
  Future<ApiResult<List<Inspection>>> list({String? status, int? warehouseId}) async =>
      online ? ApiSuccess([Inspection.fromJson(raw())]) : const ApiFailure(message: 'No connection to the server.');

  @override
  Future<ApiResult<InspectionCount>> recordCount(int itemId, int quantity, {InspectionCountMode mode = InspectionCountMode.set}) async {
    if (!online) return const ApiFailure(message: 'No connection to the server.');
    if (itemId == refuseItem) return const ApiFailure(message: 'inspection 1 is already completed', statusCode: 400);
    calls.add('count:$itemId:$quantity:${mode.wire}');
    return ApiSuccess(InspectionCount(itemId: itemId, counted: quantity, received: 10));
  }

  @override
  Future<ApiResult<Inspection>> saveItem(int inspectionId, int itemId, InspectionFinding finding) async {
    if (!online) return const ApiFailure(message: 'No connection to the server.');
    calls.add('item:$itemId:${finding.passedQuantity}/${finding.failedQuantity}');
    return ApiSuccess(Inspection.fromJson(raw()));
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId, {String? note, String? failStatus}) async =>
      online ? ApiSuccess(Inspection.fromJson(raw())) : const ApiFailure(message: 'No connection to the server.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Inner inner;
  late PendingSyncController sync;
  late OfflineInspectionRepository repo;

  setUp(() async {
    inner = _Inner();
    sync = PendingSyncController(fakeSecureStore());
    await sync.ready;
    repo = OfflineInspectionRepository(inner, sync);
  });

  test('an offline failure is one with no HTTP status', () {
    expect(isOfflineFailure(_offline), isTrue);
    expect(isOfflineFailure(const ApiFailure<Never>(message: 'x', statusCode: 500)), isFalse);
  });

  test('offline: the kept copy is shown and field writes wait in the queue', () async {
    // Read once online: the device keeps the copy.
    await sync.putCache(OfflineInspectionRepository.showKey(1), _Inner.raw());
    await sync.putCache(OfflineInspectionRepository.listKey(null, null), [_Inner.raw()]);
    inner.online = false;

    final shown = await repo.show(1);
    expect(shown, isA<ApiSuccess<Inspection>>());
    expect((shown as ApiSuccess<Inspection>).data.items, hasLength(2));
    expect(sync.state.offline, isTrue);
    final listed = await repo.list();
    expect((listed as ApiSuccess<List<Inspection>>).data.single.id, 1);

    final counted = await repo.recordCount(11, 3, mode: InspectionCountMode.add);
    expect((counted as ApiSuccess<InspectionCount>).data.counted, 3);
    await repo.recordCount(11, 2, mode: InspectionCountMode.add);
    final ticked = await repo.recordCount(12, 0, mode: InspectionCountMode.check);
    expect((ticked as ApiSuccess<InspectionCount>).data.counted, 5);

    final saved = await repo.saveItem(1, 12, const InspectionFinding(passedQuantity: 4, failedQuantity: 1));
    final item = (saved as ApiSuccess<Inspection>).data.items.firstWhere((i) => i.id == 12);
    expect(item.result, QcResult.partial);
    expect(item.failedQuantity, 1);

    expect(sync.ops.map((o) => o.kind), ['inspection_count', 'inspection_count', 'inspection_count', 'inspection_item']);
    // The kept copy moved on with the writes.
    final again = (await repo.show(1)) as ApiSuccess<Inspection>;
    expect(again.data.items.firstWhere((i) => i.id == 11).countedQuantity, 5);

    // Settling stock is never queued.
    expect(await repo.complete(1), isA<ApiFailure<Inspection>>());
    expect(sync.ops, hasLength(4));
  });

  test('flush sends in order, sets refusals aside and clears offline', () async {
    await sync.putCache(OfflineInspectionRepository.showKey(1), _Inner.raw());
    inner.online = false;
    await repo.recordCount(11, 3, mode: InspectionCountMode.add);
    await repo.recordCount(12, 1);
    await repo.saveItem(1, 11, const InspectionFinding(passedQuantity: 3, failedQuantity: 0));

    // Still offline: nothing is sent, nothing is lost.
    expect(await repo.flush(), 0);
    expect(sync.ops, hasLength(3));
    expect(sync.ops.first.attempts, 1);

    inner
      ..online = true
      ..refuseItem = 12;
    expect(await repo.flush(), 2);
    expect(inner.calls, ['count:11:3:add', 'item:11:3/0']);
    expect(sync.ops, isEmpty);
    expect(sync.state.failed.single.op.payload['item_id'], 12);
    expect(sync.state.failed.single.error, contains('already completed'));
    expect(sync.state.offline, isFalse);

    await sync.dismissFailed(sync.state.failed.single);
    expect(sync.state.failed, isEmpty);
  });

  test('the queue survives a restart of the app', () async {
    final store = fakeSecureStore();
    final first = PendingSyncController(store);
    await first.ready;
    await first.enqueue('inspection_count', {'item_id': 11, 'quantity': 1, 'mode': 'add'});
    first.dispose();

    final second = PendingSyncController(store);
    await second.ready;
    expect(second.ops.single.payload['item_id'], 11);
  });

  test('a finding for an item never seen on this device is not queued', () async {
    inner.online = false;
    final r = await repo.saveItem(1, 99, const InspectionFinding(passedQuantity: 1, failedQuantity: 0));
    expect(r, isA<ApiFailure<Inspection>>());
    expect(sync.ops, isEmpty);
  });
}
