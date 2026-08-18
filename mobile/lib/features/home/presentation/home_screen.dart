import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/status_pill.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/feature_catalog.dart';
import '../domain/feature_entry.dart';
import 'coming_soon_screen.dart';

/// The app's home hub: a branded greeting plus a grouped grid of every
/// warehouse capability. Ready features open their live screen; the rest open a
/// [ComingSoonScreen] so the whole menu is explorable from day one.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final groups = buildFeatureCatalog();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WMS'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _GreetingCard(name: user?.name, email: user?.email),
          const SizedBox(height: AppSpacing.xl),
          for (final group in groups) ...[
            _GroupHeader(title: group.title),
            const SizedBox(height: AppSpacing.md),
            _FeatureGrid(entries: group.entries),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
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
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.entries});

  final List<FeatureEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 134,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _FeatureCard(entry: entries[index]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.entry});

  final FeatureEntry entry;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            entry.isReady ? entry.builder!(ctx) : ComingSoonScreen(feature: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = entry.isReady ? StatusTone.info : StatusTone.neutral;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
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
