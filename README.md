# BitFinite Wallet

**BitFinite Wallet** is a free, open-source, **non-custodial** mobile wallet for
[BitFinite (BFX)](https://bitfinitechain.org) — a fair-launch, fixed-supply,
SHA-256 proof-of-work cryptocurrency. Your keys and recovery phrase never leave
your device.

- 🌐 Website & whitepaper: https://bitfinitechain.org
- 🔎 Block explorer: https://explorer.bitfinitechain.org
- 👛 Web wallet (PWA): https://wallet.bitfinitechain.org
- 💬 X: https://x.com/bitfinitechain

## Features

- **Non-custodial** — private keys and seed stay on device, encrypted at rest.
- **Light wallet** — connects to the BitFinite Electrum server; no full node
  required to send, receive, and check balances.
- **BFX-native** — BitFinite's CashAddr format (`bfx:` addresses) and consensus.
- **Send / receive / QR**, transaction history, address book, and custom nodes.
- **Open source. No ads. No tracking.**

## Building

BitFinite Wallet builds with a Dockerized toolchain (no host SDK required):

```bash
scripts/build-android-docker.sh           # debug Android APK
scripts/build-android-docker.sh release   # split-per-abi release APKs
```

By default it pulls a prebuilt CI image; set `BUILD_IMAGE=1` to build the image
locally from the `Dockerfile`. See [docs/building.md](docs/building.md) for the
underlying Flutter / `build_app.sh` details and other platforms.

### iOS

**Status: builds and runs on device, not yet distributed.** Android is the
released platform; iOS is in active development and has no App Store or
TestFlight build yet. Installing it means building from source and sideloading.

The Dockerized toolchain above is Android-only — iOS needs a Mac with Xcode:

```bash
cd scripts
./build_app.sh -p ios -a bitfinite -d   # configure (must run from scripts/)
cd ../ios && pod install
flutter run                             # or: flutter build ios --release
```

Two things that will otherwise bite you:

- **`lib/external_api_keys.dart` is gitignored** and the build fails without it.
  It holds third-party exchange/purchase API keys, none of which BFX uses, so
  create it with empty string constants for the keys the compiler asks for.
- **Do not build from an iCloud-synced folder.** If the repo lives under a
  synced `~/Documents` or `~/Desktop`, codesigning fails on `Flutter.framework`
  with a "bundle format is ambiguous" / detritus error, because iCloud writes
  its own metadata into the build output. Point `build/` at a path outside
  iCloud (a symlink is enough).

Sideloading with a free Apple ID works and needs no paid account, but the app
stops launching after **7 days** and has to be reinstalled.

The iOS build carries platform-specific UI that Android does not: SF Symbols in
place of the bundled SVG icon set, the San Francisco system font, and a floating
frosted-glass dock for the wallet actions. These are gated on `Platform.isIOS`,
so Android rendering is unchanged.

## Credits

BitFinite Wallet is a fork of **[Stack Wallet](https://github.com/cypherstack/stack_wallet)**
by **Cypher Stack**, adapted into a single-coin BitFinite wallet. Huge thanks to
the Stack Wallet team for their excellent, audited, open-source foundation.
Upstream copyright notices and file headers are preserved as required by the license.

## License

Released under the **GPLv3** (inherited from Stack Wallet). See [LICENSE](LICENSE).
