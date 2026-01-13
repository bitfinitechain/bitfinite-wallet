import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../providers/global/wallets_provider.dart';
import '../../themes/stack_colors.dart';
import '../../utilities/assets.dart';
import '../../utilities/text_styles.dart';
import '../../utilities/util.dart';
import '../../wallets/wallet/impl/firo_wallet.dart';
import '../../widgets/custom_buttons/app_bar_icon_button.dart';
import '../../widgets/desktop/desktop_app_bar.dart';
import '../../widgets/desktop/desktop_scaffold.dart';
import '../../widgets/desktop/primary_button.dart';
import '../../widgets/dialogs/s_dialog.dart';
import 'create_masternode_view.dart';
import 'sub_widgets/masternode_info_widget.dart';

class MasternodesHomeView extends ConsumerStatefulWidget {
  const MasternodesHomeView({super.key, required this.walletId});

  final String walletId;

  static const String routeName = "/masternodesHomeView";

  @override
  ConsumerState<MasternodesHomeView> createState() =>
      _MasternodesHomeViewState();
}

class _MasternodesHomeViewState extends ConsumerState<MasternodesHomeView> {
  late Future<List<MasternodeInfo>> _masternodesFuture;

  FiroWallet get _wallet =>
      ref.read(pWallets).getWallet(widget.walletId) as FiroWallet;

  @override
  void initState() {
    super.initState();
    _masternodesFuture = _wallet.getMyMasternodes();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Util.isDesktop;

    return MasterScaffold(
      isDesktop: isDesktop,
      appBar: isDesktop
          ? DesktopAppBar(
              isCompactHeight: true,
              background: Theme.of(context).extension<StackColors>()!.popupBG,
              leading: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 20),
                    child: AppBarIconButton(
                      size: 32,
                      color: Theme.of(
                        context,
                      ).extension<StackColors>()!.textFieldDefaultBG,
                      shadows: const [],
                      icon: SvgPicture.asset(
                        Assets.svg.arrowLeft,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          Theme.of(
                            context,
                          ).extension<StackColors>()!.topNavIconPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: Navigator.of(context).pop,
                    ),
                  ),
                  SvgPicture.asset(
                    Assets.svg.robotHead,
                    width: 32,
                    height: 32,
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).extension<StackColors>()!.textDark,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Masternodes", style: STextStyles.desktopH3(context)),
                ],
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: PrimaryButton(
                  label: "Create Masternode",
                  buttonHeight: .l,
                  horizontalContentPadding: 10,
                  icon: SvgPicture.asset(
                    Assets.svg.circlePlus,
                    colorFilter: ColorFilter.mode(
                      Theme.of(
                        context,
                      ).extension<StackColors>()!.buttonTextPrimary,
                      .srcIn,
                    ),
                  ),
                  onPressed: _showDesktopCreateMasternodeDialog,
                ),
              ),
            )
          : AppBar(
              leading: AppBarBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
              titleSpacing: 0,
              title: Text(
                "Masternodes",
                style: STextStyles.navBarTitle(context),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                    right: 10,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AppBarIconButton(
                      key: const Key("createNewMasterNodeButton"),
                      size: 36,
                      shadows: const [],
                      color: Theme.of(
                        context,
                      ).extension<StackColors>()!.background,
                      icon: SvgPicture.asset(
                        Assets.svg.plus,
                        colorFilter: ColorFilter.mode(
                          Theme.of(
                            context,
                          ).extension<StackColors>()!.accentColorDark,
                          .srcIn,
                        ),
                        width: 20,
                        height: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          CreateMasternodeView.routeName,
                          arguments: widget.walletId,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      body: _buildMasternodesTable(context),
    );
  }

  Widget _buildMasternodesTable(BuildContext context) {
    return FutureBuilder<List<MasternodeInfo>>(
      future: _masternodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Failed to load masternodes",
              style: STextStyles.w600_14(context),
            ),
          );
        }
        final nodes = snapshot.data ?? const <MasternodeInfo>[];
        if (nodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "No masternodes found",
                  style: STextStyles.w600_14(context),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: .min,
                  mainAxisAlignment: .center,
                  children: [
                    PrimaryButton(
                      label: "Create Your First Masternode",
                      horizontalContentPadding: 16,
                      buttonHeight: Util.isDesktop ? .l : null,
                      onPressed: () {
                        if (Util.isDesktop) {
                          _showDesktopCreateMasternodeDialog();
                        } else {
                          Navigator.of(context).pushNamed(
                            CreateMasternodeView.routeName,
                            arguments: widget.walletId,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final isDesktop = Util.isDesktop;
        final stack = Theme.of(context).extension<StackColors>()!;

        if (isDesktop) {
          return _buildDesktopTable(nodes, stack);
        } else {
          return _buildMobileTable(nodes, stack);
        }
      },
    );
  }

  Widget _buildDesktopTable(List<MasternodeInfo> nodes, StackColors stack) {
    return Container(
      color: stack.textFieldDefaultBG,
      child: Column(
        children: [
          // Fixed header
          Container(
            height: 56,
            color: stack.textFieldDefaultBG,
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('IP'),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Last Paid Height'),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Status'),
                    ),
                  ),
                ),
                Expanded(flex: 3, child: Container()),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: Container(
              width: double.infinity,
              color: stack.textFieldDefaultBG,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: nodes.map((node) {
                    final status = node.revocationReason == 0
                        ? 'Active'
                        : 'Revoked';
                    return SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  node.serviceAddr,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  node.lastPaidHeight.toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status.toLowerCase() == 'active'
                                        ? stack.accentColorGreen
                                        : stack.accentColorRed,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: STextStyles.w600_12(
                                      context,
                                    ).copyWith(color: stack.textWhite),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _showMasternodeInfoDialog(node),
                                      icon: const Icon(Icons.info_outline),
                                      tooltip: 'View Details',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTable(List<MasternodeInfo> nodes, StackColors stack) {
    return Container(
      color: stack.textFieldDefaultBG,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: nodes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final node = nodes[index];
          final status = node.revocationReason == 0 ? 'Active' : 'Revoked';

          return Container(
            width: double.infinity,
            color: stack.textFieldDefaultBG,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'IP: ${node.serviceAddr}',
                          style: STextStyles.w600_14(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status.toLowerCase() == 'active'
                            ? stack.accentColorGreen
                            : stack.accentColorRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: STextStyles.w600_12(
                          context,
                        ).copyWith(color: stack.textWhite),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMobileRow(
                  'Last Paid Height',
                  node.lastPaidHeight.toString(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showMasternodeInfoDialog(node),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: stack.textFieldDefaultBG,
                        foregroundColor: stack.buttonTextSecondary,
                        side: BorderSide(
                          color: stack.buttonBackBorderSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$label:',
                style: STextStyles.w500_12(context).copyWith(
                  color: Theme.of(
                    context,
                  ).extension<StackColors>()!.textSubtitle1,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(value, style: STextStyles.w500_12(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDesktopCreateMasternodeDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          SDialog(child: CreateMasternodeView(firoWalletId: widget.walletId)),
    );
  }

  void _showMasternodeInfoDialog(MasternodeInfo node) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => SDialog(
        child: SizedBox(width: 600, child: MasternodeInfoWidget(info: node)),
      ),
    );
  }
}
