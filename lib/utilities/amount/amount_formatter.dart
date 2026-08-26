import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/isar/models/contract.dart';
import '../../providers/global/locale_provider.dart';
import '../../providers/global/prefs_provider.dart';
import '../../wallets/crypto_currency/crypto_currency.dart';
import 'amount.dart';
import 'amount_unit.dart';

final pAmountUnit = Provider.family<AmountUnit, CryptoCurrency>(
  (ref, coin) => ref.watch(
    prefsChangeNotifierProvider.select((value) => value.amountUnit(coin)),
  ),
);
final pMaxDecimals = Provider.family<int, CryptoCurrency>(
  (ref, coin) => ref.watch(
    prefsChangeNotifierProvider.select((value) => value.maxDecimals(coin)),
  ),
);

final pAmountFormatter = Provider.family<AmountFormatter, CryptoCurrency>((
  ref,
  coin,
) {
  final locale = ref.watch(
    localeServiceChangeNotifierProvider.select((value) => value.locale),
  );

  return AmountFormatter(
    unit: ref.watch(pAmountUnit(coin)),
    locale: locale,
    coin: coin,
    maxDecimals: ref.watch(pMaxDecimals(coin)),
  );
});

/// Composes a signed amount label from a sign [prefix] ("+", "-" or "") and an
/// already-[formatted] amount.
///
/// The formatter marks a rounded value by prefixing "~". Concatenating a sign
/// in front of that produces "-~1.234,5678", which reads as a typo rather than
/// as "approximately minus 1,234.5678". Hoist the marker out so the sign sits
/// against its own digits, and use the real "almost equal to" glyph while we
/// are here.
String signedAmountLabel(String prefix, String formatted) {
  if (formatted.startsWith("~")) {
    return "≈ $prefix${formatted.substring(1)}";
  }
  return "$prefix$formatted";
}

class AmountFormatter {
  final AmountUnit unit;
  final String locale;
  final CryptoCurrency coin;
  final int maxDecimals;

  AmountFormatter({
    required this.unit,
    required this.locale,
    required this.coin,
    required this.maxDecimals,
  });

  String format(
    Amount amount, {
    String? overrideUnit,
    Contract? tokenContract,
    bool withUnitName = true,
    bool indicatePrecisionLoss = true,
    bool trimTrailingZeros = false,
  }) {
    return unit.displayAmount(
      amount: amount,
      locale: locale,
      coin: coin,
      maxDecimalPlaces: maxDecimals,
      withUnitName: withUnitName,
      indicatePrecisionLoss: indicatePrecisionLoss,
      trimTrailingZeros: trimTrailingZeros,
      overrideUnit: overrideUnit,
      tokenContract: tokenContract,
    );
  }

  Amount? tryParse(String string, {Contract? tokenContract}) {
    return unit.tryParse(
      string,
      locale: locale,
      coin: coin,
      tokenContract: tokenContract,
    );
  }
}
