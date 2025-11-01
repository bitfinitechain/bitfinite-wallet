/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:solana/solana.dart';

/// Exception for Solana token API errors.
class SolanaTokenApiException implements Exception {
  final String message;
  final Exception? originalException;

  SolanaTokenApiException(
    this.message, {
    this.originalException,
  });

  @override
  String toString() => 'SolanaTokenApiException: $message';
}

/// Response wrapper for Solana token API calls.
/// 
/// Follows the pattern that the result is either value or exception
class SolanaTokenApiResponse<T> {
  final T? value;
  final Exception? exception;

  SolanaTokenApiResponse({
    this.value,
    this.exception,
  });

  bool get isSuccess => exception == null && value != null;
  bool get isError => exception != null;

  @override
  String toString() =>
      isSuccess ? 'Success($value)' : 'Error($exception)';
}

/// Data class for token account information.
class TokenAccountInfo {
  final String address;
  final String owner;
  final String mint;
  final BigInt balance;
  final int decimals;
  final bool isNative;

  TokenAccountInfo({
    required this.address,
    required this.owner,
    required this.mint,
    required this.balance,
    required this.decimals,
    required this.isNative,
  });

  factory TokenAccountInfo.fromJson(String address, Map<String, dynamic> json) {
    Map<String, dynamic>? parsed;
    Map<String, dynamic>? infoMap;

    try {
      final data = json['data'];
      if (data is Map) {
        final dataMap = Map<String, dynamic>.from(data);
        final parsedVal = dataMap['parsed'];
        if (parsedVal is Map) {
          parsed = Map<String, dynamic>.from(parsedVal);
        }
      }
      if (parsed != null) {
        final infoVal = parsed['info'];
        if (infoVal is Map) {
          infoMap = Map<String, dynamic>.from(infoVal);
        }
      }
    } catch (e) {
      // Silently ignore parsing errors, use empty map
    }

    final info = infoMap ?? <String, dynamic>{};

    final owner = info['owner'];
    final mint = info['mint'];
    final tokenAmount = info['tokenAmount'];
    final amountStr = (tokenAmount is Map) ? (tokenAmount as Map<String, dynamic>)['amount'] : null;
    final decimalsVal = (tokenAmount is Map) ? (tokenAmount as Map<String, dynamic>)['decimals'] : null;

    final isNative = (parsed is Map)
        ? ((parsed as Map<String, dynamic>)['type'] == 'account' &&
            (parsed as Map<String, dynamic>)['program'] == 'spl-token')
        : false;

    return TokenAccountInfo(
      address: address,
      owner: owner is String ? owner : (owner?.toString() ?? ''),
      mint: mint is String ? mint : (mint?.toString() ?? ''),
      balance: BigInt.parse((amountStr?.toString() ?? '0')),
      decimals: decimalsVal is int ? decimalsVal : (int.tryParse(decimalsVal?.toString() ?? '0') ?? 0),
      isNative: isNative,
    );
  }

  @override
  String toString() =>
      'TokenAccountInfo(address=$address, owner=$owner, mint=$mint, balance=$balance, decimals=$decimals)';
}

/// Solana SPL Token API service.
///
/// Provides methods to interact with Solana token accounts and metadata
/// using RPC calls.  Uses the solana package's RpcClient under the hood.
class SolanaTokenAPI {
  static final SolanaTokenAPI _instance = SolanaTokenAPI._internal();

  factory SolanaTokenAPI() {
    return _instance;
  }

  SolanaTokenAPI._internal();

  RpcClient? _rpcClient;

  /// Initialize with a configured RPC client.
  /// This should be called with the same RPC client from SolanaWallet.
  void initializeRpcClient(RpcClient rpcClient) {
    _rpcClient = rpcClient;
  }

  void _checkClient() {
    if (_rpcClient == null) {
      throw SolanaTokenApiException(
        'RPC client not initialized. Call initializeRpcClient() first.',
      );
    }
  }

  /// Get token accounts owned by a wallet address for a specific mint.
  ///
  /// Parameters:
  ///   - ownerAddress: The wallet address to query
  ///   - mint: (Optional) Filter by specific token mint address
  ///
  /// Returns a list of token account addresses.
  /// 
  /// Currently returns placeholder data for UI development.
  /// TODO: Implement full RPC call with proper TokenAccountsFilter.
  Future<SolanaTokenApiResponse<List<String>>> getTokenAccountsByOwner(
    String ownerAddress, {
    String? mint,
  }) async {
    try {
      _checkClient();

      // TODO: Implement actual RPC call when solana package APIs are stable.
      // For now, return placeholder token account address derived from owner and mint.
      if (mint != null) {
        // Placeholder: In production, derive Associated Token Account (ATA)
        // using findAssociatedTokenAddress.
        return SolanaTokenApiResponse<List<String>>(
          value: ['TokenAccount_${ownerAddress}_$mint'],
        );
      }

      return SolanaTokenApiResponse<List<String>>(value: []);
    } on Exception catch (e) {
      return SolanaTokenApiResponse<List<String>>(
        exception: SolanaTokenApiException(
          'Failed to get token accounts: ${e.toString()}',
          originalException: e,
        ),
      );
    }
  }

  /// Get the balance of a specific token account.
  ///
  /// Parameters:
  ///   - tokenAccountAddress: The token account address to query.
  ///
  /// Returns the balance as a BigInt (in smallest units).
  /// NOTE: Currently returns placeholder data for UI development
  /// TODO: Implement full RPC call when API is ready
  Future<SolanaTokenApiResponse<BigInt>> getTokenAccountBalance(
    String tokenAccountAddress,
  ) async {
    try {
      _checkClient();

      // TODO: Query account info to get token amount when RPC APIs are stable
      // For now return placeholder mock data
      return SolanaTokenApiResponse<BigInt>(
        value: BigInt.from(1000000),
      );
    } on Exception catch (e) {
      return SolanaTokenApiResponse<BigInt>(
        exception: SolanaTokenApiException(
          'Failed to get token balance: ${e.toString()}',
          originalException: e,
        ),
      );
    }
  }

  /// Get the total supply of a token.
  ///
  /// Parameters:
  ///   - mint: The token mint address.
  ///
  /// Returns the total supply as a BigInt.
  /// NOTE: Currently returns placeholder data for UI development
  /// TODO: Implement full RPC call when API is ready
  Future<SolanaTokenApiResponse<BigInt>> getTokenSupply(String mint) async {
    try {
      _checkClient();

      // TODO: Get the mint account info when RPC APIs are stable
      // For now return placeholder mock data
      return SolanaTokenApiResponse<BigInt>(
        value: BigInt.parse('1000000000000000000'),
      );
    } on Exception catch (e) {
      return SolanaTokenApiResponse<BigInt>(
        exception: SolanaTokenApiException(
          'Failed to get token supply: ${e.toString()}',
          originalException: e,
        ),
      );
    }
  }

  /// Get token account information with balance and metadata.
  ///
  /// Parameters:
  ///   - tokenAccountAddress: The token account address.
  ///
  /// Returns detailed token account information.
  /// 
  /// Currently returns placeholder data for UI development.
  /// TODO: Implement full RPC call when API is ready.
  Future<SolanaTokenApiResponse<TokenAccountInfo>>
      getTokenAccountInfo(String tokenAccountAddress) async {
    try {
      _checkClient();

      // Return placeholder data.
      // TODO: Implement actual RPC call using proper client methods.
      return SolanaTokenApiResponse<TokenAccountInfo>(
        value: TokenAccountInfo(
          address: tokenAccountAddress,
          owner: 'placeholder_owner',
          mint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          balance: BigInt.from(1000000000),
          decimals: 6,
          isNative: false,
        ),
      );
    } on Exception catch (e) {
      return SolanaTokenApiResponse<TokenAccountInfo>(
        exception: SolanaTokenApiException(
          'Failed to get token account info: ${e.toString()}',
          originalException: e,
        ),
      );
    }
  }

  /// Find the Associated Token Account (ATA) for a wallet and mint.
  ///
  /// Parameters:
  ///   - ownerAddress: The wallet address.
  ///   - mint: The token mint address.
  ///
  /// Returns the derived ATA address.
  String findAssociatedTokenAddress(
    String ownerAddress,
    String mint,
  ) {
    // Return a placeholder.
    // TODO: Implement ATA derivation using Solana SDK.
    return '';
  }

  /// Check if a wallet owns a token (has a token account for the given mint).
  ///
  /// Parameters:
  ///   - ownerAddress: The wallet address.
  ///   - mint: The token mint address.
  ///
  /// Returns true if the wallet has a token account for this mint, false otherwise.
  /// NOTE: Currently returns placeholder data for UI development.
  /// TODO: Implement actual RPC call to check token account ownership.
  Future<SolanaTokenApiResponse<bool>> ownsToken(
    String ownerAddress,
    String mint,
  ) async {
    try {
      _checkClient();

      // Return placeholder.
      // TODO: Implement actual RPC call to getTokenAccountsByOwner with mint filter.
      return SolanaTokenApiResponse<bool>(value: false);
    } on Exception catch (e) {
      return SolanaTokenApiResponse<bool>(
        exception: SolanaTokenApiException(
          'Failed to check token ownership: ${e.toString()}',
          originalException: e,
        ),
      );
    }
  }
}
