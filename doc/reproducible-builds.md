# Reproducible builds

You should not have to trust that the APK we publish was built from the code we
published. This document lets you check it.

Building v2.0.0 from its tag produces an APK **byte-for-byte identical** to the
one attached to the GitHub release — same SHA-256, all 658 archive entries
matching.

## Verify a release

You need Docker and about 20 minutes. Nothing else — the toolchain lives in a
pinned image, so your Java, Flutter, Rust and NDK versions do not matter.

```sh
git clone https://github.com/bitfinitechain/bitfinite-wallet
cd bitfinite-wallet
git checkout v2.0.0

VERSION=2.0.0 BUILD_NUM=8201 scripts/build-android-docker.sh release

sha256sum build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Compare that against `SHA256SUMS` on the [release
page](https://github.com/bitfinitechain/bitfinite-wallet/releases). They should
match exactly.

**`BUILD_NUM` is not optional.** It sets `versionCode` inside the APK, so
building without it produces a different binary for a reason that has nothing to
do with the source. The value for each release is in the table below.

## Release parameters

| release | tag | `VERSION` | `BUILD_NUM` | arm64 `versionCode` |
|---|---|---|---|---|
| v2.0.0 | `v2.0.0` | `2.0.0` | `8201` | 10201 |

`versionCode` is `BUILD_NUM` plus an ABI offset — 2000 for `arm64-v8a`, applied
by `--split-per-abi`. That is why the number in the APK does not match the one
you typed.

## What makes this work

**The toolchain is pinned by digest, not by tag.** `scripts/build-android-docker.sh`
runs the entire build inside:

```
ghcr.io/bitfinitechain/bitfinitewallet-ci@sha256:193012d6983743632a3c5ccb87851bd192ab8921bed45414453afaaed3bc5f4f
```

A tag would be mutable: rebuild the image and every subsequent release gets a
different compiler, so an APK that reproduced yesterday quietly stops
reproducing — and only someone trying to verify it would ever find out. Moving
to a new image is a deliberate commit that changes that line.

**Dependencies are locked.** `pubspec.lock` pins every package to a version and,
for git dependencies, to a commit. One of those commits was force-pushed out of
reach upstream in August 2026, which broke every clean build until we forked the
package and hosted the same commit ourselves. Anything we depend on by git ref
now lives somewhere we control, precisely so a third party can still fetch it.

## What is not reproducible, and why

**The signature block.** APKs are signed with our release key, which we do not
publish; you cannot produce a byte-identical *signed* APK without it. Compare
the archive contents — the 658 entries — rather than the whole file if you build
unsigned. Every release is signed with both the v2 and v3 Android signature
schemes.

**Nothing else, currently.** If your build differs in any archive entry, that is
a finding and we would like to hear about it:
<https://github.com/bitfinitechain/bitfinite-wallet/issues>

## Honest limitations

- **Releases are currently built by hand**, not by CI, because the repository has
  no signing secrets configured. The build is deterministic and pinned, but it
  runs on a maintainer's machine rather than a clean runner. Moving it to CI
  would remove that gap.
- **Reproducibility is per release.** Each new version needs verifying again;
  passing once says nothing about the next one.
- **This proves the APK matches the source. It does not prove the source is
  safe.** It removes one specific risk — a binary that differs from what we
  published — and no others. The code has had no external security audit.
