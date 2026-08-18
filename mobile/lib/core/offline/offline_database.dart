import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'offline_database.g.dart';

/// Queue of mutations captured while offline. Each row is a self-contained
/// request (endpoint + JSON payload) replayed in order once connectivity
/// returns. Attachments store the local file path until uploaded.
class QueuedMutations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// e.g. record_item | upload_attachment | complete_inspection
  TextColumn get operation => text()();

  IntColumn get inspectionId => integer()();

  /// JSON-encoded request body.
  TextColumn get payload => text()();

  /// Local file path for attachment uploads (null for JSON-only mutations).
  TextColumn get filePath => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [QueuedMutations])
class OfflineDatabase extends _$OfflineDatabase {
  OfflineDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'wms_offline',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 1;

  Future<List<QueuedMutation>> pendingMutations() =>
      (select(queuedMutations)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<int> enqueue(QueuedMutationsCompanion mutation) =>
      into(queuedMutations).insert(mutation);

  Future<void> remove(int id) =>
      (delete(queuedMutations)..where((t) => t.id.equals(id))).go();

  Future<void> incrementAttempts(int id) async {
    final row = await (select(queuedMutations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row != null) {
      await (update(queuedMutations)..where((t) => t.id.equals(id)))
          .write(QueuedMutationsCompanion(attempts: Value(row.attempts + 1)));
    }
  }
}
