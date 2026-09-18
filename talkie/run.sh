#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
swift build -c release
APP="$ROOT/build/Talkie.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift Resources/GenerateIcon.swift "$ROOT/build/AppIcon.iconset"
iconutil -c icns "$ROOT/build/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/Talkie "$APP/Contents/MacOS/Talkie"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier ai.jev.talkie "$APP"
if [ "${1:-}" != "--build-only" ]; then
    exec "$APP/Contents/MacOS/Talkie"
fi
