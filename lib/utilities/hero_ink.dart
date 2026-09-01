/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter/material.dart';

/// Ink for content sitting on the wallet hero — adaptive since 2026-09-01.
///
/// History, because the old rule is in session notes as "do not fix": this
/// was **always white by design direction** when the hero only ever wore the
/// theme's own colour. Multi-coin heroes broke that premise — Bellscoin's
/// official Bell Bag Gold #F3C532 puts white ink at 1.64:1, and the first
/// "fix" (darkening the surface) traded away the brand colour. The user then
/// asked for a rule that works for ANY coin colour, which is this:
///
/// **White when white passes AA (>= 4.5:1); otherwise whichever of white and
/// near-black ink carries more contrast.** BFX blue keeps white ink
/// unchanged; Bells gold and Doge-like golds take dark ink; Pepecoin's
/// mid-green — where white had been quietly failing at 3.57:1 — flips to
/// dark ink and finally passes. The 4.5 gate (rather than a pure max) keeps
/// white, the product's signature look, wherever it is legitimate.
///
/// Everything on the hero must derive from this one value (and scale its
/// de-emphasis through [heroEmphasis]) — never from the page theme.
Color heroInk(Color hero) {
  final white = _contrast(Colors.white, hero);
  if (white >= 4.5) return Colors.white;
  return _contrast(kInkDark, hero) > white ? kInkDark : Colors.white;
}

/// Maps a white-ink de-emphasis opacity to the dark-ink equivalent.
///
/// The shipped opacities (0.80 labels, 0.78 fiat, 0.62 dust, 0.85 unit,
/// 0.92 address) were measured against white-on-blue. Dark ink on a
/// mid-luminance fill has less headroom — on Pepecoin green, dark ink at
/// 0.80 lands at 3.91:1 — so each step rides higher. Measured on the two
/// worst supported fills (Pepecoin #269B4D, Bells gold #F3C532):
/// labels 0.90 -> 4.54/9.05, fiat 0.88 -> 4.41 (the Forest precedent)/8.65,
/// dust 0.75 -> 3.64/6.09 (large-text floor), unit 0.92 -> 4.6+/9.5,
/// address 0.95 -> 4.80/10.1. Scrim/fill opacities (<= 0.25) pass through
/// untouched: they are surfaces, not text.
double heroEmphasis(Color ink, double whiteTunedOpacity) {
  if (ink == Colors.white) return whiteTunedOpacity;
  // Not a const map: double keys are const_map_key_not_primitive_equality.
  if (whiteTunedOpacity == 0.8) return 0.9;
  if (whiteTunedOpacity == 0.78) return 0.88;
  if (whiteTunedOpacity == 0.62) return 0.75;
  if (whiteTunedOpacity == 0.85) return 0.92;
  if (whiteTunedOpacity == 0.92) return 0.95;
  return whiteTunedOpacity;
}

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
