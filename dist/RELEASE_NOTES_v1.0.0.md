## BitFinite Wallet v1.0.0

The first release of the **BitFinite Wallet** — a free, open-source, **non-custodial**
Android wallet for [BitFinite (BFX)](https://bitfinitechain.org). Your keys and
recovery phrase never leave your device.

### Download (Android sideload)
Pick the APK for your phone — **most modern phones use `arm64-v8a`**:

| File | For |
|---|---|
| `BitFinite-Wallet-1.0.0-arm64-v8a.apk` | Most phones (64-bit ARM) |
| `BitFinite-Wallet-1.0.0-armeabi-v7a.apk` | Older 32-bit ARM devices |
| `BitFinite-Wallet-1.0.0-x86_64.apk` | Emulators / x86 devices |

### Install
1. Download the APK for your device.
2. Verify the checksum against `SHA256SUMS` (recommended).
3. Enable "Install unknown apps" for your browser/file manager, then open the APK.

### Verify
```
sha256sum -c SHA256SUMS
```
The app is signed with the BitFinite release key (`CN=BitFinite`).

### Notes
- **Non-custodial** — back up your recovery phrase; it cannot be recovered if lost.
- Connects to the BitFinite Electrum server over TLS on port 443 (works on any network).
- Source (GPLv3): https://github.com/bitfinitechain/bitfinite-wallet
- Website & whitepaper: https://bitfinitechain.org
