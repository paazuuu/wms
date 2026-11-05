import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error_mapper.dart';
import '../../../core/api/api_result.dart';
import '../../delivery/application/delivery_providers.dart';

/// The currency a shipping list's prices are written in (0197). Usually 円;
/// whoever made the list may have put some in 人民元.
enum PriceCurrency {
  jpy('JPY', '円'),
  cny('CNY', '元'),
  usd('USD', r'$');

  const PriceCurrency(this.wire, this.mark);
  final String wire;

  /// Shown after a price: 円, 元, $.
  final String mark;

  static PriceCurrency fromWire(String? w) => values.firstWhere((c) => c.wire == w, orElse: () => jpy);
}

/// How a row's currency was decided: from the sheet's headings, by the AI,
/// by our own rule (no AI to ask), or by hand.
enum CurrencySource {
  file('file'),
  ai('ai'),
  guess('guess'),
  manual('manual');

  const CurrencySource(this.wire);
  final String wire;
}

typedef RowCurrency = ({PriceCurrency currency, CurrencySource source, bool confident});

/// The currency the headings name, if they do: 元 / RMB / CNY / 人民币 → CNY;
/// 円 / JPY → JPY; USD → USD.
PriceCurrency? currencyInHeadings(Iterable<String> headings) {
  final all = headings.join(' ');
  if (RegExp(r'人民币|人民幣|人民元|RMB|CNY|\(元\)|（元）|元\)|元）', caseSensitive: false).hasMatch(all)) return PriceCurrency.cny;
  if (RegExp(r'USD|US\$|ドル|美元', caseSensitive: false).hasMatch(all)) return PriceCurrency.usd;
  if (RegExp(r'円|JPY|日元|日币', caseSensitive: false).hasMatch(all)) return PriceCurrency.jpy;
  return null;
}

/// A sales price far under what it was bought for (in 円) is likely 人民元:
/// under a third, where 1 元 is some 20 円.
bool priceLooksLikeCny(double? price, double? purchaseJpy) =>
    price != null && purchaseJpy != null && price > 0 && purchaseJpy > 0 && price < purchaseJpy * 0.35;

/// One row for the AI: its product, its price, what we bought it for.
typedef CurrencyAsk = ({int i, String? name, String? maker, String? code, double? priceEx, double? priceTax, double? purchaseJpy});

/// Asks the AI (price-currency) in which currency each price is written.
abstract class PriceCurrencyRepository {
  /// Row number → (currency, confident); rows it could not judge are left out.
  Future<ApiResult<Map<int, (PriceCurrency, bool)>>> judge(List<CurrencyAsk> rows, {String? hint});
}

class PriceCurrencyRepositoryImpl implements PriceCurrencyRepository {
  PriceCurrencyRepositoryImpl(this._functions);

  final Dio _functions;

  @override
  Future<ApiResult<Map<int, (PriceCurrency, bool)>>> judge(List<CurrencyAsk> rows, {String? hint}) async {
    final out = <int, (PriceCurrency, bool)>{};
    try {
      for (var at = 0; at < rows.length; at += 150) {
        final part = rows.sublist(at, at + 150 > rows.length ? rows.length : at + 150);
        final r = await _functions.post('/price-currency', data: {
          'hint': hint,
          'rows': [
            for (final x in part)
              {
                'i': x.i,
                'name': x.name,
                'maker': x.maker,
                'code': x.code,
                'price_ex': x.priceEx,
                'price_tax': x.priceTax,
                'purchase_jpy': x.purchaseJpy,
              },
          ],
        });
        final d = r.data is Map ? (r.data as Map)['data'] : null;
        for (final e in ((d is Map ? d['rows'] : null) as List? ?? const []).whereType<Map>()) {
          final i = (e['i'] as num?)?.toInt();
          if (i != null) out[i] = (PriceCurrency.fromWire('${e['currency']}'), e['confident'] == true);
        }
      }
      return ApiSuccess(out);
    } on DioException catch (e) {
      return mapDioError<Map<int, (PriceCurrency, bool)>>(e);
    }
  }
}

final priceCurrencyRepositoryProvider =
    Provider<PriceCurrencyRepository>((ref) => PriceCurrencyRepositoryImpl(ref.watch(deliveryDioProvider)));
