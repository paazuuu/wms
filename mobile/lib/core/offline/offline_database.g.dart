// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $QueuedMutationsTable extends QueuedMutations
    with TableInfo<$QueuedMutationsTable, QueuedMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inspectionIdMeta =
      const VerificationMeta('inspectionId');
  @override
  late final GeneratedColumn<int> inspectionId = GeneratedColumn<int>(
      'inspection_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, operation, inspectionId, payload, filePath, attempts, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_mutations';
  @override
  VerificationContext validateIntegrity(Insertable<QueuedMutation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('inspection_id')) {
      context.handle(
          _inspectionIdMeta,
          inspectionId.isAcceptableOrUnknown(
              data['inspection_id']!, _inspectionIdMeta));
    } else if (isInserting) {
      context.missing(_inspectionIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedMutation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      inspectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}inspection_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $QueuedMutationsTable createAlias(String alias) {
    return $QueuedMutationsTable(attachedDatabase, alias);
  }
}

class QueuedMutation extends DataClass implements Insertable<QueuedMutation> {
  final int id;

  /// e.g. record_item | upload_attachment | complete_inspection
  final String operation;
  final int inspectionId;

  /// JSON-encoded request body.
  final String payload;

  /// Local file path for attachment uploads (null for JSON-only mutations).
  final String? filePath;
  final int attempts;
  final DateTime createdAt;
  const QueuedMutation(
      {required this.id,
      required this.operation,
      required this.inspectionId,
      required this.payload,
      this.filePath,
      required this.attempts,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation'] = Variable<String>(operation);
    map['inspection_id'] = Variable<int>(inspectionId);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QueuedMutationsCompanion toCompanion(bool nullToAbsent) {
    return QueuedMutationsCompanion(
      id: Value(id),
      operation: Value(operation),
      inspectionId: Value(inspectionId),
      payload: Value(payload),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
    );
  }

  factory QueuedMutation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedMutation(
      id: serializer.fromJson<int>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      inspectionId: serializer.fromJson<int>(json['inspectionId']),
      payload: serializer.fromJson<String>(json['payload']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation': serializer.toJson<String>(operation),
      'inspectionId': serializer.toJson<int>(inspectionId),
      'payload': serializer.toJson<String>(payload),
      'filePath': serializer.toJson<String?>(filePath),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QueuedMutation copyWith(
          {int? id,
          String? operation,
          int? inspectionId,
          String? payload,
          Value<String?> filePath = const Value.absent(),
          int? attempts,
          DateTime? createdAt}) =>
      QueuedMutation(
        id: id ?? this.id,
        operation: operation ?? this.operation,
        inspectionId: inspectionId ?? this.inspectionId,
        payload: payload ?? this.payload,
        filePath: filePath.present ? filePath.value : this.filePath,
        attempts: attempts ?? this.attempts,
        createdAt: createdAt ?? this.createdAt,
      );
  QueuedMutation copyWithCompanion(QueuedMutationsCompanion data) {
    return QueuedMutation(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      inspectionId: data.inspectionId.present
          ? data.inspectionId.value
          : this.inspectionId,
      payload: data.payload.present ? data.payload.value : this.payload,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedMutation(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('inspectionId: $inspectionId, ')
          ..write('payload: $payload, ')
          ..write('filePath: $filePath, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, operation, inspectionId, payload, filePath, attempts, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedMutation &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.inspectionId == this.inspectionId &&
          other.payload == this.payload &&
          other.filePath == this.filePath &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt);
}

class QueuedMutationsCompanion extends UpdateCompanion<QueuedMutation> {
  final Value<int> id;
  final Value<String> operation;
  final Value<int> inspectionId;
  final Value<String> payload;
  final Value<String?> filePath;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  const QueuedMutationsCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.inspectionId = const Value.absent(),
    this.payload = const Value.absent(),
    this.filePath = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  QueuedMutationsCompanion.insert({
    this.id = const Value.absent(),
    required String operation,
    required int inspectionId,
    required String payload,
    this.filePath = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : operation = Value(operation),
        inspectionId = Value(inspectionId),
        payload = Value(payload);
  static Insertable<QueuedMutation> custom({
    Expression<int>? id,
    Expression<String>? operation,
    Expression<int>? inspectionId,
    Expression<String>? payload,
    Expression<String>? filePath,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (inspectionId != null) 'inspection_id': inspectionId,
      if (payload != null) 'payload': payload,
      if (filePath != null) 'file_path': filePath,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  QueuedMutationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? operation,
      Value<int>? inspectionId,
      Value<String>? payload,
      Value<String?>? filePath,
      Value<int>? attempts,
      Value<DateTime>? createdAt}) {
    return QueuedMutationsCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      inspectionId: inspectionId ?? this.inspectionId,
      payload: payload ?? this.payload,
      filePath: filePath ?? this.filePath,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (inspectionId.present) {
      map['inspection_id'] = Variable<int>(inspectionId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedMutationsCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('inspectionId: $inspectionId, ')
          ..write('payload: $payload, ')
          ..write('filePath: $filePath, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $QueuedMutationsTable queuedMutations =
      $QueuedMutationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [queuedMutations];
}

typedef $$QueuedMutationsTableCreateCompanionBuilder = QueuedMutationsCompanion
    Function({
  Value<int> id,
  required String operation,
  required int inspectionId,
  required String payload,
  Value<String?> filePath,
  Value<int> attempts,
  Value<DateTime> createdAt,
});
typedef $$QueuedMutationsTableUpdateCompanionBuilder = QueuedMutationsCompanion
    Function({
  Value<int> id,
  Value<String> operation,
  Value<int> inspectionId,
  Value<String> payload,
  Value<String?> filePath,
  Value<int> attempts,
  Value<DateTime> createdAt,
});

class $$QueuedMutationsTableFilterComposer
    extends Composer<_$OfflineDatabase, $QueuedMutationsTable> {
  $$QueuedMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get inspectionId => $composableBuilder(
      column: $table.inspectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$QueuedMutationsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $QueuedMutationsTable> {
  $$QueuedMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get inspectionId => $composableBuilder(
      column: $table.inspectionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$QueuedMutationsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $QueuedMutationsTable> {
  $$QueuedMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get inspectionId => $composableBuilder(
      column: $table.inspectionId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QueuedMutationsTableTableManager extends RootTableManager<
    _$OfflineDatabase,
    $QueuedMutationsTable,
    QueuedMutation,
    $$QueuedMutationsTableFilterComposer,
    $$QueuedMutationsTableOrderingComposer,
    $$QueuedMutationsTableAnnotationComposer,
    $$QueuedMutationsTableCreateCompanionBuilder,
    $$QueuedMutationsTableUpdateCompanionBuilder,
    (
      QueuedMutation,
      BaseReferences<_$OfflineDatabase, $QueuedMutationsTable, QueuedMutation>
    ),
    QueuedMutation,
    PrefetchHooks Function()> {
  $$QueuedMutationsTableTableManager(
      _$OfflineDatabase db, $QueuedMutationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<int> inspectionId = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              QueuedMutationsCompanion(
            id: id,
            operation: operation,
            inspectionId: inspectionId,
            payload: payload,
            filePath: filePath,
            attempts: attempts,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String operation,
            required int inspectionId,
            required String payload,
            Value<String?> filePath = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              QueuedMutationsCompanion.insert(
            id: id,
            operation: operation,
            inspectionId: inspectionId,
            payload: payload,
            filePath: filePath,
            attempts: attempts,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QueuedMutationsTableProcessedTableManager = ProcessedTableManager<
    _$OfflineDatabase,
    $QueuedMutationsTable,
    QueuedMutation,
    $$QueuedMutationsTableFilterComposer,
    $$QueuedMutationsTableOrderingComposer,
    $$QueuedMutationsTableAnnotationComposer,
    $$QueuedMutationsTableCreateCompanionBuilder,
    $$QueuedMutationsTableUpdateCompanionBuilder,
    (
      QueuedMutation,
      BaseReferences<_$OfflineDatabase, $QueuedMutationsTable, QueuedMutation>
    ),
    QueuedMutation,
    PrefetchHooks Function()>;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$QueuedMutationsTableTableManager get queuedMutations =>
      $$QueuedMutationsTableTableManager(_db, _db.queuedMutations);
}
