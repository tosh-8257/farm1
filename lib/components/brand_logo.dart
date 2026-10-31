import 'package:flutter/material.dart';

/// The FARM brand logo (the original app logo, `assets/images/app_logo.png`).
///
/// Use for app branding: splash, login, register, onboarding, headers and
/// About. For the FARM token itself (balances, asset rows, receive screen)
/// use `FarmCoinIcon` instead.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});

  static const asset = 'assets/images/app_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size / 3),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'FARM',
        ),
      );
}
