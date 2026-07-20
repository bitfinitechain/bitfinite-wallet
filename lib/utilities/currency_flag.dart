/// Best-effort national flag emoji for an ISO-4217 currency code.
///
/// The first two letters of a currency code are almost always the ISO-3166
/// country code (USD -> US, AUD -> AU, EUR -> EU), which maps directly onto the
/// regional-indicator code points that render as a flag. Returns null for codes
/// that have no country (X-prefixed metals/special drawing rights such as XAU,
/// XAG, XDR) so callers can fall back gracefully.
String? currencyFlagEmoji(String currencyCode) {
  if (currencyCode.length < 2) return null;

  final code = currencyCode.substring(0, 2).toUpperCase();

  // X-prefixed codes are metals / special units, not countries.
  if (code.startsWith("X")) return null;

  final first = code.codeUnitAt(0);
  final second = code.codeUnitAt(1);

  const a = 0x41; // 'A'
  const z = 0x5A; // 'Z'
  if (first < a || first > z || second < a || second > z) return null;

  const regionalIndicatorA = 0x1F1E6;
  return String.fromCharCodes([
    regionalIndicatorA + (first - a),
    regionalIndicatorA + (second - a),
  ]);
}
