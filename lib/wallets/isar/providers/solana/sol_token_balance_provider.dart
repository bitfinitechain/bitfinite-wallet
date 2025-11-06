import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/balance.dart';
import '../../../../providers/global/wallets_provider.dart';
import '../../../../services/solana/solana_token_api.dart';
import '../../../../utilities/amount/amount.dart';
import '../../../../wallets/wallet/impl/solana_wallet.dart';

/// Provider family for Solana token balance.
///
/// Fetches the token balance from the Solana blockchain via RPC.
///
/// Example usage in UI:
///   final balance = ref.watch(
///     pSolanaTokenBalance((walletId: 'wallet1', tokenMint: 'EPjFWaJUwYUoRwzwkH4H8gNB7zHW9tLT6NCKB8S4yh6h', fractionDigits: 6))
///   );
final pSolanaTokenBalance = FutureProvider.family<
    Balance,
    ({String walletId, String tokenMint, int fractionDigits})>((ref, params) async {
  // Get the wallet from the wallets provider.
  final wallets = ref.watch(pWallets);
  final wallet = wallets.getWallet(params.walletId);

  if (wallet == null || wallet is! SolanaWallet) {
    // Return zero balance if wallet not found or not Solana.
    return Balance(
      total: Amount.zeroWith(fractionDigits: params.fractionDigits),
      spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
      pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
    );
  }

  try {
    // Initialize the SolanaTokenAPI with the RPC client.
    final tokenApi = SolanaTokenAPI();
    final rpcClient = wallet.getRpcClient();

    if (rpcClient == null) {
      // Return zero balance if RPC client not available.
      return Balance(
        total: Amount.zeroWith(fractionDigits: params.fractionDigits),
        spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
        blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
        pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      );
    }

    tokenApi.initializeRpcClient(rpcClient);

    // Get the wallet address.
    final addressObj = await wallet.getCurrentReceivingAddress();
    if (addressObj == null) {
      // Return zero balance if address not found.
      return Balance(
        total: Amount.zeroWith(fractionDigits: params.fractionDigits),
        spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
        blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
        pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      );
    }

    final walletAddress = addressObj.value;

    // Get token accounts for this wallet and mint.
    final accountsResponse = await tokenApi.getTokenAccountsByOwner(
      walletAddress,
      mint: params.tokenMint,
    );

    if (accountsResponse.isError || accountsResponse.value == null || accountsResponse.value!.isEmpty) {
      // Return zero balance if no token accounts found.
      return Balance(
        total: Amount.zeroWith(fractionDigits: params.fractionDigits),
        spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
        blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
        pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      );
    }

    // Get the balance of the first token account.
    final tokenAccountAddress = accountsResponse.value!.first;
    final balanceResponse = await tokenApi.getTokenAccountBalance(tokenAccountAddress);

    if (balanceResponse.isError || balanceResponse.value == null) {
      // Return zero balance if balance fetch failed.
      return Balance(
        total: Amount.zeroWith(fractionDigits: params.fractionDigits),
        spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
        blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
        pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      );
    }

    // Convert the BigInt balance to an Amount with the token's fractional digits.
    final balanceBigInt = balanceResponse.value!;
    final balanceAmount = Amount(
      rawValue: balanceBigInt,
      fractionDigits: params.fractionDigits,
    );

    return Balance(
      total: balanceAmount,
      spendable: balanceAmount,
      blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
      pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
    );
  } catch (e) {
    // Return zero balance if any error occurs.
    print('Error fetching Solana token balance: $e');
    return Balance(
      total: Amount.zeroWith(fractionDigits: params.fractionDigits),
      spendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
      blockedTotal: Amount.zeroWith(fractionDigits: params.fractionDigits),
      pendingSpendable: Amount.zeroWith(fractionDigits: params.fractionDigits),
    );
  }
});
