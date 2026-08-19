import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';

/// The content-area landing page inside the app shell: a branded greeting,
/// a "ready to scan" banner, and the full capability menu grouped by area.
/// Selecting anything is delegated to the shell via [onOpen] so the sidebar
/// stays in sync.
class DashboardOverviewScreen extends StatelessWidget {
  const DashboardOverviewScreen({
    super.key,
    required this.onOpen,
    this.userName,
    this.userEmail,
  });

  /// Opens a feature in the shell's content area.
  final void Function(FeatureEntry entry) onOpen;

  final String? userName;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final groups = buildFeatureCatalog();
    FeatureEntry? entryById(String id) {
      for (final g in groups) {
        for (final e in g.entries) {
          if (e.id == id) return e;
        }
      }
      return null;
    }

    final lookup = entryById('product_lookup');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _GreetingCard(name: userName, email: userEmail),
        const SizedBox(height: AppSpacing.lg),
        _ScanHeroCard(
          onTap: lookup == null ? null : () => onOpen(lookup),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final group in groups) ...[
          _SectionLabel(group.title),
          const SizedBox(height: AppSpacing.md),
          _FeatureGrid(entries: group.entries, onOpen: onOpen),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}

/// A prominent banner reminding operators that scanning works anywhere; tapping
/// it opens Product Lookup for a manual search.
class _ScanHeroCard extends StatelessWidget {
  const _ScanHeroCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner_outlined,
                  size: 32, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ready to scan',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fire a handheld scanner anywhere, or tap to search by '
                      'barcode, SKU or name.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({this.name, this.email});

  final String? name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()
        : 'Operator';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const BrandMark(size: 48),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email != null && email!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const StatusPill(
              tone: StatusTone.success,
              label: 'Scanner ready',
              icon: Icons.qr_code_scanner_outlined,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.entries, required this.onOpen});

  final List<FeatureEntry> entries;
  final void Function(FeatureEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 134,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) =>
          _FeatureCard(entry: entries[index], onOpen: onOpen),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.entry, required this.onOpen});

  final FeatureEntry entry;
  final void Function(FeatureEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = entry.isReady ? StatusTone.info : StatusTone.neutral;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(entry),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusAvatar(tone: tone, icon: entry.icon),
                  const Spacer(),
                  if (entry.isReady)
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)
                  else
                    const StatusPill(
                      tone: StatusTone.neutral,
                      label: 'Soon',
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                entry.label,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  entry.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
