/*
 * This file is part of BitFinite Wallet.
 *
 * The coin's colour, tone-mapped for text on the page ground.
 */

import 'package:flutter/material.dart';

import '../wallets/crypto_currency/coins/bellscoin.dart';
import '../wallets/crypto_currency/coins/bitfinite.dart';
import '../wallets/crypto_currency/coins/pepecoin.dart';
import '../wallets/crypto_currency/crypto_currency.dart';

/// A coin's colour has two jobs with opposite requirements, and using one value
/// for both is what left "See all" unreadable.
///
///   SURFACE  the coin icon, the notification dot, the card on the home screen.
///            The raw brand colour, always — these are fills, and a fill only
///            has to be recognisable.
///   TEXT     a link or label sitting on the page ground. This one has to be
///            legible against that ground, and the raw colour often is not:
///            Bellscoin gold on the light page measures 1.64:1.
///
/// So this returns the TEXT form. Surfaces keep reading pCoinColor directly.
///
/// The three known coins use the values from the design handoff rather than a
/// computed darkening. They were picked by eye as well as by ratio: Bellscoin's
/// #7A5B00 keeps reading as gold, where a purely arithmetic darkening
/// desaturates it toward olive. Measured against the page grounds:
///
///     BitFinite  light #1E4FD0  6.2:1     dark #7FA3FF   9.4:1
///     Pepecoin   light #12793A  5.0:1     dark #4FD07E  10.6:1
///     Bellscoin  light #7A5B00  5.8:1     dark #F3C532  12.4:1
///
/// Anything else falls back to [_toneMapped], so a fourth coin is legible on
/// the day it is added rather than waiting for a design pass. That fallback is
/// the whole reason this is a function and not a constant map.
Color coinAccent(
  CryptoCurrency coin,
  Color coinColor,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;

  if (coin is Bitfinite) {
    return dark ? const Color(0xFF7FA3FF) : const Color(0xFF1E4FD0);
  }
  if (coin is Pepecoin) {
    return dark ? const Color(0xFF4FD07E) : const Color(0xFF12793A);
  }
  if (coin is Bellscoin) {
    return dark ? const Color(0xFFF3C532) : const Color(0xFF7A5B00);
  }

  return _toneMapped(coinColor, dark);
}

/// The page grounds the accent has to survive, from the design handoff.
const Color _pageLight = Color(0xFFEFF1F6);
const Color _pageDark = Color(0xFF12151C);

/// Walks a colour toward black on light, toward white on dark, until it clears
/// AA against the page. Steps of 4% keep the hue and spend only lightness.
Color _toneMapped(Color c, bool dark) {
  final ground = dark ? _pageDark : _pageLight;
  if (_contrast(c, ground) >= 4.5) return c;

  for (double f = 0.96; f >= 0.04; f -= 0.04) {
    final moved = dark
        ? Color.fromARGB(
            255,
            _mix(_ch(c.r), 255, 1 - f),
            _mix(_ch(c.g), 255, 1 - f),
            _mix(_ch(c.b), 255, 1 - f),
          )
        : Color.fromARGB(
            255,
            (_ch(c.r) * f).round(),
            (_ch(c.g) * f).round(),
            (_ch(c.b) * f).round(),
          );
    if (_contrast(moved, ground) >= 4.5) return moved;
  }
  // Nothing in the ramp cleared it: fall back to whichever end is legible
  // rather than returning something unreadable.
  return dark ? Colors.white : const Color(0xFF14161B);
}

int _ch(double component) => (component * 255.0).round();
int _mix(int from, int to, double t) => (from + (to - from) * t).round();

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
