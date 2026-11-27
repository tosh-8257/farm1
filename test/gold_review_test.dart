import 'package:farm/core/app_theme.dart';
import 'package:farm/pages/ecosystem/ecosystem_flows.dart';
import 'package:farm/pages/ecosystem/ecosystem_logic.dart';
import 'package:farm/pages/ecosystem/ecosystem_pages.dart';
import 'package:farm/pages/merchant_portal/merchant_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real screens in light and dark', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final screens = <String, Widget Function()>{
      'merchant-portal': () => MerchantPortalPage(
            previewFlags: const EcosystemFlags(dropship: true, cargo: true, orders: true, catalogue: true),
          ),
      'cargo': () => const CargoPage(history: true, addresses: true),
      'dropship-sales': () => DropshipSalesPage(previewOrders: [
            {'id': '1', 'status': 'placed', 'retail_total': 120, 'supplier_total': 80, 'commission_farm': 8},
          ]),
      'pay-breakdown': () => Scaffold(
            body: FeeBreakdown(orderFeeLines({
              'retail_total': 120,
              'supplier_total': 80,
              'commission_farm': 8,
            })),
          ),
      'partner-portal': () => PartnerPortalPage(previewJobs: [
            {'id': 'j1', 'status': 'open', 'from_zone': 'Nairobi', 'to_zone': 'Mombasa'},
          ]),
      'shipment': () => ShipmentStatusPage(
            shipment: const {'id': 's1', 'status': 'booked', 'price_farm': 40, 'eta': null, 'maps_verified': false},
            previewDetail: const {
              'data': {
                'status': 'booked',
                'price_farm': 40,
                'eta': null,
                'maps_verified': false,
                'timeline': [
                  {'status': 'quoted', 'note': 'Quote accepted'},
                  {'status': 'booked', 'note': 'Booked'},
                ],
              },
            },
          ),
    };
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in screens.entries) {
        await tester.pumpWidget(MaterialApp(
          key: ValueKey('${mode.name}-${screen.key}'),
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: mode,
          home: screen.value(),
        ));
        await tester.pump();
        final painted = Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
        expect(painted, mode == ThemeMode.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
        await expectLater(
          find.byType(Scaffold).first,
          matchesGoldenFile('../docs/gold-review/${screen.key}-${mode.name}.png'),
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
    expect(
      progress.color ?? Theme.of(tester.element(find.byType(LinearProgressIndicator))).progressIndicatorTheme.color,
      AppTheme.hairline,
    );
  });
}
