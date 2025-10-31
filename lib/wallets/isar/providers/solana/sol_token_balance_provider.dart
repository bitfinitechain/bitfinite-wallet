import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/balance.dart';
import '../../../../utilities/amount/amount.dart';

/// Provider family for Solana token balance.
/// 
/// Currently returns mock data while API is a WIP.
///
/// Example usage in UI:
///   final balance = ref.watch(
///     pSolanaTokenBalance((walletId: 'wallet1', tokenMint: 'EPjFWaJUwYUoRwzwkH4H8gNB7zHW9tLT6NCKB8S4yh6h'))
///   );
final pSolanaTokenBalance = Provider.family<
    Balance,
    ({String walletId, String tokenMint})>((ref, params) {
  // Mock data for UI development.
  // TODO: when API is ready, this should fetch real balance from SolanaAPI.
  return Balance(
    total: Amount.fromDecimal(
      Decimal.parse("1000.00"),
      fractionDigits: 6,
    ),
    spendable: Amount.fromDecimal(
      Decimal.parse("1000.00"),
      fractionDigits: 6,
    ),
    blockedTotal: Amount.zeroWith(fractionDigits: 6),
    pendingSpendable: Amount.zeroWith(fractionDigits: 6),
  );
});
