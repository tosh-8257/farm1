import 'package:flutter/material.dart';

import '/pages/business/ops/ops_ui.dart';
import '/pages/ecosystem/ecosystem_pages.dart';
import '/pages/merchant_dashboard/merchant_dashboard_widget.dart';
import '/pages/merchant_sales/merchant_sales_widget.dart';
import '/pages/notifications/user_notifications_page_widget.dart';
import '/pages/profile_settings/profile_settings_widget.dart';
import '/pages/settings/support_help_center_page.dart';

/// Merchant Portal areas. Existing QR, sales, and settlement screens stay
/// as they are. QR collection still credits the owner's personal balance.
class MerchantArea {
  const MerchantArea(this.title, this.detail);
  final String title;
  final String detail;
}

const merchantPortalAreas = <MerchantArea>[
  MerchantArea('Dashboard', 'Sales overview, QR collection, and recent sales.'),
  MerchantArea('Sales history', 'Payments already collected. Receipts open from each row.'),
  MerchantArea('QR collection', 'The same QR. Payments still credit your personal FARM balance.'),
  MerchantArea('Profile and verification', 'Account and identity status.'),
  MerchantArea('Notifications', 'Payment alerts.'),
  MerchantArea('Help', 'Support and questions.'),
  MerchantArea('Dropshipping, cargo, supplier', 'Shown only when this server has those routes.'),
];

class MerchantPortalPage extends StatelessWidget {
  const MerchantPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final areas = <(MerchantArea, Widget)>[
      (merchantPortalAreas[0], const MerchantDashboardWidget()),
      (merchantPortalAreas[1], const MerchantSalesWidget()),
      (merchantPortalAreas[2], const MerchantDashboardWidget()),
      (merchantPortalAreas[3], const ProfileSettingsWidget()),
      (merchantPortalAreas[4], const UserNotificationsPageWidget()),
      (merchantPortalAreas[5], const SupportHelpCenterPageWidget()),
    ];
    return BizScaffold(
      title: 'Merchant Portal',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text(
          'QR sales still settle to your personal wallet. Fees are unchanged.',
          style: TextStyle(color: mutedColor(context)),
        ),
        const SizedBox(height: 12),
        for (final area in areas)
          BizTile(
            title: area.$1.title,
            subtitle: area.$1.detail,
            onTap: () => pushPage(context, area.$2),
          ),
        const SizedBox(height: 8),
        Text(merchantPortalAreas[6].title, style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        Text(merchantPortalAreas[6].detail, style: TextStyle(color: mutedColor(context), fontSize: 12)),
        const SizedBox(height: 8),
        const EcosystemTools(),
      ]),
    );
  }
}
