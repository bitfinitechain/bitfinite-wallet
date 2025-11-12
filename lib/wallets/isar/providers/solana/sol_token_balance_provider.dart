import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/balance.dart';
import '../../../../utilities/amount/amount.dart';

/// Provider for Solana token balance.
///
/// NOTE: This is a temporary implementation that returns zero balance.
/// TODO: Integrate with Isar database persistence once SolanaTokenWalletInfo
/// model is properly registered in the Isar schema.
///
/// The intent is to follow the Ethereum token balance pattern:
/// - pSolanaTokenWalletInfo: Watches SolanaTokenWalletInfo from database
/// - pSolanaTokenBalance: Returns cached balance from SolanaTokenWalletInfo
///
/// This ensures the UI reactively updates when balances are persisted to the
/// database by SolanaTokenWallet.updateBalance().
///
/// Example usage:
///   final balance = ref.watch(
///     pSolanaTokenBalance((walletId: 'wallet1', tokenMint: 'EPjFWaJUwYUoRwzwkH4H8gNB7zHW9tLT6NCKB8S4yh6h'))
///   );
final pSolanaTokenBalance = Provider.family<
  Balance,
  ({String walletId, String tokenMint})
>((ref, data) {
  // TODO: Replace with database-backed implementation once Isar schema includes
  // SolanaTokenWalletInfo. For now, return zero balance to prevent crashes.
  // This ensures the UI doesn't break while the database layer is being prepared.
  return Balance(
    total: Amount.zeroWith(fractionDigits: 6),
    spendable: Amount.zeroWith(fractionDigits: 6),
    blockedTotal: Amount.zeroWith(fractionDigits: 6),
    pendingSpendable: Amount.zeroWith(fractionDigits: 6),
  );
});
