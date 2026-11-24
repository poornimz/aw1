import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';
import '../providers/space_providers.dart';
import '../widgets/countdown_card.dart';
import '../widgets/state_views.dart';

class LaunchControlScreen extends ConsumerWidget {
  const LaunchControlScreen({super.key});

  static const _quickFilters = [
    'All',
    'Gaganyaan',
    'Chandrayaan',
    'Private Launches',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextAsync = ref.watch(nextMissionProvider);
    final selectedChip = ref.watch(launchControlChipProvider);
    final missionsAsync = ref.watch(launchControlMissionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nextMissionProvider);
        ref.invalidate(launchControlMissionsProvider);
        await Future.wait([
          ref.read(nextMissionProvider.future),
          ref.read(launchControlMissionsProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          nextAsync.when(
            data: (nextData) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: LastSyncedBadge(lastSyncedAt: nextData.lastSyncedAt),
                ),
                const SizedBox(height: 10),
                CountdownCard(data: nextData),
              ],
            ),
            loading: () => const LoadingShimmerList(itemCount: 1, itemHeight: 220),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(nextMissionProvider),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Mission Feed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickFilters.map((chip) {
                final isSelected = selectedChip == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(chip),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(launchControlChipProvider.notifier).state = chip;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          missionsAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyStateView(
                  onReset: () =>
                      ref.read(launchControlChipProvider.notifier).state = 'All',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LastSyncedBadge(
                      lastSyncedAt: page.lastSyncedAt,
                      cacheHit: page.cacheHit,
                    ),
                  ),
                  ...page.items.map((mission) => _LaunchFeedTile(mission: mission)),
                ],
              );
            },
            loading: () => const LoadingShimmerList(itemCount: 4, itemHeight: 96),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(launchControlMissionsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaunchFeedTile extends StatelessWidget {
  final MissionModel mission;

  const _LaunchFeedTile({required this.mission});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'successful':
        return AppTheme.emeraldSuccess;
      case 'failed':
        return AppTheme.crimsonAlert;
      case 'upcoming':
      case 'scheduled':
        return AppTheme.saffronAccent;
      default:
        return AppTheme.orbitalCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(mission.status);
    final dateStr = mission.launchDateUtc != null
        ? DateFormat('dd MMM yyyy • HH:mm UTC')
            .format(mission.launchDateUtc!.toUtc())
        : 'Date TBD';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mission.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mission.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  mission.program,
                  style: const TextStyle(
                    color: AppTheme.orbitalCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (mission.vehicleName != null)
                  Text(
                    '• ${mission.vehicleName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  '• $dateStr',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (mission.summary != null && mission.summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                mission.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}