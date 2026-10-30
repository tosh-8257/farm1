import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'business_ui.dart';
import 'business_onboarding_page.dart';

/// Entry point from the Merchant Portal into the Merchant -> Business upgrade.
class BusinessUpgradeTile extends StatelessWidget {
  const BusinessUpgradeTile({super.key});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => context.pushNamed(BusinessOnboardingPage.routeName),
    child: BizCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.business_center_outlined, color: fgColor(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Business',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verify your business (KYB) to unlock business tools.',
                  style: TextStyle(fontSize: 13, color: mutedColor(context)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: mutedColor(context)),
        ],
      ),
    ),
  );
}
