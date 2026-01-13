import 'package:flutter/material.dart';

import '../../../themes/stack_colors.dart';
import '../../../utilities/text_styles.dart';
import '../../../wallets/wallet/impl/firo_wallet.dart';

class MasternodesList extends StatelessWidget {
  const MasternodesList({super.key, required this.nodes});

  final List<MasternodeInfo> nodes;

  @override
  Widget build(BuildContext context) {
    final stack = Theme.of(context).extension<StackColors>()!;
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
}
