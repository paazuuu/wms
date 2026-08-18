import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;

import '../../features/inspection/data/inspection_repository.dart';
import '../api/api_result.dart';
import 'offline_database.dart';

/// Operation identifiers persisted in [QueuedMutations.operation].
class SyncOp {
  static const recordItem = 'record_item';
  static const completeInspection = 'complete_inspection';
  static const uploadAttachment = 'upload_attachment';
}

/// Replays mutations captured while offline. Mutations are appended to the
/// Drift queue by the UI (or by a repository decorator) and drained in FIFO
/// order once connectivity returns.
///
/// Poison handling: a mutation that the server rejects with a definitive HTTP
/// status (a 4xx — the same payload will never succeed) is dropped so it cannot
/// block the queue. A mutation that fails without any response (no network) is
/// kept and retried on the next flush. A mutation that exceeds [maxAttempts] is
/// dropped regardless, as a last-resort guard against an unexpected poison row.
class OfflineSyncService {
  OfflineSyncService({
    required OfflineDatabase database,
    required InspectionRepository repository,
    required Stream<bool> connectivityStream,
    Future<bool> Function()? isOnline,
    this.maxAttempts = 5,
  })  : _db = database,
        _repository = repository,
        _connectivity = connectivityStream,
        _isOnline = isOnline;

  final OfflineDatabase _db;
  final InspectionRepository _repository;
  final Stream<bool> _connectivity;
  final Future<bool> Function()? _isOnline;
  final int maxAttempts;

  StreamSubscription<bool>? _subscription;
  bool _flushing = false;

  /// Begin draining the queue whenever connectivity is (re)gained. Also drains
  /// once on startup if the device is already online, so mutations queued in a
  /// previous session are not stranded.
  void start() {
    if (_subscription != null) return;
    _subscription = _connectivity.listen((online) {
      if (online) {
        // Fire-and-forget; flush guards against re-entrancy itself.
        unawaited(flush());
      }
    });
    final probe = _isOnline;
    if (probe != null) {
      unawaited(probe().then((online) {
        if (online) unawaited(flush());
      }));
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<int> enqueueRecordItem(
    int inspectionId,
    Map<String, dynamic> payload,
  ) {
    return _db.enqueue(QueuedMutationsCompanion.insert(
      operation: SyncOp.recordItem,
      inspectionId: inspectionId,
      payload: jsonEncode(payload),
    ));
  }

  Future<int> enqueueComplete(int inspectionId) {
    return _db.enqueue(QueuedMutationsCompanion.insert(
      operation: SyncOp.completeInspection,
      inspectionId: inspectionId,
      payload: jsonEncode(const <String, dynamic>{}),
    ));
  }

  Future<int> enqueueAttachment(
    int inspectionId, {
    required String filePath,
    String? kind,
    int? inspectionItemId,
  }) {
    return _db.enqueue(QueuedMutationsCompanion.insert(
      operation: SyncOp.uploadAttachment,
      inspectionId: inspectionId,
      payload: jsonEncode({
        if (kind != null) 'kind': kind,
        if (inspectionItemId != null) 'inspection_item_id': inspectionItemId,
      }),
      filePath: Value(filePath),
    ));
  }

  /// Drain every pending mutation in order. Stops early on the first network
  /// failure (still offline) so ordering is preserved. Returns the number of
  /// mutations successfully replayed.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var replayed = 0;
    try {
      final pending = await _db.pendingMutations();
      for (final mutation in pending) {
        final outcome = await _replay(mutation);
        switch (outcome) {
          case _Outcome.success:
            await _db.remove(mutation.id);
            replayed++;
          case _Outcome.drop:
            await _db.remove(mutation.id);
          case _Outcome.retry:
            await _db.incrementAttempts(mutation.id);
            if (mutation.attempts + 1 >= maxAttempts) {
              await _db.remove(mutation.id);
              continue;
            }
            // Network is down — preserve FIFO order, resume next flush.
            return replayed;
        }
      }
    } finally {
      _flushing = false;
    }
    return replayed;
  }

  Future<_Outcome> _replay(QueuedMutation mutation) async {
    final payload = jsonDecode(mutation.payload) as Map<String, dynamic>;

    final ApiResult<Object?> result = switch (mutation.operation) {
      SyncOp.recordItem =>
        await _repository.recordItem(mutation.inspectionId, payload),
      SyncOp.completeInspection =>
        await _repository.complete(mutation.inspectionId),
      SyncOp.uploadAttachment => await _replayAttachment(mutation, payload),
      _ => const ApiFailure<Object?>(message: 'Unknown operation'),
    };

    return result.when(
      success: (_) => _Outcome.success,
      failure: (f) {
        // No status code => request never reached the server (offline). Retry.
        if (f.statusCode == null) return _Outcome.retry;
        // 5xx is transient; anything else the server definitively rejected.
        return f.statusCode! >= 500 ? _Outcome.retry : _Outcome.drop;
      },
    );
  }

  Future<ApiResult<Object?>> _replayAttachment(
    QueuedMutation mutation,
    Map<String, dynamic> payload,
  ) async {
    final path = mutation.filePath;
    if (path == null) {
      return const ApiFailure<Object?>(
        message: 'Missing file path for queued attachment',
        statusCode: 422,
      );
    }
    final file = await MultipartFile.fromFile(path);
    return _repository.uploadAttachments(
      mutation.inspectionId,
      files: [file],
      kind: payload['kind'] as String?,
      inspectionItemId: payload['inspection_item_id'] as int?,
    );
  }
}

enum _Outcome { success, drop, retry }
