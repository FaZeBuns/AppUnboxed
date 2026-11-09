#!/usr/bin/env bash
#
# Smoke-tests the last build_on_iphone.sh build on the jailbroken build phone.
# Installs it as a jailbreak app, switches on the in-app debug harness (which
# auto-plays an unbox and saves window snapshots and the app-scan log), then
# pulls the results back.
#
# Setup:  build.env with PHONE (and SSH_KEY), same as the build script.
# Usage:  bash scripts/test_on_iphone.sh <output-dir>
#         NOPLAY=1 WAIT=60 bash scripts/test_on_iphone.sh <output-dir>   # time the scan only
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
require_phone
RESULTS="${1:?usage: test_on_iphone.sh <output-dir>}"
NOPLAY="${NOPLAY:-0}"
WAIT="${WAIT:-20}"

ssh "${SSHOPTS[@]}" "$PHONE" \
    "R='$REMOTE_DIR' JB='$JBROOT' APP_NAME='$APP_NAME' NOPLAY='$NOPLAY' WAIT='$WAIT' bash -s" <<'REMOTE_EOF'
DOCS=/var/mobile/Documents
INSTALLED="$JB/Applications/$APP_NAME.app"

killall -9 "$APP_NAME" 2>/dev/null; sleep 1
rm -rf "$INSTALLED" "$DOCS/au_shots"
cp -R "$R/Payload/$APP_NAME.app" "$JB/Applications/"

# The test copy runs on the build phone's own iOS, so give it a matching SDK
# stamp (the 27.1 stamp is for the Duo) and unsandboxed test entitlements.
"$JB/usr/bin/python3" -I "$R/stamp_sdk.py" "$INSTALLED/$APP_NAME" 16.2
cat > "$R/test_entitlements.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>platform-application</key><true/>
<key>com.apple.private.security.no-sandbox</key><true/>
</dict></plist>
EOF
"$JB/usr/bin/ldid" -S"$R/test_entitlements.plist" "$INSTALLED/$APP_NAME"
uicache -p "$INSTALLED" >/dev/null 2>&1

# Flag files the app's DebugHarness looks for (a sandboxed install cannot see them).
touch "$DOCS/appunboxed_debug"; chown mobile "$DOCS/appunboxed_debug"
if [ "$NOPLAY" = "1" ]; then touch "$DOCS/appunboxed_debug_noplay"; else rm -f "$DOCS/appunboxed_debug_noplay"; fi

# Wake the display: a sleeping screen renders nothing.
"$JB/usr/bin/python3" -c 'import ctypes; ctypes.CDLL("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices").SBSUndimScreen()' 2>/dev/null || true
sleep 1
uiopen --bundleid com.appunboxed.duo
sleep "$WAIT"

ps -Ao pid,%cpu,comm | grep "$APP_NAME.app" | grep -v grep | awk '{print "cpu=" $2 "%"}'
grep -v "^apps:" "$DOCS/au_shots/log.txt"
rm -f "$DOCS/appunboxed_debug" "$DOCS/appunboxed_debug_noplay"
REMOTE_EOF

rm -rf "$RESULTS"; mkdir -p "$RESULTS"
scp -q "${SSHOPTS[@]}" "$PHONE:/var/mobile/Documents/au_shots/*" "$RESULTS/"
echo "frames: $(ls "$RESULTS" | grep -c jpg)"
