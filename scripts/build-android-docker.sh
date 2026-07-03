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
#   VERSION / BUILD_NUM   app version + build number (default 0.1.0 / 1)
#
# Output: build/app/outputs/flutter-apk/

set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"

APP=bitfinite
VERSION="${VERSION:-0.1.0}"
BUILD_NUM="${BUILD_NUM:-1}"
MODE="${1:-debug}"
# The fork hasn't changed the Dockerfile, so the upstream image matches. Swap to
# ghcr.io/bitfinitechain/stackwallet-ci:android once the fork's CI publishes one.
IMAGE="${BFX_CI_IMAGE:-ghcr.io/cypherstack/stackwallet-ci:android}"

echo ">> BitFinite Android build (mode=$MODE, app=$APP, v$VERSION+$BUILD_NUM)"

# 1) Obtain the toolchain image ------------------------------------------------
if [[ "${BUILD_IMAGE:-0}" == "1" ]]; then
  echo ">> Building android image locally from Dockerfile (--target android)…"
  docker build --target android -t bitfinite-wallet-ci:android "$REPO"
  IMAGE=bitfinite-wallet-ci:android
else
  echo ">> Pulling $IMAGE (set BUILD_IMAGE=1 to build locally instead)…"
  if ! docker pull "$IMAGE"; then
    echo ">> Pull failed — falling back to local image build."
    docker build --target android -t bitfinite-wallet-ci:android "$REPO"
    IMAGE=bitfinite-wallet-ci:android
  fi
fi

# 2) Build inside the container ------------------------------------------------
# Named volumes cache pub + gradle across runs; repo is bind-mounted so the APK
# lands on the host. Runs as root (image expects writable dirs), then chowns the
# outputs back to the invoking user.
docker run --rm \
  -v "$REPO":/work -w /work \
  -v bfx-pub-cache:/root/.pub-cache \
  -v bfx-gradle:/root/.gradle \
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
