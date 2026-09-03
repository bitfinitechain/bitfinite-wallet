import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../notifications/show_flush_bar.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/assets.dart';
import '../../../utilities/text_styles.dart';
import '../../../widgets/desktop/primary_button.dart';
import '../../../widgets/desktop/secondary_button.dart';
import '../../../widgets/wallet_navigation_bar/components/wallet_navigation_bar_item.dart';

/// Redesign of the wallet home's bottom controls: two full-width buttons —
/// Receive and Send — instead of the floating icon dock.
///
/// The coin-conditional actions the dock carried (Finalize, Sign, Swap, Buy,
/// Names, Tokens, …) are not dropped: whatever the wallet declares beyond
/// Receive/Send goes into a "more" sheet behind a third compact button, which
/// simply does not render for wallets that have nothing extra — the common
/// case, which then matches the mockups exactly. Hiding a working feature to
/// match a picture would be a regression, not a redesign.
///
/// On a view-only wallet Send renders locked rather than absent: the wallet
/// deliberately cannot sign, and a control that explains that beats one that
/// vanished. Tapping it says so instead of doing nothing.
///
/// Colour comes from the theme, not the coin. Chrome — buttons, links,
/// switches, the sync chip — is one set of controls that happens to be showing
/// a coin, so it stays put as you move between wallets; the coin colour is
/// reserved for the marks that identify the coin itself (its icon and its card
/// on the home list). Recolouring the accent per coin meant every theme's
/// contrast pairing had to be re-earned for each coin, which is how a
/// white-on-gold Save button shipped.
class WalletActionBar extends StatelessWidget {
  const WalletActionBar({
    super.key,
    required this.items,
    required this.moreItems,
    required this.viewOnly,
  });

  final List<WalletNavigationBarItemData> items;
  final List<WalletNavigationBarItemData> moreItems;
  final bool viewOnly;

  WalletNavigationBarItemData? _byLabel(String label) {
    for (final e in items) {
      if (e.label == label) return e;
    }
    return null;
  }

  void _showExtrasSheet(
    BuildContext context,
    List<WalletNavigationBarItemData> extras,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).extension<StackColors>()!.popupBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in extras)
                ListTile(
                  leading: item.icon,
                  title: Text(
                    item.label ?? "",
                    style: STextStyles.w500_14(context),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    item.onTap?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StackColors>()!;

    final receive = _byLabel("Receive");
    final send = _byLabel("Send");
    final extras = [
      ...items.where((e) => e.label != "Receive" && e.label != "Send"),
      ...moreItems,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
        children: [
          if (receive != null)
            Expanded(
              child: SecondaryButton(
                label: "Receive",
                onPressed: receive.onTap,
              ),
            ),
          if (receive != null) const SizedBox(width: 12),
          Expanded(
            child: (viewOnly || send == null)
                ? SecondaryButton(
                    label: "Send",
                    icon: SvgPicture.asset(
                      Assets.svg.lock,
                      width: 14,
                      height: 14,
                      colorFilter: ColorFilter.mode(
                        colors.buttonTextSecondary.withOpacity(0.6),
                        BlendMode.srcIn,
                      ),
                    ),
                    onPressed: () {
                      showFloatingFlushBar(
                        type: FlushBarType.info,
                        message:
                            "This is a watch-only wallet. It can receive and "
                            "monitor, but holds no keys to send with.",
                        context: context,
                      );
                    },
                  )
                : PrimaryButton(label: "Send", onPressed: send.onTap),
          ),
          if (extras.isNotEmpty) const SizedBox(width: 12),
          if (extras.isNotEmpty)
            SecondaryButton(
              width: 56,
              icon: Icon(
                Icons.more_horiz,
                size: 22,
                color: colors.buttonTextSecondary,
              ),
              onPressed: () => _showExtrasSheet(context, extras),
            ),
        ],
        ),
      ),
    );
  }
}
