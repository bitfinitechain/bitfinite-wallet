import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../pages/settings_views/global_settings_view/tor_settings/tor_settings_view.dart';
import '../services/event_bus/events/global/tor_connection_status_changed_event.dart';
import '../services/tor_service.dart';
import '../themes/stack_colors.dart';
import '../utilities/assets.dart';
import 'custom_buttons/app_bar_icon_button.dart';
import 'tor_subscription.dart';

class SmallTorIcon extends ConsumerStatefulWidget {
  const SmallTorIcon({super.key});

  @override
  ConsumerState<SmallTorIcon> createState() => _SmallTorIconState();
}

class _SmallTorIconState extends ConsumerState<SmallTorIcon> {
  late TorConnectionStatus _status;

  // Miso Tor status: animate while connecting and on connect; a static (grey)
  // onion when disconnected.
  Widget _icon(
    TorConnectionStatus status,
    StackColors colors,
    bool isDark,
  ) {
    switch (status) {
      case TorConnectionStatus.connecting:
        return Lottie.asset(
          isDark ? Assets.lottie.torConnectingDark : Assets.lottie.torConnecting,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );

      case TorConnectionStatus.connected:
        return Lottie.asset(
          isDark ? Assets.lottie.torConnectedDark : Assets.lottie.torConnected,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          repeat: false,
        );

      case TorConnectionStatus.disconnected:
        return SvgPicture.asset(
          Assets.svg.tor,
          color: colors.textSubtitle3,
          width: 20,
          height: 20,
        );
    }
  }

  @override
  void initState() {
    _status = ref.read(pTorService).status;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TorSubscription(
      onTorStatusChanged: (status) {
        setState(() {
          _status = status;
        });
      },
      child: AppBarIconButton(
        semanticsLabel: "Tor Settings Button. Takes To Tor Settings Page.",
        key: const Key("walletsViewTorButton"),
        size: 36,
        shadows: const [],
        color: Theme.of(context).extension<StackColors>()!.backgroundAppBar,
        icon: _icon(
          _status,
          Theme.of(context).extension<StackColors>()!,
          Theme.of(context).extension<StackColors>()!.brightness ==
              Brightness.dark,
        ),
        onPressed: () {
          Navigator.of(context).pushNamed(TorSettingsView.routeName);
        },
      ),
    );
  }
}
