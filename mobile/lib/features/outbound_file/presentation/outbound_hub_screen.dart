import 'package:flutter/material.dart';

import '../../../core/ui/help_tab.dart';
import '../../../l10n/app_localizations.dart';
import '../../outbound/presentation/outbound_proposal_screen.dart';
import '../../outbound/presentation/ship_destinations_screen.dart';
import '../../packing/presentation/packing_lists_screen.dart';
import '../../packing/presentation/packing_settings_screen.dart';
import '../../shipment/presentation/shipment_list_screen.dart';
import 'outbound_file_screen.dart' show OutboundImportTab;

/// The tabs of 出庫, in order.
enum OutboundHubTab { file, proxy, cards, packing, packingLists, boxes, proposal }

/// 出荷手配: the sales side of sending goods out, in one place —
///  * 出荷明細の取込: the usual shipping list read and taken out of stock;
///  * 在庫外出荷: 直送・出荷代行 — kept as a record, no stock moved;
///  * 出荷先カード: where goods go, with what an export needs;
///  * 出荷指示・梱包: a customer's order packed into cartons and shipped;
///  * パッキングリスト: those uploaded (kept as they came and improved) and
///    those made from a list's boxes (0192);
///  * 箱と入数: our cartons and each product's own case;
///  * 出荷の提案: a shipment worked out from the stock.
/// What left the warehouse, by day, is the 出庫カレンダー (現場作業).
class OutboundHubScreen extends StatelessWidget {
  const OutboundHubScreen({super.key, this.tab = OutboundHubTab.file});

  final OutboundHubTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final help = {
      OutboundHubTab.file: l10n.obHelpFile,
      OutboundHubTab.proxy: l10n.obHelpProxy,
      OutboundHubTab.cards: l10n.obHelpCards,
      OutboundHubTab.packing: l10n.obHelpPacking,
      OutboundHubTab.packingLists: l10n.obHelpPackingLists,
      OutboundHubTab.boxes: l10n.obHelpBoxes,
      OutboundHubTab.proposal: l10n.obHelpProposal,
    };
    final labels = {
      OutboundHubTab.file: (l10n.obHubFile, Icons.upload_file_outlined),
      OutboundHubTab.proxy: (l10n.obHubProxy, Icons.edit_note_outlined),
      OutboundHubTab.cards: (l10n.obHubCards, Icons.contact_mail_outlined),
      OutboundHubTab.packing: (l10n.obHubPacking, Icons.inventory_2_outlined),
      OutboundHubTab.packingLists: (l10n.obHubPackingLists, Icons.table_view_outlined),
      OutboundHubTab.boxes: (l10n.obHubBoxes, Icons.all_inbox_outlined),
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
                HelpTab(
                  help: help[t]!,
                  child: Tab(key: ValueKey('ob-hub-${t.name}'), icon: Icon(labels[t]!.$2, size: 20), text: labels[t]!.$1),
                ),
            ],
          ),
        ),
        body: const TabBarView(children: [
          OutboundImportTab(),
          OutboundImportTab(proxy: true),
          ShipDestinationsScreen(embedded: true),
          ShipmentListScreen(embedded: true),
          PackingListsScreen(embedded: true),
          PackingSettingsScreen(embedded: true),
          OutboundProposalScreen(embedded: true),
        ]),
      ),
    );
  }
}
