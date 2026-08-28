import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;

import '../../../models/isar/models/blockchain_data/address.dart';
import '../../../models/node_model.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/default_nodes.dart';
import '../../../utilities/enums/derive_path_type_enum.dart';
import '../crypto_currency.dart';
import '../interfaces/electrumx_currency_interface.dart';
import '../intermediate/bip39_hd_currency.dart';

class Pepecoin extends Bip39HDCurrency with ElectrumXCurrencyInterface {
  Pepecoin(super.network) {
    _idMain = "pepecoin";
    _uriScheme = "pepecoin";
    switch (network) {
      case CryptoCurrencyNetwork.main:
        _id = _idMain;
        _name = "Pepecoin";
        _ticker = "PEP";
      case CryptoCurrencyNetwork.test:
        _id = "pepecoinTestNet";
        _name = "tPepecoin";
        _ticker = "tPEP";
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  late final String _id;
  @override
  String get identifier => _id;

  late final String _idMain;
  @override
  String get mainNetId => _idMain;

  late final String _name;
  @override
  String get prettyName => _name;

  late final String _uriScheme;
  @override
  String get uriScheme => _uriScheme;

  late final String _ticker;
  @override
  String get ticker => _ticker;

  @override
  bool get torSupport => true;

  @override
  List<DerivePathType> get supportedDerivationPathTypes => [
    DerivePathType.bip44,
  ];

  @override
  String constructDerivePath({
    required DerivePathType derivePathType,
    int account = 0,
    required int chain,
    required int index,
  }) {
    // SLIP-44 registers Pepecoin Core as 3434. Do NOT derive this from
    // wifPrefix the way Dogecoin does: Pepecoin shares Dogecoin's wif byte
    // (0x9e main, 0xf1 test), so that switch returns Dogecoin's coin type and
    // quietly puts every PEP wallet on m/44'/3'/... The addresses still look
    // right and still spend, so nothing appears wrong until someone restores
    // the same seed in another Pepecoin wallet and finds an empty account.
    final String coinType = switch (network) {
      CryptoCurrencyNetwork.main => "3434",
      CryptoCurrencyNetwork.test => "1",
      _ => throw Exception("Unsupported network: $network"),
    };

    int purpose;
    switch (derivePathType) {
      case DerivePathType.bip44:
        purpose = 44;
        break;

      default:
        throw Exception("DerivePathType $derivePathType not supported");
    }

    return "m/$purpose'/$coinType'/$account'/$chain/$index";
  }

  // Two public servers are all that exist. The published list had three and
  // electrum.pepelum.site no longer resolves, so this is the whole of Pepecoin's
  // public Electrum infrastructure — neither host is ours. isFailover:true moves
  // the client here when the primary fails and keeps it here, rather than
  // retrying a dead host on every request.
  @override
  List<NodeModel> get additionalDefaultNodes =>
      network == CryptoCurrencyNetwork.main
          ? [
            NodeModel(
              host: "electrum.pepe.tips",
              port: 50002,
              name: "Pepecoin Electrum 2",
              id: "${DefaultNodes.defaultNodeIdPrefix}${identifier}_electrum2",
              useSSL: true,
              enabled: true,
              coinName: identifier,
              isFailover: true,
              isDown: false,
              torEnabled: true,
              clearnetEnabled: true,
              isPrimary: false,
            ),
          ]
          : const [];

  @override
  Amount get dustLimit =>
      Amount(rawValue: BigInt.from(1000000), fractionDigits: fractionDigits);

  @override
  String get genesisHash {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return "1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691";
      case CryptoCurrencyNetwork.test:
        return "bb0a78264637406b6360aad926284d544d7049f45189db5664f3c4d07350559e";
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  @override
  ({coinlib.Address address, AddressType addressType}) getAddressForPublicKey({
    required coinlib.ECPublicKey publicKey,
    required DerivePathType derivePathType,
  }) {
    switch (derivePathType) {
      case DerivePathType.bip44:
        final addr = coinlib.P2PKHAddress.fromPublicKey(
          publicKey,
          version: networkParams.p2pkhPrefix,
        );

        return (address: addr, addressType: AddressType.p2pkh);

      default:
        throw Exception("DerivePathType $derivePathType not supported");
    }
  }

  /// #269B4D, the primary green from Pepecoin's brand guide (page 02).
  /// Their palette also carries #208241 and #16532A as darker greens and
  /// #C07A4E for the mouth; the primary is the one that identifies the coin.
  @override
  int get brandColorValue => 0xFF269B4D;

  @override
  int get minConfirms => 1;

  @override
  coinlib.Network get networkParams {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return coinlib.Network(
          wifPrefix: 0x9e,
          p2pkhPrefix: 0x38, // 56 -> addresses start with P
          p2shPrefix: 0x16,
          privHDPrefix: 0x02fac398,
          pubHDPrefix: 0x02facafd,
          bech32Hrp: "pep", // unused: Pepecoin Core has no segwit
          messagePrefix: '\x19Pepecoin Signed Message:\n',
          minFee: BigInt.from(1), // Not used in stack wallet currently
          minOutput: dustLimit.raw, // Not used in stack wallet currently
          feePerKb: BigInt.from(1), // Not used in stack wallet currently
        );
      case CryptoCurrencyNetwork.test:
        return coinlib.Network(
          wifPrefix: 0xf1,
          p2pkhPrefix: 0x71,
          p2shPrefix: 0xc4,
          privHDPrefix: 0x04358394,
          pubHDPrefix: 0x043587cf,
          bech32Hrp: "tpep", // unused: Pepecoin Core has no segwit
          messagePrefix: "\x19Pepecoin Signed Message:\n",
          minFee: BigInt.from(1), // Not used in stack wallet currently
          minOutput: dustLimit.raw, // Not used in stack wallet currently
          feePerKb: BigInt.from(1), // Not used in stack wallet currently
        );
      default:
        throw Exception("Unsupported network: $network");
    }
  }

  @override
  bool validateAddress(String address) {
    try {
      coinlib.Address.fromString(address, networkParams);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  NodeModel defaultNode({required bool isPrimary}) {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return NodeModel(
          host: "electrum.pepeblocks.com",
          port: 50002,
          // NOT DefaultNodes.defaultName: that constant is
          // "${AppConfig.prefix} Default" — literally "BitFinite Default" —
          // and every coin shares it. Copying it here produced two nodes with
          // the same name pointing at different chains, which on the node list
          // reads as BFX using Pepecoin's server.
          name: "Pepecoin Default",
          id: DefaultNodes.buildId(this),
          useSSL: true,
          enabled: true,
          coinName: identifier,
          isFailover: true,
          isDown: false,
          torEnabled: true,
          clearnetEnabled: true,
          isPrimary: isPrimary,
        );

      case CryptoCurrencyNetwork.test:
        return NodeModel(
          host: "electrum.pepeblocks.com",
          port: 50002,
          // NOT DefaultNodes.defaultName: that constant is
          // "${AppConfig.prefix} Default" — literally "BitFinite Default" —
          // and every coin shares it. Copying it here produced two nodes with
          // the same name pointing at different chains, which on the node list
          // reads as BFX using Pepecoin's server.
          name: "Pepecoin Default",
          id: DefaultNodes.buildId(this),
          useSSL: true,
          enabled: true,
          coinName: identifier,
          isFailover: true,
          isDown: false,
          torEnabled: true,
          clearnetEnabled: true,
          isPrimary: isPrimary,
        );

      default:
        throw UnimplementedError();
    }
  }

  @override
  int get defaultSeedPhraseLength => 12;

  @override
  int get fractionDigits => 8;

  @override
  bool get hasBuySupport => true;

  @override
  bool get hasMnemonicPassphraseSupport => true;

  @override
  List<int> get possibleMnemonicLengths => [defaultSeedPhraseLength, 24];

  @override
  AddressType get defaultAddressType => defaultDerivePathType.getAddressType();

  @override
  BigInt get satsPerCoin => BigInt.from(100000000);

  @override
  int get targetBlockTimeSeconds => 60;

  @override
  DerivePathType get defaultDerivePathType => DerivePathType.bip44;

  @override
  Uri defaultBlockExplorer(String txid) {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return Uri.parse("https://pepecoinexplorer.com/tx/$txid");
      case CryptoCurrencyNetwork.test:
        return Uri.parse("https://pepeblocks.com/tx/$txid");
      default:
        throw Exception(
          "Unsupported network for defaultBlockExplorer(): $network",
        );
    }
  }

  @override
  int get transactionVersion => 1;

  @override
  BigInt get defaultFeeRate => BigInt.from(1000000);
  // Inherited from Dogecoin, whose fee schedule Pepecoin forked unchanged:
  // https://github.com/dogecoin/dogecoin/blob/master/doc/fee-recommendation.md
}
