import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/supabase_session_storage.dart';

// Work in a warehouse with poor signal (spec §58): what the field screens
// need is kept on the device, and what the worker records while offline
// waits in a queue until the network is back. The queue is kept on the
// device too, so closing the app does not lose it.
//
//   * `PendingOp` — one write that has not reached the server yet.
//   * `PendingSyncController` — the queue and the ops the server refused
//     (shown to the worker, never retried blindly), persisted in the
//     device's secure store, plus the last-read copies of work lists.

class PendingOp extends Equatable {
  const PendingOp({required this.id, required this.kind, required this.payload, required this.createdAt, this.attempts = 0});

  final String id;

  /// e.g. `inspection_count`, `inspection_item`.
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  PendingOp retried() => PendingOp(id: id, kind: kind, payload: payload, createdAt: createdAt, attempts: attempts + 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: '${j['id']}',
        kind: '${j['kind']}',
        payload: (j['payload'] as Map? ?? const {}).cast<String, dynamic>(),
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, kind, payload, attempts];
}

/// An op the server answered with a refusal: kept for a person to see.
class FailedOp extends Equatable {
  const FailedOp(this.op, this.error);

  final PendingOp op;
  final String error;

  Map<String, dynamic> toJson() => {'op': op.toJson(), 'error': error};

  factory FailedOp.fromJson(Map<String, dynamic> j) =>
      FailedOp(PendingOp.fromJson((j['op'] as Map).cast<String, dynamic>()), '${j['error']}');

  @override
  List<Object?> get props => [op, error];
}

class PendingSyncState extends Equatable {
  const PendingSyncState({this.ops = const [], this.failed = const [], this.offline = false, this.syncing = false, this.lastSyncedAt, this.loaded = false});

  final List<PendingOp> ops;
  final List<FailedOp> failed;

  /// The last call could not reach the server.
  final bool offline;
  final bool syncing;
  final DateTime? lastSyncedAt;
  final bool loaded;

  PendingSyncState copyWith({List<PendingOp>? ops, List<FailedOp>? failed, bool? offline, bool? syncing, DateTime? lastSyncedAt, bool? loaded}) =>
      PendingSyncState(
        ops: ops ?? this.ops,
        failed: failed ?? this.failed,
        offline: offline ?? this.offline,
        syncing: syncing ?? this.syncing,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [ops, failed, offline, syncing, lastSyncedAt, loaded];
}

class PendingSyncController extends StateNotifier<PendingSyncState> {
  PendingSyncController(this._store) : super(const PendingSyncState()) {
    _ready = _restore();
  }

  static const _queueKey = 'offline_queue_v1';
  static const _failedKey = 'offline_failed_v1';
  static const _cachePrefix = 'offline_cache_v1:';

  final SecureKeyValueStore _store;
  late final Future<void> _ready;
  final Map<String, Object?> _cache = {};
  int _seq = 0;

  /// Resolves once the queue saved on the device has been read back.
  Future<void> get ready => _ready;

  /// The writes still waiting, oldest first.
  List<PendingOp> get ops => state.ops;

  Future<void> _restore() async {
    try {
      final q = await _store.read(_queueKey);
      final f = await _store.read(_failedKey);
      final ops = q == null ? <PendingOp>[] : [for (final e in jsonDecode(q) as List) PendingOp.fromJson((e as Map).cast<String, dynamic>())];
      final failed = f == null ? <FailedOp>[] : [for (final e in jsonDecode(f) as List) FailedOp.fromJson((e as Map).cast<String, dynamic>())];
      if (mounted) state = state.copyWith(ops: [...ops, ...state.ops], failed: [...failed, ...state.failed], loaded: true);
    } catch (_) {
      if (mounted) state = state.copyWith(loaded: true);
    }
  }

  Future<void> _persist() async {
    try {
      await _store.write(_queueKey, jsonEncode([for (final o in state.ops) o.toJson()]));
      await _store.write(_failedKey, jsonEncode([for (final f in state.failed) f.toJson()]));
    } catch (_) {
      // The queue still lives in memory; the next change tries again.
    }
  }

  Future<PendingOp> enqueue(String kind, Map<String, dynamic> payload) async {
    await _ready;
    final op = PendingOp(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      kind: kind,
      payload: payload,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(ops: [...state.ops, op], offline: true);
    await _persist();
    return op;
  }

  Future<void> done(PendingOp op) async {
    state = state.copyWith(ops: [for (final o in state.ops) if (o.id != op.id) o]);
    await _persist();
  }

  Future<void> refused(PendingOp op, String error) async {
    state = state.copyWith(
      ops: [for (final o in state.ops) if (o.id != op.id) o],
      failed: [...state.failed, FailedOp(op, error)],
    );
    await _persist();
  }

  Future<void> stillOffline(PendingOp op) async {
    state = state.copyWith(ops: [for (final o in state.ops) o.id == op.id ? o.retried() : o], offline: true);
    await _persist();
  }

  Future<void> dismissFailed(FailedOp f) async {
    state = state.copyWith(failed: [for (final x in state.failed) if (x != f) x]);
    await _persist();
  }

  void setOffline(bool offline) {
    if (state.offline != offline) state = state.copyWith(offline: offline);
  }

  void setSyncing(bool syncing, {bool finished = false}) {
    state = state.copyWith(syncing: syncing, lastSyncedAt: finished ? DateTime.now() : null);
  }

  // ------------------------------------------------------------ read cache

  /// The last copy of a work list read from the server.
  Future<void> putCache(String key, Object? raw) async {
    _cache[key] = raw;
    try {
      await _store.write('$_cachePrefix$key', jsonEncode(raw));
    } catch (_) {}
  }

  Future<Object?> getCache(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final s = await _store.read('$_cachePrefix$key');
      if (s == null) return null;
      final v = jsonDecode(s);
      _cache[key] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Every cached entry whose key starts with [prefix] that this session
  /// has seen (for finding the inspection an item belongs to).
  Iterable<MapEntry<String, Object?>> cachedEntries(String prefix) =>
      _cache.entries.where((e) => e.key.startsWith(prefix));
}

/// The device store the queue and cache live in. Tests swap in memory.
final offlineStoreProvider = Provider<SecureKeyValueStore>((_) => const FlutterSecureKeyValueStore());

final pendingSyncProvider = StateNotifierProvider<PendingSyncController, PendingSyncState>(
    (ref) => PendingSyncController(ref.watch(offlineStoreProvider)));
