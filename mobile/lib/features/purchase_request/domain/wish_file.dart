import 'package:equatable/equatable.dart';

import '../../outbound_file/domain/outbound_sheet.dart';
import 'purchase_request.dart';

/// How a row of a customer's wish list (入荷希望リストのファイル) was found in
/// the library.
enum WishMatchedBy { jan, code, picked, none }

/// What a row read from the file is.
enum WishRowStatus {
  /// One of our products.
  found,

  /// Not in the library: taken in as a product typed by hand (a wish may be
  /// for something we do not carry yet).
  notInLibrary,

  /// Its 品番 fits several products: one to choose.
  several,

  /// No quantity: nothing wished.
  noQuantity,
}

/// One row of the file, and the product of ours it is.
class WishFileLine extends Equatable {
  const WishFileLine({required this.row, this.key, this.by = WishMatchedBy.none, this.several = false});

  final OutboundRow row;

  /// The library row's key (p<product id>), when found.
  final String? key;
  final WishMatchedBy by;

  /// Its 品番 fits more than one product.
  final bool several;

  bool get found => key != null;
  int get quantity => row.quantity ?? 0;

  WishRowStatus get status => quantity <= 0
      ? WishRowStatus.noQuantity
      : found
          ? WishRowStatus.found
          : several
              ? WishRowStatus.several
              : WishRowStatus.notInLibrary;

  @override
  List<Object?> get props => [row, key, by, several];
}

/// A code as compared: half-width, lower case, without spaces and hyphens.
String wishCodeKey(String? s) {
  if (s == null) return '';
  final b = StringBuffer();
  for (final c in s.trim().runes) {
    b.writeCharCode(c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c);
  }
  return b.toString().toLowerCase().replaceAll(RegExp(r'[\s　\-_‐－]'), '');
}

/// Each row's product of ours: by JAN, else by 品番 (the product's SKU, or
/// what a supplier calls it), narrowed by maker when it fits several.
/// [picked] (row number → key) are chosen by hand and win.
List<WishFileLine> matchWishRows(List<OutboundRow> rows, Iterable<RequestRow> library,
    {Map<int, String> picked = const {}}) {
  final byJan = <String, String>{};
  final byCode = <String, List<RequestRow>>{};
  for (final r in library) {
    if (r.productId == null) continue;
    final jan = r.janCode?.trim() ?? '';
    if (jan.isNotEmpty) byJan.putIfAbsent(jan, () => r.key);
    for (final c in {wishCodeKey(r.sku), wishCodeKey(r.supplierCode)}) {
      if (c.isNotEmpty) (byCode[c] ??= []).add(r);
    }
  }
  return [
    for (final row in rows)
      if (picked[row.rowNo] case final k?)
        WishFileLine(row: row, key: k, by: WishMatchedBy.picked)
      else if (row.jan.isNotEmpty && byJan[row.jan] != null)
        WishFileLine(row: row, key: byJan[row.jan], by: WishMatchedBy.jan)
      else
        _byCode(row, byCode),
  ];
}

WishFileLine _byCode(OutboundRow row, Map<String, List<RequestRow>> byCode) {
  var hits = [...{for (final r in byCode[wishCodeKey(row.code)] ?? const <RequestRow>[]) r.key: r}.values];
  final maker = wishCodeKey(row.maker);
  if (hits.length > 1 && maker.isNotEmpty) {
    final same = [for (final r in hits) if (wishCodeKey(r.maker).contains(maker) || maker.contains(wishCodeKey(r.maker))) r];
    if (same.isNotEmpty) hits = same;
  }
  if (hits.length == 1) return WishFileLine(row: row, key: hits.single.key, by: WishMatchedBy.code);
  return WishFileLine(row: row, several: hits.length > 1);
}

/// What the rows ticked put in the list: each product's quantity (all its
/// rows added up; 0 when every row of it is unticked), and the rows not in
/// the library as products typed by hand.
class WishFileApplied extends Equatable {
  const WishFileApplied({this.quantities = const {}, this.manual = const []});

  final Map<String, int> quantities;
  final List<RequestRow> manual;

  int get rows => quantities.values.where((q) => q > 0).length + manual.length;
  int get units => quantities.values.fold(0, (a, q) => a + q) + manual.fold(0, (a, r) => a + r.quantity);

  @override
  List<Object?> get props => [quantities, manual];
}

WishFileApplied applyWishFile(List<WishFileLine> lines, Set<int> excluded) {
  final q = <String, int>{};
  final manual = <RequestRow>[];
  for (final l in lines) {
    final on = !excluded.contains(l.row.rowNo) && l.quantity > 0;
    if (l.key case final k?) {
      q[k] = (q[k] ?? 0) + (on ? l.quantity : 0);
    } else if (on) {
      final r = l.row;
      manual.add(RequestRow(
        key: 'f${r.rowNo}',
        name: r.name ?? r.code ?? (r.jan.isEmpty ? r.janRaw : r.jan),
        janCode: r.jan.isEmpty ? null : r.jan,
        maker: r.maker,
        sku: r.code,
        quantity: l.quantity,
        inList: true,
        manual: true,
      ));
    }
  }
  return WishFileApplied(quantities: q, manual: manual);
}

/// The columns a wish list is read by (the rest of a shipping list's are
/// not asked for).
const wishColumns = [
  OutboundColumn.jan,
  OutboundColumn.code,
  OutboundColumn.maker,
  OutboundColumn.name,
  OutboundColumn.quantity,
];
