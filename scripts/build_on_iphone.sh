#!/usr/bin/env bash
#
# Builds App Unboxed on a jailbroken iPhone, with no Mac or Xcode.
#
# Ships the sources to the phone over SSH, compiles them there with the
# Procursus toolchain, stamps the binary's SDK version for the iPhone Duo,
# signs it ad hoc with ldid, zips an .ipa and pulls it back.
#
# Setup:  copy build.env.example to build.env and set PHONE (and SSH_KEY).
# Usage:  bash scripts/build_on_iphone.sh
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_phone

echo "==> [1/4] shipping sources to the build phone"
ssh "${SSHOPTS[@]}" "$PHONE" "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR/src' '$REMOTE_DIR/res'"
scp -q "${SSHOPTS[@]}" "$ROOT"/src/*.swift "$ROOT"/src/*.m "$ROOT"/src/*.h "$PHONE:$REMOTE_DIR/src/"
scp -q "${SSHOPTS[@]}" "$ROOT"/Resources/Info.plist "$ROOT"/Resources/entitlements.plist \
    "$ROOT"/Resources/catalog.json "$ROOT"/Resources/sounds/*.wav "$ROOT"/Resources/AppIcon*.png \
    "$PHONE:$REMOTE_DIR/res/"
scp -q "${SSHOPTS[@]}" "$ROOT"/scripts/stamp_sdk.py "$PHONE:$REMOTE_DIR/"

echo "==> [2/4] compiling, stamping and signing on the phone"
ssh "${SSHOPTS[@]}" "$PHONE" \
    "R='$REMOTE_DIR' JB='$JBROOT' SDK_STAMP='$SDK_STAMP' IOS_TARGET='$IOS_TARGET' FRAMEWORKS='$FRAMEWORKS' APP_NAME='$APP_NAME' bash -s" <<'REMOTE_EOF'
set -e
SDK="$JB/usr/share/SDKs/iPhoneOS.sdk"
APP="$R/Payload/$APP_NAME.app"
cd "$R"
rm -rf "$R/Payload"; mkdir -p "$APP"

echo "    clang (Objective-C)"
"$JB/usr/bin/clang" -c -fobjc-arc -isysroot "$SDK" -target "$IOS_TARGET" -O1 src/AUProbe.m -o "$R/AUProbe.o"

echo "    swiftc"
"$JB/usr/bin/swiftc" -import-objc-header src/AUProbe.h "$R/AUProbe.o" \
    -sdk "$SDK" -target "$IOS_TARGET" -O -module-name "$APP_NAME" $FRAMEWORKS \
    src/*.swift -o "$APP/$APP_NAME"

cp res/Info.plist "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
cp res/*.wav res/catalog.json res/AppIcon*.png "$APP/"

echo "    stamp SDK $SDK_STAMP"
"$JB/usr/bin/python3" -I stamp_sdk.py "$APP/$APP_NAME" "$SDK_STAMP"

# Sign last: stamping after signing would invalidate the signature.
echo "    ldid"
"$JB/usr/bin/ldid" -S"$R/res/entitlements.plist" "$APP/$APP_NAME"

rm -f "$R/$APP_NAME.ipa"
"$JB/usr/bin/zip" -r -y -q "$R/$APP_NAME.ipa" Payload
REMOTE_EOF

echo "==> [3/4] pulling the IPA back"
mkdir -p "$(dirname "$OUT")"
scp -q "${SSHOPTS[@]}" "$PHONE:$REMOTE_DIR/$APP_NAME.ipa" "$OUT"

echo "==> [4/4] done: $OUT"
echo "    Sideload it with Sideloadly, AltStore or similar."
