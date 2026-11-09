#!/usr/bin/env bash
# Shared settings for the build and test scripts. Sourced, not run.
#
# Machine-specific values live in build.env at the repo root (git-ignored).
# Copy build.env.example to build.env and fill it in.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT/build.env" ]; then
    # shellcheck disable=SC1091
    source "$ROOT/build.env"
fi

APP_NAME="AppUnboxed"
VERSION="$(sed -n '/CFBundleShortVersionString/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$ROOT/Resources/Info.plist")"

# SDK version stamped into the binary. 27.1 gives the iPhone Duo's full canvas.
SDK_STAMP="${SDK_STAMP:-27.1}"
# Minimum iOS the app runs on.
IOS_TARGET="${IOS_TARGET:-arm64-apple-ios16.0}"
# Where the finished .ipa goes.
OUT="${OUT:-$ROOT/dist/${APP_NAME}_v${VERSION}.ipa}"

FRAMEWORKS="-framework SwiftUI -framework UIKit -framework Foundation -framework Combine -framework AVFoundation -framework AudioToolbox"

# --- jailbroken-iPhone builds only ---
# PHONE      ssh destination of the build phone, e.g. root@192.0.2.10
# SSH_KEY    private key that logs in to it (optional if your ssh config covers it)
# JBROOT     jailbreak prefix on the phone (rootless default)
JBROOT="${JBROOT:-/var/jb}"
REMOTE_DIR="${REMOTE_DIR:-$JBROOT/tmp/appunboxed_build}"

require_phone() {
    if [ -z "${PHONE:-}" ]; then
        echo "PHONE is not set. Copy build.env.example to build.env and set PHONE (and SSH_KEY)." >&2
        exit 2
    fi
    SSHOPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)
    if [ -n "${SSH_KEY:-}" ]; then SSHOPTS+=(-i "$SSH_KEY"); fi
}
