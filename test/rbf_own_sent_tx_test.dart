// Boost (replace-by-fee) must rebuild a pending payment from the wallet's own
// copy, never from the Electrum server's. A malicious server can report a
// conflicting payment to itself, and rebuilding from that signs it for real.
// That is the flaw Electrum fixed in 4.8.3. These tests pin the record that
// makes the safe path possible.

import 'dart:io';

import 'package:bitfinite/models/input.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/address.dart';
import 'package:bitfinite/models/isar/models/blockchain_data/utxo.dart';
import 'package:bitfinite/utilities/amount/amount.dart';
import 'package:bitfinite/wallets/crypto_currency/crypto_currency.dart';
import 'package:bitfinite/wallets/models/own_sent_tx.dart';
import 'package:bitfinite/wallets/models/tx_recipient.dart';
import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_test/flutter_test.dart';

OwnSentTx _record({required String txid, required int timestamp}) => OwnSentTx(
  txid: txid,
  raw: "00",
  vSize: 141,
  timestamp: timestamp,
  inputs: [
    OwnSentTxInput(
      txid: "aa" * 32,
      vout: 1,
      value: BigInt.from(100000),
      address: "bc1qinput",
    ),
  ],
  outputs: [
    OwnSentTxOutput(address: "bc1qpayee", value: BigInt.from(60000)),
    OwnSentTxOutput(address: "bc1qchange", value: BigInt.from(38590)),
  ],
);

void main() {
  group("OwnSentTx (pure Dart)", () {
    test("fee is inputs minus outputs", () {
      expect(_record(txid: "t", timestamp: 0).fee, BigInt.from(1410));
    });

    test("survives a JSON round trip unchanged", () {
      final a = _record(txid: "t1", timestamp: 1700000000);
      final b = OwnSentTx.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(b.inputs.single.value, BigInt.from(100000));
      expect(b.outputs.last.value, BigInt.from(38590));
    });

    test("prune drops records past the age limit and keeps the newest", () {
      const now = 2000000000;
      const day = 24 * 60 * 60;
      final records = <String, dynamic>{
        "old": _record(txid: "old", timestamp: now - 31 * day).toJson(),
        for (int i = 0; i < 40; i++)
          "t$i": _record(txid: "t$i", timestamp: now - i).toJson(),
      };
      final kept = OwnSentTx.prune(records, nowSeconds: now);
      expect(kept.length, 30);
      expect(kept.containsKey("old"), false);
      expect(kept.containsKey("t0"), true);
      expect(kept.containsKey("t29"), true);
      expect(kept.containsKey("t30"), false);
    });
  });

  group(
    "OwnSentTx.fromSigned (requires coinlib)",
    () {
      final btc = Bitcoin(CryptoCurrencyNetwork.main);
      final network = btc.networkParams;

      setUpAll(() => coinlib.loadCoinlib());

      late coinlib.ECPrivateKey key;
      late String fromAddress;
      late String payee;
      late String change;
      const prevTxid =
          "1111111111111111111111111111111111111111111111111111111111111111";

      setUp(() {
        key = coinlib.ECPrivateKey.fromHex("01" * 32);
        fromAddress = coinlib.P2WPKHAddress.fromPublicKey(
          key.pubkey,
          hrp: network.bech32Hrp,
        ).toString();
        payee = coinlib.P2WPKHAddress.fromPublicKey(
          coinlib.ECPrivateKey.fromHex("02" * 32).pubkey,
          hrp: network.bech32Hrp,
        ).toString();
        change = coinlib.P2WPKHAddress.fromPublicKey(
          coinlib.ECPrivateKey.fromHex("03" * 32).pubkey,
          hrp: network.bech32Hrp,
        ).toString();
      });

      TxRecipient recipient(
        String address,
        int sats, {
        bool isChange = false,
      }) => TxRecipient(
        address: address,
        amount: Amount(rawValue: BigInt.from(sats), fractionDigits: 8),
        isChange: isChange,
        addressType: AddressType.p2wpkh,
      );

      StandardInput input(String txid, int vout, int sats) => StandardInput(
        UTXO(
          walletId: "w",
          txid: txid,
          vout: vout,
          value: sats,
          name: "",
          isBlocked: false,
          blockedReason: null,
          isCoinbase: false,
          blockHash: null,
          blockHeight: null,
          blockTime: null,
          address: fromAddress,
        ),
      );

      /// Signs a payment of 60000 to [payee] with 38590 change, the way
      /// buildTransaction does: recipients in order, then sign each input.
      coinlib.Transaction signedPayment() {
        var tx = coinlib.Transaction(
          inputs: [
            coinlib.P2WPKHInput(
              prevOut: coinlib.OutPoint.fromHex(prevTxid, 1),
              publicKey: key.pubkey,
            ),
          ],
          outputs: [
            coinlib.Output.fromAddress(
              BigInt.from(60000),
              coinlib.Address.fromString(payee, network),
            ),
            coinlib.Output.fromAddress(
              BigInt.from(38590),
              coinlib.Address.fromString(change, network),
            ),
          ],
        );
        tx = tx.signLegacyWitness(
          inputN: 0,
          key: key,
          value: BigInt.from(100000),
        );
        return tx;
      }

      OwnSentTx? record(
        coinlib.Transaction tx, {
        List<TxRecipient>? recipients,
        List<BaseInput>? inputs,
      }) => OwnSentTx.fromSigned(
        raw: tx.toHex(),
        vSize: 141,
        recipients:
            recipients ??
            [recipient(payee, 60000), recipient(change, 38590, isChange: true)],
        usedInputs: inputs ?? [input(prevTxid, 1, 100000)],
        network: network,
        normalizeAddress: (a) => a,
        nowSeconds: 1700000000,
      );

      test("records what was signed, keyed by the locally computed txid", () {
        final tx = signedPayment();
        final r = record(tx)!;
        expect(r.txid, tx.txid);
        expect(r.rawMatchesTxid, true);
        expect(r.inputs.single.txid, prevTxid);
        expect(r.inputs.single.vout, 1);
        expect(r.outputs.map((e) => e.address), [payee, change]);
        expect(r.fee, BigInt.from(1410));
      });

      test("refuses when a signed output pays someone else", () {
        final attacker = coinlib.P2WPKHAddress.fromPublicKey(
          coinlib.ECPrivateKey.fromHex("04" * 32).pubkey,
          hrp: network.bech32Hrp,
        ).toString();
        expect(
          record(
            signedPayment(),
            recipients: [
              recipient(attacker, 60000),
              recipient(change, 38590, isChange: true),
            ],
          ),
          null,
        );
      });

      test("refuses when a signed output value differs", () {
        expect(
          record(
            signedPayment(),
            recipients: [
              recipient(payee, 59000),
              recipient(change, 38590, isChange: true),
            ],
          ),
          null,
        );
      });

      test("refuses when the signed inputs are not the ones used", () {
        expect(
          record(signedPayment(), inputs: [input(prevTxid, 0, 100000)]),
          null,
        );
        expect(
          record(signedPayment(), inputs: [input("22" * 32, 1, 100000)]),
          null,
        );
      });

      test("refuses when the output count differs", () {
        expect(
          record(signedPayment(), recipients: [recipient(payee, 60000)]),
          null,
        );
      });

      test("a record whose raw no longer matches its txid is rejected", () {
        final r = record(signedPayment())!;
        final damaged = OwnSentTx.fromJson({...r.toJson(), "txid": "ff" * 32});
        expect(damaged.rawMatchesTxid, false);
      });
    },
    // Same gate as the Bellscoin coinlib tests: coinlib needs the native
    // secp256k1 library, and the suite skips cleanly where it is absent.
    skip: File("build/libsecp256k1.so").existsSync()
        ? false
        : "Requires build/libsecp256k1.so for coinlib-backed signing",
  );
}
