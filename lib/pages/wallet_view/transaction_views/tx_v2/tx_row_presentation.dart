import 'package:flutter/material.dart';

import '../../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../../themes/stack_colors.dart';
import '../../../../models/isar/models/blockchain_data/transaction.dart';

/// How a transaction row presents itself: what happened, where it has got to,
/// and how loudly to say it.
///
/// The stored `statusLabel` fuses both halves into one string ("Receiving
/// (1/6)"), which forces a row to spend its title on something that is really
/// two facts. Splitting them lets the title say what happened and the subtitle
/// carry the state, next to the time.
enum TxTone { credit, debit, pending, failed }

class TxRowPresentation {
  const TxRowPresentation({
    required this.title,
    required this.state,
    required this.tone,
  });

  /// What happened, in the past tense. The row's title.
  final String title;

  /// Where it has got to. Sits in the subtitle, before the time.
  final String state;

  /// Drives the amount chip's tint.
  final TxTone tone;

  /// Chips are a wash of their tone rather than a solid fill: the row already
  /// has an icon in the same colour family, and two saturated blocks per row
  /// reads as an alert rather than a list.
  Color chipFill(StackColors colors) {
    switch (tone) {
      case TxTone.credit:
        return colors.accentColorGreen.withOpacity(0.13);
      case TxTone.debit:
        return colors.textSubtitle1.withOpacity(0.10);
      case TxTone.pending:
        return colors.accentColorYellow.withOpacity(0.16);
      case TxTone.failed:
        return colors.textSubtitle1.withOpacity(0.10);
    }
  }

  /// Ink for the amount itself. Failed transactions are deliberately muted:
  /// the number did not happen, so it should not read as loudly as one that
  /// did.
  Color chipInk(StackColors colors) {
    switch (tone) {
      case TxTone.credit:
        return colors.accentColorGreen;
      case TxTone.debit:
        return colors.textDark;
      case TxTone.pending:
        return colors.accentColorYellow;
      case TxTone.failed:
        return colors.textSubtitle1;
    }
  }
}

/// Derives the row's presentation.
///
/// [fallbackLabel] is the existing fused label. Coins with their own vocabulary
/// - fusion, epiccash, mimblewimblecoin - keep it verbatim rather than being
/// forced through a plain sent/received split that would lose meaning. Those
/// paths are unreachable in a BitFinite build, but the card is shared.
TxRowPresentation txRowPresentation(
  TransactionV2 tx, {
  required String fallbackLabel,
  required int currentHeight,
  required int minConfirms,
  required int minCoinbaseConfirms,
  required bool isFailed,
}) {
  final confirmed = tx.isConfirmed(
    currentHeight,
    minConfirms,
    minCoinbaseConfirms,
  );

  final String state;
  if (isFailed) {
    state = "Failed";
  } else if (confirmed) {
    state = "Confirmed";
  } else {
    final have = tx.getConfirmations(currentHeight);
    final need = tx.isCoinbase() ? minCoinbaseConfirms : minConfirms;
    state = "$have/$need confirmations";
  }

  final TxTone tone;
  if (isFailed) {
    tone = TxTone.failed;
  } else if (!confirmed) {
    tone = TxTone.pending;
  } else if (tx.type == TransactionType.incoming) {
    tone = TxTone.credit;
  } else {
    tone = TxTone.debit;
  }

  final String title;
  switch (tx.type) {
    case TransactionType.incoming:
      title = "Received";
      break;
    case TransactionType.outgoing:
      title = "Sent";
      break;
    case TransactionType.sentToSelf:
      title = "Sent to self";
      break;
    default:
      // Anything with its own vocabulary keeps it.
      title = fallbackLabel;
  }

  return TxRowPresentation(title: title, state: state, tone: tone);
}
