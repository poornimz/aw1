import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';
import '../providers/space_providers.dart';
import '../widgets/state_views.dart';

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  final _searchController = TextEditingController();

  static const _programs = [
    'All',
    'Gaganyaan',
    'Chandrayaan',
    'NavIC',
    'Earth Observation',
    'Commercial',
    'Private Launches',
  ];

  static const _statuses = [
    'All',
    'Upcoming',
    'Scheduled',
    'Successful',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetAll() {
    _searchController.clear();
    ref.read(missionFilterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(missionFilterProvider);
    final missionsAsync = ref.watch(filteredMissionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(filteredMissionsProvider);
        await ref.read(filteredMissionsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search missions (e.g. NVS-03, PSLV-C62, Gaganyaan)...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(missionFilterProvider.notifier).setSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {});
              ref.read(missionFilterProvider.notifier).setSearch(value);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DropdownButton<String>(
                value: filter.program ?? 'All',
                dropdownColor: AppTheme.surfaceElevated,
                items: _programs
                    .map((p) => DropdownMenuItem(value: p, child: Text('Program: $p')))
                    .toList(),
                onChanged: (val) =>
                    ref.read(missionFilterProvider.notifier).setProgram(val),
              ),
              DropdownButton<String>(
                value: filter.status ?? 'All',
                dropdownColor: AppTheme.surfaceElevated,
                items: _statuses
                    .map((s) => DropdownMenuItem(value: s, child: Text('Status: $s')))
                    .toList(),
                onChanged: (val) =>
                    ref.read(missionFilterProvider.notifier).setStatus(val),
              ),
            ],
          ),
          const SizedBox(height: 14),
          missionsAsync.when(
            data: (page) {
              if (page.items.isEmpty) {
                return EmptyStateView(onReset: _resetAll);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${page.pagination.total} missions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      LastSyncedBadge(
                        lastSyncedAt: page.lastSyncedAt,
                        cacheHit: page.cacheHit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...page.items.map((m) => _MissionManifestCard(mission: m)),
                ],
              );
            },
            loading: () => const LoadingShimmerList(itemCount: 5, itemHeight: 110),
            error: (err, _) => ErrorStateView(
              error: err,
              onRetry: () => ref.invalidate(filteredMissionsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionManifestCard extends StatelessWidget {
  final MissionModel mission;

  const _MissionManifestCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final dateText = mission.launchDateUtc != null
        ? DateFormat('dd MMM yyyy • HH:mm UTC')
            .format(mission.launchDateUtc!.toUtc())
        : 'TBD';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          mission.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${mission.missionCode}  •  ${mission.status}  •  $dateText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        children: [
          if (mission.summary != null && mission.summary!.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mission.summary!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (mission.organizationName != null)
                Chip(label: Text('Org: ${mission.organizationName}')),
              if (mission.vehicleName != null)
                Chip(label: Text('Vehicle: ${mission.vehicleName}')),
              if (mission.orbitType != null)
                Chip(label: Text('Orbit: ${mission.orbitType}')),
              if (mission.launchSite != null)
                Chip(label: Text('Site: ${mission.launchSite}')),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payload Manifest (${mission.payloads.length})',
              style: const TextStyle(
                color: AppTheme.orbitalCyan,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (mission.payloads.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No individual payloads listed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...mission.payloads.map(
              (p) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.payloadType}'
                      '${p.massKg != null ? ' • ${p.massKg!.toStringAsFixed(0)} kg' : ''}'
                      '${p.orbit != null ? ' • ${p.orbit}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}