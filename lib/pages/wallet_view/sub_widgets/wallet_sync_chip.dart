import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/global/wallets_provider.dart';
import '../../../services/event_bus/events/global/wallet_sync_status_changed_event.dart';
import '../../../services/event_bus/global_event_bus.dart';
import '../../../themes/stack_colors.dart';
import '../../../utilities/text_styles.dart';

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
    final colors = Theme.of(context).extension<StackColors>()!;
    final favText = colors.textFavoriteCard;

    final (Color dotColor, String label) = switch (_status) {
      WalletSyncStatus.synced => (colors.accentColorGreen, "Synced"),
      WalletSyncStatus.syncing => (colors.accentColorYellow, "Syncing"),
      WalletSyncStatus.unableToSync => (colors.accentColorRed, "Offline"),
    };

    return GestureDetector(
      onTap: _refresh,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: favText.withOpacity(0.16),
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
                  color: dotColor,
                ),
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: STextStyles.subtitle500(context).copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: favText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
