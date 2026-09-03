/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter/material.dart';

/// Ink for content sitting on the wallet hero: **always white**.
///
/// History, because two earlier rules are in the session notes. It began as
/// white by design direction, when the hero only ever wore one colour.
/// Multi-coin heroes broke that: white on Bellscoin's Bell Bag Gold #F3C532
/// measures 1.64:1, near invisible. The fix then was to adapt the INK, which
/// kept every fill exactly as the brand drew it but flipped the text between
/// white and near-black from coin to coin. Measured: BitFinite white, but
/// Pepecoin and Bellscoin dark. That reads as three different products.
///
/// So the ink is fixed and the SURFACE moves instead: see [heroFill], which
/// deepens a fill only when white would fail on it. One ink everywhere, and a
/// brand colour is only touched when it cannot carry legible text.
Color heroInk(Color hero) => Colors.white;

/// The hero surface for a coin, dark enough for white text.
///
/// Returns [coinColor] untouched when white already passes AA on it, so
/// BitFinite blue (5.43:1) is exactly the brand blue. Otherwise it walks the
/// colour down toward black in 2% steps, which keeps the hue and only spends
/// lightness: Pepecoin green needs a small step, Bellscoin gold a large one.
///
/// This is the hero FILL only. The coin's real colour still paints its icon,
/// its card on the home screen, and the accents, so the brand is intact
/// everywhere it is not being asked to sit under white text.
Color heroFill(Color coinColor) {
  if (_contrast(Colors.white, coinColor) >= 4.5) return coinColor;

  Color scaled = coinColor;
  for (double f = 0.98; f >= 0.2; f -= 0.02) {
    scaled = Color.fromARGB(
      255,
      ((coinColor.r * 255.0).round() * f).round(),
      ((coinColor.g * 255.0).round() * f).round(),
      ((coinColor.b * 255.0).round() * f).round(),
    );
    if (_contrast(Colors.white, scaled) >= 4.5) return scaled;
  }
  return scaled;
}

/// Kept so the hero's de-emphasis steps read the same at every call site.
///
/// The ink is white everywhere now, so the dark-ink mapping this used to
/// carry is gone and the shipped opacities pass straight through.
double heroEmphasis(Color ink, double whiteTunedOpacity) => whiteTunedOpacity;

/// Ink for content on any *other* filled surface — dock pills, the dock itself.
///
/// Unlike the hero, these are not a brand statement, and unreadable text here
/// is a defect rather than a style. The rule is "trust the theme, verify the
/// result": a theme's declared ink is used as-is, and replaced only when it
/// actually fails against the surface it lands on.
///
/// This exists because tokens can disagree with reality. The Orange theme sets
/// `bottom_nav_text` and `popup_bg` to the *same* `#FFFFFF`, so its inactive
/// nav label was painted in the dock's own background — 1.00:1, invisible.
/// No amount of trusting the token fixes that.
///
/// The 4.0 floor sits just under the 4.5 AA line on purpose. Forest puts white
/// at 4.41:1, which reads correctly and was signed off; snapping at 4.5 would
/// restyle Forest over a 0.09 difference. Only genuine failures are replaced.
Color readableInk(Color preferred, Color surface, {double min = 4.0}) {
  if (_contrast(preferred, surface) >= min) return preferred;
  return _contrast(Colors.white, surface) >= _contrast(kInkDark, surface)
      ? Colors.white
      : kInkDark;
}

/// A near-black rather than pure black: on a saturated fill pure black reads as
/// a hole punched in the surface.
const Color kInkDark = Color(0xFF14161A);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
