import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../themes/stack_colors.dart';
import 'assets.dart';

/// Themed "?" help icon used in app bars / inline helpers. The bare
/// `Assets.svg.circleQuestion` bakes a dark color and disappears on dark
/// backgrounds; routing help icons through here guarantees a theme-aware,
/// visible color (and SF Symbol on iOS). Systematic fix for the dark-mode
/// invisible help button.
Widget questionHelpIcon(BuildContext context, {double size = 20, Color? color}) {
  return adaptiveIcon(
    Assets.svg.circleQuestion,
    CupertinoIcons.question_circle,
    size: size,
    color:
        color ?? Theme.of(context).extension<StackColors>()!.topNavIconPrimary,
  );
}

/// Maps the app's settings-row SVG assets to native SF Symbols. Used by
/// [SettingsListButton] so every settings row picks up the iOS icon set in one
/// place. Returns null on non-iOS or for unmapped assets (falls back to SVG).
IconData? cupertinoForSettingAsset(String assetPath) {
  if (!Platform.isIOS) return null;
  return _settingsAssetToCupertino[assetPath];
}

final Map<String, IconData> _settingsAssetToCupertino = <String, IconData>{
  Assets.svg.addressBook: CupertinoIcons.person_2_fill,
  Assets.svg.downloadFolder: CupertinoIcons.arrow_down_doc_fill,
  Assets.svg.lock: CupertinoIcons.lock_fill,
  Assets.svg.dollarSign: CupertinoIcons.money_dollar,
  Assets.svg.language: CupertinoIcons.globe,
  Assets.svg.tor: CupertinoIcons.shield_lefthalf_fill,
  Assets.svg.node: CupertinoIcons.square_stack_3d_up_fill,
  Assets.svg.arrowRotate: CupertinoIcons.arrow_2_circlepath,
  Assets.svg.arrowUpRight: CupertinoIcons.power,
  Assets.svg.sun: CupertinoIcons.paintbrush_fill,
  Assets.svg.circleAlert: CupertinoIcons.trash_fill,
  Assets.svg.ellipsis: CupertinoIcons.info_circle_fill,
  Assets.svg.solidSliders: CupertinoIcons.slider_horizontal_3,
  Assets.svg.key: CupertinoIcons.gear_alt_fill,
  Assets.svg.questionMessage: CupertinoIcons.question_circle_fill,
  Assets.svg.eye: CupertinoIcons.eye_fill,
  Assets.svg.swap: CupertinoIcons.arrow_2_squarepath,
  Assets.svg.peers: CupertinoIcons.person_3_fill,
};

/// Renders a native SF Symbol ([CupertinoIcons]) on iOS, falling back to the
/// app's bundled SVG asset on every other platform. Lets us adopt the native
/// iOS icon set without touching Android/desktop.
Widget adaptiveIcon(
  String svgAsset,
  IconData cupertino, {
  double size = 20,
  Color? color,
}) {
  if (Platform.isIOS) {
    return Icon(cupertino, size: size, color: color);
  }
  return SvgPicture.asset(
    svgAsset,
    width: size,
    height: size,
    color: color,
  );
}
