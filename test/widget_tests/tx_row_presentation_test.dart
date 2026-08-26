import 'package:flutter_test/flutter_test.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/transaction.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/v2/transaction_v2.dart';
import 'package:bitfinite/pages/wallet_view/transaction_views/tx_v2/tx_row_presentation.dart';

void main() {
  // Height 100, and a tx mined at 98, is 3 confirmations (98, 99, 100).
  TransactionV2 tx({
    required TransactionType type,
    required int height,
  }) =>
      TransactionV2(
        walletId: "w",
        blockHash: "b",
        hash: "h",
        txid: "t",
        timestamp: 1756000000,
        height: height,
        inputs: const [],
        outputs: const [],
        version: 1,
        type: type,
        subType: TransactionSubType.none,
        otherData: null,
      );

  TxRowPresentation present(
    TransactionV2 t, {
    bool isFailed = false,
    int currentHeight = 100,
  }) =>
      txRowPresentation(
        t,
        fallbackLabel: "fallback",
        currentHeight: currentHeight,
        minConfirms: 3,
        minCoinbaseConfirms: 100,
        isFailed: isFailed,
      );

  group("title says what happened", () {
    test("incoming and outgoing read in the past tense", () {
      expect(
        present(tx(type: TransactionType.incoming, height: 98)).title,
        "Received",
      );
      expect(
        present(tx(type: TransactionType.outgoing, height: 98)).title,
        "Sent",
      );
      expect(
        present(tx(type: TransactionType.sentToSelf, height: 98)).title,
        "Sent to self",
      );
    });

    test("the title does not carry confirmation counts", () {
      // That was the old fused label's job; it belongs in the subtitle now.
      final p = present(tx(type: TransactionType.incoming, height: 100));
      expect(p.title, "Received");
      expect(p.title.contains("/"), isFalse);
      expect(p.title.contains("("), isFalse);
    });
  });

  group("state says where it got to", () {
    test("a settled transaction is Confirmed", () {
      expect(
        present(tx(type: TransactionType.incoming, height: 98)).state,
        "Confirmed",
      );
    });

    test("an unsettled one counts toward its threshold", () {
      // Mined this block: 1 of the 3 required.
      expect(
        present(tx(type: TransactionType.incoming, height: 100)).state,
        "1/3 confirmations",
      );
    });

    test("failure outranks confirmation", () {
      final p = present(
        tx(type: TransactionType.outgoing, height: 98),
        isFailed: true,
      );
      expect(p.state, "Failed");
      expect(p.tone, TxTone.failed);
    });
  });

  group("tone drives the amount chip", () {
    test("settled credits and debits are told apart", () {
      expect(
        present(tx(type: TransactionType.incoming, height: 98)).tone,
        TxTone.credit,
      );
      expect(
        present(tx(type: TransactionType.outgoing, height: 98)).tone,
        TxTone.debit,
      );
    });

    test("anything still confirming reads as pending, either direction", () {
      expect(
        present(tx(type: TransactionType.incoming, height: 100)).tone,
        TxTone.pending,
      );
      expect(
        present(tx(type: TransactionType.outgoing, height: 100)).tone,
        TxTone.pending,
      );
    });
  });
}
