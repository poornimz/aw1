import 'package:flutter/material.dart';

class AppTheme {
  static const Color spaceBackground = Color(0xFF070B14);
  static const Color surfaceCard = Color(0xFF101829);
  static const Color surfaceElevated = Color(0xFF17223B);
  static const Color saffronAccent = Color(0xFFFF8A34);
  static const Color orbitalCyan = Color(0xFF38BDF8);
  static const Color emeraldSuccess = Color(0xFF34D399);
  static const Color crimsonAlert = Color(0xFFF87171);
  static const Color borderSubtle = Color(0xFF233252);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    const colorScheme = ColorScheme.dark(
      primary: saffronAccent,
      secondary: orbitalCyan,
      surface: surfaceCard,
      error: crimsonAlert,
      onPrimary: Color(0xFF0B0F1A),
      onSecondary: Color(0xFF06131F),
      onSurface: Color(0xFFE6EDF7),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: spaceBackground,
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: spaceBackground,
        foregroundColor: Color(0xFFF1F5F9),
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceElevated,
        selectedColor: saffronAccent.withValues(alpha: 0.2),
        side: const BorderSide(color: borderSubtle),
        labelStyle: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orbitalCyan, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceCard,
        indicatorColor: saffronAccent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceCard,
        indicatorColor: saffronAccent.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: saffronAccent),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Color(0xFFF8FAFC),
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1F5F9),
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFFE2E8F0),
        ),
        bodyMedium: const TextStyle(
          color: Color(0xFFCBD5E1),
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}