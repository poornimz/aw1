import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';
import '../providers/space_providers.dart';
import '../widgets/state_views.dart';

class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});

  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centresAsync = ref.watch(centresProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(centresProvider);
        await ref.read(centresProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Filter ISRO centres by city, code, or specialization...',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(centreSearchProvider.notifier).state = '';
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
              ref.read(centreSearchProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          centresAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyStateView(
                  onReset: () {
                    _searchController.clear();
                    ref.read(centreSearchProvider.notifier).state = '';
                  },
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
                  ...page.items.map((c) => _CentreCard(centre: c)),
                ],
              );
            },
            loading: () => const LoadingShimmerList(itemCount: 5, itemHeight: 120),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(centresProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _CentreCard extends StatelessWidget {
  final ISROCentreModel centre;

  const _CentreCard({required this.centre});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.orbitalCyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    centre.code,
                    style: const TextStyle(
                      color: AppTheme.orbitalCyan,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    centre.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${centre.city}, ${centre.state}  •  '
              '(${centre.latitude.toStringAsFixed(4)}° N, ${centre.longitude.toStringAsFixed(4)}° E)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              centre.specialization,
              style: const TextStyle(
                color: AppTheme.saffronAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (centre.description != null) ...[
              const SizedBox(height: 8),
              Text(
                centre.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}