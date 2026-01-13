import 'dart:math';

export '../generated/libepiccash_interface_impl.dart';

abstract class LibEpicCashInterface {
  const LibEpicCashInterface();

  bool txTypeIsReceived(Enum value);
  bool txTypeIsReceiveCancelled(Enum value);
  bool txTypeIsSentCancelled(Enum value);

  Future<String> initializeNewWallet({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
  });

  Future<String> openWallet({required String config, required String password});

  Future<void> recoverWallet({
    required String config,
    required String password,
    required String mnemonic,
    required String name,
  });

  Future<({String commitId, String slateId})> txHttpSend({
    required String wallet,
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  });

  Future<({String commitId, String slateId, String slateJson})> createTransaction({
    required String wallet,
    required int amount,
    required String address,
    required int secretKeyIndex,
    required String epicboxConfig,
    required int minimumConfirmations,
    required String note,
    bool returnSlate = false,
  });

  Future<({String slateId, String commitId, String slateJson})> txReceive({
    required String wallet,
    required String slateJson,
  });

  Future<({String slateId, String commitId})> txFinalize({
    required String wallet,
    required String slateJson,
  });

  Future<String> cancelTransaction({
    required String wallet,
    required String transactionId,
  });

  Future<List<EpicTransaction>> getTransactions({
    required String wallet,
    required int refreshFromNode,
  });

  void startEpicboxListener({
    required String walletId,
    required String wallet,
    required String epicboxConfig,
  });

  void stopEpicboxListener({required String walletId});

  void stopAllEpicboxListeners();

  bool isEpicboxListenerRunning({required String walletId});

  List<String> getActiveListenerWalletIds();

  bool validateSendAddress({required String address});

  Future<({int fee, bool strategyUseAll, int total})> getTransactionFees({
    required String wallet,
    required int amount,
    required int minimumConfirmations,
    required int available,
  });

  Future<
    ({
      double awaitingFinalization,
      double pending,
      double spendable,
      double total,
    })
  >
  getWalletBalances({
    required String wallet,
    required int refreshFromNode,
    required int minimumConfirmations,
  });

  Future<String> getAddressInfo({
    required String wallet,
    required int index,
    required String epicboxConfig,
  });

  Future<int> scanOutputs({
    required String wallet,
    required int startHeight,
    required int numberOfBlocks,
  });

  Future<int> getChainHeight({required String config});

  Future<String> deleteWallet({required String wallet, required String config});

  String getPluginVersion();
}

class EpicTransaction {
  final String parentKeyId;
  final int id;
  final String? txSlateId;
  final Enum txType;
  final String creationTs;
  final String confirmationTs;
  final bool confirmed;
  final int numInputs;
  final int numOutputs;
  final String amountCredited;
  final String amountDebited;
  final String? fee;
  final String? ttlCutoffHeight;
  final List<EpicMessage>? messages;
  final String? storedTx;
  final String? kernelExcess;
  final int? kernelLookupMinHeight;
  final String? paymentProof;

  EpicTransaction({
    required this.parentKeyId,
    required this.id,
    this.txSlateId,
    required this.txType,
    required this.creationTs,
    required this.confirmationTs,
    required this.confirmed,
    required this.numInputs,
    required this.numOutputs,
    required this.amountCredited,
    required this.amountDebited,
    this.fee,
    this.ttlCutoffHeight,
    this.messages,
    this.storedTx,
    this.kernelExcess,
    this.kernelLookupMinHeight,
    this.paymentProof,
  });

  @override
  String toString() {
    return 'EpicTransaction('
        'id: $id, '
        'txSlateId: $txSlateId, '
        'type: $txType, '
        'confirmed: $confirmed, '
        'inputs: $numInputs, '
        'outputs: $numOutputs, '
        'credited: $amountCredited, '
        'debited: $amountDebited, '
        'fee: $fee, '
        'created: $creationTs, '
        'confirmed: $confirmationTs, '
        'messages: ${messages?.length ?? 0}'
        ')';
  }
}

class EpicMessage {
  final String id;
  final String publicKey;
  final String? message;
  final String? messageSig;

  EpicMessage({
    required this.id,
    required this.publicKey,
    this.message,
    this.messageSig,
  });

  @override
  String toString() {
    return 'EpicMessage('
        'id: $id, '
        'publicKey: ${publicKey.substring(0, 8)}..., '
        'message: ${message != null ? '"${message!.substring(0, min(20, message!.length))}..."' : 'null'}'
        ')';
  }
}

class BadHttpAddressException implements Exception {}
