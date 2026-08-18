import 'package:flutter/material.dart';

/// Lifecycle of a feature surfaced on the home menu.
enum FeatureStatus {
  /// Screen is implemented and navigable.
  ready,

  /// Backend API exists but the mobile screen is not built yet.
  comingSoon,
}

/// A single warehouse capability shown on the home dashboard.
///
/// Each entry maps 1:1 to an InventorOS backend capability so the menu is the
/// single source of truth for "what this app can do". `ready` entries navigate
/// to a live screen via [builder]; `comingSoon` entries fall back to a
/// placeholder until their screen ships.
@immutable
class FeatureEntry {
  const FeatureEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.status = FeatureStatus.comingSoon,
    this.builder,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final FeatureStatus status;

  /// Navigation target when the feature is [FeatureStatus.ready].
  final WidgetBuilder? builder;

  bool get isReady => status == FeatureStatus.ready && builder != null;
}

/// A titled cluster of related features (e.g. "Field Operations").
@immutable
class FeatureGroup {
  const FeatureGroup({required this.title, required this.entries});

  final String title;
  final List<FeatureEntry> entries;
}
