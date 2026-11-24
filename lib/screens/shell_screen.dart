import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/space_providers.dart';
import 'centres_screen.dart';
import 'launch_control_screen.dart';
import 'missions_screen.dart';
import 'rockets_startups_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    (
      label: 'Launch Control',
      icon: Icons.rocket_launch_outlined,
      selectedIcon: Icons.rocket_launch_rounded,
    ),
    (
      label: 'Missions',
      icon: Icons.public_outlined,
      selectedIcon: Icons.public_rounded,
    ),
    (
      label: 'Rockets & Startups',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
    ),
    (
      label: 'ISRO Centres',
      icon: Icons.location_city_outlined,
      selectedIcon: Icons.location_city_rounded,
    ),
  ];

  static const _screens = [
    LaunchControlScreen(),
    MissionsScreen(),
    RocketsStartupsScreen(),
    CentresScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    ref.listen<AsyncValue<String?>>(syncNotifierProvider, (prev, next) {
      next.whenOrNull(
        data: (msg) {
          if (msg != null && prev is AsyncLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: $err')),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.satellite_alt_rounded, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Indian Space Tracker',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Sync Telemetry',
              onPressed: syncState.isLoading
                  ? null
                  : () => ref.read(syncNotifierProvider.notifier).triggerSync(),
              icon: syncState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _screens[_selectedIndex]),
              ],
            )
          : _screens[_selectedIndex],
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) =>
                  setState(() => _selectedIndex = idx),
              destinations: _destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}