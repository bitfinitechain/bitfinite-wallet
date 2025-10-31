/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:isar_community/isar.dart';

import '../../../../models/paymint/fee_object_model.dart';
import '../../../../utilities/amount/amount.dart';
import '../../../crypto_currency/crypto_currency.dart';
import '../../../models/tx_data.dart';
import '../../wallet.dart';

/// Mock Solana Token Wallet for UI development.
///
/// TODO: Complete implementation with real balance fetching, transaction
/// handling, and fee estimation when SolanaAPI is ready.
class SolanaTokenWallet extends Wallet {
  /// Mock wallet for testing UI.
  SolanaTokenWallet({
    required this.tokenMint,
    required this.tokenName,
    required this.tokenSymbol,
    required this.tokenDecimals,
  }) : super(Solana(CryptoCurrencyNetwork.main)); // TODO: make testnet-capable.

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
  Future<void> init() async {
    await super.init();
    // TODO: Initialize token account address derivation.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<TxData> prepareSend({required TxData txData}) async {
    // TODO: Build SPL token transfer instruction.
    throw UnimplementedError("prepareSend not yet implemented");
  }

  @override
  Future<TxData> confirmSend({required TxData txData}) async {
    // TODO: Sign and broadcast SPL token transfer.
    throw UnimplementedError("confirmSend not yet implemented");
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
}
