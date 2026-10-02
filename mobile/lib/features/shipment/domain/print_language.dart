import 'package:equatable/equatable.dart';

/// Which languages documents and carton labels print in, and the words they
/// use (0118). The first language is the main line; the others are printed
/// under it (or after it, on a label), so goods going abroad carry words
/// their receiver can read.
class PrintLanguage extends Equatable {
  const PrintLanguage({
    this.languages = const ['ja', 'en'],
    this.terms = const {},
  });

  /// The languages a document may print in.
  static const supported = ['ja', 'en', 'zh'];

  /// `ja`, `en`, `zh` in print order. Never empty.
  final List<String> languages;

  /// key → {ja, en, zh} as set in the database; a key not there falls back
  /// to [defaults].
  final Map<String, Map<String, String>> terms;

  /// The words as 0118 seeds them, so a document prints the same before the
  /// settings have loaded, or without a connection.
  static const defaults = <String, Map<String, String>>{
    'shipment_no': {'ja': '出庫番号', 'en': 'Shipment No.', 'zh': '出库单号'},
    'ref_no': {'ja': '整理番号', 'en': 'Ref. No.', 'zh': '参考编号'},
    'customer': {'ja': '得意先', 'en': 'Customer', 'zh': '客户'},
    'customer_code': {'ja': 'お客様コード', 'en': 'Customer code', 'zh': '客户代码'},
    'date': {'ja': '日付', 'en': 'Date', 'zh': '日期'},
    'issued': {'ja': '発行日', 'en': 'Issued', 'zh': '开具日期'},
    'ship_from': {'ja': '出荷元', 'en': 'Ship from', 'zh': '发货地'},
    'destination': {'ja': '仕向国', 'en': 'Destination', 'zh': '目的国'},
    'cartons': {'ja': '箱数', 'en': 'Cartons', 'zh': '箱数'},
    'jan': {'ja': 'JANコード', 'en': 'JAN', 'zh': 'JAN码'},
    'maker': {'ja': 'メーカー', 'en': 'Maker', 'zh': '制造商'},
    'product': {'ja': '品名', 'en': 'Product', 'zh': '品名'},
    'item_code': {'ja': '品番', 'en': 'Item code', 'zh': '货号'},
    'spec': {'ja': '規格', 'en': 'Spec', 'zh': '规格'},
    'qty': {'ja': '数量', 'en': 'Qty', 'zh': '数量'},
    'unit_price': {'ja': '単価', 'en': 'Unit price', 'zh': '单价'},
    'amount': {'ja': '金額', 'en': 'Amount', 'zh': '金额'},
    'total': {'ja': '合計', 'en': 'Total', 'zh': '合计'},
    'barcode': {'ja': 'バーコード', 'en': 'Barcode', 'zh': '条码'},
    'shipping_list': {'ja': '出庫リスト', 'en': 'Shipping List', 'zh': '出库清单'},
    'packing_list': {'ja': '内容リスト', 'en': 'Packing List', 'zh': '装箱清单'},
    'packing_list_by_carton': {'ja': '段ボール別 内容リスト', 'en': 'Packing List by Carton', 'zh': '分箱装箱清单'},
    'carton': {'ja': '段ボール', 'en': 'Carton', 'zh': '纸箱'},
    'delivery_note': {'ja': '送り状', 'en': 'DELIVERY NOTE', 'zh': '送货单'},
    'delivery_note_lead': {
      'ja': '下記の通り納品いたします。',
      'en': 'Please find the goods listed below.',
      'zh': '兹按下列明细交货。',
    },
    'label_shipment': {'ja': '出庫', 'en': 'Shipment', 'zh': '出库'},
    'label_box': {'ja': '箱', 'en': 'Box', 'zh': '箱'},
    'label_qty': {'ja': '数量', 'en': 'Qty', 'zh': '数量'},
    'label_lot': {'ja': 'ロット', 'en': 'Lot', 'zh': '批次'},
    'label_items': {'ja': '品目', 'en': 'items', 'zh': '种'},
  };

  /// Every key, in the order the settings screen lists them.
  static List<String> get keys => defaults.keys.toList(growable: false);

  String get main => languages.first;

  /// [key] in [lang]: the database's word, else the seeded one, else the key.
  String word(String key, String lang) {
    final set = terms[key]?[lang]?.trim();
    if (set != null && set.isNotEmpty) return set;
    return defaults[key]?[lang] ?? defaults[key]?['en'] ?? key;
  }

  /// [key] in every print language, in order, without repeats (数量 is
  /// 数量 in Chinese too).
  List<String> words(String key) {
    final out = <String>[];
    for (final l in languages) {
      final w = word(key, l);
      if (!out.contains(w)) out.add(w);
    }
    return out;
  }

  PrintLanguage copyWith({List<String>? languages, Map<String, Map<String, String>>? terms}) =>
      PrintLanguage(languages: languages ?? this.languages, terms: terms ?? this.terms);

  factory PrintLanguage.fromJson(Map<String, dynamic> j) {
    final langs = [
      for (final l in (j['languages'] is List ? j['languages'] as List : const []))
        if (supported.contains('$l')) '$l',
    ];
    final terms = <String, Map<String, String>>{};
    final raw = j['terms'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          terms['$k'] = {
            for (final e in v.entries)
              if (e.value != null && '${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}',
          };
        }
      });
    }
    return PrintLanguage(languages: langs.isEmpty ? const ['ja', 'en'] : langs, terms: terms);
  }

  @override
  List<Object?> get props => [languages, terms];
}
