/*
 * This file is part of BitFinite Wallet.
 *
 * A miner's summary of what mining has actually paid into this wallet.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../providers/db/main_db_provider.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/amount/amount_formatter.dart';
import '../../../utilities/compact_amount.dart';
import '../../../utilities/mining_payouts.dart';
import '../../../utilities/text_styles.dart';
import '../../../wallets/crypto_currency/crypto_currency.dart';

/// Shows how mining is going, for wallets that mining actually pays.
///
/// A miner opens the wallet to answer one question: are the payouts still
/// arriving. The balance alone does not answer it, because a wallet that
/// stopped earning yesterday looks exactly like one still earning. So the
/// card leads with when the last payout landed.
///
/// It renders nothing at all when the wallet has no payouts in it, which is
/// every ordinary wallet. Nobody who does not mine ever sees this.
class MiningPayoutCard extends ConsumerStatefulWidget {
  const MiningPayoutCard({
    super.key,
    required this.walletId,
    required this.coin,
  });

  final String walletId;
  final CryptoCurrency coin;

  @override
  ConsumerState<MiningPayoutCard> createState() => _MiningPayoutCardState();
}

class _MiningPayoutCardState extends ConsumerState<MiningPayoutCard> {
  late final Query<TransactionV2> _query;
  late final StreamSubscription<List<TransactionV2>> _subscription;
  MiningPayoutSummary? _summary;

  void _recompute(List<TransactionV2> txns) {
    _summary = summariseMiningPayouts(txns, widget.coin);
  }

  @override
  void initState() {
    _query = ref
        .read(mainDBProvider)
        .isar
        .transactionV2s
        .buildQuery<TransactionV2>(
          whereClauses: [
            IndexWhereClause.equalTo(
              indexName: 'walletId',
              value: [widget.walletId],
            ),
          ],
          sortBy: [const SortProperty(property: "timestamp", sort: Sort.desc)],
        );

    _recompute(_query.findAllSync());

    _subscription = _query.watch().listen((event) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _recompute(event));
        }
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  /// 5033 -> "5,033", so the count is grouped like every other number here.
  static String _grouped(int n) {
    final digits = n.toString();
    final out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(",");
      out.write(digits[i]);
    }
    return out.toString();
  }

  /// The total, with sub-coin dust dropped once it is large enough that the
  /// dust is only making the row overflow.
  String _totalLabel(AmountFormatter formatter, Amount total) {
    final full = formatter.format(total, withUnitName: false);
    return "${withoutDustDecimals(full, minWholeDigits: 1) ?? full} ${widget.coin.ticker}";
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null || summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<StackColors>()!;
    final formatter = ref.watch(pAmountFormatter(widget.coin));

    // The count used to carry the word "recent" on a truncated history. It is
    // gone because the truncation notice sits directly below this row and says
    // it properly ("Showing 5,033 of about 45,335"), while here the extra word
    // pushed the count off the end into an ellipsis, which told the reader
    // nothing at all.
    final countLabel = summary.count == 1
        ? "1 payout"
        : "${_grouped(summary.count)} payouts";

    final last = summary.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colors.popupBG,
          borderRadius: BorderRadius.circular(12),
        ),
        // One row, not a two line card. This sits between the hero and the
        // transaction list, and every pixel it takes is a pixel of list the
        // reader does not get. The facts fit on a line: how many, how recent,
        // how much.
        child: LayoutBuilder(
          builder: (context, rowConstraints) => Row(
            children: [
              Icon(Icons.hardware_outlined, size: 16, color: colors.textDark3),
              const SizedBox(width: 8),
              Text(
                "Payouts",
                style: STextStyles.w600_14(
                  context,
                ).copyWith(color: colors.textDark),
              ),
              const SizedBox(width: 8),
              // Ellipsises before the total does, because the total is the
              // number someone came here to read.
              Expanded(
                child: Text(
                  last == null
                      ? countLabel
                      : "${describeAgeShort(last)} · $countLabel",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: STextStyles.w500_12(
                    context,
                  ).copyWith(color: colors.textSubtitle1),
                ),
              ),
              const SizedBox(width: 8),
              // Flexible, not a bare FittedBox. A FittedBox with unbounded
              // width never scales anything, so a pool total of
              // 50,290,869.11145680 overflowed this row by 2 pixels rather than
              // shrinking. Flexible gives it a bound to shrink into, and the
              // compact form means it rarely has to.
              // Capped rather than sharing the free space evenly with the text
              // beside it. Two Flexibles split the row down the middle, so the
              // payout count was cut to "99..." while the total sat in space it
              // did not need.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: rowConstraints.maxWidth * 0.45,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _totalLabel(formatter, summary.total),
                    maxLines: 1,
                    style: STextStyles.w600_14(
                      context,
                    ).copyWith(color: colors.textDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
