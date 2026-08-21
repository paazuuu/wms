import 'package:flutter/material.dart';
import 'package:wms_mobile/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/inspection/application/inspection_providers.dart';
import 'package:wms_mobile/features/inspection/domain/inspection.dart';
import 'package:wms_mobile/features/inspection/presentation/inspection_list_screen.dart';

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InspectionListScreen(),
      ),
    );

void main() {
  testWidgets('renders a tile per inspection', (tester) async {
    await tester.pumpWidget(_wrap([
      inspectionListProvider.overrideWith((ref) async => const [
            Inspection(
                id: 1,
                code: 'INS-000001',
                type: 'receiving',
                status: InspectionStatus.pending,
                itemsCount: 3),
            Inspection(
                id: 2,
                code: 'INS-000002',
                type: 'shipping',
                status: InspectionStatus.passed,
                itemsCount: 0),
          ]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('INS-000001'), findsOneWidget);
    expect(find.text('INS-000002'), findsOneWidget);
    expect(find.textContaining('3 items'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no inspections', (tester) async {
    await tester.pumpWidget(_wrap([
      inspectionListProvider.overrideWith((ref) async => const <Inspection>[]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('No inspections yet.'), findsOneWidget);
  });
}
