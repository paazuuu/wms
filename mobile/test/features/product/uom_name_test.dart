import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/product/domain/product.dart';
import 'package:wms_mobile/features/product/presentation/product_labels.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';

Product _p(int id, String? code) => Product(
      id: id,
      janCode: '490999900001$id',
      name: 'p$id',
      baseUom: code == null ? null : Uom(code: code, name: code),
    );

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('本 is named in each language; an unknown code keeps its stored name', () {
    expect(uomName(ja, 'HON', '本'), '本');
    expect(uomName(zh, 'HON', '本'), '支');
    expect(uomName(ja, 'PCS', '個'), '個');
    expect(uomName(ja, 'XYZ', 'ロット'), 'ロット');
  });

  test('a total takes the unit every product shares, else 個', () {
    expect(sharedUnitName(ja, [_p(1, 'HON'), _p(2, 'hon')]), '本');
    expect(sharedUnitName(ja, [_p(1, 'HON'), _p(2, 'PCS')]), '個');
    expect(sharedUnitName(ja, [_p(1, 'HON'), _p(2, null)]), '本');
    expect(sharedUnitName(ja, const []), '個');
  });
}
