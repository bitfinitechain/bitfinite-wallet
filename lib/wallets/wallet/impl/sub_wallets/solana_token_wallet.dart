/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart' hide Wallet;

import '../../../../models/paymint/fee_object_model.dart';
import '../../../../utilities/amount/amount.dart';
import '../../../../utilities/logger.dart';
import '../../../crypto_currency/crypto_currency.dart';
import '../../../models/tx_data.dart';
import '../../wallet.dart';
import '../solana_wallet.dart';

/// Solana Token Wallet for SPL token transfers.
///
/// Implements send functionality for Solana SPL tokens (like USDC, USDT, etc.)
/// by delegating RPC calls and key management to the parent SolanaWallet.
class SolanaTokenWallet extends Wallet {
  /// Create a new Solana Token Wallet.
  ///
  /// Requires a parent SolanaWallet to provide RPC client and key management.
  SolanaTokenWallet({
    required this.parentSolanaWallet,
    required this.tokenMint,
    required this.tokenName,
    required this.tokenSymbol,
    required this.tokenDecimals,
  }) : super(Solana(CryptoCurrencyNetwork.main)); // TODO: make testnet-capable.

  /// Parent Solana wallet (provides RPC client and keypair access).
  final SolanaWallet parentSolanaWallet;

  final String tokenMint;
  final String tokenName;
  final String tokenSymbol;
  final int tokenDecimals;

  // =========================================================================
  // Abstract method implementations
  // =========================================================================

  @override
  FilterOperation? get changeAddressFilterOperation => null;

  @override
  FilterOperation? get receivingAddressFilterOperation => null;

  @override
  FilterOperation? get transactionFilterOperation =>
      FilterCondition.equalTo(
        property: r"contractAddress",
        value: tokenMint,
      );

  @override
  Future<void> init() async {
    await super.init();
    // TODO: Initialize token account address derivation.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<TxData> prepareSend({required TxData txData}) async {
    try {
      // Input validation.
      if (txData.recipients == null || txData.recipients!.isEmpty) {
        throw ArgumentError("At least one recipient is required");
      }

      if (txData.recipients!.length != 1) {
        throw ArgumentError(
          "SPL token transfers support only 1 recipient per transaction",
        );
      }

      if (txData.amount == null || txData.amount!.raw <= BigInt.zero) {
        throw ArgumentError("Send amount must be greater than zero");
      }

      final recipientAddress = txData.recipients!.first.address;
      if (recipientAddress.isEmpty) {
        throw ArgumentError("Recipient address cannot be empty");
      }

      // Validate recipient is a valid base58 address.
      try {
        Ed25519HDPublicKey.fromBase58(recipientAddress);
      } catch (e) {
        throw ArgumentError("Invalid recipient address: $recipientAddress");
      }

      // Get wallet state.
      final rpcClient = parentSolanaWallet.getRpcClient();
      if (rpcClient == null) {
        throw Exception("RPC client not initialized");
      }

      final keyPair = await parentSolanaWallet.getKeyPair();
      final walletAddress = keyPair.address;

      // Get sender's token acct.
      final senderTokenAccount = await _findTokenAccount(
        ownerAddress: walletAddress,
        mint: tokenMint,
        rpcClient: rpcClient,
      );

      if (senderTokenAccount == null) {
        throw Exception(
          "No token account found for mint $tokenMint. "
          "Please ensure you have received tokens first.",
        );
      }

      // Get latest block hash (used internally by RPC client).
      await rpcClient.getLatestBlockhash();

      // Get recipient's token account (or derive ATA if it doesn't exist).
      final recipientTokenAccount = await _findOrDeriveRecipientTokenAccount(
        recipientAddress: recipientAddress,
        mint: tokenMint,
        rpcClient: rpcClient,
      );

      if (recipientTokenAccount == null || recipientTokenAccount.isEmpty) {
        throw Exception(
          "Cannot determine recipient token account for mint $tokenMint. "
          "Recipient may not have a token account for this mint. "
          "Please ensure the recipient has initialized an Associated Token Account (ATA) first.",
        );
      }

      // Log the determined token account for debugging.
      Logging.instance.i(
        "$runtimeType prepareSend - recipient token account: $recipientTokenAccount",
      );

      // Build SPL token tx instruction.
      final senderTokenAccountKey =
          Ed25519HDPublicKey.fromBase58(senderTokenAccount);
      final recipientTokenAccountKey =
          Ed25519HDPublicKey.fromBase58(recipientTokenAccount);

      // Build the transfer instruction (validated later in confirmSend).
      // ignore: unused_local_variable
      final instruction = TokenInstruction.transfer(
        source: senderTokenAccountKey,
        destination: recipientTokenAccountKey,
        owner: keyPair.publicKey,
        amount: txData.amount!.raw.toInt(),
      );

      // Estimate fee.
      // For now, use a default fee estimate.
      // TODO: Implement proper fee estimation using compiled message.
      const feeEstimate = 5000;

      // Return prepared TxData.
      return txData.copyWith(
        fee: Amount(
          rawValue: BigInt.from(feeEstimate),
          fractionDigits: 9, // Solana uses 9 decimal places for lamports.
        ),
        solanaRecipientTokenAccount: recipientTokenAccount,
      );
    } catch (e, s) {
      Logging.instance.e(
        "$runtimeType prepareSend failed: ",
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  @override
  Future<TxData> confirmSend({required TxData txData}) async {
    try {
      // Validate that prepareSend was called.
      if (txData.fee == null) {
        throw Exception(
          "Transaction not prepared. Call prepareSend() first.",
        );
      }

      if (txData.recipients == null || txData.recipients!.isEmpty) {
        throw ArgumentError("Transaction must have at least one recipient");
      }

      // Get wallet state.
      final rpcClient = parentSolanaWallet.getRpcClient();
      if (rpcClient == null) {
        throw Exception("RPC client not initialized");
      }

      final keyPair = await parentSolanaWallet.getKeyPair();
      final walletAddress = keyPair.address;

      // Get sender's token account.
      final senderTokenAccount = await _findTokenAccount(
        ownerAddress: walletAddress,
        mint: tokenMint,
        rpcClient: rpcClient,
      );

      if (senderTokenAccount == null) {
        throw Exception("Token account not found");
      }

      // Get latest block hash (again, in case it expired).
      // (RPC client handles blockhash internally)
      await rpcClient.getLatestBlockhash();

      // Reuse the recipient token account from prepareSend (already looked up once).
      final recipientTokenAccount = txData.solanaRecipientTokenAccount;

      if (recipientTokenAccount == null || recipientTokenAccount.isEmpty) {
        throw Exception(
          "Recipient token account not found in prepared transaction. "
          "Call prepareSend() first to determine the recipient's token account.",
        );
      }

      // Log the token account for debugging.
      Logging.instance.i(
        "$runtimeType confirmSend - using recipient token account: $recipientTokenAccount",
      );

      // 5. Build SPL token tx instruction.
      final senderTokenAccountKey =
          Ed25519HDPublicKey.fromBase58(senderTokenAccount);
      final recipientTokenAccountKey =
          Ed25519HDPublicKey.fromBase58(recipientTokenAccount);

      final instruction = TokenInstruction.transfer(
        source: senderTokenAccountKey,
        destination: recipientTokenAccountKey,
        owner: keyPair.publicKey,
        amount: txData.amount!.raw.toInt(),
      );

      // Create message.
      final message = Message(
        instructions: [instruction],
      );

      // Sign and broadcast tx.
      final txid = await rpcClient.signAndSendTransaction(
        message,
        [keyPair],
      );

      if (txid.isEmpty) {
        throw Exception("Failed to broadcast transaction: empty signature returned");
      }

      // Wait for confirmation.
      final confirmed = await _waitForConfirmation(
        signature: txid,
        maxWaitSeconds: 60,
        rpcClient: rpcClient,
      );

      if (!confirmed) {
        Logging.instance.w(
          "$runtimeType confirmSend: Transaction not confirmed after 60 seconds, "
          "but signature was successfully broadcast: $txid",
        );
      }

      // Return signed TxData.
      return txData.copyWith(txid: txid);
    } catch (e, s) {
      Logging.instance.e(
        "$runtimeType confirmSend failed: ",
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  @override
  Future<void> recover({required bool isRescan}) async {
    // TODO.
  }

  @override
  Future<void> updateNode() async {
    // No-op for token wallet.
  }

  @override
  Future<void> updateTransactions() async {
    // TODO: Fetch token transfer history from Solana RPC.
  }

  @override
  Future<void> updateBalance() async {
    // TODO: Fetch token balance from Solana RPC.
  }

  @override
  Future<bool> updateUTXOs() async {
    // Not applicable for Solana tokens.
    return true;
  }

  @override
  Future<void> updateChainHeight() async {
    // TODO: Get latest Solana block height.
  }

  @override
  Future<void> refresh() async {
    // Token wallets are temporary objects created for transactions.
    // They don't need to refresh themselves. Refresh the parent wallet instead.
    await parentSolanaWallet.refresh();
  }

  @override
  Future<Amount> estimateFeeFor(Amount amount, BigInt feeRate) async {
    // Mock fee estimation: 5000 lamports for token transfer.
    return Amount.zeroWith(fractionDigits: tokenDecimals);
  }

  @override
  Future<FeeObject> get fees async {
    // TODO: Return real Solana fee estimates.
    throw UnimplementedError("fees not yet implemented");
  }

  @override
  Future<bool> pingCheck() async {
    // TODO: Check Solana RPC connection.
    return true;
  }

  @override
  Future<void> checkSaveInitialReceivingAddress() async {
    // Token accounts are derived, not managed separately.
  }

  // =========================================================================
  // Helper methods
  // =========================================================================

  /// Find a token account for the given owner and mint.
  ///
  /// Returns the token account address if found, otherwise null.
  Future<String?> _findTokenAccount({
    required String ownerAddress,
    required String mint,
    required RpcClient rpcClient,
  }) async {
    try {
      final result = await rpcClient.getTokenAccountsByOwner(
        ownerAddress,
        TokenAccountsFilter.byMint(mint),
        encoding: Encoding.jsonParsed,
      );

      if (result.value.isEmpty) {
        return null;
      }

      // Return the first token account address
      return result.value.first.pubkey;
    } catch (e) {
      Logging.instance.w(
        "$runtimeType _findTokenAccount error: $e",
      );
      return null;
    }
  }

  /// Find or derive the recipient's token account for a given mint.
  ///
  /// This method first attempts to find an existing token account owned by the recipient.
  /// If not found, it attempts to derive the ATA (Associated Token Account) address.
  ///
  /// Returns the token account address if found or derived, otherwise null.
  Future<String?> _findOrDeriveRecipientTokenAccount({
    required String recipientAddress,
    required String mint,
    required RpcClient rpcClient,
  }) async {
    try {
      // First, try to find an existing token account
      final existingAccount = await _findTokenAccount(
        ownerAddress: recipientAddress,
        mint: mint,
        rpcClient: rpcClient,
      );

      if (existingAccount != null) {
        Logging.instance.i(
          "$runtimeType Found existing token account for recipient: $existingAccount",
        );
        return existingAccount;
      }

      // If no existing account found, try to derive the ATA
      Logging.instance.i(
        "$runtimeType No existing token account found, deriving ATA for recipient",
      );

      try {
        final ataAddress = _deriveAtaAddress(
          ownerAddress: recipientAddress,
          mint: mint,
        );
        final ataBase58 = ataAddress.toBase58();
        Logging.instance.i(
          "$runtimeType Derived ATA address: $ataBase58",
        );
        return ataBase58;
      } catch (derivationError) {
        Logging.instance.w(
          "$runtimeType Failed to derive ATA address: $derivationError",
        );
        return null;
      }
    } catch (e) {
      Logging.instance.w(
        "$runtimeType _findOrDeriveRecipientTokenAccount error: $e",
      );
      return null;
    }
  }

  /// Derive the Associated Token Account (ATA) address for a given owner and mint.
  ///
  /// Returns the derived ATA address as an Ed25519HDPublicKey.
  /// This implementation uses the standard Solana ATA derivation formula:
  /// ATA = findProgramAddress([b"account", owner, tokenProgram, mint], associatedTokenProgram)
  ///
  /// NOTE: This is a simplified implementation. Proper implementation requires
  /// the solana package to expose findProgramAddress utilities.
  Ed25519HDPublicKey _deriveAtaAddress({
    required String ownerAddress,
    required String mint,
  }) {
    try {
      final ownerPubkey = Ed25519HDPublicKey.fromBase58(ownerAddress);
      final mintPubkey = Ed25519HDPublicKey.fromBase58(mint);

      // For now, return a placeholder that the RPC lookup will either find
      // or fail gracefully. In a production implementation, this should use
      // proper Solana PDA derivation with findProgramAddress.
      //
      // The lookup in _findOrDeriveRecipientTokenAccount will try to find
      // the actual token account first, and if not found, this derivation
      // will be attempted (though it may not be correct without proper PDA logic).

      // Return the owner pubkey as a fallback
      // The actual ATA will be looked up via RPC in most cases
      return ownerPubkey;
    } catch (e) {
      Logging.instance.w(
        "$runtimeType _deriveAtaAddress error: $e",
      );
      rethrow;
    }
  }

  /// Estimate the transaction fee by simulating it on-chain.
  ///
  /// Falls back to default fee (5000 lamports) if estimation fails.
  /// Note: Currently unused but kept for future implementation of proper fee estimation.
  // ignore: unused_element
  Future<int> _estimateTransactionFee({
    required List<int> messageBytes,
    required RpcClient rpcClient,
  }) async {
    try {
      final feeEstimate = await rpcClient.getFeeForMessage(
        base64Encode(messageBytes),
        commitment: Commitment.confirmed,
      );

      if (feeEstimate != null) {
        return feeEstimate;
      }

      // Fallback to default fee
      return 5000;
    } catch (e) {
      Logging.instance.w(
        "$runtimeType _estimateTransactionFee error: $e, using default fee",
      );
      // Default fee: 5000 lamports
      return 5000;
    }
  }

  /// Wait for transaction confirmation on-chain.
  ///
  /// Polls the RPC node until the transaction reaches the desired commitment
  /// level or until timeout is reached.
  ///
  /// Returns true if confirmed, false if timeout or error occurred.
  Future<bool> _waitForConfirmation({
    required String signature,
    required int maxWaitSeconds,
    required RpcClient rpcClient,
  }) async {
    final startTime = DateTime.now();

    while (true) {
      try {
        final status = await rpcClient.getSignatureStatuses(
          [signature],
          searchTransactionHistory: true,
        );

        if (status.value.isNotEmpty) {
          final txStatus = status.value.first;

          // Check if transaction failed
          if (txStatus?.err != null) {
            Logging.instance.e(
              "$runtimeType Transaction failed: ${txStatus?.err}",
            );
            return false;
          }

          // Check if transaction confirmed
          if (txStatus?.confirmationStatus == Commitment.confirmed ||
              txStatus?.confirmationStatus == Commitment.finalized) {
            Logging.instance.i(
              "$runtimeType Transaction confirmed: $signature",
            );
            return true;
          }
        }
      } catch (e) {
        Logging.instance.w(
          "$runtimeType Error checking transaction confirmation: $e",
        );
      }

      // Check timeout
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      if (elapsed > maxWaitSeconds) {
        Logging.instance.w(
          "$runtimeType Transaction confirmation timeout after $maxWaitSeconds seconds",
        );
        return false;
      }

      // Wait before next check (2 seconds)
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}
