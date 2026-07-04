# Building BitFinite Wallet

BitFinite Wallet is a single-coin fork of [Stack Wallet](https://github.com/cypherstack/stack_wallet)
and reuses its whitelabel build system. The easiest, most reproducible way to build
the Android app is the Dockerized toolchain — **no host SDK, Flutter, or Rust required.**

## Quick build (Docker — recommended)

From the repo root:

```bash
scripts/build-android-docker.sh           # debug APK
scripts/build-android-docker.sh release   # split-per-abi release APKs + AAB
```

- By default it **pulls a prebuilt CI image**; set `BUILD_IMAGE=1` to build the
  image locally from the `Dockerfile` (`--target android`).
- Output: `build/app/outputs/flutter-apk/` (and `build/app/outputs/bundle/release/`
  for the AAB).
- Caches pub/gradle in named Docker volumes so re-runs are fast.

## What the build does

BitFinite is defined as an app "flavor". The build runs, inside the container:

1. `scripts/prebuild.sh` — generates template API-key / test files.
2. `scripts/build_app.sh -a bitfinite -p android` — configures the flavor:
   - `scripts/app_config/configure_bitfinite.sh` writes `lib/app_config.g.dart`
     (single coin = `Bitfinite`, app name, icons) and the pubspec,
   - links the BitFinite brand assets and generates the launcher icon + splash.
3. `flutter pub get`, then `flutter build apk` (per-abi for release).

The BitFinite coin itself lives in
`lib/wallets/crypto_currency/coins/bitfinite.dart` (+ `bitfinite_wallet.dart` and
the `BfxCashAddr` codec in `lib/utilities/bfx_cashaddr.dart`).

## Release signing

Release builds are signed from `android/key.properties` (git-ignored), which points
at a keystore (also git-ignored — never commit `*.jks`):

```
storeFile=../keystore.jks
storePassword=...
keyPassword=...
keyAlias=bitfinite
```

Generate one with `keytool -genkeypair -keystore android/keystore.jks -alias bitfinite
-keyalg RSA -keysize 2048 -validity 10000`. Back it up — it is your app's permanent
Play Store identity.

## Toolchain / other platforms

The pinned toolchain (Flutter, Rust, Android SDK/NDK, Go versions) is defined in the
repo `Dockerfile`. For manual host setup, or to build Linux/Windows/macOS/iOS
targets, follow the upstream Stack Wallet build guide — the underlying steps are the
same, using `-a bitfinite` as the app id:
https://github.com/cypherstack/stack_wallet/blob/main/docs/building.md
