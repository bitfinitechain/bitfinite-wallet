import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/global/wallets_provider.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/amount/amount.dart';
import '../../../utilities/if_not_already.dart';
import '../../../utilities/logger.dart';
import '../../../utilities/show_loading.dart';
import '../../../utilities/text_styles.dart';
import '../../../utilities/util.dart';
import '../../../wallets/isar/providers/wallet_info_provider.dart';
import '../../../wallets/wallet/impl/firo_wallet.dart';
import '../../../widgets/desktop/primary_button.dart';
import '../../../widgets/desktop/secondary_button.dart';
import '../../../widgets/rounded_container.dart';
import '../../../widgets/stack_dialog.dart';
import '../../../widgets/textfields/adaptive_text_field.dart';

class RegisterMasternodeForm extends ConsumerStatefulWidget {
  const RegisterMasternodeForm({super.key, required this.firoWalletId});

  final String firoWalletId;

  @override
  ConsumerState<RegisterMasternodeForm> createState() =>
      _RegisterMasternodeFormState();
}

class _RegisterMasternodeFormState
    extends ConsumerState<RegisterMasternodeForm> {
  late final Amount _masternodeThreshold;

  final _ipAndPortController = TextEditingController();
  final _operatorPubKeyController = TextEditingController();
  final _votingAddressController = TextEditingController();
  final _operatorRewardController = TextEditingController(text: "0");
  final _payoutAddressController = TextEditingController();

  TextStyle _getStyle(BuildContext context) {
    return Util.isDesktop
        ? STextStyles.desktopTextExtraExtraSmall(context).copyWith(
            color: Theme.of(
              context,
            ).extension<StackColors>()!.textFieldActiveSearchIconRight,
          )
        : STextStyles.smallMed12(context);
  }

  late final VoidCallback _register;

  bool _enableCreateButton = false;

  void _validate() {
    if (mounted) {
      setState(() {
        _enableCreateButton = [
          _ipAndPortController.text.trim().isNotEmpty,
          _operatorPubKeyController.text.trim().isNotEmpty,
          _operatorRewardController.text.trim().isNotEmpty,
          _payoutAddressController.text.trim().isNotEmpty,
        ].every((e) => e);
      });
    }
  }

  Future<String> _registerMasternode() async {
    final parts = _ipAndPortController.text.trim().split(':');
    final ip = parts[0];
    final port = int.parse(parts[1]);
    final operatorPubKey = _operatorPubKeyController.text.trim();
    final votingAddress = _votingAddressController.text.trim();
    final operatorReward = _operatorRewardController.text.trim().isNotEmpty
        ? (double.parse(_operatorRewardController.text.trim()) * 100).floor()
        : 0;
    final payoutAddress = _payoutAddressController.text.trim();

    final wallet =
        ref.read(pWallets).getWallet(widget.firoWalletId) as FiroWallet;

    final txId = await wallet.registerMasternode(
      ip,
      port,
      operatorPubKey,
      votingAddress,
      operatorReward,
      payoutAddress,
    );

    Logging.instance.i('Masternode registration submitted: $txId');

    return txId;
  }

  @override
  void initState() {
    super.initState();
    final coin = ref.read(pWalletCoin(widget.firoWalletId));
    _masternodeThreshold = Amount.fromDecimal(
      kMasterNodeValue,
      fractionDigits: coin.fractionDigits,
    );

    _register = IfNotAlreadyAsync<void>(() async {
      Exception? ex;

      final txId = await showLoading(
        whileFuture: _registerMasternode(),
        context: context,
        message: "Creating and submitting masternode registration...",
        delay: const Duration(seconds: 1),
        onException: (e) => ex = e,
      );

      if (mounted) {
        final String title;
        String message;
        if (ex != null || txId == null) {
          message = ex?.toString().trim() ?? "Unknown error: txId=$txId";
          const exceptionPrefix = "Exception:";
          while (message.startsWith(exceptionPrefix) &&
              message.length > exceptionPrefix.length) {
            message = message.substring(exceptionPrefix.length).trim();
          }
          title = "Registration failed";
        } else {
          title = "Masternode Registration Submitted";
          message =
              "Masternode registration submitted, your masternode will "
              "appear in the list after the tx is confirmed.\n\nTransaction"
              " ID: $txId";
        }

        await showDialog<void>(
          context: context,
          builder: (_) => StackOkDialog(
            title: title,
            message: message,
            desktopPopRootNavigator: Util.isDesktop,
            maxWidth: Util.isDesktop ? 400 : null,
          ),
        );
      }
    }).execute;
  }

  @override
  void dispose() {
    _ipAndPortController.dispose();
    _operatorPubKeyController.dispose();
    _votingAddressController.dispose();
    _operatorRewardController.dispose();
    _payoutAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = Theme.of(context).extension<StackColors>()!;
    final spendableFiro = ref.watch(
      pWalletBalance(widget.firoWalletId).select((s) => s.spendable),
    );
    final canRegister = spendableFiro >= _masternodeThreshold;
    final availableCount = (spendableFiro.raw ~/ _masternodeThreshold.raw)
        .toInt();

    final infoColor = canRegister
        ? stack.snackBarTextSuccess
        : stack.snackBarTextError;
    final infoColorBG = canRegister
        ? stack.snackBarBackSuccess
        : stack.snackBarBackError;

    final infoMessage = canRegister
        ? "You can register $availableCount masternode(s)."
        : "Insufficient funds to register a masternode. "
              "You need at least 1000 public FIRO.";

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: RoundedContainer(
                  color: infoColorBG,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      infoMessage,
                      style: STextStyles.w600_14(
                        context,
                      ).copyWith(color: infoColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: Util.isDesktop ? 24 : 16),

        SelectableText("IP:Port", style: _getStyle(context)),
        SizedBox(height: Util.isDesktop ? 10 : 8),
        AdaptiveTextField(
          controller: _ipAndPortController,
          showPasteClearButton: true,
          maxLines: 1,
          onChangedComprehensive: (_) => _validate(),
        ),
        SizedBox(height: Util.isDesktop ? 24 : 16),

        SelectableText("Operator public key (BLS)", style: _getStyle(context)),
        SizedBox(height: Util.isDesktop ? 10 : 8),
        AdaptiveTextField(
          controller: _operatorPubKeyController,
          showPasteClearButton: true,
          maxLines: 1,
          onChangedComprehensive: (_) => _validate(),
        ),
        SizedBox(height: Util.isDesktop ? 24 : 16),

        SelectableText("Voting address (optional)", style: _getStyle(context)),
        SizedBox(height: Util.isDesktop ? 10 : 8),
        AdaptiveTextField(
          controller: _votingAddressController,
          showPasteClearButton: true,
          maxLines: 1,
          labelText: "Defaults to owner address",
          onChangedComprehensive: (_) => _validate(),
        ),
        SizedBox(height: Util.isDesktop ? 24 : 16),

        SelectableText("Operator reward (%)", style: _getStyle(context)),
        SizedBox(height: Util.isDesktop ? 10 : 8),
        AdaptiveTextField(
          controller: _operatorRewardController,
          showPasteClearButton: true,
          maxLines: 1,
          onChangedComprehensive: (_) => _validate(),
        ),
        SizedBox(height: Util.isDesktop ? 24 : 16),

        SelectableText("Payout address", style: _getStyle(context)),
        SizedBox(height: Util.isDesktop ? 10 : 8),
        AdaptiveTextField(
          controller: _payoutAddressController,
          showPasteClearButton: true,
          maxLines: 1,
          onChangedComprehensive: (_) => _validate(),
        ),

        Util.isDesktop ? const SizedBox(height: 32) : const Spacer(),

        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: "Cancel",
                onPressed: Navigator.of(context).pop,
                buttonHeight: Util.isDesktop ? .l : null,
              ),
            ),
            SizedBox(width: Util.isDesktop ? 24 : 16),
            Expanded(
              child: PrimaryButton(
                label: "Create",
                enabled: _enableCreateButton,
                onPressed: _enableCreateButton ? _register : null,
                buttonHeight: Util.isDesktop ? .l : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
