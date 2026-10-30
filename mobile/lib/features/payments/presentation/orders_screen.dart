import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../purchasing/presentation/purchase_order_list_screen.dart';
import 'payments_screen.dart';

/// 会計 → 発注 (0172): every order as it goes — the file uploaded, the
/// reading checked by a person, the products in 商品ライブラリー, 商品名 and
/// 重量 by the AI, inspected and in stock, the 振込先 and amount, paid, and the
/// proof of the transfer — on one line per order; with the payments there,
/// and the purchase orders (発注書) beside them.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.today});

  /// For tests: the month the month view starts on.
  final DateTime? today;

  static const _books = ['inventory.adjust', 'report.view', 'user.manage'];
  static const _po = ['purchase_order.view', 'purchase_order.manage', 'purchase_order.approve'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).user;
    bool any(List<String> ps) => ps.any((x) => user?.hasPermission(x) ?? false);
    final tabs = <(Key, String, Widget)>[
      if (any(_books)) (const ValueKey('ord-tab-progress'), l10n.ordTabProgress, PaymentsScreen(embedded: true, today: today)),
      if (any(_po)) (const ValueKey('ord-tab-po'), l10n.ordTabPurchaseOrders, const PurchaseOrderListScreen(embedded: true)),
    ];
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.featPurchaseOrders)),
        body: Center(child: Text(l10n.txNoPermission, key: const ValueKey('ord-no-permission'))),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featPurchaseOrders),
          bottom: TabBar(tabs: [for (final (k, t, _) in tabs) Tab(key: k, text: t)]),
        ),
        body: TabBarView(children: [for (final (_, _, w) in tabs) w]),
      ),
    );
  }
}
