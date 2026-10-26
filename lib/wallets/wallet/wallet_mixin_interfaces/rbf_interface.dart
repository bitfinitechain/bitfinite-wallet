import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../models/input.dart';
import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../models/isar/models/isar_models.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/enums/fee_rate_type_enum.dart';
import '../../../utilities/logger.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import '../../isar/models/wallet_info.dart';
import '../../models/own_sent_tx.dart';
import '../../models/tx_data.dart';
import 'electrumx_interface.dart';

typedef TxSize = ({int real, int virtual});

mixin RbfInterface<T extends ElectrumXCurrencyInterface>
    on ElectrumXInterface<T> {
  bool get flagOptInRBF =>
      info.otherData[WalletInfoKeys.enableOptInRbf] as bool? ?? false;

  /// Broadcasts, then keeps this wallet's own copy of what it signed so a
  /// later boost never has to trust the server's copy. See [OwnSentTx].
  @override
  Future<TxData> confirmSend({required TxData txData}) async {
    final sent = await super.confirmSend(txData: txData);
    try {
      await _rememberOwnSentTx(sent);
    } catch (e, s) {
      // The payment is already out. Failing here only means it cannot be
      // boosted later, which is the safe direction.
      Logging.instance.w(
        "Could not keep a boost record for ${sent.txid}",
        error: e,
        stackTrace: s,
      );
    }
    return sent;
  }

  Future<void> _rememberOwnSentTx(TxData sent) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final record = OwnSentTx.fromSigned(
      raw: sent.raw!,
      vSize: sent.vSize!,
      recipients: sent.recipients!,
      usedInputs: sent.usedUTXOs!,
      network: cryptoCurrency.networkParams,
      normalizeAddress: normalizeAddress,
      nowSeconds: now,
    );
    if (record == null) {
      Logging.instance.w(
        "Signed transaction does not match what was built; it will not be "
        "boostable",
      );
      return;
    }
    if (sent.txid != null && sent.txid != record.txid) {
      Logging.instance.w(
        "Server answered broadcast with txid ${sent.txid}, "
        "but the signed transaction is ${record.txid}",
      );
    }
    final records = Map<String, dynamic>.from(
      info.otherData[WalletInfoKeys.rbfOwnSentTxs] as Map? ?? {},
    );
    records[record.txid] = record.toJson();
    await info.updateOtherData(
      newEntries: {
        WalletInfoKeys.rbfOwnSentTxs: OwnSentTx.prune(records, nowSeconds: now),
      },
      isar: mainDB.isar,
    );
  }

  /// This wallet's own copy of [txid], or null if it has none.
  OwnSentTx? ownSentTx(String txid) {
    final records = info.otherData[WalletInfoKeys.rbfOwnSentTxs] as Map?;
    final json = records?[txid];
    if (json is! Map) return null;
    final record = OwnSentTx.fromJson(Map<String, dynamic>.from(json));
    if (record.txid != txid || !record.rawMatchesTxid) return null;
    return record;
  }

  Future<TxSize?> getVSize(String txid) async {
    final tx = await electrumXCachedClient.getTransaction(
      txHash: txid,
      cryptoCurrency: cryptoCurrency,
    );

    try {
      return (real: tx["size"] as int, virtual: tx["vsize"] as int);
    } catch (_) {
      return null;
    }
  }

  Future<TransactionV2> updateVSize(TransactionV2 transactionV2) async {
    final size = await getVSize(transactionV2.txid);
    final otherData = jsonDecode(transactionV2.otherData ?? "{}");
    otherData[TxV2OdKeys.vSize] = size!.virtual;
    otherData[TxV2OdKeys.size] = size.real;
    final updatedTx = transactionV2.copyWith(otherData: jsonEncode(otherData));
    await mainDB.updateOrPutTransactionV2s([updatedTx]);
    return updatedTx;
  }

  Future<TxData> prepareRbfSend({
    required TransactionV2 oldTransaction,
    required int newRate,
  }) async {
    final note = await mainDB.isar.transactionNotes
        .where()
        .walletIdEqualTo(walletId)
        .filter()
        .txidEqualTo(oldTransaction.txid)
        .findFirst();

    // Inputs, outputs, fee and size all come from this wallet's own copy.
    // oldTransaction came from the Electrum server and is only the key: a
    // malicious server can report a conflicting payment to itself, and
    // rebuilding from that would sign it for real.
    final own = ownSentTx(oldTransaction.txid);
    if (own == null) {
      throw Exception(
        "This transaction can't be boosted here. Boost only works on a "
        "payment this wallet sent from this device.",
      );
    }

    final Set<StandardInput> utxos = {};
    for (final input in own.inputs) {
      final utxo = UTXO(
        walletId: walletId,
        txid: input.txid,
        vout: input.vout,
        value: input.value.toInt(),
        name: "rbf",
        isBlocked: false,
        blockedReason: null,
        isCoinbase: false,
        blockHash: "rbf",
        blockHeight: 1,
        blockTime: 1,
        used: false,
        address: input.address,
      );

      utxos.add(StandardInput(utxo));
    }

    final List<TxRecipient> recipients = [];
    for (final output in own.outputs) {
      final address = output.address;
      final addressModel = await mainDB.getAddress(walletId, address);
      final isChange = addressModel?.subType == AddressSubType.change;

      recipients.add(
        TxRecipient(
          address: address,
          amount: Amount(
            rawValue: output.value,
            fractionDigits: cryptoCurrency.fractionDigits,
          ),
          isChange: isChange,
          addressType: cryptoCurrency.getAddressType(address)!,
        ),
      );
    }

    final oldFee = own.fee;
    final inSum = utxos.map((e) => e.value).fold(BigInt.zero, (p, e) => p + e);

    final noChange =
        recipients.map((e) => e.isChange).fold(false, (p, e) => p || e) ==
        false;
    final otherAvailableUtxos = await mainDB
        .getUTXOs(walletId)
        .filter()
        .isBlockedEqualTo(false)
        .and()
        .group((q) => q.usedIsNull().or().usedEqualTo(false))
        .findAll();

    final height = await chainHeight;
    otherAvailableUtxos.removeWhere(
      (e) => !e.isConfirmed(
        height,
        cryptoCurrency.minConfirms,
        cryptoCurrency.minCoinbaseConfirms,
      ),
    );

    TxData txData = TxData(
      recipients: recipients,
      feeRateType: FeeRateType.custom,
      satsPerVByte: newRate,
      utxos: utxos,
      ignoreCachedBalanceChecks: true,
      note: note?.value ?? "",
    );

    if (otherAvailableUtxos.isEmpty && noChange && recipients.length == 1) {
      // safe to assume send all?
      txData = txData.copyWith(
        recipients: [
          TxRecipient(
            address: recipients.first.address,
            amount: Amount(
              rawValue: inSum,
              fractionDigits: cryptoCurrency.fractionDigits,
            ),
            isChange: false,
            addressType: recipients.first.addressType,
          ),
        ],
      );
      Logging.instance.d("RBF on assumed send all");
      return await prepareSend(txData: txData);
    } else if (txData.recipients!.where((e) => e.isChange).length == 1) {
      final newFee = BigInt.from(own.vSize * newRate);
      final feeDifferenceRequired = newFee - oldFee;
      if (feeDifferenceRequired < BigInt.zero) {
        throw Exception("Negative new fee in RBF found");
      } else if (feeDifferenceRequired == BigInt.zero) {
        throw Exception("New fee in RBF has not changed at all");
      }

      final indexOfChangeOutput = txData.recipients!.indexWhere(
        (e) => e.isChange,
      );

      final removed = txData.recipients!.removeAt(indexOfChangeOutput);

      BigInt newChangeAmount = removed.amount.raw - feeDifferenceRequired;

      if (newChangeAmount >= BigInt.zero) {
        if (newChangeAmount >= cryptoCurrency.dustLimit.raw) {
          // yay we have enough
          // update recipients
          txData.recipients!.insert(
            indexOfChangeOutput,
            removed.copyWith(
              amount: Amount(
                rawValue: newChangeAmount,
                fractionDigits: cryptoCurrency.fractionDigits,
              ),
            ),
          );
          Logging.instance.d(
            "RBF with same utxo set with increased fee and reduced change",
          );
        } else {
          // new change amount is less than dust limit.
          // TODO: check if worth adding another utxo?
          // depending on several factors, it may be cheaper to just add]
          // the dust to the fee...
          // we'll do that for now... aka remove the change output entirely
          // which now that I think about it, will reduce the size of the tx...
          // oh well...

          // do nothing here as we already removed the change output above
          Logging.instance.d(
            "RBF with same utxo set with increased fee and no change",
          );
        }
        return await buildTransaction(
          txData: txData.copyWith(
            usedUTXOs: txData.utxos!.toList(),
            fee: Amount(
              rawValue: newFee,
              fractionDigits: cryptoCurrency.fractionDigits,
            ),
          ),
          inputsWithKeys: await addSigningKeys(txData.utxos!.toList()),
        );

        // if change amount is negative
      } else {
        // we need more utxos
        if (otherAvailableUtxos.isEmpty) {
          throw Exception("Insufficient funds to pay for increased fee");
        }

        final List<UTXO> extraUtxos = [];
        for (int i = 0; i < otherAvailableUtxos.length; i++) {
          final utxoToAdd = otherAvailableUtxos[i];
          newChangeAmount += BigInt.from(utxoToAdd.value);
          extraUtxos.add(utxoToAdd);

          if (newChangeAmount >= cryptoCurrency.dustLimit.raw) {
            break;
          }
        }

        if (newChangeAmount < cryptoCurrency.dustLimit.raw) {
          throw Exception("Insufficient funds to pay for increased fee");
        }
        txData.recipients!.insert(
          indexOfChangeOutput,
          removed.copyWith(
            amount: Amount(
              rawValue: newChangeAmount,
              fractionDigits: cryptoCurrency.fractionDigits,
            ),
          ),
        );

        final newUtxoSet = {
          ...txData.utxos!.whereType<StandardInput>(),
          ...extraUtxos.map((e) => StandardInput(e)),
        };

        // TODO: remove assert
        assert(newUtxoSet.length == txData.utxos!.length + extraUtxos.length);

        Logging.instance.d(
          "RBF with ${extraUtxos.length} extra utxo(s)"
          " added to pay for the new fee",
        );

        return await buildTransaction(
          txData: txData.copyWith(
            utxos: newUtxoSet,
            usedUTXOs: newUtxoSet.toList(),
            fee: Amount(
              rawValue: newFee,
              fractionDigits: cryptoCurrency.fractionDigits,
            ),
          ),
          inputsWithKeys: await addSigningKeys(newUtxoSet.toList()),
        );
      }
    } else {
      // TODO handle building a tx here in this case
      throw Exception(
        "Unexpected number of change outputs found:"
        " ${txData.recipients!.where((e) => e.isChange).length}",
      );
    }
  }
}
