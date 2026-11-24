import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';
import '../providers/space_providers.dart';
import '../widgets/payload_chart.dart';
import '../widgets/state_views.dart';

class RocketsStartupsScreen extends ConsumerWidget {
  const RocketsStartupsScreen({super.key});

  static const _focusTags = [
    'All',
    'Launch Vehicles',
    'Earth Observation',
    'In-Space Propulsion',
    'Satellite Platforms',
    'Space Situational Awareness',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final startupsAsync = ref.watch(startupsProvider);
    final selectedFocus = ref.watch(startupFocusProvider) ?? 'All';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(vehiclesProvider);
        ref.invalidate(startupsProvider);
        await Future.wait([
          ref.read(vehiclesProvider.future),
          ref.read(startupsProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Indian Launch Vehicles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          vehiclesAsync.when(
            data: (page) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PayloadComparisonChart(vehicles: page.items),
                const SizedBox(height: 12),
                ...page.items.map((v) => _VehicleCard(vehicle: v)),
              ],
            ),
            loading: () => const LoadingShimmerList(itemCount: 3, itemHeight: 140),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(vehiclesProvider),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Indian Space Startups',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _focusTags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag),
                    selected: selectedFocus == tag,
                    onSelected: (_) {
                      ref.read(startupFocusProvider.notifier).state =
                          tag == 'All' ? null : tag;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          startupsAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyStateView(
                  onReset: () =>
                      ref.read(startupFocusProvider.notifier).state = null,
                );
              }
              return Column(
                children: page.items.map((s) => _StartupCard(startup: s)).toList(),
              );
            },
            loading: () => const LoadingShimmerList(itemCount: 4, itemHeight: 110),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(startupsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final LaunchVehicleModel vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(vehicle.status),
                ),
              ],
            ),
            if (vehicle.organizationName != null)
              Text(
                vehicle.organizationName!,
                style: const TextStyle(
                  color: AppTheme.orbitalCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('LEO: ${vehicle.leoPayloadKg ?? 0} kg'),
                Text('GTO: ${vehicle.gtoPayloadKg ?? 0} kg'),
                if (vehicle.heightM != null)
                  Text('Height: ${vehicle.heightM!.toStringAsFixed(1)} m'),
                Text(
                  'Launches: ${vehicle.successfulLaunches}/${vehicle.totalLaunches}',
                ),
              ],
            ),
            if (vehicle.description != null) ...[
              const SizedBox(height: 8),
              Text(
                vehicle.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  final StartupModel startup;

  const _StartupCard({required this.startup});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    startup.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (startup.fundingStage != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.saffronAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      startup.fundingStage!,
                      style: const TextStyle(
                        color: AppTheme.saffronAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  startup.focusArea,
                  style: const TextStyle(
                    color: AppTheme.orbitalCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (startup.city != null)
                  Text(
                    '• ${startup.city}, ${startup.state ?? 'India'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (startup.foundedYear != null)
                  Text(
                    '• Est. ${startup.foundedYear}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (startup.description != null) ...[
              const SizedBox(height: 8),
              Text(
                startup.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}