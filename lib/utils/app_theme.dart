import 'package:flutter/material.dart';

class AppTheme {
  // Aurora Borealis Palette - Purple, Pink & Blue
  static const Color auroraPurple = Color(0xFF6D4DB8); // Deep Purple
  static const Color auroraLavender = Color(0xFF9370DB); // Lavender
  static const Color auroraPink = Color(0xFFE91E8C); // Hot Pink
  static const Color auroraBlue = Color(0xFF00D4FF); // Cyan Blue
  static const Color auroraLightBlue = Color(0xFF7FE5FF); // Light Blue

  static const Color _lightPrimary = auroraBlue;
  static const Color _lightSecondary = auroraPink;
  static const Color _lightBackground = Color(
    0xFFFAF9FF,
  ); // Almost white with slight purple tint
  static const Color _lightSurface = Colors.white;

  static const Color _darkPrimary = auroraBlue;
  static const Color _darkSecondary = auroraPink;
  static const Color _darkBackground = Color(0xFF0F0A1F); // Deep purple-black
  static const Color _darkSurface = Color(0xFF1A1430); // Dark purple

  /// Shared gradient for aurora background, adapted per brightness.
  static LinearGradient auroraBackgroundGradient(Brightness brightness) {
    final base = brightness == Brightness.dark ? 0.16 : 0.08;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        auroraPurple.withOpacity(base + 0.02),
        auroraBlue.withOpacity(base),
        auroraPink.withOpacity(base - 0.02),
      ],
    );
  }

  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkSurface : _lightSurface;

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? _darkBackground : _lightBackground;

  static List<BoxShadow> softShadow(Brightness brightness) => [
    BoxShadow(
      color: brightness == Brightness.dark
          ? Colors.black.withOpacity(0.35)
          : auroraPurple.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightSurface,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _lightPrimary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkPrimary,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
      useMaterial3: true,
    );
  }
}
