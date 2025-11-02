/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:solana/dto.dart';
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
  /// Returns a list of token account addresses owned by the wallet.
  Future<SolanaTokenApiResponse<List<String>>> getTokenAccountsByOwner(
    String ownerAddress, {
    String? mint,
  }) async {
    try {
      _checkClient();

      const splTokenProgramId = 'TokenkegQfeZyiNwAJsyFbPVwwQQfg5bgUiqhStM5QA';

      final result = await _rpcClient!.getTokenAccountsByOwner(
        ownerAddress,
        // Create the appropriate filter: by mint if specified, or else all SPL tokens.
        mint != null
            ? TokenAccountsFilter.byMint(mint)
            : TokenAccountsFilter.byProgramId(splTokenProgramId),
        encoding: Encoding.jsonParsed,
      );

      // Extract token account addresses from the RPC response.
      final accountAddresses = result.value
          .map((account) => account.pubkey)
          .toList();

      return SolanaTokenApiResponse<List<String>>(
        value: accountAddresses,
      );
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
  Future<SolanaTokenApiResponse<BigInt>> getTokenAccountBalance(
    String tokenAccountAddress,
  ) async {
    try {
      _checkClient();

      // Query the token account with jsonParsed encoding to get token amount.
      final response = await _rpcClient!.getAccountInfo(
        tokenAccountAddress,
        encoding: Encoding.jsonParsed,
      );

      if (response.value == null) {
        // Token account doesn't exist.
        return SolanaTokenApiResponse<BigInt>(
          value: BigInt.zero,
        );
      }

      final accountData = response.value!;

      // Extract token amount from parsed data.
      try {
        // Debug: Print the structure of accountData.
        print('[SOLANA_TOKEN_API] accountData type: ${accountData.runtimeType}');
        print('[SOLANA_TOKEN_API] accountData.data type: ${accountData.data.runtimeType}');
        print('[SOLANA_TOKEN_API] accountData.data: ${accountData.data}');

        // The solana package returns a ParsedAccountData which is a sealed class/union type.
        // For SPL Token accounts, it contains SplTokenProgramAccountData.

        final parsedData = accountData.data;

        if (parsedData is ParsedAccountData) {
          print('[SOLANA_TOKEN_API] ParsedAccountData detected');

          try {
            final extractedBalance = parsedData.when(
              splToken: (spl) {
                print('[SOLANA_TOKEN_API] Handling splToken variant');
                print('[SOLANA_TOKEN_API] spl type: ${spl.runtimeType}');

                return spl.when(
                  account: (info, type, accountType) {
                    print('[SOLANA_TOKEN_API] Handling account variant');
                    print('[SOLANA_TOKEN_API] info type: ${info.runtimeType}');
                    print('[SOLANA_TOKEN_API] info.tokenAmount: ${info.tokenAmount}');

                    try {
                      final tokenAmount = info.tokenAmount;
                      print('[SOLANA_TOKEN_API] tokenAmount.amount: ${tokenAmount.amount}');
                      print('[SOLANA_TOKEN_API] tokenAmount.decimals: ${tokenAmount.decimals}');

                      final balanceBigInt = BigInt.parse(tokenAmount.amount);
                      print('[SOLANA_TOKEN_API] Successfully extracted balance: $balanceBigInt');
                      return balanceBigInt;
                    } catch (e) {
                      print('[SOLANA_TOKEN_API] Error extracting balance: $e');
                      return null;
                    }
                  },
                  mint: (info, type, accountType) {
                    print('[SOLANA_TOKEN_API] Got mint variant (not expected for token account balance)');
                    return null;
                  },
                  unknown: (type) {
                    print('[SOLANA_TOKEN_API] Got unknown account variant');
                    return null;
                  },
                );
              },
              stake: (_) {
                print('[SOLANA_TOKEN_API] Got stake account type (not expected)');
                return null;
              },
              token2022: (_) {
                print('[SOLANA_TOKEN_API] Got token2022 account type (not expected)');
                return null;
              },
              unsupported: (_) {
                print('[SOLANA_TOKEN_API] Got unsupported account type');
                return null;
              },
            );

            if (extractedBalance != null && extractedBalance is BigInt) {
              print('[SOLANA_TOKEN_API] Extracted balance: $extractedBalance');
              return SolanaTokenApiResponse<BigInt>(
                value: extractedBalance as BigInt,
              );
            }
          } catch (e) {
            print('[SOLANA_TOKEN_API] Error using when() method: $e');
            print('[SOLANA_TOKEN_API] Stack trace: ${StackTrace.current}');
          }
        }

        // If we can't extract from the Dart object, return zero.
        print('[SOLANA_TOKEN_API] Returning zero balance');
        return SolanaTokenApiResponse<BigInt>(
          value: BigInt.zero,
        );
      } catch (e) {
        // If parsing fails, return zero balance.
        print('[SOLANA_TOKEN_API] Exception during parsing: $e');
        return SolanaTokenApiResponse<BigInt>(
          value: BigInt.zero,
        );
      }
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
  /// Returns true if the wallet has a token account for this mint, false otherwise.
  Future<SolanaTokenApiResponse<bool>> ownsToken(
    String ownerAddress,
    String mint,
  ) async {
    try {
      _checkClient();

      // Get token accounts for this owner and mint.
      final accounts = await getTokenAccountsByOwner(ownerAddress, mint: mint);

      if (accounts.isError) {
        return SolanaTokenApiResponse<bool>(exception: accounts.exception);
      }

      // If we got token accounts, the user owns this token.
      final hasTokenAccount = accounts.value != null && (accounts.value as List).isNotEmpty;
      return SolanaTokenApiResponse<bool>(value: hasTokenAccount);
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
