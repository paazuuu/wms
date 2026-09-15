import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/feature_catalog.dart';

/// One step in the breadcrumb trail. [path] is null for a step that names a
/// place but isn't one — a sidebar section heading like "Field Operations"
/// groups screens without being a screen itself, so it reads as context
/// rather than offering a click that would go nowhere.
@immutable
class Crumb {
  const Crumb(this.label, {this.path});

  final String label;
  final String? path;

  bool get isLink => path != null;
}

/// The trail for a selected feature id.
///
/// Derived from the catalog rather than recorded while navigating, so it is
/// correct no matter how the operator arrived — sidebar, dashboard tile, deep
/// link or browser back. The middle step is the feature's sidebar group, which
/// is the only real hierarchy this app has: the menu is two levels deep, so a
/// trail of dashboard → section → screen says exactly where you are without
/// inventing structure that doesn't exist.
///
/// The dashboard itself gets a single non-link crumb. A one-item trail where
/// that item is also a link to where you already are is just a button that
/// does nothing.
List<Crumb> crumbsFor(AppLocalizations l10n, String selectedId) {
  final home = Crumb(l10n.navDashboard, path: AppRoutes.dashboard);

  switch (selectedId) {
    case 'dashboard':
      return [Crumb(l10n.navDashboard)];
    case 'search':
      return [home, Crumb(l10n.searchTitle)];
    case 'stock_lookup':
      return [home, Crumb(l10n.searchKindStock)];
  }

  for (final group in buildFeatureCatalog()) {
    for (final entry in group.entries) {
      if (entry.id == selectedId) {
        return [home, Crumb(group.title(l10n)), Crumb(entry.label(l10n))];
      }
    }
  }
  return [Crumb(l10n.navDashboard)];
}

/// Renders [crumbsFor] as the top bar's title area: clickable ancestors, a
/// chevron between steps, and the current screen in full weight.
///
/// Replaces a bare page title. The title told an operator what they were
/// looking at; the trail also tells them where it sits and gives them one
/// click back out, which is the part that was missing on screens reached from
/// a dashboard tile rather than the sidebar.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final crumbs = crumbsFor(l10n, selectedId);

    final children = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final crumb = crumbs[i];
      final isLast = i == crumbs.length - 1;

      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            Icons.chevron_right,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ));
      }

      // The current screen keeps the weight the old single title had, so the
      // trail reads as one heading with context rather than a row of links.
      final style = isLast
          ? theme.textTheme.titleLarge
          : theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

      final text = Text(
        crumb.label,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

      children.add(
        // Only the last step may shrink: an ellipsised ancestor is unreadable
        // *and* unclickable-looking, whereas a truncated current title is
        // still recognisable next to the screen it labels.
        isLast
            ? Flexible(child: text)
            : crumb.isLink
                ? InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    onTap: () => context.go(crumb.path!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs, vertical: 2),
                      child: text,
                    ),
                  )
                : text,
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
