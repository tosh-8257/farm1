import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The FARM coin mark in the brand accent. The source asset is a white mark
/// on black; multiplying by the accent turns the mark gold and keeps the
/// black ground. Bundled asset, no network.
class FarmMark extends StatelessWidget {
  const FarmMark({super.key, this.size = 72, this.color = AppTheme.accent});
  final double size;
  final Color color;

  static const asset = 'assets/images/app_logo.png';

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.multiply),
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
    );
  }
}
