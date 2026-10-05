import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/inbound.dart';

/// A calendar day as the floor reads it.
String ibDay(AppLocalizations l10n, DateTime d) => DateFormat('y/MM/dd').format(d);

/// A planned day, or 未定 when there is none (§16: never filled with today).
String ibDayOrUndated(AppLocalizations l10n, DateTime? d) => d == null ? l10n.ibUndated : ibDay(l10n, d);

String ibDateTime(DateTime d) => DateFormat('y/MM/dd HH:mm').format(d);

String receiptStateLabel(AppLocalizations l10n, ReceiptState s) => switch (s) {
      ReceiptState.draft => l10n.ibStateDraft,
      ReceiptState.expected => l10n.ibStateExpected,
      ReceiptState.partiallyReceived => l10n.ibStatePartial,
      ReceiptState.received => l10n.ibStateReceived,
      ReceiptState.overReceived => l10n.ibStateOver,
      ReceiptState.closed => l10n.ibStateClosed,
      ReceiptState.cancelled => l10n.ibStateCancelled,
      ReceiptState.onHold => l10n.ibStateOnHold,
    };

StatusTone receiptStateTone(ReceiptState s) => switch (s) {
      ReceiptState.expected || ReceiptState.draft => StatusTone.neutral,
      ReceiptState.partiallyReceived => StatusTone.info,
      ReceiptState.received => StatusTone.success,
      ReceiptState.overReceived || ReceiptState.onHold => StatusTone.warning,
      ReceiptState.closed || ReceiptState.cancelled => StatusTone.danger,
    };

IconData receiptStateIcon(ReceiptState s) => switch (s) {
      ReceiptState.expected || ReceiptState.draft => Icons.schedule,
      ReceiptState.partiallyReceived => Icons.timelapse,
      ReceiptState.received => Icons.check_circle_outline,
      ReceiptState.overReceived => Icons.add_circle_outline,
      ReceiptState.closed => Icons.do_disturb_on_outlined,
      ReceiptState.cancelled => Icons.cancel_outlined,
      ReceiptState.onHold => Icons.pause_circle_outline,
    };

/// The state of an expected receipt as a pill.
class ReceiptStatePill extends StatelessWidget {
  const ReceiptStatePill(this.state, {super.key, this.dense = true});

  final ReceiptState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StatusPill(
      tone: receiptStateTone(state),
      label: receiptStateLabel(l10n, state),
      icon: receiptStateIcon(state),
      dense: dense,
    );
  }
}

String documentTypeLabel(AppLocalizations l10n, DocumentType t) => switch (t) {
      DocumentType.purchaseConfirmation => l10n.ibDocPurchaseConfirmation,
      DocumentType.deliverySchedule => l10n.ibDocDeliverySchedule,
      DocumentType.deliveryNote => l10n.ibDocDeliveryNote,
      DocumentType.invoice => l10n.ibDocInvoice,
      DocumentType.other => l10n.ibDocOther,
    };

/// 予定 n・入荷済 n・残 n.
String ibTotals(AppLocalizations l10n, {required int planned, required int received, required int remaining}) =>
    l10n.ibPlanTotals(planned, received, remaining);

/// One history entry in words.
String inboundEventLabel(AppLocalizations l10n, InboundEvent e) {
  String day(Object? v) {
    final d = v == null ? null : DateTime.tryParse('$v');
    return ibDayOrUndated(l10n, d);
  }

  String state(Object? v) => receiptStateLabel(l10n, ReceiptState.fromWire(v?.toString()));
  final d = e.details;
  return switch (e.event) {
    'inbound.expected_created' => l10n.ibEvCreated(day(d['expected_arrival_date'])),
    'inbound.expected_date_changed' => d['field'] == 'scheduled_inspection_date'
        ? l10n.ibEvInspectionDateChanged(day(d['from']), day(d['to']))
        : l10n.ibEvExpectedChanged(day(d['from']), day(d['to'])),
    'inbound.state_changed' => l10n.ibEvStateChanged(state(d['from']), state(d['to'])),
    'receiving.confirmed' => l10n.ibEvReceived,
    'receiving.arrival_date_set' => l10n.ibEvArrivalSet(day(d['from']), day(d['to'])),
    'receiving.over_receipt' => l10n.ibEvOverReceipt(switch (d['choice']) {
        'accept' => l10n.ibOverAccept,
        'cap' => l10n.ibOverCap,
        'hold' => l10n.ibOverHold,
        _ => '${d['choice'] ?? ''}',
      }),
    'receiving.cancelled' => l10n.ibEvCancelled,
    'receiving.item_recorded' => l10n.ibEvItemRecorded('${d['jan_code'] ?? ''}', '${d['quantity'] ?? ''}'),
    'inspection.started' => l10n.ibEvInspectionOpened,
    'inspection.scheduled' => l10n.ibEvInspectionDateChanged(day(d['from']), day(d['to'])),
    'inspection.confirmed' => l10n.ibEvInspectionConfirmed,
    _ => e.event,
  };
}

/// Asks what to do with more than the plan still expects (§8). Accepting
/// everything needs `receiving.over_accept`; without it the choice is shown
/// but cannot be taken.
Future<OverReceiptChoice?> showOverReceiptDialog(
  BuildContext context,
  List<OverReceiptLine> lines, {
  required bool canAcceptAll,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  return showDialog<OverReceiptChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('over-receipt-dialog'),
      icon: Icon(Icons.warning_amber, color: theme.colorScheme.tertiary),
      title: Text(l10n.ibOverTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.productName?.isNotEmpty == true ? l.productName! : l.janCode,
                        style: theme.textTheme.titleSmall),
                    Text(l10n.ibOverLine(l.planned, l.received, l.arriving, l.over),
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: AppFonts.mono)),
                  ],
                ),
              ),
            if (!canAcceptAll)
              Text(l10n.ibOverAcceptNoPermission,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: AppSpacing.xs,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.actionCancel)),
        OutlinedButton(
          key: const ValueKey('over-hold'),
          onPressed: () => Navigator.pop(ctx, OverReceiptChoice.hold),
          child: Text(l10n.ibOverHold),
        ),
        OutlinedButton(
          key: const ValueKey('over-cap'),
          onPressed: () => Navigator.pop(ctx, OverReceiptChoice.cap),
          child: Text(l10n.ibOverCap),
        ),
        FilledButton(
          key: const ValueKey('over-accept'),
          onPressed: canAcceptAll ? () => Navigator.pop(ctx, OverReceiptChoice.accept) : null,
          child: Text(l10n.ibOverAccept),
        ),
      ],
    ),
  );
}

/// Picks a planned day, with 未定 as a real answer. Returns null when
/// dismissed, `(date: null)` for 未定.
Future<({DateTime? date})?> pickPlannedDay(BuildContext context, DateTime? current, {DateTime? today}) async {
  final l10n = AppLocalizations.of(context);
  final base = DateUtils.dateOnly(today ?? DateTime.now());
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('planned-day-pick'),
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.ibSetDate),
            onTap: () => Navigator.pop(ctx, 'pick'),
          ),
          ListTile(
            key: const ValueKey('planned-day-clear'),
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(l10n.ibClearDate),
            onTap: () => Navigator.pop(ctx, 'clear'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'clear') return (date: null);
  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? base,
    firstDate: base.subtract(const Duration(days: 730)),
    lastDate: base.add(const Duration(days: 730)),
  );
  return picked == null ? null : (date: picked);
}
