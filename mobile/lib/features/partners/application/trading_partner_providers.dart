import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../delivery/application/delivery_providers.dart';
import '../data/trading_partner_repository.dart';
import '../domain/trading_partner.dart';

final tradingPartnerRepositoryProvider = Provider<TradingPartnerRepository>((ref) {
  return TradingPartnerRepositoryImpl(ref.watch(restDioProvider));
});

/// Free-text filter over name/code; empty shows every partner in scope.
final partnerSearchProvider = StateProvider<String>((_) => '');

/// Kind tab: null shows both suppliers and customers.
final partnerKindFilterProvider = StateProvider<PartnerKind?>((_) => null);

/// Whether the list also shows deactivated partners.
final showInactivePartnersProvider = StateProvider<bool>((_) => false);

/// The supplier/customer directory filtered by search/kind/active, name-sorted.
final tradingPartnerListProvider =
    FutureProvider.autoDispose<List<TradingPartner>>((ref) async {
  final search = ref.watch(partnerSearchProvider);
  final kind = ref.watch(partnerKindFilterProvider);
  final showInactive = ref.watch(showInactivePartnersProvider);
  final result = await ref.watch(tradingPartnerRepositoryProvider).list(
        kind: kind,
        search: search.isEmpty ? null : search,
        status: showInactive ? null : 'active',
      );
  return result.when(
    success: (data) => data,
    failure: (f) => throw Exception(f.message),
  );
});

/// A company's codes for its own suppliers (0112).
final partnerVendorCodesProvider = FutureProvider.autoDispose.family<List<PartnerVendorCode>, int>((ref, partnerId) async =>
    (await ref.watch(tradingPartnerRepositoryProvider).vendorCodes(partnerId))
        .when(success: (d) => d, failure: (f) => throw Exception(f.message)));
