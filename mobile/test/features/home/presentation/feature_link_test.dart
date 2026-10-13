import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/auth/application/auth_controller.dart';
import 'package:wms_mobile/features/auth/domain/auth_user.dart';
import 'package:wms_mobile/features/home/presentation/feature_link.dart';
import 'package:wms_mobile/features/wave/presentation/pick_wave_list_screen.dart';

import '../../../support/harness.dart';

Override _signedIn(List<String> permissions) => authControllerProvider.overrideWith((ref) =>
    fakeAuthControllerFor(AuthUser(id: 'u1', email: 'a@b.test', name: '倉庫', permissions: permissions)));

/// A screen as the app shows it: the sign-in already known.
class _Host extends ConsumerWidget {
  const _Host(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authControllerProvider);
    return Scaffold(appBar: AppBar(actions: [child]));
  }
}

void main() {
  testWidgets('a screen left out of the menu opens from the one it belongs to', (tester) async {
    await pumpApp(tester, const _Host(FeatureLinkButton('wave')), overrides: [_signedIn(['pick.confirm'])]);

    await tester.tap(find.byKey(const ValueKey('link-wave')));
    await tester.pumpAndSettle();

    expect(find.byType(PickWaveListScreen), findsOneWidget);
  });

  testWidgets('no link to a screen the user may not open', (tester) async {
    await pumpApp(tester, const _Host(FeatureLinkButton('wave')), overrides: [_signedIn(['inventory.view'])]);

    expect(find.byKey(const ValueKey('link-wave')), findsNothing);
  });

  testWidgets('the supply chain detail screens are offered as chips', (tester) async {
    await pumpApp(tester, const _Host(SizedBox(width: 600, child: FeatureLinkChips(['sc_routes', 'sc_risk']))),
        overrides: [_signedIn(['supply_chain.view'])]);

    expect(find.byKey(const ValueKey('link-sc_routes')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-sc_risk')), findsOneWidget);
  });
}
