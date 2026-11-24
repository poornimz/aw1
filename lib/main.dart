import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'screens/shell_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: IndianSpaceTrackerApp(),
    ),
  );
}

class IndianSpaceTrackerApp extends StatelessWidget {
  const IndianSpaceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indian Space Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ShellScreen(),
    );
  }
}