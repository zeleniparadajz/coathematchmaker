import 'package:flutter/material.dart';

class AppTheme {
  static const court = Color(0xFF1F8A5B);
  static const lime = Color(0xFFD5F45D);
  static const clay = Color(0xFFE66A3A);
  static const ink = Color(0xFF17211C);
  static const mist = Color(0xFFF5F8F1);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: court,
      primary: court,
      secondary: clay,
      tertiary: lime,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: mist,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: court.withValues(alpha: .035),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink.withValues(alpha: .08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: court, width: 1.5),
        ),
      ),
    );
  }
}
