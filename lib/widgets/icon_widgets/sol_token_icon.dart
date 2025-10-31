/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:isar_community/isar.dart';

import '../../models/isar/exchange_cache/currency.dart';
import '../../services/exchange/change_now/change_now_exchange.dart';
import '../../services/exchange/exchange_data_loading_service.dart';
import '../../themes/coin_icon_provider.dart';
import '../../wallets/crypto_currency/crypto_currency.dart';

/// Token icon widget for Solana SPL tokens.
///
/// Displays the token icon by attempting to fetch from exchange data service.
/// Falls back to generic Solana token icon if no icon is found.
class SolTokenIcon extends ConsumerStatefulWidget {
  const SolTokenIcon({super.key, required this.mintAddress, this.size = 22});

  /// The SPL token mint address.
  final String mintAddress;

  /// Size of the icon in pixels.
  final double size;

  @override
  ConsumerState<SolTokenIcon> createState() => _SolTokenIconState();
}

class _SolTokenIconState extends ConsumerState<SolTokenIcon> {
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadTokenIcon();
  }

  Future<void> _loadTokenIcon() async {
    try {
      final isar = await ExchangeDataLoadingService.instance.isar;
      final currency = await isar.currencies
          .where()
          .exchangeNameEqualTo(ChangeNowExchange.exchangeName)
          .filter()
          .tokenContractEqualTo(widget.mintAddress, caseSensitive: false)
          .and()
          .imageIsNotEmpty()
          .findFirst();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              imageUrl = currency?.image;
            });
          }
        });
      }
    } catch (e) {
      // Silently fail - we'll use fallback icon.
      if (mounted) {
        setState(() {
          imageUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      // Fallback to generic Solana icon.
      return SvgPicture.asset(
        ref.watch(coinIconProvider(Solana(CryptoCurrencyNetwork.main))),
        width: widget.size,
        height: widget.size,
      );
    } else {
      // Display token icon from network.
      return SvgPicture.network(
        imageUrl!,
        width: widget.size,
        height: widget.size,
        placeholderBuilder: (context) {
          return SvgPicture.asset(
            ref.watch(coinIconProvider(Solana(CryptoCurrencyNetwork.main))),
            width: widget.size,
            height: widget.size,
          );
        },
      );
    }
  }
}
