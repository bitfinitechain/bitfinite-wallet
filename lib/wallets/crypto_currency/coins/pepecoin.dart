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
            // Kept as failovers, named for who runs them rather than numbered:
            // "Pepecoin Electrum 2" told nobody which server they were on when
            // one of them was the one misbehaving.
            NodeModel(
              host: "electrum.pepeblocks.com",
              port: 50002,
              name: "PepeBlocks Electrum",
              id: "${DefaultNodes.defaultNodeIdPrefix}${identifier}_pepeblocks",
              useSSL: true,
              enabled: true,
              coinName: identifier,
              isFailover: true,
              isDown: false,
              torEnabled: true,
              clearnetEnabled: true,
              isPrimary: false,
            ),
            NodeModel(
              host: "electrum.pepe.tips",
              port: 50002,
              name: "Pepe Tips Electrum",
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
            // Last-resort failover: a TLS relay on our own infrastructure in
            // front of a community-operated backup server whose operator
            // asked not to be named publicly. The relay terminates our cert
            // and forwards over verified TLS, so neither this file nor the
            // shipped APK carries their hostname. It shares a box with the
            // primary, so it covers a dead ElectrumX, not a dead box — which
            // is why it sits behind the two independent public servers.
            NodeModel(
              host: "pepelectrum.bitfinitechain.org",
              port: 50012,
              name: "BitFinite Pepecoin Backup",
              id: "${DefaultNodes.defaultNodeIdPrefix}${identifier}_relay",
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

  /// Checked against the server's reported `genesis_hash` on every connect;
  /// a mismatch means the server is serving a different chain.
  ///
  /// This carried Dogecoin's hash, inherited when the class was derived from
  /// dogecoin.dart. That did not fail loudly: the check is wrapped in a
  /// try/catch that only logs, so the guard has been quietly not-guarding —
  /// and worse than absent, because Dogecoin's value means a Dogecoin server
  /// would have *passed* it.
  ///
  /// The value below was derived twice, independently: double-SHA256 of the
  /// block 0 header fetched from the chain, and again by our own ElectrumX,
  /// which logs `verified genesis block with hash ...` on startup. Both agree.
  @override
  String get genesisHash {
    switch (network) {
      case CryptoCurrencyNetwork.main:
        return "37981c0c48b8d48965376c8a42ece9a0838daadb93ff975cb091f57f8c2a5faa";
      case CryptoCurrencyNetwork.test:
        // Still Dogecoin's testnet value, and still wrong. Left rather than
        // guessed: we ship no Pepecoin testnet, so there is no chain to read
        // the real one from. Anyone enabling it must fix this line first.
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
        // Ours, and primary since 2026-08-29. Measured against both public
        // servers on the same address at the same moment: connect 0.1s vs
        // 0.6-0.7s, headers.subscribe 0.03s vs ~0.30s, a 435-tx history 0.18s
        // vs ~0.90s. All three returned identical tip, balance and history, so
        // this is the same data sooner rather than different data.
        //
        // The reason is reliability rather than speed. electrum.pepe.tips spent
        // a day answering server.version in a second and then hanging forever
        // on anything touching the chain — a client connects "successfully" and
        // waits, with nothing to trigger failover — then refused connections
        // outright, then recovered. Intermittent is the hard case, and running
        // our own is the only real answer to it.
        return NodeModel(
          host: "pepelectrum.bitfinitechain.org",
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
