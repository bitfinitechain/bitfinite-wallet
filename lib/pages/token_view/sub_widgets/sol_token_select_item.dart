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

import '../../../models/isar/models/solana/spl_token.dart';
import '../../../pages_desktop_specific/my_stack_view/wallet_view/desktop_sol_token_view.dart';
import '../../../providers/providers.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/constants.dart';
import '../../../utilities/text_styles.dart';
import '../../../utilities/util.dart';
import '../../../wallets/isar/providers/solana/sol_token_balance_provider.dart';
import '../../../widgets/icon_widgets/sol_token_icon.dart';
import '../../../widgets/rounded_white_container.dart';
import '../sol_token_view.dart';

class SolTokenSelectItem extends ConsumerStatefulWidget {
  const SolTokenSelectItem({
    super.key,
    required this.walletId,
    required this.token,
  });

  final String walletId;
  final SplToken token;

  @override
  ConsumerState<SolTokenSelectItem> createState() => _SolTokenSelectItemState();
}

class _SolTokenSelectItemState extends ConsumerState<SolTokenSelectItem> {
  final bool isDesktop = Util.isDesktop;

  void _onPressed() async {
    // TODO [prio=high]: Implement Solana token wallet setup and navigation.
    if (mounted) {
      await Navigator.of(context).pushNamed(
        isDesktop ? DesktopSolTokenView.routeName : SolTokenView.routeName,
        arguments: (
          walletId: widget.walletId,
          tokenMint: widget.token.address,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String? priceString;
    if (ref.watch(prefsChangeNotifierProvider.select((s) => s.externalCalls))) {
      priceString = ref.watch(
        priceAnd24hChangeNotifierProvider.select(
          (s) =>
              s.getTokenPrice(widget.token.address)?.value.toStringAsFixed(2),
        ),
      );
    }

    return RoundedWhiteContainer(
      padding: const EdgeInsets.all(0),
      child: MaterialButton(
        key: Key("walletListItemButtonKey_${widget.token.symbol}"),
        padding:
            isDesktop
                ? const EdgeInsets.symmetric(horizontal: 28, vertical: 24)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            Constants.size.circularBorderRadius,
          ),
        ),
        onPressed: _onPressed,
        child: Row(
          children: [
            SolTokenIcon(
              mintAddress: widget.token.address,
              size: 32,
            ),
            SizedBox(width: isDesktop ? 12 : 10),
            Expanded(
              child: Consumer(
                builder: (_, ref, __) {
                  // Fetch the balance.
                  final balanceAsync = ref.watch(
                    pSolanaTokenBalance(
                      (
                        walletId: widget.walletId,
                        tokenMint: widget.token.address,
                        fractionDigits: widget.token.decimals,
                      ),
                    ),
                  );

                  // Format the balance.
                  String balanceString = "0.00 ${widget.token.symbol}";
                  balanceAsync.when(
                    data: (balance) {
                      // Format the amount with the token symbol.
                      final decimalValue = balance.total.decimal.toStringAsFixed(widget.token.decimals);
                      balanceString = "$decimalValue ${widget.token.symbol}";
                    },
                    loading: () {
                      balanceString = "... ${widget.token.symbol}";
                    },
                    error: (error, stackTrace) {
                      balanceString = "0.00 ${widget.token.symbol}";
                    },
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.token.name,
                            style:
                                isDesktop
                                    ? STextStyles.desktopTextExtraSmall(
                                      context,
                                    ).copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).extension<StackColors>()!.textDark,
                                    )
                                    : STextStyles.titleBold12(context),
                          ),
                          const Spacer(),
                          Text(
                            balanceString,
                            style:
                                isDesktop
                                    ? STextStyles.desktopTextExtraSmall(
                                      context,
                                    ).copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).extension<StackColors>()!.textDark,
                                    )
                                    : STextStyles.itemSubtitle(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            widget.token.symbol,
                            style:
                                isDesktop
                                    ? STextStyles.desktopTextExtraExtraSmall(
                                      context,
                                    )
                                    : STextStyles.itemSubtitle(context),
                          ),
                          const Spacer(),
                          if (priceString != null)
                            Text(
                              "$priceString "
                              "${ref.watch(prefsChangeNotifierProvider.select((value) => value.currency))}",
                              style:
                                  isDesktop
                                      ? STextStyles.desktopTextExtraExtraSmall(
                                        context,
                                      )
                                      : STextStyles.itemSubtitle(context),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
