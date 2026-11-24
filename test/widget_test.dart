import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indian_space_tracker/main.dart';
import 'package:indian_space_tracker/models/space_models.dart';
import 'package:indian_space_tracker/providers/space_providers.dart';

void main() {
  testWidgets('App shell renders Indian Space Tracker header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nextMissionProvider.overrideWith((ref) async {
            return NextMissionData(
              mission: null,
              serverTimeUtc: DateTime.utc(2026, 12, 1),
            );
          }),
          launchControlMissionsProvider.overrideWith((ref) async {
            return const PaginatedResponse<MissionModel>(
              items: [],
              pagination: PaginationMeta(
                total: 0,
                limit: 25,
                offset: 0,
                hasMore: false,
              ),
            );
          }),
        ],
        child: const IndianSpaceTrackerApp(),
      ),
    );

    await tester.pump();
    expect(find.text('Indian Space Tracker'), findsOneWidget);

    // Unmount cleanly so CountdownCard cancels its periodic timer
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}