#!/usr/bin/env bash
#
# Builds App Unboxed on a Mac with the Xcode command-line tools.
#
# NOTE: written from the same steps as the jailbroken-iPhone build, but not
# yet run on a real Mac by the author. If it fails, please open an issue.
#
# Usage:  bash scripts/build_macos.sh
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
BUILD="$ROOT/build"
APP="$BUILD/Payload/$APP_NAME.app"
rm -rf "$BUILD"; mkdir -p "$APP"

echo "==> clang (Objective-C)"
xcrun --sdk iphoneos clang -c -fobjc-arc -isysroot "$SDK" -target "$IOS_TARGET" -O1 \
    "$ROOT/src/AUProbe.m" -o "$BUILD/AUProbe.o"

echo "==> swiftc"
# shellcheck disable=SC2086
xcrun --sdk iphoneos swiftc -import-objc-header "$ROOT/src/AUProbe.h" "$BUILD/AUProbe.o" \
    -sdk "$SDK" -target "$IOS_TARGET" -O -swift-version 5 -module-name "$APP_NAME" $FRAMEWORKS \
    "$ROOT"/src/*.swift -o "$APP/$APP_NAME"

cp "$ROOT/Resources/Info.plist" "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
cp "$ROOT"/Resources/sounds/*.wav "$ROOT/Resources/catalog.json" "$ROOT"/Resources/AppIcon*.png "$APP/"

echo "==> stamp SDK $SDK_STAMP"
python3 "$ROOT/scripts/stamp_sdk.py" "$APP/$APP_NAME" "$SDK_STAMP"

# Sign last: stamping after signing would invalidate the signature.
# Ad-hoc is enough here; Sideloadly/AltStore re-sign with your Apple ID.
echo "==> codesign (ad hoc)"
codesign --force --sign - --entitlements "$ROOT/Resources/entitlements.plist" "$APP"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd "$BUILD" && zip -r -y -q "$OUT" Payload)
echo "==> done: $OUT"
