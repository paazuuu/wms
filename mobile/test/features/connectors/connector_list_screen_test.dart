import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/connectors/application/connector_providers.dart';
import 'package:wms_mobile/features/connectors/domain/connector.dart';
import 'package:wms_mobile/features/connectors/presentation/connector_list_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('lists registered connectors with their enabled state',
      (tester) async {
    final repo = FakeConnectorRepository([
      const Connector(
        code: 'inventoros',
        name: 'InventorOS',
        kind: 'wms',
        enabled: false,
        note: 'Legacy REST backend; not currently reachable.',
      ),
    ]);

    await pumpApp(
      tester,
      const ConnectorListScreen(),
      overrides: [connectorRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('InventorOS'), findsOneWidget);
    expect(find.text('無効'), findsOneWidget);
    expect(find.text('実行履歴なし'), findsOneWidget);
    expect(
        find.textContaining('Legacy REST backend'), findsOneWidget);
  });

  testWidgets('an empty registry explains itself rather than showing nothing',
      (tester) async {
    final repo = FakeConnectorRepository(const []);

    await pumpApp(
      tester,
      const ConnectorListScreen(),
      overrides: [connectorRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('登録されたコネクタがありません'), findsOneWidget);
  });

  testWidgets('toggling the switch enables the connector', (tester) async {
    final repo = FakeConnectorRepository([
      const Connector(
        code: 'inventoros',
        name: 'InventorOS',
        kind: 'wms',
        enabled: false,
      ),
    ]);

    await pumpApp(
      tester,
      const ConnectorListScreen(),
      overrides: [connectorRepositoryProvider.overrideWithValue(repo)],
    );

    expect(find.text('無効'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('有効'), findsOneWidget);
  });
}
