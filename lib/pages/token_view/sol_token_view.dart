/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2023 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../providers/db/main_db_provider.dart';
import '../../providers/providers.dart';
import '../../services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import '../../themes/stack_colors.dart';
import '../../utilities/assets.dart';
import '../../utilities/constants.dart';
import '../../utilities/default_spl_tokens.dart';
import '../../utilities/text_styles.dart';
import '../../wallets/isar/providers/solana/current_sol_token_wallet_provider.dart';
import '../../wallets/isar/providers/solana/solana_wallet_provider.dart';
import '../../wallets/wallet/impl/sub_wallets/solana_token_wallet.dart';
import '../../widgets/background.dart';
import '../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../widgets/custom_buttons/blue_text_button.dart';
import '../../widgets/icon_widgets/sol_token_icon.dart';
import 'sub_widgets/token_summary_sol.dart';
import 'sub_widgets/token_transaction_list_widget_sol.dart';

/// [eventBus] should only be set during testing.
class SolTokenView extends ConsumerStatefulWidget {
  const SolTokenView({
    super.key,
    required this.walletId,
    required this.tokenMint,
    this.popPrevious = false,
    this.eventBus,
  });

  static const String routeName = "/sol_token";

  final String walletId;
  final String tokenMint;
  final bool popPrevious;
  final EventBus? eventBus;

  @override
  ConsumerState<SolTokenView> createState() => _SolTokenViewState();
}

class _SolTokenViewState extends ConsumerState<SolTokenView> {
  late final WalletSyncStatus initialSyncStatus;

  @override
  void initState() {
    // Get the initial sync status from the Solana wallet's refresh mutex.
    final solanaWallet = ref.read(pSolanaWallet(widget.walletId));
    initialSyncStatus = solanaWallet?.refreshMutex.isLocked ?? false
        ? WalletSyncStatus.syncing
        : WalletSyncStatus.synced;

    // Initialize the Solana token wallet provider with mock data.
    // 
    // This sets up the pCurrentSolanaTokenWallet provider so that
    // SolanaTokenSummary can access the token wallet information.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeSolanaTokenWallet();
      }
    });

    super.initState();
  }

  /// Initialize the Solana token wallet for this token view.
  /// 
  /// Creates a SolanaTokenWallet with token data from DefaultSplTokens or the database.
  /// First looks in DefaultSplTokens, then checks the database for custom tokens.
  /// Sets it as the current token wallet in the provider so that UI widgets can access it.
  /// 
  /// If the token is not found anywhere, sets the token wallet to null
  /// so the UI can display an error message.
  void _initializeSolanaTokenWallet() {
    dynamic tokenInfo;

    // First try to find in default tokens.
    try {
      tokenInfo = DefaultSplTokens.list.firstWhere(
        (token) => token.address == widget.tokenMint,
      );
    } catch (e) {
      // Token not found in DefaultSplTokens, try database for custom tokens.
      tokenInfo = null;
    }

    // If not found in defaults, try database for custom tokens.
    if (tokenInfo == null) {
      try {
        final db = ref.read(mainDBProvider);
        tokenInfo = db.getSplTokenSync(widget.tokenMint);
      } catch (e) {
        tokenInfo = null;
      }
    }

    if (tokenInfo == null) {
      ref.read(solanaTokenServiceStateProvider.state).state = null;
      debugPrint(
        'ERROR: Token not found in DefaultSplTokens or database: ${widget.tokenMint}',
      );
      return;
    }

    // Get the parent Solana wallet.
    final parentWallet = ref.read(pSolanaWallet(widget.walletId));

    if (parentWallet == null) {
      ref.read(solanaTokenServiceStateProvider.state).state = null;
      debugPrint(
        'ERROR: Wallet is not a SolanaWallet: ${widget.walletId}',
      );
      return;
    }

    final solanaTokenWallet = SolanaTokenWallet(
      parentSolanaWallet: parentWallet,
      tokenMint: widget.tokenMint,
      tokenName: "${tokenInfo.name}",
      tokenSymbol: "${tokenInfo.symbol}",
      tokenDecimals: tokenInfo.decimals as int,
    );

    ref.read(solanaTokenServiceStateProvider.state).state = solanaTokenWallet;

    // Fetch the token balance when the wallet is opened.
    solanaTokenWallet.updateBalance();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("BUILD: $runtimeType");

    return WillPopScope(
      onWillPop: () async {
        final nav = Navigator.of(context);
        if (widget.popPrevious) {
          nav.pop();
        }
        nav.pop();
        return false;
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
            title: Consumer(
              builder: (context, ref, _) {
                final tokenWallet = ref.watch(pCurrentSolanaTokenWallet);
                final tokenName = tokenWallet?.tokenName ?? "Token";
                return Row(
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
                              tokenName,
                              style: STextStyles.navBarTitle(context),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AppBarIconButton(
                    icon: SvgPicture.asset(
                      Assets.svg.verticalEllipsis,
                      color: Theme.of(
                        context,
                      ).extension<StackColors>()!.topNavIconPrimary,
                    ),
                    onPressed: () {
                      // TODO: Implement token details navigation for Solana.
                      // Navigator.of(context).pushNamed(
                      //   TokenContractDetailsView.routeName,
                      //   arguments: Tuple2(
                      //     widget.tokenMint,
                      //     widget.walletId,
                      //   ),
                      // );
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SolanaTokenSummary(
                      walletId: widget.walletId,
                      tokenMint: widget.tokenMint,
                      initialSyncStatus: initialSyncStatus,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        CustomTextButton(
                          text: "See all",
                          onTap: () {
                            // TODO: Navigate to all transactions for this token.
                            // Navigator.of(context).pushNamed(
                            //   AllTransactionsV2View.routeName,
                            //   arguments: (
                            //     walletId: widget.walletId,
                            //     tokenMint: widget.tokenMint,
                            //   ),
                            // );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                            Constants.size.circularBorderRadius,
                          ),
                          bottom: Radius.circular(
                            // TokenView.navBarHeight / 2.0,
                            Constants.size.circularBorderRadius,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              Constants.size.circularBorderRadius,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SolanaTokenTransactionsList(
                                  walletId: widget.walletId,
                                ),
                              ),
                            ],
                          ),
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
