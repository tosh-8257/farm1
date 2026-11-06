import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The FARM coin mark (F with bars), drawn as a transparent vector and tinted
/// to match the amount next to it. There is no badge or background circle.
///
/// Pass [color] when the amount is the gold accent. Otherwise the mark uses
/// the surrounding text colour so it works on light and dark surfaces.
/// The brand logo on login stays [BrandLogo].
class FarmCoinIcon extends StatelessWidget {
  const FarmCoinIcon({super.key, this.size = 24, this.color});

  /// Height of the mark. Width follows the glyph so it sits beside the text.
  final double size;
  final Color? color;

  static const asset = 'assets/images/farm_coin_mark.svg';

  @override
  Widget build(BuildContext context) {
    final tint = color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      asset,
      width: size * 42 / 89,
      height: size,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: 'FARM',
    );
  }
}
