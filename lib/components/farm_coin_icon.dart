import 'package:flutter/material.dart';

/// FARM coin logo (white rounded square, black F-with-bars mark). Use next to FARM balances and asset rows.
class FarmCoinIcon extends StatelessWidget {
  const FarmCoinIcon({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          size <= 64 ? 'assets/images/farm_coin_128.png' : 'assets/images/farm_coin.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'FARM',
        ),
      );
}
