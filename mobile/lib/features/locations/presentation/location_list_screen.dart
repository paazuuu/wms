import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scan/scan_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../application/location_providers.dart';
import '../domain/location.dart';
import 'location_detail_screen.dart';
import 'location_status_ui.dart';

/// Browse and search warehouse locations (bins, shelves, zones). Read-only:
/// tapping a location opens its detail.
class LocationListScreen extends ConsumerStatefulWidget {
  const LocationListScreen({super.key});

  @override
  ConsumerState<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends ConsumerState<LocationListScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _controller.text.trim();
    if (next == _query) {
      ref.invalidate(locationSearchProvider(_query));
    } else {
      setState(() => _query = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(locationSearchProvider(_query));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featLocations)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ScanField(
              controller: _controller,
              autofocusOnWide: true,
              clearOnSubmit: false,
              hintText: l10n.hintLocations,
              onSubmitted: (_) => _submit(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(locationSearchProvider(_query)),
              child: results.when(
                data: (items) => items.isEmpty
                    ? EmptyStateView(
                        icon: Icons.wrong_location_outlined,
                        title: _query.isEmpty
                            ? l10n.emptyLocations
                            : l10n.noMatchesFor(_query),
                        message: l10n.tryDifferentNameCode,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            _LocationCard(location: items[index]),
                      ),
                loading: () => LoadingView(message: l10n.loading),
                error: (error, _) => ErrorStateView(
                  message: '$error',
                  onRetry: () => ref.invalidate(locationSearchProvider(_query)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = LocationStatusUi.of(location);
    final count = location.productsCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationDetailScreen(locationId: location.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              StatusAvatar(tone: status.tone, icon: status.icon),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location.displayCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'FiraCode',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (count != null)
                StatusPill(
                  tone: StatusTone.info,
                  label: '$count ${count == 1 ? 'item' : 'items'}',
                  icon: Icons.inventory_2_outlined,
                  dense: true,
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
