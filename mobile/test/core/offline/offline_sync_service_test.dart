import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:wms_mobile/core/api/api_result.dart';
import 'package:wms_mobile/core/offline/offline_database.dart';
import 'package:wms_mobile/core/offline/offline_sync_service.dart';
import 'package:wms_mobile/features/inspection/data/inspection_repository.dart';
import 'package:wms_mobile/features/inspection/domain/attachment.dart';
import 'package:wms_mobile/features/inspection/domain/inspection.dart';
import 'package:wms_mobile/features/inspection/domain/inspection_item.dart';

/// Repository test double: each call pops the next programmed result.
class _FakeRepository implements InspectionRepository {
  final List<ApiResult<InspectionItem>> recordResults = [];
  final List<ApiResult<Inspection>> completeResults = [];
  int recordCalls = 0;
  int completeCalls = 0;

  @override
  Future<ApiResult<InspectionItem>> recordItem(
      int inspectionId, Map<String, dynamic> payload) async {
    return recordResults[recordCalls++];
  }

  @override
  Future<ApiResult<Inspection>> complete(int inspectionId) async {
    return completeResults[completeCalls++];
  }

  @override
  Future<ApiResult<List<Attachment>>> uploadAttachments(int inspectionId,
      {required List<MultipartFile> files,
      String? kind,
      int? inspectionItemId}) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<Inspection>> create(
      {required String type,
      String? note,
      List<Map<String, dynamic>> items = const []}) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<List<Inspection>>> list({String? status, String? type}) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<Inspection>> show(int id) {
    throw UnimplementedError();
  }
}

InspectionItem _item() => const InspectionItem(
    id: 1, inspectionId: 1, matchResult: MatchResult.ok);
Inspection _inspection() => const Inspection(
    id: 1, code: 'INS-000001', type: 'receiving', status: InspectionStatus.pending);

void main() {
  // Some Linux hosts ship only the versioned `libsqlite3.so.0` without the
  // unversioned symlink the sqlite3 package loads by default. Fall back to it.
  if (Platform.isLinux) {
    open.overrideForAll(() {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } on ArgumentError {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  }

  late OfflineDatabase db;
  late _FakeRepository repo;
  late StreamController<bool> connectivity;

  OfflineSyncService build() => OfflineSyncService(
        database: db,
        repository: repo,
        connectivityStream: connectivity.stream,
      );

  setUp(() {
    db = OfflineDatabase(NativeDatabase.memory());
    repo = _FakeRepository();
    connectivity = StreamController<bool>.broadcast();
  });

  tearDown(() async {
    await connectivity.close();
    await db.close();
  });

  test('drains queued mutations in FIFO order and clears them', () async {
    repo.recordResults.add(ApiSuccess(_item()));
    repo.completeResults.add(ApiSuccess(_inspection()));
    final sync = build();

    await sync.enqueueRecordItem(1, {'scanned_barcode': 'x', 'actual_quantity': 1});
    await sync.enqueueComplete(1);

    final replayed = await sync.flush();

    expect(replayed, 2);
    expect(await db.pendingMutations(), isEmpty);
    expect(repo.recordCalls, 1);
    expect(repo.completeCalls, 1);
  });

  test('keeps mutation and stops when offline (no status code)', () async {
    repo.recordResults.add(const ApiFailure(message: 'network'));
    final sync = build();

    await sync.enqueueRecordItem(1, {'scanned_barcode': 'x', 'actual_quantity': 1});
    final replayed = await sync.flush();

    expect(replayed, 0);
    final pending = await db.pendingMutations();
    expect(pending, hasLength(1));
    expect(pending.single.attempts, 1);
  });

  test('drops a poison mutation the server rejects with 4xx', () async {
    repo.recordResults.add(const ApiFailure(message: 'invalid', statusCode: 422));
    repo.completeResults.add(ApiSuccess(_inspection()));
    final sync = build();

    await sync.enqueueRecordItem(1, {'bad': true});
    await sync.enqueueComplete(1);

    final replayed = await sync.flush();

    // Poison dropped (not counted), following mutation still processed.
    expect(replayed, 1);
    expect(await db.pendingMutations(), isEmpty);
  });

  test('flushes automatically when connectivity is regained', () async {
    repo.completeResults.add(ApiSuccess(_inspection()));
    final sync = build()..start();

    await sync.enqueueComplete(1);
    connectivity.add(true);
    // Allow the listener microtask/flush to run.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(await db.pendingMutations(), isEmpty);
    await sync.dispose();
  });
}
