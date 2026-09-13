import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wms_mobile/features/home/domain/feature_catalog.dart';
import 'package:wms_mobile/features/home/domain/feature_entry.dart';

void main() {
  group('FeatureEntry.visibleFor (UI spec §37)', () {
    const gated = FeatureEntry(
      id: 'picking',
      icon: Icons.shopping_cart_checkout_outlined,
      requiredAnyOf: ['pick.confirm'],
    );
    const ungated = FeatureEntry(id: 'dashboard', icon: Icons.dashboard);

    test('an entry with no requirement is visible to anyone', () {
      expect(ungated.visibleFor(const []), isTrue);
      expect(ungated.visibleFor(const ['anything']), isTrue);
    });

    test('a gated entry needs at least one of its permissions', () {
      expect(gated.visibleFor(const []), isFalse);
      expect(gated.visibleFor(const ['audit.view']), isFalse);
      expect(gated.visibleFor(const ['pick.confirm']), isTrue);
    });
  });

  group('FeatureGroup.visibleEntries', () {
    const group = FeatureGroup(id: 'field_operations', entries: [
      FeatureEntry(
          id: 'picking',
          icon: Icons.shopping_cart_checkout_outlined,
          requiredAnyOf: ['pick.confirm']),
      FeatureEntry(
          id: 'putaway',
          icon: Icons.move_to_inbox_outlined,
          requiredAnyOf: ['putaway.confirm']),
    ]);

    test('keeps only entries the permission set unlocks', () {
      final visible = group.visibleEntries(const ['pick.confirm']);

      expect(visible.map((e) => e.id), ['picking']);
    });

    test('comes back empty when nothing in the group is held', () {
      expect(group.visibleEntries(const ['audit.view']), isEmpty);
    });

    test('holding every permission keeps every entry, in order', () {
      final visible =
          group.visibleEntries(const ['pick.confirm', 'putaway.confirm']);

      expect(visible.map((e) => e.id), ['picking', 'putaway']);
    });
  });

  group('the real catalog', () {
    test('every entry declares at least one required permission', () {
      // §37's whole point: nothing in the menu is unrestricted by accident.
      for (final group in buildFeatureCatalog()) {
        for (final entry in group.entries) {
          expect(entry.requiredAnyOf, isNotEmpty,
              reason: '${entry.id} has no permission requirement');
        }
      }
    });

    test('an unpermissioned user sees no groups at all', () {
      final groups = buildFeatureCatalog()
          .map((g) => g.visibleEntries(const []))
          .where((e) => e.isNotEmpty);

      expect(groups, isEmpty);
    });
  });
}
