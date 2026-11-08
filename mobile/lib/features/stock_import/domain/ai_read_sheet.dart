import '../../../core/export/xlsx.dart' show XlsxSheetRows;
import '../../master_import/domain/master_import.dart' show MasterLine;

/// The headings of a sheet made from what the AI read.
const aiReadHeadings = ['JAN', '品番', '商品名', 'メーカー', '数量', '単位', '単価（税抜）', '単価（税込）', '金額', '注番'];

/// Whether a file is read as a sheet here (Excel, CSV); anything else — a
/// PDF, a photo — is read by the AI.
bool readsAsSheet(String fileName) {
  final n = fileName.toLowerCase();
  return n.endsWith('.xlsx') || n.endsWith('.xlsm') || n.endsWith('.csv') || n.endsWith('.tsv') || n.endsWith('.txt');
}

/// What the AI read from a PDF or a photo (import-plan, nothing booked), as
/// the rows of a sheet with plain headings — read from then on as an Excel
/// is: its columns, the products found, the rows ticked.
XlsxSheetRows aiReadAsSheet(List<MasterLine> lines, {String name = 'AI読み取り'}) {
  String v(Object? x) => x == null ? '' : '$x'.trim();
  return (
    name: name,
    rows: [
      aiReadHeadings,
      for (final l in lines)
        [
          l.janCode,
          l.productCode.isNotEmpty ? l.productCode : l.supplierCode,
          l.name,
          l.maker,
          l.quantity,
          l.unit.isNotEmpty ? l.unit : v(l.ledger['unit']),
          v(l.ledger['unit_price']),
          v(l.ledger['unit_price_tax']),
          v(l.ledger['amount']),
          v(l.ledger['order_number']),
        ],
    ],
  );
}
