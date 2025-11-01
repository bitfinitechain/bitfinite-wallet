/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wallet_info_provider.dart';

/// Provides the list of Solana SPL token mint addresses for a wallet.
///
/// This is a family provider that takes a walletId and returns the list of
/// mint addresses from the WalletInfo's otherData.
final pSolanaWalletTokenAddresses = Provider.family<List<String>, String>(
  (ref, walletId) {
    final walletInfo = ref.watch(pWalletInfo(walletId));
    return walletInfo.solanaTokenMintAddresses;
  },
);
