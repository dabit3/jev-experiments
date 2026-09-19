#!/bin/sh
# Builds the Debug app and launches it from the shell so TYPESAFE_API_KEY is inherited.
# Usage: ./run.sh [--show]
set -e
cd "$(dirname "$0")"
xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build -quiet
pkill -x JevLauncher 2>/dev/null || true
pkill -x Launcher 2>/dev/null || true
exec ./build/Build/Products/Debug/Launcher.app/Contents/MacOS/Launcher "$@"
