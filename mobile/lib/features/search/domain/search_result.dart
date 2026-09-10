import 'package:equatable/equatable.dart';

int? _asIntOrNull(dynamic v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

/// What kind of record a [SearchResult] points at — decides which detail
/// screen a tap opens.
enum SearchResultKind {
  stock('stock'),
  delivery('delivery'),
  shipment('shipment'),
  pickList('pick_list'),
  transfer('transfer');

  const SearchResultKind(this.wire);
  final String wire;

  static SearchResultKind? parse(String? v) => switch (v) {
        'stock' => SearchResultKind.stock,
        'delivery' => SearchResultKind.delivery,
        'shipment' => SearchResultKind.shipment,
        'pick_list' => SearchResultKind.pickList,
        'transfer' => SearchResultKind.transfer,
        _ => null,
      };
}

/// One row of `global_search` (spec §23). [id] is the record's id as a
/// string — a JAN code for [SearchResultKind.stock], an integer id (as text)
/// for everything else — kept opaque here since the client only ever parses
/// it back to the type the target screen expects.
class SearchResult extends Equatable {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    this.janCode,
    this.subtitle,
    this.warehouseId,
  });

  final SearchResultKind kind;
  final String id;
  final String title;
  final String? janCode;
  final String? subtitle;
  final int? warehouseId;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        kind: SearchResultKind.parse(json['kind'] as String?) ?? SearchResultKind.stock,
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        janCode: json['jan_code'] as String?,
        subtitle: json['subtitle'] as String?,
        warehouseId: _asIntOrNull(json['warehouse_id']),
      );

  @override
  List<Object?> get props => [kind, id];
}
