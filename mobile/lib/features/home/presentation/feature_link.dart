import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';

/// The catalog entry [id], or null when there is none.
FeatureEntry? featureById(String id) {
  for (final g in buildFeatureCatalog()) {
    for (final e in g.entries) {
      if (e.id == id) return e;
    }
  }
  return null;
}

/// The entry [id] when the signed-in user may open it — the same rule the
/// menu applies, so a link never offers a screen its menu entry would have
/// been hidden for.
FeatureEntry? _openable(WidgetRef ref, String id) {
  final e = featureById(id);
  if (e == null || !e.isReady) return null;
  // Signed in, the app built the auth controller long before any screen; a
  // screen shown on its own (a test, a preview) is not made to start one.
  final perms = ref.exists(authControllerProvider)
      ? ref.watch(authControllerProvider).user?.permissions ?? const <String>[]
      : const <String>[];
  return e.visibleFor(perms) ? e : null;
}

void _open(BuildContext context, FeatureEntry e) =>
    Navigator.of(context).push(MaterialPageRoute(builder: e.builder!));

/// An app-bar button opening the screen [id] that the menu no longer lists
/// on its own (it belongs to this screen). Nothing when the user may not
/// open it.
class FeatureLinkButton extends ConsumerWidget {
  const FeatureLinkButton(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = _openable(ref, id);
    if (e == null) return const SizedBox.shrink();
    return IconButton(
      key: ValueKey('link-$id'),
      tooltip: e.label(AppLocalizations.of(context)),
      icon: Icon(e.icon),
      onPressed: () => _open(context, e),
    );
  }
}

/// A row of chips opening the screens [ids], each with its label and icon:
/// the screens that belong to this one, offered here rather than in the menu.
class FeatureLinkChips extends ConsumerWidget {
  const FeatureLinkChips(this.ids, {super.key});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = [for (final id in ids) _openable(ref, id)].whereType<FeatureEntry>().toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          ActionChip(
            key: ValueKey('link-${e.id}'),
            avatar: Icon(e.icon, size: 18),
            label: Text(e.label(l10n)),
            tooltip: e.description(l10n),
            onPressed: () => _open(context, e),
          ),
      ],
    );
  }
}
