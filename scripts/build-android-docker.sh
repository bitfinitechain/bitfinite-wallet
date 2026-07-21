#!/usr/bin/env bash
#
# BitFinite native wallet — Dockerized Android build (Stack Wallet fork toolchain).
#
# Mirrors the webwallet's Capacitor Docker build: no host Flutter/SDK/Rust needed.
# Uses the fork's own multi-stage Dockerfile (`--target android`) — or, by default,
# PULLS the upstream prebuilt CI image to skip the ~30-45 min local image build.
#
# Usage:
#   scripts/build-android-docker.sh            # debug APK (default)
#   scripts/build-android-docker.sh release    # split-per-abi release APKs (unsigned unless keystore wired)
#
# Env overrides:
#   BUILD_IMAGE=1   force a local `docker build` instead of pulling
#   BFX_CI_IMAGE=…  override the image ref (default: upstream cypherstack CI image)
#   BFX_PLATFORM=…  docker platform (default linux/amd64 — see note below)
#   VERSION / BUILD_NUM   app version + build number (default 0.1.0 / 1)
#
# On Apple Silicon this runs the amd64 toolchain under emulation, so expect it
# to be considerably slower than on an x86_64 host. It is the only workable
# route: the Android NDK ships no linux-arm64 host toolchain, and this build
# compiles Rust crypto libs for Android.
#
# Output: build/app/outputs/flutter-apk/

set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"

APP=bitfinite
VERSION="${VERSION:-0.1.0}"
BUILD_NUM="${BUILD_NUM:-1}"
MODE="${1:-debug}"
# Our own CI toolchain image, published to GHCR by build-ci-image.yaml. It is
# publicly pullable, so no `docker login` is needed. Override with BFX_CI_IMAGE
# to fall back to upstream (ghcr.io/cypherstack/stackwallet-ci:android) if ours
# is ever unavailable.
IMAGE="${BFX_CI_IMAGE:-ghcr.io/bitfinitechain/bitfinitewallet-ci:android}"
# The CI image is published for linux/amd64 only, and the Dockerfile hardcodes
# amd64 paths (JAVA_HOME, the Go tarball) while the Android NDK ships no
# linux-arm64 host toolchain. So pin the platform: on Apple Silicon this runs
# under emulation (slower, but correct) instead of failing to find a manifest
# and falling back to an arm64 image build that cannot work.
PLATFORM="${BFX_PLATFORM:-linux/amd64}"

echo ">> BitFinite Android build (mode=$MODE, app=$APP, v$VERSION+$BUILD_NUM)"

# 1) Obtain the toolchain image ------------------------------------------------
if [[ "${BUILD_IMAGE:-0}" == "1" ]]; then
  echo ">> Building android image locally from Dockerfile (--target android)…"
  docker build --platform "$PLATFORM" --target android -t bitfinite-wallet-ci:android "$REPO"
  IMAGE=bitfinite-wallet-ci:android
else
  echo ">> Pulling $IMAGE (set BUILD_IMAGE=1 to build locally instead)…"
  if ! docker pull --platform "$PLATFORM" "$IMAGE"; then
    echo ">> Pull failed — falling back to local image build."
    docker build --platform "$PLATFORM" --target android -t bitfinite-wallet-ci:android "$REPO"
    IMAGE=bitfinite-wallet-ci:android
  fi
fi

# 2) Build inside the container ------------------------------------------------
# Named volumes cache pub + gradle across runs; repo is bind-mounted so the APK
# lands on the host. The bfx-android-config volume persists /root/.android so the
# debug keystore is STABLE across builds — otherwise every rebuild signs the
# debug APK with a fresh key and `adb install -r` fails with
# INSTALL_FAILED_UPDATE_INCOMPATIBLE (forcing an uninstall that wipes wallet data).
# Runs as root (image expects writable dirs), then chowns the outputs back to the
# invoking user.
#
# `build/` is sometimes a symlink pointing outside the repo — on macOS it has to
# be moved off an iCloud-synced folder or iOS codesigning fails on
# Flutter.framework. A symlink to a host path does not resolve inside the
# container, so the build would die writing its outputs; mount its target
# explicitly when that is the case.
BUILD_MOUNT=()
if [[ -L "$REPO/build" ]]; then
  BUILD_TARGET="$(cd "$REPO" && readlink build)"
  echo ">> build/ is a symlink -> $BUILD_TARGET (mounting it into the container)"
  mkdir -p "$BUILD_TARGET"
  BUILD_MOUNT=(-v "$BUILD_TARGET":/work/build)
fi

docker run --rm --platform "$PLATFORM" \
  -v "$REPO":/work -w /work \
  "${BUILD_MOUNT[@]+"${BUILD_MOUNT[@]}"}" \
  -v bfx-pub-cache:/root/.pub-cache \
  -v bfx-gradle:/root/.gradle \
  -v bfx-android-config:/root/.android \
  -e APP="$APP" -e VERSION="$VERSION" -e BUILD_NUM="$BUILD_NUM" -e MODE="$MODE" \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  "$IMAGE" bash -euxo pipefail -c '
    git config --system --add safe.directory "*"

    # api-key + test-param templates (dev build; exchange features stubbed)
    ( cd scripts && ./prebuild.sh )

    # configure the flavor (app_config.g.dart, pubspec, assets, launcher icons).
    # build_app.sh sources ./env.sh relatively, so it MUST run from scripts/.
    # download_all.sh is a no-op for the bitfinite app, so -d is safe.
    ( cd scripts && echo yes | ./build_app.sh -v "$VERSION" -b "$BUILD_NUM" -p android -a "$APP" -d -s )

    flutter pub get

    # stub dirs the build expects to exist (epic/mwc plugins are not built here)
    mkdir -p crypto_plugins/flutter_libepiccash/lib crypto_plugins/flutter_libmwc/lib

    # Keep Gradle inside the container'"'"'s memory budget and off features that
    # break under emulation. Without this the build daemon is killed partway
    # ("Gradle build daemon disappeared unexpectedly") on Apple Silicon, where
    # QEMU overhead sits on top of Gradle and the Kotlin daemon. Written to
    # GRADLE_USER_HOME (a cached volume) so the repo tree stays clean.
    mkdir -p /root/.gradle
    cat > /root/.gradle/gradle.properties <<EOF
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=768m
org.gradle.daemon=false
org.gradle.vfs.watch=false
org.gradle.parallel=false
kotlin.compiler.execution.strategy=in-process
kotlin.incremental=false
EOF

    # point gradle at the in-image SDK/Flutter (matches CI)
    cat > android/local.properties <<EOF
sdk.dir=/opt/android-sdk
flutter.sdk=/opt/flutter
EOF

    if [ "$MODE" = "release" ]; then
      flutter build apk --split-per-abi --release
    else
      flutter build apk --debug
    fi

    chown -R "$HOST_UID:$HOST_GID" build android/app .dart_tool 2>/dev/null || true
  '

echo ">> Done. APK(s):"
ls -1 build/app/outputs/flutter-apk/*.apk 2>/dev/null || echo "   (check build output above)"
echo ">> Sideload: adb install -r build/app/outputs/flutter-apk/app-debug.apk"
