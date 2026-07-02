import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:isar_community/isar.dart';

import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/isar/models/blockchain_data/v2/input_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/output_v2.dart';
import '../../../models/isar/models/blockchain_data/v2/transaction_v2.dart';
import '../../../services/coins/bitcoincash/bch_utils.dart';
import '../../../services/coins/bitcoincash/cashtokens.dart' as cash_tokens;
import '../../../utilities/amount/amount.dart';
import '../../../utilities/bfx_cashaddr.dart';
import '../../../utilities/extensions/extensions.dart';
import '../../../utilities/logger.dart';
import '../../crypto_currency/crypto_currency.dart';
import '../../crypto_currency/interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_wallet.dart';
import '../wallet_mixin_interfaces/bcash_interface.dart';
import '../wallet_mixin_interfaces/coin_control_interface.dart';
import '../wallet_mixin_interfaces/electrumx_interface.dart';
import '../wallet_mixin_interfaces/extended_keys_interface.dart';

/// BitFinite (BFX) wallet — a faithful adaptation of BitcoincashWallet.
///
/// Differences from BCH:
///  - super(Bitfinite(network)) and single derivation path (m/44'/9116').
///  - CashFusionInterface dropped (no BFX fusion servers). BCashInterface is
///    KEPT because BFX signs with BCH-style SIGHASH_FORKID (fork id 0 — verified
///    against bitfinite-core: identical to BCH, so BCH tx-building/signing is
///    correct as-is).
///  - The two bitbox cashaddr calls (convertAddressString / normalizeAddress)
///    are routed through BfxCashAddr because BFX uses a custom base32 alphabet
///    (q<->f swapped) — stock bitbox would emit/verify the wrong strings.
///
/// The token/SLP/fusion *detection* in checkBlockUTXO + tx classification is kept
/// as a safety net (harmless if BFX has no tokens active).
class BitfiniteWallet<T extends ElectrumXCurrencyInterface>
    extends Bip39HDWallet<T>
    with
        ElectrumXInterface<T>,
        ExtendedKeysInterface<T>,
        BCashInterface<T>,
        CoinControlInterface<T> {
  @override
  int get isarTransactionVersion => 2;

  BitfiniteWallet(CryptoCurrencyNetwork network)
    : super(Bitfinite(network) as T);

  @override
  FilterOperation? get changeAddressFilterOperation =>
      FilterGroup.and(standardChangeAddressFilters);

  @override
  FilterOperation? get receivingAddressFilterOperation =>
      FilterGroup.and(standardReceivingAddressFilters);

  // ===========================================================================

  @override
  Future<List<Address>> fetchAddressesForElectrumXScan() async {
    final allAddresses = await mainDB
        .getAddresses(walletId)
        .filter()
        .not()
        .typeEqualTo(AddressType.nonWallet)
        .and()
        .group(
          (q) => q
              .subTypeEqualTo(AddressSubType.receiving)
              .or()
              .subTypeEqualTo(AddressSubType.change),
        )
        .findAll();
    return allAddresses;
  }

  /// Convert a stored legacy (base58) address to BFX cashaddr for display and
  /// for matching against ElectrumX-reported output addresses.
  ///
  /// NOTE: confirm the exact address string electr-bfx returns in tx vout JSON
  /// during the first sync test, and make sure both sides use the same canonical
  /// form (BFX cashaddr here). If electr-bfx returns base58, drop this conversion.
  @override
  String convertAddressString(String address) {
    if (address.startsWith("1") || address.startsWith("3")) {
      final decoded = bs58check.decode(address);
      final type = decoded[0] == cryptoCurrency.networkParams.p2shPrefix
          ? BfxCashAddr.typeP2SH
          : BfxCashAddr.typeP2PKH;
      return BfxCashAddr.encode(
        hash160: Uint8List.fromList(decoded.sublist(1)),
        type: type,
        prefix: BfxCashAddr.mainnetPrefix,
      );
    }
    return address;
  }

  // ===========================================================================

  @override
  Future<void> updateTransactions() async {
    final List<Address> allAddressesOld =
        await fetchAddressesForElectrumXScan();

    final Set<String> receivingAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.receiving)
        .map((e) => convertAddressString(e.value))
        .toSet();

    final Set<String> changeAddresses = allAddressesOld
        .where((e) => e.subType == AddressSubType.change)
        .map((e) => convertAddressString(e.value))
        .toSet();

    final allAddressesSet = {...receivingAddresses, ...changeAddresses};

    final List<Map<String, dynamic>> allTxHashes = await fetchHistory(
      allAddressesSet,
    );

    final List<Map<String, dynamic>> allTransactions = [];

    for (final txHash in allTxHashes) {
      final tx = await electrumXCachedClient.getTransaction(
        txHash: txHash["tx_hash"] as String,
        verbose: true,
        cryptoCurrency: cryptoCurrency,
      );

      if (allTransactions.indexWhere(
            (e) => e["txid"] == tx["txid"] as String,
          ) ==
          -1) {
        tx["height"] = txHash["height"];
        allTransactions.add(tx);
      }
    }

    final List<TransactionV2> txns = [];

    for (final txData in allTransactions) {
      bool wasSentFromThisWallet = false;
      bool wasReceivedInThisWallet = false;
      BigInt amountReceivedInThisWallet = BigInt.zero;
      BigInt changeAmountReceivedInThisWallet = BigInt.zero;

      // parse inputs
      final List<InputV2> inputs = [];
      for (final jsonInput in txData["vin"] as List) {
        final map = Map<String, dynamic>.from(jsonInput as Map);

        final List<String> addresses = [];
        String valueStringSats = "0";
        OutpointV2? outpoint;

        final coinbase = map["coinbase"] as String?;

        if (coinbase == null) {
          final txid = map["txid"] as String;
          final vout = map["vout"] as int;

          final inputTx = await electrumXCachedClient.getTransaction(
            txHash: txid,
            cryptoCurrency: cryptoCurrency,
          );

          try {
            final prevOutJson = Map<String, dynamic>.from(
              (inputTx["vout"] as List).firstWhere((e) => e["n"] == vout)
                  as Map,
            );
            final prevOut = OutputV2.fromElectrumXJson(
              prevOutJson,
              decimalPlaces: cryptoCurrency.fractionDigits,
              walletOwns: false,
              isFullAmountNotSats: true,
            );

            outpoint = OutpointV2.isarCantDoRequiredInDefaultConstructor(
              txid: txid,
              vout: vout,
            );
            valueStringSats = prevOut.valueStringSats;
            addresses.addAll(prevOut.addresses);
          } catch (e, s) {
            Logging.instance.w(
              "Error getting prevOutJson: $e\nStack trace: $s",
              error: e,
              stackTrace: s,
            );
          }
        }

        InputV2 input = InputV2.isarCantDoRequiredInDefaultConstructor(
          scriptSigHex: map["scriptSig"]?["hex"] as String?,
          scriptSigAsm: map["scriptSig"]?["asm"] as String?,
          sequence: map["sequence"] as int?,
          outpoint: outpoint,
          valueStringSats: valueStringSats,
          addresses: addresses,
          witness: map["witness"] as String?,
          coinbase: coinbase,
          innerRedeemScriptAsm: map["innerRedeemscriptAsm"] as String?,
          walletOwns: false,
        );

        if (allAddressesSet.intersection(input.addresses.toSet()).isNotEmpty) {
          wasSentFromThisWallet = true;
          input = input.copyWith(walletOwns: true);
        }

        inputs.add(input);
      }

      // parse outputs
      final List<OutputV2> outputs = [];
      for (final outputJson in txData["vout"] as List) {
        OutputV2 output = OutputV2.fromElectrumXJson(
          Map<String, dynamic>.from(outputJson as Map),
          decimalPlaces: cryptoCurrency.fractionDigits,
          walletOwns: false,
          isFullAmountNotSats: true,
        );

        if (receivingAddresses
            .intersection(output.addresses.toSet())
            .isNotEmpty) {
          wasReceivedInThisWallet = true;
          amountReceivedInThisWallet += output.value;
          output = output.copyWith(walletOwns: true);
        } else if (changeAddresses
            .intersection(output.addresses.toSet())
            .isNotEmpty) {
          wasReceivedInThisWallet = true;
          changeAmountReceivedInThisWallet += output.value;
          output = output.copyWith(walletOwns: true);
        }

        outputs.add(output);
      }

      final totalOut = outputs
          .map((e) => e.value)
          .fold(BigInt.zero, (value, element) => value + element);

      TransactionType type;
      TransactionSubType subType = TransactionSubType.none;

      if (wasSentFromThisWallet) {
        type = TransactionType.outgoing;

        if (wasReceivedInThisWallet) {
          if (changeAmountReceivedInThisWallet + amountReceivedInThisWallet ==
              totalOut) {
            type = TransactionType.sentToSelf;
          } else if (amountReceivedInThisWallet == BigInt.zero) {
            // typical send
          }

          if (outputs.isNotEmpty) {
            final output = outputs.first;
            if (BchUtils.isFUZE(output.scriptPubKeyHex.toUint8ListFromHex)) {
              subType = TransactionSubType.cashFusion;
            }
          }
        }
      } else if (wasReceivedInThisWallet) {
        type = TransactionType.incoming;
      } else {
        Logging.instance.e("Unexpected tx found (ignoring it)");
        Logging.instance.d("Unexpected tx found (ignoring it): $txData");
        continue;
      }

      final tx = TransactionV2(
        walletId: walletId,
        blockHash: txData["blockhash"] as String?,
        hash: txData["hash"] as String,
        txid: txData["txid"] as String,
        height: txData["height"] as int?,
        version: txData["version"] as int,
        timestamp:
            txData["blocktime"] as int? ??
            DateTime.timestamp().millisecondsSinceEpoch ~/ 1000,
        inputs: List.unmodifiable(inputs),
        outputs: List.unmodifiable(outputs),
        type: type,
        subType: subType,
        otherData: null,
      );

      txns.add(tx);
    }

    await mainDB.updateOrPutTransactionV2s(txns);
  }

  @override
  Future<({String? blockedReason, bool blocked, String? utxoLabel})>
  checkBlockUTXO(
    Map<String, dynamic> jsonUTXO,
    String? scriptPubKeyHex,
    Map<String, dynamic> jsonTX,
    String? utxoOwnerAddress,
  ) async {
    bool blocked = false;
    String? blockedReason;

    if (scriptPubKeyHex != null) {
      // Block accidental spends of token outputs (safety net).
      try {
        final ctOutput = cash_tokens.unwrap_spk(
          scriptPubKeyHex.toUint8ListFromHex,
        );
        if (ctOutput.token_data != null) {
          blocked = true;
          blockedReason = "Cash token output detected";
        }
      } catch (e, s) {
        Logging.instance.w(
          "Script pub key cash token parsing check failed",
          error: e,
          stackTrace: s,
        );
      }

      if (!blocked && BchUtils.isSLP(scriptPubKeyHex.toUint8ListFromHex)) {
        blocked = true;
        blockedReason = "SLP token output detected";
      }
    }

    return (blockedReason: blockedReason, blocked: blocked, utxoLabel: null);
  }

  @override
  Amount roughFeeEstimate(
    int inputCount,
    int outputCount,
    BigInt feeRatePerKB,
  ) {
    return Amount(
      rawValue: BigInt.from(
        ((181 * inputCount) + (34 * outputCount) + 10) *
            (feeRatePerKB.toInt() / 1000).ceil(),
      ),
      fractionDigits: info.coin.fractionDigits,
    );
  }

  @override
  int estimateTxFee({required int vSize, required BigInt feeRatePerKB}) {
    return (feeRatePerKB * BigInt.from(vSize) ~/ BigInt.from(1000)).toInt();
  }

  @override
  String normalizeAddress(String address) {
    try {
      if (BfxCashAddr.isValid(address)) {
        final d = BfxCashAddr.decode(address);
        final version = d.type == BfxCashAddr.typeP2SH
            ? cryptoCurrency.networkParams.p2shPrefix
            : cryptoCurrency.networkParams.p2pkhPrefix;
        return bs58check.encode(
          Uint8List.fromList([version, ...d.hash160]),
        );
      }
      return address;
    } catch (_) {
      return address;
    }
  }
}
