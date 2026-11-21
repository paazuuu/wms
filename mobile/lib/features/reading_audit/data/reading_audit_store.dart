import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/local_prefs.dart';
import '../domain/reading_audit.dart';

/// Where the readings are kept: this browser's localStorage. Nothing goes
/// to the database — it is for improving the reader, not a record of stock.
typedef AuditStorage = ({String? Function() read, void Function(String? value) write});

const readingAuditKey = 'reading_audit_v1';

/// The newest kept; older ones fall off.
const readingAuditMax = 200;

final readingAuditStorageProvider = Provider<AuditStorage>((_) => (
      read: () => readLocalPref(readingAuditKey),
      write: (v) => writeLocalPref(readingAuditKey, v),
    ));

/// The readings kept, newest first.
class ReadingAuditStore extends Notifier<List<ReadingAudit>> {
  @override
  List<ReadingAudit> build() {
    final raw = ref.watch(readingAuditStorageProvider).read();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final j in list.whereType<Map>()) ReadingAudit.fromJson(j.cast<String, dynamic>())];
    } on FormatException {
      return const [];
    }
  }

  /// Keeps [a] (or replaces the reading with its id). One with nothing to
  /// say is not kept, and takes away what the same reading said before.
  void put(ReadingAudit a) {
    final rest = [for (final r in state) if (r.id != a.id) r];
    _set(a.issues.isEmpty ? rest : [a, ...rest]);
  }

  void remove(String id) => _set([for (final r in state) if (r.id != id) r]);

  void clear() => _set(const []);

  void _set(List<ReadingAudit> list) {
    final kept = list.length > readingAuditMax ? list.sublist(0, readingAuditMax) : list;
    state = kept;
    try {
      ref.read(readingAuditStorageProvider).write(kept.isEmpty ? null : jsonEncode([for (final r in kept) r.toJson()]));
    } catch (_) {
      // A full or blocked storage: still shown for this visit.
    }
  }
}

final readingAuditProvider = NotifierProvider<ReadingAuditStore, List<ReadingAudit>>(ReadingAuditStore.new);

/// A fresh id for one reading.
String newReadingAuditId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
