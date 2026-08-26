import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/utilities/amount/amount.dart';
import 'package:bitfinite/utilities/amount/amount_formatter.dart';
import 'package:bitfinite/utilities/amount/amount_unit.dart';
import 'package:bitfinite/wallets/crypto_currency/coins/bitfinite.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';

void main() {
  final coin = Bitfinite(CryptoCurrencyNetwork.main);

  String show(BigInt raw, {bool trim = false, int maxDecimals = 8}) =>
      AmountUnit.normal.displayAmount(
        amount: Amount(rawValue: raw, fractionDigits: 8),
        locale: "en_US",
        coin: coin,
        maxDecimalPlaces: maxDecimals,
        trimTrailingZeros: trim,
      );

  group("trailing zeros", () {
    test("are kept by default, so nothing else changes", () {
      expect(show(BigInt.from(5000000000)), "50.00000000 BFX");
      expect(show(BigInt.from(1250000000)), "12.50000000 BFX");
    });

    test("are trimmed when asked, leaving a whole number bare", () {
      expect(show(BigInt.from(5000000000), trim: true), "50 BFX");
      expect(show(BigInt.zero, trim: true), "0 BFX");
    });

    test("trim stops at the last significant digit", () {
      expect(show(BigInt.from(1250000000), trim: true), "12.5 BFX");
      expect(show(BigInt.from(123456700), trim: true), "1.234567 BFX");
    });

    test("trimming never drops significant digits", () {
      // 1.23456789 - every place is meaningful, so nothing may be removed.
      expect(show(BigInt.from(123456789), trim: true), "1.23456789 BFX");
    });

    test("a fully trimmed remainder leaves no dangling separator", () {
      final out = show(BigInt.from(700000000), trim: true);
      expect(out, "7 BFX");
      expect(out.contains("."), isFalse);
      expect(out.contains(","), isFalse);
    });

    test("trimming does not suppress the precision-loss marker", () {
      // More precision than maxDecimalPlaces can show: still approximate.
      final out = show(BigInt.from(123456789), trim: true, maxDecimals: 4);
      expect(out.startsWith("~"), isTrue, reason: "still a rounded value");
    });
  });

  group("signedAmountLabel", () {
    test("keeps a plain sign flush against the digits", () {
      expect(signedAmountLabel("+", "50 BFX"), "+50 BFX");
      expect(signedAmountLabel("-", "50 BFX"), "-50 BFX");
      expect(signedAmountLabel("", "50 BFX"), "50 BFX");
    });

    test("hoists the approximation marker out of the sign's way", () {
      // The bug: "-" + "~1.234,5678" read as "-~1.234,5678".
      expect(
        signedAmountLabel("-", "~1.234567 BFX"),
        "≈ -1.234567 BFX",
      );
      expect(signedAmountLabel("+", "~0.5 BFX"), "≈ +0.5 BFX");
    });

    test("never emits the sign/tilde collision", () {
      for (final prefix in ["+", "-", ""]) {
        expect(signedAmountLabel(prefix, "~1.5 BFX").contains("~"), isFalse);
        expect(signedAmountLabel(prefix, "~1.5 BFX").contains("-~"), isFalse);
      }
    });
  });
}
