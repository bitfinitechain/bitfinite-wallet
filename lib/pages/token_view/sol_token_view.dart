/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import '../../themes/stack_colors.dart';
import '../../utilities/assets.dart';
import '../../utilities/constants.dart';
import '../../utilities/text_styles.dart';
import '../../wallets/isar/providers/solana/current_sol_token_wallet_provider.dart';
import '../../wallets/isar/providers/solana/sol_token_balance_provider.dart';
import '../../widgets/background.dart';
import '../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../widgets/icon_widgets/sol_token_icon.dart';

/// Solana SPL Token View
///
/// This view displays a Solana token with its balance, transaction history,
/// and quick action buttons (Send, Receive, More).
///
/// Uses mock data for UI development. The backend API will be integrated later.
class SolTokenView extends ConsumerStatefulWidget {
  const SolTokenView({
    super.key,
    required this.walletId,
    required this.tokenMint,
    this.popPrevious = false,
  });

  static const String routeName = "/sol_token";

  /// The ID of the parent Solana wallet
  final String walletId;

  /// The SPL token mint address
  final String tokenMint;

  /// Whether to pop the previous view when closing
  final bool popPrevious;

  @override
  ConsumerState<SolTokenView> createState() => _SolTokenViewState();
}

class _SolTokenViewState extends ConsumerState<SolTokenView> {
  late final WalletSyncStatus initialSyncStatus;

  @override
  void initState() {
    initialSyncStatus = WalletSyncStatus.synced;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("BUILD: $runtimeType");

    // Get the current token wallet from provider
    final tokenWallet = ref.watch(pCurrentSolanaTokenWallet);

    // Get the balance for this token
    final balance = ref.watch(
      pSolanaTokenBalance((
        walletId: widget.walletId,
        tokenMint: widget.tokenMint,
      )),
    );

    // If no token wallet is set, show placeholder
    if (tokenWallet == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).extension<StackColors>()!.background,
        body: SafeArea(
          child: Center(
            child: Text(
              "Token not loaded",
              style: STextStyles.pageTitleH1(context),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (widget.popPrevious) {
          nav.pop();
        }
        nav.pop();
      },
      child: Background(
        child: Scaffold(
          backgroundColor: Theme.of(
            context,
          ).extension<StackColors>()!.background,
          appBar: AppBar(
            leading: AppBarBackButton(
              onPressed: () {
                final nav = Navigator.of(context);
                if (widget.popPrevious) {
                  nav.pop();
                }
                nav.pop();
              },
            ),
            centerTitle: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SolTokenIcon(mintAddress: widget.tokenMint, size: 24),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          tokenWallet.tokenName,
                          style: STextStyles.navBarTitle(context),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AppBarIconButton(
                    icon: SvgPicture.asset(
                      Assets.svg.verticalEllipsis,
                      colorFilter: ColorFilter.mode(
                        Theme.of(
                          context,
                        ).extension<StackColors>()!.topNavIconPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    onPressed: () {
                      // TODO: Show context menu with more options.
                    },
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Container(
              color: Theme.of(context).extension<StackColors>()!.background,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Balance Display Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Balance",
                              style: STextStyles.itemSubtitle(context).copyWith(
                                color: Theme.of(
                                  context,
                                ).extension<StackColors>()!.textDark3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${balance.spendable.decimal.toStringAsFixed(tokenWallet.tokenDecimals)} ${tokenWallet.tokenSymbol}",
                                  style: STextStyles.subtitle600(context),
                                ),
                                SolTokenIcon(
                                  mintAddress: widget.tokenMint,
                                  size: 32,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Action Buttons.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Navigate to send view
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Send not yet implemented"),
                                ),
                              );
                            },
                            icon: const Icon(Icons.send),
                            label: const Text("Send"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Navigate to receive view.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Receive not yet implemented"),
                                ),
                              );
                            },
                            icon: const Icon(Icons.call_received),
                            label: const Text("Receive"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Transaction History Section.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Transactions",
                          style: STextStyles.itemSubtitle(context).copyWith(
                            color: Theme.of(
                              context,
                            ).extension<StackColors>()!.textDark3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Transaction List (placeholder).
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).extension<StackColors>()!.popupBG,
                          borderRadius: BorderRadius.circular(
                            Constants.size.circularBorderRadius,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "No transactions yet",
                              style: STextStyles.itemSubtitle(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Your token transactions will appear here",
                              style: STextStyles.itemSubtitle12(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
