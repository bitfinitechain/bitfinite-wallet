/*
 * Re-themes a subtree around one coin's colour.
 *
 * This wallet ships two coins and will ship more, so a screen that belongs to a
 * coin should wear that coin's colour — not a single app-wide accent that makes
 * every wallet look like the same wallet.
 *
 * Done at the theme rather than per button. PrimaryButton alone has 311 call
 * sites; overriding the accent slots in StackColors means every button, switch
 * and link inside the subtree follows automatically, and anything added later
 * follows without being told.
 *
 * Only the accent slots move. Backgrounds, text and status colours are the
 * theme's own, so a coin colour cannot quietly break contrast on a surface it
 * was never chosen against.
 *
 * Routes pushed with Navigator are NOT inside the pushing widget's subtree, so
 * Send, Receive and friends each need their own wrapper. That is why this is a
 * widget and not something applied once at the top.
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tuple/tuple.dart';

import '../models/add_wallet_list_entity/add_wallet_list_entity.dart';
import '../providers/global/wallets_provider.dart';
import '../themes/stack_colors.dart';
import '../themes/theme_providers.dart';
import '../utilities/hero_ink.dart';
import '../wallets/crypto_currency/crypto_currency.dart';

class CoinThemed extends ConsumerWidget {
  const CoinThemed({super.key, required this.coin, required this.child});

  final CryptoCurrency coin;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<StackColors>()!;
    final accent = ref.watch(pCoinColor(coin));

    // pCoinColor already falls back to the theme's own primary for a coin with
    // no published colour, so BFX resolves to exactly what it had. Skipping the
    // rebuild in that case keeps the widget free rather than merely harmless.
    if (accent == colors.buttonBackPrimary) return child;

    // The theme states its own disabled fill, but only for its own primary. Read
    // how far that sits between the primary and the page behind it, then move the
    // coin accent the same distance — so a coin button greys out by however much
    // the active theme greys out, instead of a fraction picked here that would be
    // wrong in half of the seven themes.
    final t = _fade(
      colors.buttonBackPrimary,
      colors.buttonBackPrimaryDisabled,
      colors.background,
    );

    // Every slot below was found the same way rather than by spotting things on
    // screen: dump the two bundled themes and list every token whose value IS
    // the brand blue (#0644F1 light, #2258E6 dark). That is the definition of
    // "an accent slot" in this theme set, and it came to twelve. Picking them
    // off one bug report at a time is how the switch, the radios and the step
    // indicator stayed blue after the buttons were fixed.
    final recoloured =
        colors.copyWith(
              // Fills.
              buttonBackPrimary: accent,
              buttonBackPrimaryDisabled:
                  Color.lerp(accent, colors.background, t)!,
              buttonBackBorder: accent,
              // Controls: the switch, the checkbox, the radio.
              switchBGOn: accent,
              checkboxBGChecked: accent,
              radioButtonIconEnabled: accent,
              radioButtonIconBorder: accent,
              radioButtonBorderEnabled: accent,
              // The wallet-creation flow's step indicator.
              stepIndicatorBGLines: accent,
              stepIndicatorBGCheck: accent,
              stepIndicatorBGNumber: accent,
              // Text and glyphs. accentColorBlue is named for a colour rather
              // than a role, but it is what toggle.dart, options.dart and the
              // tab bar actually reach for when they want the accent, so it
              // follows the coin like the rest.
              accentColorBlue: accent,
              customTextButtonEnabledText: accent,
              infoItemIcons: accent,
              bottomNavIconIconHighlighted: accent,
              numpadBackDefault: accent,
              // Text ON the accent adapts to the accent. The earlier comment
              // here claimed the theme's pairing could stay — true while every
              // coin colour was dark enough for white ink, false the day Bells
              // brought Bell Bag Gold (#F3C532, white 1.64:1): the units
              // editor's Save button shipped white-on-gold. readableInk keeps
              // the theme's ink wherever it genuinely reads and flips to dark
              // ink only where it fails, so BFX and PEP buttons are untouched.
              buttonTextPrimary: readableInk(colors.buttonTextPrimary, accent),
            )
            as StackColors;

    return Theme(
      data: theme.copyWith(extensions: [recoloured]),
      child: child,
    );
  }
}

/// Applies [CoinThemed] to a route when its arguments name a coin.
///
/// Wrapping routes by hand does not hold. Send alone has four argument shapes
/// and only one of them was wrapped, so the screen the dock actually opens kept
/// the app's blue; the same omission then repeated on the add-wallet screen.
/// Every route in RouteGenerator is built by one function, and that function
/// already receives the arguments, so the coin is resolved there once and every
/// route follows — including ones added later, which is the point.
///
/// A route whose arguments name no coin is returned untouched.
class CoinScope extends ConsumerWidget {
  const CoinScope({super.key, required this.args, required this.child});

  final Object? args;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coin = _coinFrom(args, ref);
    return coin == null ? child : CoinThemed(coin: coin, child: child);
  }
}

CryptoCurrency? _coinFrom(Object? args, WidgetRef ref) {
  if (args is CryptoCurrency) return args;
  if (args is AddWalletListEntity) return args.cryptoCurrency;

  // Written against Object? rather than the concrete third type because Dart
  // generics are covariant: Tuple3<String, CryptoCurrency, SendViewAutoFillData>
  // matches, and so does every other payload these routes carry.
  if (args is Tuple2<Object?, CryptoCurrency>) return args.item2;
  if (args is Tuple3<Object?, CryptoCurrency, Object?>) return args.item2;
  if (args is ({CryptoCurrency coin, String walletId})) return args.coin;

  // A bare String is usually a walletId, but plenty of routes take some other
  // string. pWalletCoin ends in findFirstSync()! and would throw on those, so
  // the lookup is done by hand and simply finds nothing when the id is not a
  // wallet — an unthemed route, not a crash.
  if (args is String) {
    for (final w in ref.read(pWallets).wallets) {
      if (w.walletId == args) return w.info.coin;
    }
  }
  return null;
}

/// How far `mid` has travelled from `from` toward `to`, by luminance.
///
/// Falls back to a middling fade when the two ends are equally light, because
/// the ratio is then undefined rather than zero — a theme whose disabled fill
/// differs in hue but not in lightness would otherwise get no fade at all.
double _fade(Color from, Color mid, Color to) {
  final a = from.computeLuminance(), b = to.computeLuminance();
  if ((b - a).abs() < 0.001) return 0.5;
  return ((mid.computeLuminance() - a) / (b - a)).clamp(0.0, 1.0);
}
