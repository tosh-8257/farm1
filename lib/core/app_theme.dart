import 'package:flutter/material.dart';

/// THE brand accent. Change this one constant to re-theme every accent use.
/// Design rule: black, white and grey everywhere, plus this single accent,
/// used sparingly (FARM mark, primary buttons, wallet balance figures,
/// active nav tab/indicator, onboarding art highlight, selected chips,
/// focus rings). Never for error or success states.
const Color kBrandAccent = Color(0xFFD4AF37); // classic gold

class AppTheme {
  // ── Accent (all derived from kBrandAccent) ─────────────────────────────
  /// Accent fill (buttons, chips, indicators, art).
  static const accent = kBrandAccent;

  /// Text/icons drawn ON an accent fill. Black on gold is ~10:1.
  static const onAccent = Color(0xFF000000);

  /// Accent for text, thin lines and focus rings on the given background,
  /// darkened just enough to reach [minContrast] (WCAG AA 4.5:1 by default).
  /// On dark backgrounds the pure accent already passes and is returned.
  static Color accentOn(Color background, {double minContrast = 4.5}) {
    var hsl = HSLColor.fromColor(accent);
    var c = accent;
    var guard = 0;
    while (contrastRatio(c, background) < minContrast && guard++ < 100) {
      final lighter = background.computeLuminance() < 0.5;
      final l = (hsl.lightness + (lighter ? 0.01 : -0.01)).clamp(0.0, 1.0);
      hsl = hsl.withLightness(l);
      c = hsl.toColor();
    }
    return c;
  }

  /// WCAG 2.x contrast ratio between two opaque colours.
  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  // Light theme colors
  static const lightPrimary = Color(0xFF000000);
  static const lightSecondary = Color(0xFF6B7280);
  static const lightTertiary = Color(0xFF0F172A);
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF9FAFB);
  static const lightError = Color(0xFFDC2626);
  static const lightSuccess = Color(0xFF16A34A);
  static const lightWarning = Color(0xFFFB923C);
  static const lightInfo = Color(0xFF0EA5E9);

  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextTertiary = Color(0xFF9CA3AF);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightDivider = Color(0xFFF3F4F6);

  // Dark theme colors
  static const darkPrimary = Color(0xFFFFFFFF);
  static const darkSecondary = Color(0xFFD1D5DB);
  static const darkTertiary = Color(0xFFE0E7FF);
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkError = Color(0xFFF87171);
  static const darkSuccess = Color(0xFF4ADE80);
  static const darkWarning = Color(0xFFFBBF24);
  static const darkInfo = Color(0xFF38BDF8);

  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFD1D5DB);
  static const darkTextTertiary = Color(0xFF9CA3AF);
  static const darkBorder = Color(0xFF334155);
  static const darkDivider = Color(0xFF1E293B);

  // Status colors (consistent across themes)
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFFB923C);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimary,
      canvasColor: lightBackground,
      cardColor: lightSurface,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: accent,
        onSecondary: onAccent,
        tertiary: lightTertiary,
        surface: lightSurface,
        error: lightError,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightTextPrimary),
        displayMedium: TextStyle(color: lightTextPrimary),
        displaySmall: TextStyle(color: lightTextPrimary),
        headlineLarge: TextStyle(color: lightTextPrimary),
        headlineMedium: TextStyle(color: lightTextPrimary),
        headlineSmall: TextStyle(color: lightTextPrimary),
        titleLarge: TextStyle(color: lightTextPrimary),
        titleMedium: TextStyle(color: lightTextPrimary),
        titleSmall: TextStyle(color: lightTextPrimary),
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextPrimary),
        bodySmall: TextStyle(color: lightTextSecondary),
        labelLarge: TextStyle(color: lightTextPrimary),
        labelMedium: TextStyle(color: lightTextPrimary),
        labelSmall: TextStyle(color: lightTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: accentOn(lightSurface, minContrast: 3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightError),
        ),
        hintStyle: const TextStyle(color: lightTextTertiary),
        labelStyle: const TextStyle(color: lightTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: lightPrimary),
      ),
      iconTheme: const IconThemeData(color: lightTextPrimary),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: lightBackground,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: accent,
        secondaryLabelStyle: const TextStyle(color: onAccent),
        checkmarkColor: onAccent,
        labelStyle: const TextStyle(color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightBackground,
        selectedItemColor: accentOn(lightBackground, minContrast: 3),
        unselectedItemColor: lightTextTertiary,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: lightBackground,
        selectedIconTheme: IconThemeData(
          color: accentOn(lightBackground, minContrast: 3),
        ),
        indicatorColor: accent,
        unselectedIconTheme: IconThemeData(color: lightTextTertiary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: lightBackground),
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accent, width: 3),
        ),
        labelColor: lightTextPrimary,
        unselectedLabelColor: lightTextTertiary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      focusColor: accent.withValues(alpha: 0.24),
      // Toggles stay monochrome: the accent is not a generic "on" colour.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? lightPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? lightPrimary.withValues(alpha: 0.5)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? lightPrimary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? lightPrimary : null,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkPrimary,
      canvasColor: darkBackground,
      cardColor: darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: accent,
        onSecondary: onAccent,
        tertiary: darkTertiary,
        surface: darkSurface,
        error: darkError,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkTextPrimary),
        displayMedium: TextStyle(color: darkTextPrimary),
        displaySmall: TextStyle(color: darkTextPrimary),
        headlineLarge: TextStyle(color: darkTextPrimary),
        headlineMedium: TextStyle(color: darkTextPrimary),
        headlineSmall: TextStyle(color: darkTextPrimary),
        titleLarge: TextStyle(color: darkTextPrimary),
        titleMedium: TextStyle(color: darkTextPrimary),
        titleSmall: TextStyle(color: darkTextPrimary),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(color: darkTextPrimary),
        labelMedium: TextStyle(color: darkTextPrimary),
        labelSmall: TextStyle(color: darkTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: accentOn(darkSurface, minContrast: 3),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkError),
        ),
        hintStyle: const TextStyle(color: darkTextTertiary),
        labelStyle: const TextStyle(color: darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkPrimary),
      ),
      iconTheme: const IconThemeData(color: darkTextPrimary),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: accent,
        secondaryLabelStyle: const TextStyle(color: onAccent),
        checkmarkColor: onAccent,
        labelStyle: const TextStyle(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: accent,
        unselectedItemColor: darkTextTertiary,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: darkSurface,
        selectedIconTheme: const IconThemeData(color: accent),
        indicatorColor: accent,
        unselectedIconTheme: IconThemeData(color: darkTextTertiary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: darkSurface),
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accent, width: 3),
        ),
        labelColor: darkTextPrimary,
        unselectedLabelColor: darkTextTertiary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      focusColor: accent.withValues(alpha: 0.24),
      // Toggles stay monochrome: the accent is not a generic "on" colour.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? darkPrimary.withValues(alpha: 0.5)
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : null,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? darkPrimary : null,
        ),
      ),
    );
  }
}
