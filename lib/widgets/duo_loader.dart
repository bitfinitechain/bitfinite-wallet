import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../themes/stack_colors.dart';
import '../utilities/assets.dart';

/// The BitFinite duo (Miso + Ollie) loading animation — the single brand
/// loader used across every full-screen loading state. Picks the light or dark
/// artwork from the active theme's brightness.
class DuoLoader extends StatelessWidget {
  const DuoLoader({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).extension<StackColors>()!.brightness ==
            Brightness.dark;
    return Lottie.asset(
      isDark ? Assets.lottie.duoLoadingDark : Assets.lottie.duoLoadingLight,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
