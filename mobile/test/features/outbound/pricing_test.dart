import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/outbound/domain/pricing.dart';

const _p = PriceInputs(cost: 420, list: 1000, sell: 800, ship: 546);

void main() {
  test('a rate and a percentage work from the chosen column', () {
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.3), 546);
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.list, value: 0.7), 700);
    expect(applyPrice(_p, method: PriceMethod.percent, base: PriceColumn.sell, value: 20), 960);
    expect(applyPrice(_p, method: PriceMethod.percent, base: PriceColumn.sell, value: -10), 720);
    // The price after a rate can be the base for the next step.
    expect(applyPrice(_p, method: PriceMethod.percent, base: PriceColumn.ship, value: 10), 601);
  });

  test('rounding to a step, in a direction', () {
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.33, step: 10), 560);
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.33, step: 10, rounding: PriceRounding.down), 550);
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.33, step: 100, rounding: PriceRounding.up), 600);
    expect(applyPrice(_p, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.001, step: 0.01), 420.42);
    // A hair of floating point does not push an exact price up a step.
    expect(roundPrice(120.0000000001, 10, PriceRounding.up), 120);
    expect(roundPrice(119.9999999999, 10, PriceRounding.down), 120);
  });

  test('nothing to work from leaves the line alone; never below zero', () {
    const noCost = PriceInputs(list: 1000);
    expect(applyPrice(noCost, method: PriceMethod.rate, base: PriceColumn.cost, value: 1.3), isNull);
    expect(applyPrice(noCost, method: PriceMethod.formula, base: PriceColumn.list, formula: '原価*1.3'), isNull);
    expect(applyPrice(noCost, method: PriceMethod.formula, base: PriceColumn.list, formula: '基準*0.6'), 600);
    expect(applyPrice(_p, method: PriceMethod.percent, base: PriceColumn.cost, value: -150), 0);
  });

  test('formulas read like Excel', () {
    double? f(String s) => evaluatePriceFormula(s, _p, base: 1000);
    expect(f('ROUNDUP(原価*1.3, -1)'), 550);
    expect(f('=ROUNDDOWN(原価*1.33, -1)'), 550);
    expect(f('ROUND(1234.5, -2)'), 1200);
    expect(f('ROUND(2.345, 2)'), closeTo(2.35, 1e-9));
    expect(f('MAX(原価*1.2, 定価*0.6)'), 600);
    expect(f('MIN(cost*2, list)'), 840);
    expect(f('基準*(1+15%)'), closeTo(1150, 1e-9));
    expect(f('x × 0.5 ÷ 2'), 250);
    expect(f('（販売価格－原価）＊２'), 760);
    expect(f('CEILING(原価*1.1, 50)'), 500);
    expect(f('FLOOR(原価*1.1, 50)'), 450);
    expect(f('ABS(-3) + -2'), 1);
    expect(f('出荷単価 + 4'), 550);
  });

  test('a formula that does not read says why', () {
    expect(priceFormulaError('原価*1.3'), isNull);
    expect(priceFormulaError('原価*'), isNotNull);
    expect(priceFormulaError('ROUNDUP(原価*1.3, -1'), isNotNull);
    expect(priceFormulaError('仕入値*2'), contains('仕入値'));
    expect(priceFormulaError('FOO(1)'), contains('FOO'));
    expect(priceFormulaError('1/0'), isNotNull);
    expect(() => evaluatePriceFormula('1 2', _p), throwsFormatException);
  });

  test('columns go by their wire names', () {
    expect(PriceColumn.fromWire('cost'), PriceColumn.cost);
    expect(PriceColumn.fromWire('ship'), PriceColumn.ship);
    expect(PriceColumn.fromWire('nope'), isNull);
  });
}
