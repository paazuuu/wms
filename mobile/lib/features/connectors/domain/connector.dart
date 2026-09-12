import 'package:equatable/equatable.dart';

/// The most recent [ConnectorRun] for a connector, if it has ever run.
class ConnectorLastRun extends Equatable {
  const ConnectorLastRun({
    required this.status,
    required this.direction,
    this.startedAt,
    this.finishedAt,
  });

  final String status;
  final String direction;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  factory ConnectorLastRun.fromJson(Map<String, dynamic> json) => ConnectorLastRun(
        status: (json['status'] ?? '').toString(),
        direction: (json['direction'] ?? '').toString(),
        startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()),
        finishedAt: DateTime.tryParse((json['finished_at'] ?? '').toString()),
      );

  @override
  List<Object?> get props => [status, direction, startedAt, finishedAt];
}

/// One row of `list_connectors` (0028) — an external system registered in
/// the connector/adapter layer (spec §34). Registration alone doesn't mean a
/// working sync exists yet: `enabled` only reflects whether an admin has
/// switched it on, not whether an adapter is actually implemented.
class Connector extends Equatable {
  const Connector({
    required this.code,
    required this.name,
    required this.kind,
    required this.enabled,
    this.note,
    this.lastRun,
  });

  final String code;
  final String name;
  final String kind;
  final bool enabled;

  /// Free-text context from `config` (e.g. why it isn't reachable yet) —
  /// the only `config` field this skeleton surfaces; the rest is for a
  /// future adapter to read, not for display.
  final String? note;

  final ConnectorLastRun? lastRun;

  factory Connector.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>?;
    final lastRunJson = json['last_run'] as Map<String, dynamic>?;
    return Connector(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      enabled: json['enabled'] == true,
      note: config?['note'] as String?,
      lastRun: lastRunJson == null ? null : ConnectorLastRun.fromJson(lastRunJson),
    );
  }

  @override
  List<Object?> get props => [code, name, kind, enabled, note, lastRun];
}
