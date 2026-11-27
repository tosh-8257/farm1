import 'package:farm/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _surfaces = [
  'Personal home',
  'Merchant Portal',
  'Business hub',
  'Wallet',
  'Payments',
  'QR receive',
  'Mkulima',
  'Projects',
  'Settings',
  'Cargo',
  'Dropshipping',
];

/// Fine-line sample of the screens listed in Module 17 P13.
/// [after] uses the gold hairline token. [before] uses the previous grey line.
class GoldLineBoard extends StatelessWidget {
  const GoldLineBoard({super.key, required this.after});

  final bool after;

  @override
  Widget build(BuildContext context) {
    final line = after ? AppTheme.hairline : const Color(0xFFB0B6BE);
    final ink = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(after ? 'After · gold hairline' : 'Before · grey line',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ink)),
          const SizedBox(height: 8),
          for (final name in _surfaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 130, child: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink))),
                Expanded(child: Divider(color: line, thickness: 1, height: 1)),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: line, width: 1),
                  ),
                  child: Text('Aa', style: TextStyle(fontSize: 10, color: ink)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: line, width: 1.5),
                  ),
                  child: Text('Selected', style: TextStyle(fontSize: 10, color: ink)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: LinearProgressIndicator(
                    value: 0.55,
                    color: line,
                    backgroundColor: line.withValues(alpha: 0.25),
                    minHeight: 3,
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('writes gold review boards for both themes', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final after in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          key: ValueKey(mode),
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: mode,
          home: Builder(builder: (context) {
            final background = Theme.of(context).scaffoldBackgroundColor;
            return Scaffold(
              backgroundColor: background,
              body: SizedBox.expand(
                child: RepaintBoundary(
                  key: const Key('gold-board'),
                  child: ColoredBox(
                    color: background,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: GoldLineBoard(after: after),
                    ),
                  ),
                ),
              ),
            );
          }),
        ));
        await tester.pump();
        final painted = Theme.of(tester.element(find.byKey(const Key('gold-board')))).scaffoldBackgroundColor;
        expect(painted, mode == ThemeMode.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
        final label = '${after ? 'after' : 'before'}-${mode.name}.png';
        await expectLater(
          find.byKey(const Key('gold-board')),
          matchesGoldenFile('../docs/gold-review/$label'),
        );
      }
    }
  });

  testWidgets('theme outlines and progress use the gold hairline', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: Column(children: [
        OutlinedButton(onPressed: () {}, child: const Text('Outline')),
        const LinearProgressIndicator(value: 0.4),
        const Divider(),
      ])),
    ));
    final theme = Theme.of(tester.element(find.byType(OutlinedButton)));
    final side = theme.outlinedButtonTheme.style?.side?.resolve(const <WidgetState>{});
    expect(side?.color, AppTheme.hairline);
    expect(side?.width, 1);
    final progress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(progress.color ?? Theme.of(tester.element(find.byType(LinearProgressIndicator))).progressIndicatorTheme.color,
        AppTheme.hairline);
  });
}
