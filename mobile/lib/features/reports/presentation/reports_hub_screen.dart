import 'package:flutter/material.dart';

import '../../../core/ui/help_tab.dart';
import '../../../l10n/app_localizations.dart';
import 'report_builder_screen.dart';
import 'work_log_screen.dart';

/// The tabs of レポート, in order.
enum ReportsHubTab { activity, history }

/// レポート: the records kept as A4 pages, Excel and PDF —
///  * 入出荷実績 (first, opened by default): a month's receipts by supplier,
///    shipments by destination and the warehouse memos, for monthly
///    reports and memoranda;
///  * 入出庫履歴: each product's movements (when, where, how many), with the
///    audit log and other records to pick too, several at once.
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key, this.tab = ReportsHubTab.activity});

  final ReportsHubTab tab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: ReportsHubTab.values.length,
      initialIndex: tab.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.featReports),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              HelpTab(
                help: l10n.rhHelpActivity,
                child: Tab(
                    key: const ValueKey('rh-activity'),
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    text: l10n.rhTabActivity),
              ),
              HelpTab(
                help: l10n.rhHelpHistory,
                child: Tab(
                    key: const ValueKey('rh-history'), icon: const Icon(Icons.swap_vert, size: 20), text: l10n.rhTabHistory),
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [
          WorkLogScreen(embedded: true),
          ReportBuilderScreen(embedded: true),
        ]),
      ),
    );
  }
}
