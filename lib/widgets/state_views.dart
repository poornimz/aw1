import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme/app_theme.dart';

class LoadingShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const LoadingShimmerList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 112,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceCard,
      highlightColor: AppTheme.surfaceElevated,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onReset;
  final String resetLabel;

  const EmptyStateView({
    super.key,
    this.title = 'No matching telemetry found',
    this.message = 'Try clearing or adjusting your active search filters.',
    this.onReset,
    this.resetLabel = 'Reset Filters',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.satellite_alt_rounded,
              size: 48,
              color: AppTheme.orbitalCyan,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onReset != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(resetLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorStateView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppTheme.crimsonAlert,
              ),
              const SizedBox(height: 12),
              Text(
                'Telemetry Link Interrupted',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LastSyncedBadge extends StatelessWidget {
  final DateTime? lastSyncedAt;
  final bool cacheHit;

  const LastSyncedBadge({
    super.key,
    required this.lastSyncedAt,
    this.cacheHit = false,
  });

  String _formatRelative(DateTime timestamp) {
    final diff = DateTime.now().toUtc().difference(timestamp.toUtc());
    if (diff.inSeconds < 60) return 'Last synced just now';
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return 'Last synced $mins min${mins == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return 'Last synced $hrs hr${hrs == 1 ? '' : 's'} ago';
    }
    final days = diff.inDays;
    return 'Last synced $days day${days == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final text = lastSyncedAt != null
        ? _formatRelative(lastSyncedAt!)
        : 'Offline dataset';
    final isStale = lastSyncedAt != null &&
        DateTime.now().toUtc().difference(lastSyncedAt!.toUtc()).inMinutes >= 30;

    final badgeColor =
        isStale ? AppTheme.saffronAccent : AppTheme.emeraldSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStale ? Icons.schedule_rounded : Icons.verified_rounded,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            cacheHit ? '$text • Cached' : text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}