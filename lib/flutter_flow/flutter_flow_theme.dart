// ignore_for_file: overridden_fields, annotate_overrides

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';

const kThemeModeKey = '__theme_mode__';

SharedPreferences? _prefs;

abstract class FlutterFlowTheme {
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();

  static ThemeMode get themeMode {
    final modeString = _prefs?.getString(kThemeModeKey);
    if (modeString != null) {
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == modeString,
        orElse: () => ThemeMode.light,
      );
    }

    final darkMode = _prefs?.getBool(kThemeModeKey);
    return darkMode == null
        ? ThemeMode.light
        : darkMode
            ? ThemeMode.dark
            : ThemeMode.light;
  }

  static void saveThemeMode(ThemeMode mode) {
    final selectedMode =
        mode == ThemeMode.system ? ThemeMode.light : mode;
    _prefs?.setString(kThemeModeKey, selectedMode.name);
    _prefs?.setBool(kThemeModeKey, selectedMode == ThemeMode.dark);
  }

  static FlutterFlowTheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkModeTheme()
        : LightModeTheme();
  }

  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  /// Brand accent (gold) from AppTheme.accent; use sparingly.
  late Color brandAccent;
  late Color onBrandAccent;
  /// Brand accent for text/lines on the page background (WCAG AA).
  late Color brandAccentText;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  late Color onPrimary;
  late Color onSecondary;
  late Color onSurface;
  late Color onError;
  late Color transparent;
  late Color onPrimary6;
  late Color onPrimary3;
  late Color onPrimary70;
  late Color onPrimary60;
  late Color onPrimary50;
  late Color primary10;
  late Color onPrimary13;
  late Color background70;
  late Color background50;
  late Color background20;
  late Color onPrimary80;
  late Color primary67;
  late Color onPrimary90;

  FFDesignTokens get designToken => FFDesignTokens(this);

  @Deprecated('Use displaySmallFamily instead')
  String get title1Family => displaySmallFamily;
  @Deprecated('Use displaySmall instead')
  TextStyle get title1 => typography.displaySmall;
  @Deprecated('Use headlineMediumFamily instead')
  String get title2Family => typography.headlineMediumFamily;
  @Deprecated('Use headlineMedium instead')
  TextStyle get title2 => typography.headlineMedium;
  @Deprecated('Use headlineSmallFamily instead')
  String get title3Family => typography.headlineSmallFamily;
  @Deprecated('Use headlineSmall instead')
  TextStyle get title3 => typography.headlineSmall;
  @Deprecated('Use titleMediumFamily instead')
  String get subtitle1Family => typography.titleMediumFamily;
  @Deprecated('Use titleMedium instead')
  TextStyle get subtitle1 => typography.titleMedium;
  @Deprecated('Use titleSmallFamily instead')
  String get subtitle2Family => typography.titleSmallFamily;
  @Deprecated('Use titleSmall instead')
  TextStyle get subtitle2 => typography.titleSmall;
  @Deprecated('Use bodyMediumFamily instead')
  String get bodyText1Family => typography.bodyMediumFamily;
  @Deprecated('Use bodyMedium instead')
  TextStyle get bodyText1 => typography.bodyMedium;
  @Deprecated('Use bodySmallFamily instead')
  String get bodyText2Family => typography.bodySmallFamily;
  @Deprecated('Use bodySmall instead')
  TextStyle get bodyText2 => typography.bodySmall;

  String get displayLargeFamily => typography.displayLargeFamily;
  bool get displayLargeIsCustom => typography.displayLargeIsCustom;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  bool get displayMediumIsCustom => typography.displayMediumIsCustom;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  bool get displaySmallIsCustom => typography.displaySmallIsCustom;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  bool get headlineLargeIsCustom => typography.headlineLargeIsCustom;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  bool get headlineMediumIsCustom => typography.headlineMediumIsCustom;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  bool get headlineSmallIsCustom => typography.headlineSmallIsCustom;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  bool get titleLargeIsCustom => typography.titleLargeIsCustom;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  bool get titleMediumIsCustom => typography.titleMediumIsCustom;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  bool get titleSmallIsCustom => typography.titleSmallIsCustom;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  bool get labelLargeIsCustom => typography.labelLargeIsCustom;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  bool get labelMediumIsCustom => typography.labelMediumIsCustom;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  bool get labelSmallIsCustom => typography.labelSmallIsCustom;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  bool get bodyLargeIsCustom => typography.bodyLargeIsCustom;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  bool get bodyMediumIsCustom => typography.bodyMediumIsCustom;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  bool get bodySmallIsCustom => typography.bodySmallIsCustom;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = AppTheme.lightPrimary;
  late Color secondary = AppTheme.lightSecondary;
  late Color tertiary = AppTheme.lightTertiary;
  late Color alternate = AppTheme.lightSurface;
  late Color primaryText = AppTheme.lightTextPrimary;
  late Color secondaryText = AppTheme.lightTextSecondary;
  late Color primaryBackground = AppTheme.lightBackground;
  late Color secondaryBackground = AppTheme.lightSurface;
  late Color brandAccent = AppTheme.accent;
  late Color onBrandAccent = AppTheme.onAccent;
  late Color brandAccentText = AppTheme.accentOn(AppTheme.lightBackground);
  late Color accent1 = AppTheme.lightInfo.withOpacity(0.3);
  late Color accent2 = AppTheme.lightSuccess.withOpacity(0.3);
  late Color accent3 = AppTheme.lightSecondary.withOpacity(0.4);
  late Color accent4 = AppTheme.lightBackground.withOpacity(0.8);
  late Color success = AppTheme.success;
  late Color warning = AppTheme.warning;
  late Color error = AppTheme.error;
  late Color info = AppTheme.info;

  late Color onPrimary = AppTheme.lightBackground;
  late Color onSecondary = AppTheme.lightBackground;
  late Color onSurface = AppTheme.lightTextPrimary;
  late Color onError = AppTheme.lightBackground;
  late Color transparent = const Color(0x00000000);
  late Color onPrimary6 = AppTheme.lightBackground.withOpacity(0.06);
  late Color onPrimary3 = AppTheme.lightBackground.withOpacity(0.03);
  late Color onPrimary70 = AppTheme.lightBackground.withOpacity(0.7);
  late Color onPrimary60 = AppTheme.lightBackground.withOpacity(0.6);
  late Color onPrimary50 = AppTheme.lightBackground.withOpacity(0.5);
  late Color primary10 = AppTheme.lightTextPrimary.withOpacity(0.1);
  late Color onPrimary13 = AppTheme.lightBackground.withOpacity(0.13);
  late Color background70 = AppTheme.lightBackground.withOpacity(0.7);
  late Color background50 = AppTheme.lightBackground.withOpacity(0.5);
  late Color background20 = AppTheme.lightBackground.withOpacity(0.2);
  late Color onPrimary80 = AppTheme.lightBackground.withOpacity(0.8);
  late Color primary67 = AppTheme.lightTextPrimary.withOpacity(0.67);
  late Color onPrimary90 = AppTheme.lightBackground.withOpacity(0.9);
}

abstract class Typography {
  String get displayLargeFamily;
  bool get displayLargeIsCustom;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  bool get displayMediumIsCustom;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  bool get displaySmallIsCustom;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  bool get headlineLargeIsCustom;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  bool get headlineMediumIsCustom;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  bool get headlineSmallIsCustom;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  bool get titleLargeIsCustom;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  bool get titleMediumIsCustom;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  bool get titleSmallIsCustom;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  bool get labelLargeIsCustom;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  bool get labelMediumIsCustom;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  bool get labelSmallIsCustom;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  bool get bodyLargeIsCustom;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  bool get bodyMediumIsCustom;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  bool get bodySmallIsCustom;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  String get displayLargeFamily => 'Inter Tight';
  bool get displayLargeIsCustom => false;
  TextStyle get displayLarge => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 64.0,
      );
  String get displayMediumFamily => 'Inter Tight';
  bool get displayMediumIsCustom => false;
  TextStyle get displayMedium => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 44.0,
      );
  String get displaySmallFamily => 'Inter Tight';
  bool get displaySmallIsCustom => false;
  TextStyle get displaySmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 36.0,
      );
  String get headlineLargeFamily => 'Plus Jakarta Sans';
  bool get headlineLargeIsCustom => false;
  TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w800,
        fontSize: 34.0,
        height: 1.2,
      );
  String get headlineMediumFamily => 'Plus Jakarta Sans';
  bool get headlineMediumIsCustom => false;
  TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        color: theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 28.0,
        height: 1.25,
      );
  String get headlineSmallFamily => 'Inter Tight';
  bool get headlineSmallIsCustom => false;
  TextStyle get headlineSmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 24.0,
      );
  String get titleLargeFamily => 'Plus Jakarta Sans';
  bool get titleLargeIsCustom => false;
  TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        color: theme.primaryText,
        fontWeight: FontWeight.bold,
        fontSize: 22.0,
        height: 1.3,
      );
  String get titleMediumFamily => 'Plus Jakarta Sans';
  bool get titleMediumIsCustom => false;
  TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 17.0,
        height: 1.4,
      );
  String get titleSmallFamily => 'Inter Tight';
  bool get titleSmallIsCustom => false;
  TextStyle get titleSmall => GoogleFonts.interTight(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
        fontSize: 16.0,
      );
  String get labelLargeFamily => 'Plus Jakarta Sans';
  bool get labelLargeIsCustom => false;
  TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 15.0,
        height: 1.3,
      );
  String get labelMediumFamily => 'Plus Jakarta Sans';
  bool get labelMediumIsCustom => false;
  TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        color: theme.secondaryText,
        fontWeight: FontWeight.w600,
        fontSize: 13.0,
        height: 1.3,
      );
  String get labelSmallFamily => 'Plus Jakarta Sans';
  bool get labelSmallIsCustom => false;
  TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        color: theme.secondaryText,
        fontWeight: FontWeight.bold,
        fontSize: 11.0,
        height: 1.2,
      );
  String get bodyLargeFamily => 'Inter';
  bool get bodyLargeIsCustom => false;
  TextStyle get bodyLarge => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 17.0,
        height: 1.5,
      );
  String get bodyMediumFamily => 'Inter';
  bool get bodyMediumIsCustom => false;
  TextStyle get bodyMedium => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 15.0,
        height: 1.5,
      );
  String get bodySmallFamily => 'Inter';
  bool get bodySmallIsCustom => false;
  TextStyle get bodySmall => GoogleFonts.inter(
        color: theme.primaryText,
        fontWeight: FontWeight.normal,
        fontSize: 13.0,
        height: 1.4,
      );
}

class DarkModeTheme extends FlutterFlowTheme {
  @Deprecated('Use primary instead')
  Color get primaryColor => primary;
  @Deprecated('Use secondary instead')
  Color get secondaryColor => secondary;
  @Deprecated('Use tertiary instead')
  Color get tertiaryColor => tertiary;

  late Color primary = AppTheme.darkPrimary;
  late Color secondary = AppTheme.darkSecondary;
  late Color tertiary = AppTheme.darkTertiary;
  late Color alternate = AppTheme.darkSurface;
  late Color primaryText = AppTheme.darkTextPrimary;
  late Color secondaryText = AppTheme.darkTextSecondary;
  late Color primaryBackground = AppTheme.darkBackground;
  late Color secondaryBackground = AppTheme.darkSurface;
  late Color brandAccent = AppTheme.accent;
  late Color onBrandAccent = AppTheme.onAccent;
  late Color brandAccentText = AppTheme.accentOn(AppTheme.darkBackground);
  late Color accent1 = AppTheme.darkInfo.withOpacity(0.3);
  late Color accent2 = AppTheme.darkSuccess.withOpacity(0.3);
  late Color accent3 = AppTheme.darkSecondary.withOpacity(0.4);
  late Color accent4 = AppTheme.darkSurface.withOpacity(0.7);
  late Color success = AppTheme.success;
  late Color warning = AppTheme.warning;
  late Color error = AppTheme.error;
  late Color info = AppTheme.info;

  late Color onPrimary = AppTheme.darkBackground;
  late Color onSecondary = AppTheme.darkBackground;
  late Color onSurface = AppTheme.darkTextPrimary;
  late Color onError = AppTheme.darkBackground;
  late Color transparent = const Color(0x00000000);
  late Color onPrimary6 = AppTheme.darkBackground.withOpacity(0.06);
  late Color onPrimary3 = AppTheme.darkBackground.withOpacity(0.03);
  late Color onPrimary70 = AppTheme.darkBackground.withOpacity(0.7);
  late Color onPrimary60 = AppTheme.darkBackground.withOpacity(0.6);
  late Color onPrimary50 = AppTheme.darkBackground.withOpacity(0.5);
  late Color primary10 = AppTheme.darkTextPrimary.withOpacity(0.1);
  late Color onPrimary13 = AppTheme.darkBackground.withOpacity(0.13);
  late Color background70 = AppTheme.darkBackground.withOpacity(0.7);
  late Color background50 = AppTheme.darkBackground.withOpacity(0.5);
  late Color background20 = AppTheme.darkBackground.withOpacity(0.2);
  late Color onPrimary80 = AppTheme.darkBackground.withOpacity(0.8);
  late Color primary67 = AppTheme.darkTextPrimary.withOpacity(0.67);
  late Color onPrimary90 = AppTheme.darkBackground.withOpacity(0.9);
}

class FFDesignTokens {
  const FFDesignTokens(this.theme);
  final FlutterFlowTheme theme;
  FFSpacing get spacing => const FFSpacing();
  FFRadius get radius => const FFRadius();
  FFShadows get shadow => FFShadows(theme);
}

class FFSpacing {
  const FFSpacing();
  double get none => 0.0;
  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
  double get xxl => 48.0;
  double get xxxl => 64.0;
}

class FFRadius {
  const FFRadius();
  double get none => 0.0;
  double get xs => 2.0;
  double get sm => 8.0;
  double get md => 14.0;
  double get lg => 20.0;
  double get xl => 24.0;
  double get xxl => 32.0;
  double get full => 9999.0;
}

class FFShadows {
  const FFShadows(this.theme);
  final FlutterFlowTheme theme;
  BoxShadow get sm => const BoxShadow(
      blurRadius: 4.0,
      color: Color(0x08000000),
      offset: Offset(0.0, 2.0),
      spreadRadius: 0.0);
  BoxShadow get md => const BoxShadow(
      blurRadius: 12.0,
      color: Color(0x0D000000),
      offset: Offset(0.0, 4.0),
      spreadRadius: 0.0);
  BoxShadow get lg => const BoxShadow(
      blurRadius: 24.0,
      color: Color(0x14000000),
      offset: Offset(0.0, 8.0),
      spreadRadius: 0.0);
  BoxShadow get xl => const BoxShadow(
      blurRadius: 32.0,
      color: Color(0x1A000000),
      offset: Offset(0.0, 12.0),
      spreadRadius: 0.0);
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null) {
      font = GoogleFonts.getFont(fontFamily,
          fontWeight: fontWeight ?? this.fontWeight,
          fontStyle: fontStyle ?? this.fontStyle);
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
