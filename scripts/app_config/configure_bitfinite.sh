#!/usr/bin/env bash
#
# BitFinite single-coin flavor for the Stack Wallet fork.
# Drop into scripts/app_config/configure_bitfinite.sh (mirrors configure_campfire.sh).
# Usage (from the fork root, via scripts/build_app.sh which sets APP_PROJECT_ROOT_DIR):
#   scripts/app_config/configure_bitfinite.sh <platform>

set -x -e

APP_BUILD_PLATFORM=$1

export NEW_NAME="BitFinite"
export NEW_APP_ID="org.bitfinitechain.wallet"        # matches the existing Capacitor appId
export NEW_APP_ID_CAMEL="org.bitfinitechain.wallet"
export NEW_APP_ID_SNAKE="org.bitfinitechain.wallet"
export NEW_BASIC_NAME="bitfinite"

NEW_PUBSPEC_NAME="bitfinite"
PUBSPEC_FILE="${APP_PROJECT_ROOT_DIR}/pubspec.yaml"

# String replacements.
if [[ "$(uname)" == 'Darwin' ]]; then
  sed -i '' "s/name: PLACEHOLDER/name: ${NEW_PUBSPEC_NAME}/g" "${PUBSPEC_FILE}"
  sed -i '' "s/description: PLACEHOLDER/description: ${NEW_NAME}/g" "${PUBSPEC_FILE}"
else
  sed -i "s/name: PLACEHOLDER/name: ${NEW_PUBSPEC_NAME}/g" "${PUBSPEC_FILE}"
  sed -i "s/description: PLACEHOLDER/description: ${NEW_NAME}/g" "${PUBSPEC_FILE}"
fi

# Coin/feature flags. BFX is pure-Dart (coinlib) like BCH — it needs NO native
# crypto .so (unlike FIRO/EPIC/MONERO). If process_pubspec_deps.dart / gen_interfaces.dart
# require an explicit token, add "BITFINITE" to their known-coins list (see POC.md).
# Passing only TOR here keeps the build lean; adjust once the flag is registered.
dart "${APP_PROJECT_ROOT_DIR}/tool/process_pubspec_deps.dart" \
      "${PUBSPEC_FILE}" \
      TOR

dart "${APP_PROJECT_ROOT_DIR}/tool/gen_interfaces.dart" \
      "${APP_PROJECT_ROOT_DIR}/tool/wl_templates" \
      "${APP_PROJECT_ROOT_DIR}/lib/wl_gen/generated" \
      TOR

export INCLUDE_EPIC_SO="OFF"
export INCLUDE_MWC_SO="OFF"

pushd "${APP_PROJECT_ROOT_DIR}"
BUILT_COMMIT_HASH=$(git log -1 --pretty=format:"%H")
popd

APP_CONFIG_DART_FILE="${APP_PROJECT_ROOT_DIR}/lib/app_config.g.dart"
rm -f "$APP_CONFIG_DART_FILE"
cat << EOF > "$APP_CONFIG_DART_FILE"
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

const _prefix = "BitFinite";
const _separator = "";
const _suffix = "";
const _emptyWalletsMessage =
    "Create your BitFinite wallet to get started.";
const _appDataDirName = "bitfinite";
const _shortDescriptionText = "Your keys. Your coins. Your BitFinite.";
const _commitHash = "$BUILT_COMMIT_HASH";

const _mwebdExeHash = "";

const Set<AppFeature> _features = {
  AppFeature.tor,
  // Enables the Appearance settings entry + installs the dark theme, so users
  // can switch between the BitFinite light/dark themes (and system-brightness).
  AppFeature.themeSelection,
};

// PoC: no in-app logo asset yet (app_icon.dart null-checks this and falls back).
// TODO(bfx): add assets/in_app_logo_icons/bitfinite-icon_light/dark.svg from Brandkit.
const ({String light, String dark})? _appIconAsset = null;

final List<CryptoCurrency> _supportedCoins = List.unmodifiable([
  Bitfinite(CryptoCurrencyNetwork.main),
]);

// BFX is not on exchanges; swap defaults are unused but the field is required.
final ({String from, String fromFuzzyNet, String to, String toFuzzyNet})
_swapDefaults = (
  from: "BTC",
  fromFuzzyNet: "btc",
  to: "BFX",
  toFuzzyNet: "bfx",
);

EOF
