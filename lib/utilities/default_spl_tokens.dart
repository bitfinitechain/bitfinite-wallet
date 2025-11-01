/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import '../models/isar/models/solana/spl_token.dart';

abstract class DefaultSplTokens {
  static List<SplToken> list = [
    SplToken(
      address: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
      name: "USD Coin",
      symbol: "USDC",
      decimals: 6,
      logoUri: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v/logo.png",
    ),
    SplToken(
      address: "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenEst",
      name: "Tether",
      symbol: "USDT",
      decimals: 6,
      logoUri: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenEst/logo.svg",
    ),
    SplToken(
      address: "MangoCzJ36AjZyKwVj3VnYU4GTonjfVEnJmvvWaxLac",
      name: "Mango",
      symbol: "MNGO",
      decimals: 6,
      logoUri: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/MangoCzJ36AjZyKwVj3VnYU4GTonjfVEnJmvvWaxLac/logo.png",
    ),
    SplToken(
      address: "SRMuApVgqbCmmp3uVrwpad5p4stLBUq3nSoSnqQQXmk",
      name: "Serum",
      symbol: "SRM",
      decimals: 6,
      logoUri: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/SRMuApVgqbCmmp3uVrwpad5p4stLBUq3nSoSnqQQXmk/logo.png",
    ),
    SplToken(
      address: "orca8TvxvggsCKvVPXSHXDvKgJ3bNroWusDawg461mpD",
      name: "Orca",
      symbol: "ORCA",
      decimals: 6,
      logoUri: "https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/orcaEKTdK7LKz57chYcSKdBI6qrE5dS1zG4FqHWGcKc/logo.svg",
    ),
  ];
}
