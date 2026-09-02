/*
 * This file is part of BitFinite Wallet.
 *
 * Recognising mining payouts, and summarising them for the wallet view.
 */

import '../models/isar/models/blockchain_data/transaction.dart';
import '../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../utilities/amount/amount.dart';
import '../wallets/crypto_currency/crypto_currency.dart';

/// Payouts come in two shapes that look nothing alike on chain.
///
///   Solo    the block reward pays the miner's address directly, so the
///           transaction carries a coinbase input. This needs no
///           configuration, works on any chain, and keeps working if a pool
///           ever moves its wallet.
///   Shared  the pool pays everyone from its own wallet in one sendmany, so
///           the only signal is the sending address.
///
/// Coinbase detection is the one that carries most of the weight here: our
/// miners are mostly solo and Bitaxe sized.
///
/// The shared-pool list is the same pair the aggregator uses (current hot
/// address plus the legacy one), kept here rather than fetched so that
/// labelling a transaction never depends on the network being reachable.
const _bitfinitePoolPayoutAddresses = <String>{
  "frq8k96fr9j004hpyz9xaa5ema0hvm2gccnn5lxw0s",
  "frkq2xkaqv3694rzc8ahreef78kpljd38gp6n2d5ch",
};

/// Addresses known to pay out shared-pool rewards for [coin], prefix stripped.
///
/// Empty for every coin but ours. That is deliberate: guessing at another
/// chain's pool addresses would mislabel ordinary payments, and a wrong label
/// on someone's money is worse than no label.
Set<String> poolPayoutAddresses(CryptoCurrency coin) {
  if (coin is Bitfinite) return _bitfinitePoolPayoutAddresses;
  return const {};
}

/// Strips any `scheme:` prefix and lowercases.
///
/// BitFinite addresses are cashaddr and turn up both as `bfx:f...` and bare
/// `f...` depending on which side produced them, so comparing raw strings
/// silently fails to match about half the time.
String _normalise(String address) {
  final i = address.indexOf(":");
  final bare = i >= 0 ? address.substring(i + 1) : address;
  return bare.toLowerCase();
}

/// Whether [tx] is money arriving from mining rather than from a person.
bool isMiningPayout(TransactionV2 tx, CryptoCurrency coin) {
  if (tx.type != TransactionType.incoming) return false;

  // Solo: a coinbase input means this is a block reward, and since it is
  // incoming, the reward is ours.
  //
  // Presence of the field is the test, not its contents. Every parser leaves
  // it null for an ordinary input and only sets it for a coinbase, and the
  // esplora path sets it to "" when the scriptsig is absent, so checking for
  // a non-empty string would silently miss Bellscoin block rewards.
  for (final input in tx.inputs) {
    if (input.coinbase != null) return true;
  }

  final pools = poolPayoutAddresses(coin);
  if (pools.isEmpty) return false;

  for (final input in tx.inputs) {
    for (final address in input.addresses) {
      if (pools.contains(_normalise(address))) return true;
    }
  }
  return false;
}

/// What the wallet view shows above the transaction list.
class MiningPayoutSummary {
  const MiningPayoutSummary({
    required this.count,
    required this.total,
    required this.last,
  });

  /// How many payouts are in the transactions we hold.
  final int count;

  /// Their sum, as received by this wallet.
  final Amount total;

  /// When the most recent one landed, or null if there are none.
  final DateTime? last;

  bool get isEmpty => count == 0;
}

/// Totals the payouts in [transactions].
///
/// Counts only what the wallet actually holds. On an address whose history was
/// truncated during sync that is a floor rather than a lifetime total, which
/// is why the card built on this says "recent" rather than claiming to be
/// complete.
MiningPayoutSummary summariseMiningPayouts(
  List<TransactionV2> transactions,
  CryptoCurrency coin,
) {
  final fractionDigits = coin.fractionDigits;
  var count = 0;
  var totalSats = BigInt.zero;
  int? newest;

  for (final tx in transactions) {
    if (!isMiningPayout(tx, coin)) continue;
    count++;
    totalSats += tx
        .getAmountReceivedInThisWallet(fractionDigits: fractionDigits)
        .raw;
    if (newest == null || tx.timestamp > newest) {
      newest = tx.timestamp;
    }
  }

  return MiningPayoutSummary(
    count: count,
    total: Amount(rawValue: totalSats, fractionDigits: fractionDigits),
    last: newest == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(newest * 1000),
  );
}

/// "just now", "14 minutes ago", "3 hours ago", "2 days ago".
///
/// A miner reads this to answer one question, which is whether the payouts
/// have stopped, so the useful precision is coarse and the wording is plain.
String describeAge(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inSeconds < 90) return "just now";
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return "$m ${m == 1 ? "minute" : "minutes"} ago";
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return "$h ${h == 1 ? "hour" : "hours"} ago";
  }
  final d = diff.inDays;
  return "$d ${d == 1 ? "day" : "days"} ago";
}
