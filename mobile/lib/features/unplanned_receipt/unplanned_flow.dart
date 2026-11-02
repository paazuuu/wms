import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../payments/domain/payment.dart' show OrderStepState;
import '../payments/presentation/payments_screen.dart' show OrderFlowBar;

/// The steps of 予定外の入荷 (0182), as 発注 shows its own: the note
/// uploaded, what the AI read checked, the products registered, checked in
/// (in stock), and the invoice tied when it comes through 発注.
List<OrderStepState> unplannedStates({
  bool uploaded = true,
  bool readChecked = true,
  bool registered = true,
  bool checkedIn = false,
  bool someIn = false,
  bool invoiced = false,
}) =>
    [
      uploaded ? OrderStepState.done : OrderStepState.todo,
      readChecked ? OrderStepState.done : OrderStepState.todo,
      registered ? OrderStepState.done : OrderStepState.todo,
      checkedIn ? OrderStepState.done : (someIn ? OrderStepState.partial : OrderStepState.todo),
      invoiced ? OrderStepState.done : OrderStepState.todo,
    ];

/// 「今: …」 and the steps, done ones ticked.
class UnplannedFlow extends StatelessWidget {
  const UnplannedFlow({super.key, required this.states});

  final List<OrderStepState> states;

  static List<String> names(AppLocalizations l10n) =>
      [l10n.ordShortUpload, l10n.ordShortCheck, l10n.ordShortLibrary, l10n.ordShortStock, l10n.urStepInvoice];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final at = states.indexWhere((s) => s != OrderStepState.done);
    final labels = names(l10n);
    return Column(key: const ValueKey('ur-flow'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(at < 0 ? l10n.urFlowAllDone : l10n.urFlowNow(labels[at]),
          key: const ValueKey('ur-flow-now'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      OrderFlowBar(states: states, current: at, names: labels),
    ]);
  }
}
