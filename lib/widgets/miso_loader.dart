import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../themes/stack_colors.dart';
import '../utilities/assets.dart';

/// The BitFinite "Miso the Cat" loading spinner — the brand loader used across
/// full-screen loading states. Picks the light or dark artwork from the active
/// theme's brightness.
class MisoLoader extends StatelessWidget {
  const MisoLoader({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).extension<StackColors>()!.brightness ==
            Brightness.dark;
    return Lottie.asset(
      isDark ? Assets.lottie.misoLoadingDark : Assets.lottie.misoLoading,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
