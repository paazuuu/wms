import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/core/export/save_bytes.dart';

void main() {
  test('a download is told what kind of file it is', () {
    expect(mimeTypeFor('原本.PDF'), 'application/pdf');
    expect(mimeTypeFor('出荷明細.xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    expect(mimeTypeFor('在庫.csv'), startsWith('text/csv'));
    expect(mimeTypeFor('photo.jpeg'), 'image/jpeg');
    expect(mimeTypeFor('no-extension'), 'application/octet-stream');
  });
}
