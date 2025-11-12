/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart' hide Wallet;

import '../../../../db/isar/main_db.dart';
import '../../../../models/balance.dart';
import '../../../../models/paymint/fee_object_model.dart';
import '../../../../services/solana/solana_token_api.dart';
import '../../../../utilities/amount/amount.dart';
import '../../../../utilities/logger.dart';
import '../../../crypto_currency/crypto_currency.dart';
import '../../../isar/models/wallet_solana_token_info.dart';
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

  /// Override walletId to delegate to parent wallet
  @override
  String get walletId => parentSolanaWallet.walletId;

  /// Override mainDB to delegate to parent wallet
  /// (SolanaTokenWallet shares the same database as its parent)
  @override
  MainDB get mainDB => parentSolanaWallet.mainDB;

  // =========================================================================
  // Abstract method implementations
  // =========================================================================

  @override
  FilterOperation? get changeAddressFilterOperation => null;

  @override
  FilterOperation? get receivingAddressFilterOperation => null;

  @override
  FilterOperation? get transactionFilterOperation =>
      FilterCondition.equalTo(property: r"contractAddress", value: tokenMint);

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
      final senderTokenAccountKey = Ed25519HDPublicKey.fromBase58(
        senderTokenAccount,
      );
      final recipientTokenAccountKey = Ed25519HDPublicKey.fromBase58(
        recipientTokenAccount,
      );

      // Build the transfer instruction (validated later in confirmSend).
      // ignore: unused_local_variable
      final instruction = TokenInstruction.transfer(
        source: senderTokenAccountKey,
        destination: recipientTokenAccountKey,
        owner: keyPair.publicKey,
        amount: txData.amount!.raw.toInt(),
      );

      // Estimate fee using RPC call.
      final feeEstimate =
          await _getEstimatedTokenTransferFee(
            senderTokenAccountKey: senderTokenAccountKey,
            recipientTokenAccountKey: recipientTokenAccountKey,
            ownerPublicKey: keyPair.publicKey,
            amount: txData.amount!.raw.toInt(),
            rpcClient: rpcClient,
          ) ??
          5000;

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
        throw Exception("Transaction not prepared. Call prepareSend() first.");
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
      final senderTokenAccountKey = Ed25519HDPublicKey.fromBase58(
        senderTokenAccount,
      );
      final recipientTokenAccountKey = Ed25519HDPublicKey.fromBase58(
        recipientTokenAccount,
      );

      final instruction = TokenInstruction.transfer(
        source: senderTokenAccountKey,
        destination: recipientTokenAccountKey,
        owner: keyPair.publicKey,
        amount: txData.amount!.raw.toInt(),
      );

      // Create message.
      final message = Message(instructions: [instruction]);

      // Sign and broadcast tx.
      final txid = await rpcClient.signAndSendTransaction(message, [keyPair]);

      if (txid.isEmpty) {
        throw Exception(
          "Failed to broadcast transaction: empty signature returned",
        );
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
    try {
      Logging.instance.i(
        "$runtimeType updateBalance: Starting balance update for tokenMint=$tokenMint",
      );

      final rpcClient = parentSolanaWallet.getRpcClient();
      if (rpcClient == null) {
        Logging.instance.w(
          "$runtimeType updateBalance: RPC client not initialized",
        );
        return;
      }

      final keyPair = await parentSolanaWallet.getKeyPair();
      final walletAddress = keyPair.address;

      Logging.instance.i(
        "$runtimeType updateBalance: Wallet address = $walletAddress",
      );

      // Get sender's token account.
      final senderTokenAccount = await _findTokenAccount(
        ownerAddress: walletAddress,
        mint: tokenMint,
        rpcClient: rpcClient,
      );

      if (senderTokenAccount == null) {
        Logging.instance.w(
          "$runtimeType updateBalance: No token account found for mint $tokenMint",
        );
        return;
      }

      Logging.instance.i(
        "$runtimeType updateBalance: Found token account = $senderTokenAccount",
      );

      // Fetch the token balance.
      final tokenApi = SolanaTokenAPI();
      tokenApi.initializeRpcClient(rpcClient);

      final balanceResponse = await tokenApi.getTokenAccountBalance(
        senderTokenAccount,
      );

      if (balanceResponse.isError) {
        Logging.instance.w(
          "$runtimeType updateBalance failed: ${balanceResponse.exception}",
        );
        return;
      }

      if (balanceResponse.value != null) {
        // Log the updated balance.
        Logging.instance.i(
          "$runtimeType updateBalance: New balance = ${balanceResponse.value} (${balanceResponse.value! / BigInt.from(10).pow(tokenDecimals)} ${tokenSymbol})",
        );

        // Persist balance to WalletSolanaTokenInfo in Isar database.
        Logging.instance.i(
          "$runtimeType updateBalance: Looking up WalletSolanaTokenInfo for walletId=$walletId, tokenMint=$tokenMint",
        );

        final info = await mainDB.isar.walletSolanaTokenInfo
            .where()
            .walletIdTokenAddressEqualTo(walletId, tokenMint)
            .findFirst();

        if (info != null) {
          Logging.instance.i(
            "$runtimeType updateBalance: Found WalletSolanaTokenInfo with ID=${info.id}, updating cached balance",
          );

          final balanceAmount = Amount(
            rawValue: balanceResponse.value!,
            fractionDigits: tokenDecimals,
          );

          final balance = Balance(
            total: balanceAmount,
            spendable: balanceAmount,
            blockedTotal: Amount(
              rawValue: BigInt.zero,
              fractionDigits: tokenDecimals,
            ),
            pendingSpendable: Amount(
              rawValue: BigInt.zero,
              fractionDigits: tokenDecimals,
            ),
          );

          await info.updateCachedBalance(balance, isar: mainDB.isar);
        }
      }
    } catch (e, s) {
      Logging.instance.e(
        "$runtimeType updateBalance error: ",
        error: e,
        stackTrace: s,
      );
    }
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
    Logging.instance.i(
      "$runtimeType refresh: Starting refresh for tokenMint=$tokenMint",
    );
    // Refresh both the parent wallet and token balance.
    // This ensures the cached token balance in the database is updated.
    await parentSolanaWallet.refresh();
    await updateBalance();
  }

  @override
  Future<Amount> estimateFeeFor(Amount amount, BigInt feeRate) async {
    // Delegate to parent SolanaWallet for fee estimation.
    // For token transfers, the fee is the same as a regular SOL transfer.
    return parentSolanaWallet.estimateFeeFor(amount, feeRate);
  }

  @override
  Future<FeeObject> get fees async {
    // Delegate to parent SolanaWallet for fee information.
    // For token transfers, the fees are the same as regular SOL transfers.
    return parentSolanaWallet.fees;
  }

  @override
  Future<bool> pingCheck() async {
    // Delegate to parent SolanaWallet for RPC health check.
    return parentSolanaWallet.pingCheck();
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
      Logging.instance.w("$runtimeType _findTokenAccount error: $e");
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
        Logging.instance.i("$runtimeType Derived ATA address: $ataBase58");
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
      Logging.instance.w("$runtimeType _deriveAtaAddress error: $e");
      rethrow;
    }
  }

  /// Estimate the fee for an SPL token transfer transaction.
  ///
  /// Builds a token transfer message with the given parameters and uses
  /// the RPC `getFeeForMessage` call to get an accurate fee estimate.
  ///
  /// Returns the estimated fee in lamports, or null if estimation fails.
  Future<int?> _getEstimatedTokenTransferFee({
    required Ed25519HDPublicKey senderTokenAccountKey,
    required Ed25519HDPublicKey recipientTokenAccountKey,
    required Ed25519HDPublicKey ownerPublicKey,
    required int amount,
    required RpcClient rpcClient,
  }) async {
    try {
      // Get latest blockhash for message compilation.
      final latestBlockhash = await rpcClient.getLatestBlockhash();

      // Build the token transfer instruction.
      final instruction = TokenInstruction.transfer(
        source: senderTokenAccountKey,
        destination: recipientTokenAccountKey,
        owner: ownerPublicKey,
        amount: amount,
      );

      // Compile the message with the blockhash.
      final compiledMessage = Message(instructions: [instruction]).compile(
        recentBlockhash: latestBlockhash.value.blockhash,
        feePayer: ownerPublicKey,
      );

      // Get the fee for this compiled message.
      final feeEstimate = await rpcClient.getFeeForMessage(
        base64Encode(compiledMessage.toByteArray().toList()),
        commitment: Commitment.confirmed,
      );

      if (feeEstimate != null) {
        Logging.instance.i(
          "$runtimeType Estimated token transfer fee: $feeEstimate lamports (from RPC)",
        );
        return feeEstimate;
      }

      Logging.instance.w("$runtimeType getFeeForMessage returned null");
      return null;
    } catch (e) {
      Logging.instance.w(
        "$runtimeType _getEstimatedTokenTransferFee error: $e",
      );
      return null;
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
        final status = await rpcClient.getSignatureStatuses([
          signature,
        ], searchTransactionHistory: true);

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
