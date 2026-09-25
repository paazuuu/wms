import 'package:equatable/equatable.dart';

int _asInt(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// One JAN code with no product behind it, as `unlinked_jan_codes` returns it
/// (0058) — the worklist for registering master data. [sources] breaks down
/// where it was seen (`stock_levels`, `delivery_plan_lines`, …) and how many
/// rows carry it, so the worklist reads as "register this one first" rather
/// than a flat, unprioritized list.
class UnlinkedJan extends Equatable {
  const UnlinkedJan({
    required this.janCode,
    required this.totalRows,
    this.seenAs,
    this.sources = const {},
  });

  final String janCode;

  /// The best-guess name recorded alongside this code somewhere, if any.
  final String? seenAs;
  final int totalRows;
  final Map<String, int> sources;

  factory UnlinkedJan.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    return UnlinkedJan(
      janCode: (json['jan_code'] ?? '').toString(),
      seenAs: (json['seen_as'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['seen_as'] as String).trim(),
      totalRows: _asInt(json['total_rows']),
      sources: rawSources is Map
          ? rawSources.map((k, v) => MapEntry('$k', _asInt(v)))
          : const {},
    );
  }

  @override
  List<Object?> get props => [janCode, totalRows, sources];
}

/// How complete `product_id` is next to `jan_code`, across every table that
/// carries both (`product_id_coverage`, 0058) — the measure of how far the
/// switch-over from code to id is from being safe.
class ProductIdCoverage extends Equatable {
  const ProductIdCoverage({
    this.rows = 0,
    this.linked = 0,
    this.unlinked = 0,
    this.readyToSwitch = false,
  });

  final int rows;
  final int linked;
  final int unlinked;

  /// True once every row with a `jan_code` also has a `product_id` — the
  /// server's own criterion, not a client-side approximation of it.
  final bool readyToSwitch;

  factory ProductIdCoverage.fromJson(Map<String, dynamic> json) =>
      ProductIdCoverage(
        rows: _asInt(json['rows']),
        linked: _asInt(json['linked']),
        unlinked: _asInt(json['unlinked']),
        readyToSwitch: json['ready_to_switch'] == true,
      );

  @override
  List<Object?> get props => [rows, linked, unlinked, readyToSwitch];
}
