import 'package:farm/components/farm_mark.dart';
import 'package:farm/core/app_theme.dart';
import 'package:farm/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = {'light': AppTheme.lightTheme(), 'dark': AppTheme.darkTheme()};

  test('one constant: classic gold', () {
    expect(kBrandAccent, const Color(0xFFD4AF37));
    expect(AppTheme.accent, kBrandAccent);
  });

  test('accent text on gold fill meets WCAG AA', () {
    expect(AppTheme.contrastRatio(AppTheme.onAccent, AppTheme.accent), greaterThanOrEqualTo(4.5));
  });

  test('accentOn darkens only as far as needed for AA', () {
    final onWhite = AppTheme.accentOn(Colors.white);
    expect(AppTheme.contrastRatio(onWhite, Colors.white), greaterThanOrEqualTo(4.5));
    expect(AppTheme.accentOn(Colors.black), AppTheme.accent, reason: 'gold on black already passes');
    expect(AppTheme.contrastRatio(AppTheme.accent, Colors.black), greaterThanOrEqualTo(4.5));
  });

  for (final e in themes.entries) {
    final t = e.value;
    group('${e.key} theme', () {
      test('colorScheme secondary is the accent with black on it', () {
        expect(t.colorScheme.secondary, AppTheme.accent);
        expect(t.colorScheme.onSecondary, AppTheme.onAccent);
      });
      test('primary buttons: gold fill, black text', () {
        for (final style in [t.elevatedButtonTheme.style!, t.filledButtonTheme.style!]) {
          final bg = style.backgroundColor!.resolve({})!;
          final fg = style.foregroundColor!.resolve({})!;
          expect(bg, AppTheme.accent);
          expect(AppTheme.contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
        }
      });
      test('selected chips, tab indicator and focus ring use the accent', () {
        expect(t.chipTheme.selectedColor, AppTheme.accent);
        expect(t.tabBarTheme.indicatorColor, AppTheme.accent);
        final focus = (t.inputDecorationTheme.focusedBorder! as OutlineInputBorder).borderSide.color;
        expect(HSLColor.fromColor(focus).hue, closeTo(HSLColor.fromColor(AppTheme.accent).hue, 1));
        expect(AppTheme.contrastRatio(focus, t.colorScheme.surface), greaterThanOrEqualTo(3));
      });
      test('error, success and toggles never use the accent', () {
        expect(t.colorScheme.error, isNot(AppTheme.accent));
        expect(AppTheme.success, isNot(AppTheme.accent));
        expect(t.colorScheme.primary, isNot(AppTheme.accent));
        expect(t.switchTheme.thumbColor!.resolve({WidgetState.selected}), isNot(AppTheme.accent));
        expect(t.checkboxTheme.fillColor!.resolve({WidgetState.selected}), isNot(AppTheme.accent));
      });
    });
  }

  test('FlutterFlow tokens expose the accent', () {
    for (final ff in [LightModeTheme(), DarkModeTheme()]) {
      expect(ff.brandAccent, AppTheme.accent);
      expect(ff.onBrandAccent, AppTheme.onAccent);
      expect(ff.error, isNot(AppTheme.accent));
      expect(ff.success, isNot(AppTheme.accent));
    }
    expect(AppTheme.contrastRatio(LightModeTheme().brandAccentText, AppTheme.lightBackground), greaterThanOrEqualTo(4.5));
    expect(AppTheme.contrastRatio(DarkModeTheme().brandAccentText, AppTheme.darkBackground), greaterThanOrEqualTo(4.5));
  });

  testWidgets('FARM mark is tinted with the accent from a bundled asset', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: FarmMark(size: 40))));
    final f = t.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(f.colorFilter, const ColorFilter.mode(AppTheme.accent, BlendMode.multiply));
    expect(FarmMark.asset, startsWith('assets/'));
  });

  test('primaryButtonStyle is gold with black text', () {
    final style = AppTheme.primaryButtonStyle();
    expect(style.backgroundColor!.resolve({}), AppTheme.accent);
    expect(style.foregroundColor!.resolve({}), AppTheme.onAccent);
  });

  test('gold balance figures stay readable on white admin surfaces', () {
    final gold = AppTheme.accentOn(Colors.white);
    expect(AppTheme.contrastRatio(gold, Colors.white), greaterThanOrEqualTo(4.5));
    expect(AppTheme.contrastRatio(AppTheme.accent, Colors.black), greaterThanOrEqualTo(4.5));
  });
}
