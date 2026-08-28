import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/global/wallets_provider.dart';
import '../../../services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import '../../../services/event_bus/global_event_bus.dart';
import '../../../themes/theme_providers.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/hero_ink.dart';
import '../../../utilities/text_styles.dart';
import '../../../widgets/coin_card.dart';
import '../../../wallets/isar/providers/wallet_info_provider.dart';

/// Live sync-status pill shown on the balance card ("Synced" / "Syncing" /
/// "Offline"). Tapping it triggers a wallet refresh, replacing the old
/// spinning-arrows refresh button.
class WalletSyncChip extends ConsumerStatefulWidget {
  const WalletSyncChip({
    super.key,
    required this.walletId,
    required this.initialSyncStatus,
  });

  final String walletId;
  final WalletSyncStatus initialSyncStatus;

  @override
  ConsumerState<WalletSyncChip> createState() => _WalletSyncChipState();
}

class _WalletSyncChipState extends ConsumerState<WalletSyncChip> {
  late WalletSyncStatus _status;
  late final StreamSubscription<dynamic> _subscription;

  @override
  void initState() {
    _status = widget.initialSyncStatus;
    _subscription =
        GlobalEventBus.instance.on<WalletSyncStatusChangedEvent>().listen((
          event,
        ) {
          if (event.walletId == widget.walletId && mounted) {
            setState(() => _status = event.newStatus);
          }
        });
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _refresh() {
    final wallet = ref.read(pWallets).getWallet(widget.walletId);
    if (!wallet.refreshMutex.isLocked) {
      unawaited(wallet.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Balance block now sits on the page background (no gradient card), so the
    // chip reads against the themed surface rather than on-card white.
    // This chip only ever renders inside the hero (its sole call site is
    // wallet_summary_info), so its ink comes from the hero, not the page.
    // textDark is near-black in the light theme and was unreadable on blue;
    // hardcoded white then failed the other way on the light-orange heroes.
    final hero = ref.watch(pCoinColor(ref.watch(pWalletCoin(widget.walletId))));
    final favText = heroInk(hero);

    final String label = switch (_status) {
      WalletSyncStatus.synced => "Synced",
      WalletSyncStatus.syncing => "Syncing",
      WalletSyncStatus.unableToSync => "Offline",
    };

    // Offline is the one state worth spending colour on, so it takes the whole
    // pill instead of a dot. A filled alarm reads on any coin colour; the red
    // dot it replaces measured 1.15:1 on BFX's blue and 1.72:1 on Pepecoin's
    // green — present, but nothing anyone would notice.
    final alarm = _status == WalletSyncStatus.unableToSync;
    final alarmFill = Theme.of(context).extension<StackColors>()!.accentColorRed;

    // Synced and syncing keep hero ink rather than their status colour, for the
    // same reason as the network glyph above: those colours are chosen against
    // the page background, and on this chip's scrim over a green hero the green
    // dot measured 1.05:1. The word beside it already carries the state.
    final pillFill = alarm ? alarmFill : favText.withOpacity(0.16);
    final pillInk = alarm ? readableInk(Colors.white, alarmFill) : favText;

    return GestureDetector(
      onTap: _refresh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: pillFill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status == WalletSyncStatus.syncing)
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: pillInk,
                ),
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: pillInk,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: STextStyles.subtitle500(context).copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: pillInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
