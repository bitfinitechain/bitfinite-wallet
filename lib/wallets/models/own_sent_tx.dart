import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;

import '../../models/input.dart';
import 'tx_recipient.dart';

/// This wallet's own record of a transaction it signed and broadcast.
///
/// Boost (replace-by-fee) signs a pending payment again with a higher fee. It
/// must never take that payment's inputs and outputs from the Electrum server.
/// A malicious server can report a conflicting transaction that pays the
/// attacker, with invalid signatures. If the wallet rebuilds from that, it
/// signs the attacker's payment for real. Electrum fixed this in 4.8.3 after
/// it was used to steal funds.
///
/// So the wallet keeps its own copy at broadcast time, and Boost rebuilds only
/// from that copy. A transaction with no copy here cannot be boosted.
class OwnSentTx {
  OwnSentTx({
    required this.txid,
    required this.raw,
    required this.vSize,
    required this.timestamp,
    required this.inputs,
    required this.outputs,
  });

  /// Computed here from [raw], never the txid the server reports back.
  final String txid;
  final String raw;
  final int vSize;

  /// Seconds since the epoch, when the wallet broadcast it.
  final int timestamp;
  final List<OwnSentTxInput> inputs;
  final List<OwnSentTxOutput> outputs;

  BigInt get fee =>
      inputs.fold(BigInt.zero, (sum, e) => sum + e.value) -
      outputs.fold(BigInt.zero, (sum, e) => sum + e.value);

  /// Builds the record from what this wallet just signed, after checking that
  /// the signed bytes say exactly what the wallet meant to send: the same
  /// inputs in order, and the same outputs, values and scripts in order.
  ///
  /// Returns null when they do not line up, or when the transaction has a part
  /// a boost cannot rebuild (an MWEB input, an OP_RETURN output). Such a
  /// transaction then simply cannot be boosted.
  static OwnSentTx? fromSigned({
    required String raw,
    required int vSize,
    required List<TxRecipient> recipients,
    required List<BaseInput> usedInputs,
    required coinlib.Network network,
    required String Function(String) normalizeAddress,
    required int nowSeconds,
  }) {
    if (usedInputs.any((e) => e is! StandardInput)) return null;
    final standardInputs = usedInputs.cast<StandardInput>();

    final tx = coinlib.Transaction.fromHex(raw);
    if (tx.inputs.length != standardInputs.length ||
        tx.outputs.length != recipients.length) {
      return null;
    }

    final inputs = <OwnSentTxInput>[];
    for (int i = 0; i < standardInputs.length; i++) {
      final utxo = standardInputs[i].utxo;
      final prevOut = tx.inputs[i].prevOut;
      final prevTxid = prevOut.hash.reversed
          .map((b) => b.toRadixString(16).padLeft(2, "0"))
          .join();
      if (prevTxid != utxo.txid || prevOut.n != utxo.vout) return null;
      final address = utxo.address;
      if (address == null) return null;
      inputs.add(
        OwnSentTxInput(
          txid: utxo.txid,
          vout: utxo.vout,
          value: BigInt.from(utxo.value),
          address: address,
        ),
      );
    }

    final outputs = <OwnSentTxOutput>[];
    for (int i = 0; i < recipients.length; i++) {
      final recipient = recipients[i];
      final signed = tx.outputs[i];
      final expected = coinlib.Output.fromAddress(
        recipient.amount.raw,
        coinlib.Address.fromString(
          normalizeAddress(recipient.address),
          network,
        ),
      );
      if (signed.value != expected.value ||
          !_sameBytes(signed.scriptPubKey, expected.scriptPubKey)) {
        return null;
      }
      outputs.add(
        OwnSentTxOutput(address: recipient.address, value: signed.value),
      );
    }

    return OwnSentTx(
      txid: tx.txid,
      raw: raw,
      vSize: vSize,
      timestamp: nowSeconds,
      inputs: inputs,
      outputs: outputs,
    );
  }

  /// True when [raw] still hashes to [txid], so a damaged record is never
  /// used to sign anything.
  bool get rawMatchesTxid => coinlib.Transaction.fromHex(raw).txid == txid;

  Map<String, dynamic> toJson() => {
    "txid": txid,
    "raw": raw,
    "vSize": vSize,
    "timestamp": timestamp,
    "inputs": inputs.map((e) => e.toJson()).toList(),
    "outputs": outputs.map((e) => e.toJson()).toList(),
  };

  factory OwnSentTx.fromJson(Map<String, dynamic> json) => OwnSentTx(
    txid: json["txid"] as String,
    raw: json["raw"] as String,
    vSize: json["vSize"] as int,
    timestamp: json["timestamp"] as int,
    inputs: (json["inputs"] as List)
        .map(
          (e) => OwnSentTxInput.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    outputs: (json["outputs"] as List)
        .map(
          (e) => OwnSentTxOutput.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );

  /// Keeps the newest [max] records that are younger than [maxAgeSeconds].
  /// A boost only matters while a payment is unconfirmed, so old records are
  /// dead weight in the wallet's settings.
  static Map<String, dynamic> prune(
    Map<String, dynamic> records, {
    required int nowSeconds,
    int max = 30,
    int maxAgeSeconds = 30 * 24 * 60 * 60,
  }) {
    final kept =
        records.entries.where((e) {
          final ts = (e.value as Map)["timestamp"];
          return ts is int && nowSeconds - ts <= maxAgeSeconds;
        }).toList()..sort(
          (a, b) => ((b.value as Map)["timestamp"] as int).compareTo(
            (a.value as Map)["timestamp"] as int,
          ),
        );
    return Map.fromEntries(kept.take(max));
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class OwnSentTxInput {
  OwnSentTxInput({
    required this.txid,
    required this.vout,
    required this.value,
    required this.address,
  });

  final String txid;
  final int vout;
  final BigInt value;
  final String address;

  Map<String, dynamic> toJson() => {
    "txid": txid,
    "vout": vout,
    "value": value.toString(),
    "address": address,
  };

  factory OwnSentTxInput.fromJson(Map<String, dynamic> json) => OwnSentTxInput(
    txid: json["txid"] as String,
    vout: json["vout"] as int,
    value: BigInt.parse(json["value"] as String),
    address: json["address"] as String,
  );
}

class OwnSentTxOutput {
  OwnSentTxOutput({required this.address, required this.value});

  final String address;
  final BigInt value;

  Map<String, dynamic> toJson() => {
    "address": address,
    "value": value.toString(),
  };

  factory OwnSentTxOutput.fromJson(Map<String, dynamic> json) =>
      OwnSentTxOutput(
        address: json["address"] as String,
        value: BigInt.parse(json["value"] as String),
      );
}
