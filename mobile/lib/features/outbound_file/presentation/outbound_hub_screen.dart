import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_proposal_screen.dart';
import '../../outbound/presentation/ship_destinations_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import 'outbound_calendar_tab.dart';
import 'outbound_file_screen.dart' show OutboundImportTab;

/// The tabs of 出庫, in order.
enum OutboundHubTab { file, proxy, calendar, cards, packing, proposal }

/// 出庫: everything that sends goods out, in one place —
///  * 出荷明細から出庫: the usual shipping list read and taken out of stock;
///  * 在庫外出荷: 直送・出荷代行 — kept as a record, no stock moved;
///  * 出庫カレンダー: both, by day, with their files;
///  * 出荷先カード: where goods go, with what an export needs;
///  * 出荷指示・梱包: a customer's order packed into cartons and shipped;
///  * 出庫の提案: a shipment worked out from the stock.
class OutboundHubScreen extends StatelessWidget {
  const OutboundHubScreen({super.key, this.tab = OutboundHubTab.file});

  final OutboundHubTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      OutboundHubTab.file: (l10n.obHubFile, Icons.upload_file_outlined),
      OutboundHubTab.proxy: (l10n.obHubProxy, Icons.edit_note_outlined),
      OutboundHubTab.calendar: (l10n.obHubCalendar, Icons.event_note_outlined),
      OutboundHubTab.cards: (l10n.obHubCards, Icons.contact_mail_outlined),
      OutboundHubTab.packing: (l10n.obHubPacking, Icons.inventory_2_outlined),
      OutboundHubTab.proposal: (l10n.obHubProposal, Icons.playlist_add_outlined),
    };
    return DefaultTabController(
      length: OutboundHubTab.values.length,
      initialIndex: tab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featOutboundHub),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final t in OutboundHubTab.values)
                Tab(key: ValueKey('ob-hub-${t.name}'), icon: Icon(labels[t]!.$2, size: 20), text: labels[t]!.$1),
            ],
          ),
        ),
        body: const TabBarView(children: [
          OutboundImportTab(),
          OutboundImportTab(proxy: true),
          OutboundCalendarTab(),
          ShipDestinationsScreen(embedded: true),
          ShipmentListScreen(embedded: true),
          OutboundProposalScreen(embedded: true),
        ]),
      ),
    );
  }
}
