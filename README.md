# BitFinite Wallet

**BitFinite Wallet** is a free, open-source, **non-custodial** mobile wallet for
[BitFinite (BFX)](https://bitfinitechain.org) — a fair-launch, fixed-supply,
SHA-256 proof-of-work cryptocurrency. Your keys and recovery phrase never leave
your device.

- 🌐 Website & whitepaper: https://bitfinitechain.org
- 🔎 Block explorer: https://explorer.bitfinitechain.org
- 👛 Web wallet (PWA): https://wallet.bitfinitechain.org
- 💬 Telegram: https://t.me/bitfinitechain · X: https://x.com/bitfinitechain

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

## Credits

BitFinite Wallet is a fork of **[Stack Wallet](https://github.com/cypherstack/stack_wallet)**
by **Cypher Stack**, adapted into a single-coin BitFinite wallet. Huge thanks to
the Stack Wallet team for their excellent, audited, open-source foundation.
Upstream copyright notices and file headers are preserved as required by the license.

## License

Released under the **GPLv3** (inherited from Stack Wallet). See [LICENSE](LICENSE).
