#!/bin/sh
# Builds a Release JevLauncher.app and packages it into JevLauncher.dmg
# (app + Applications symlink). Unsigned; recipients right-click → Open once.
# Usage: scripts/make-dmg.sh [output.dmg]   (default: ./JevLauncher.dmg)
set -eu
cd "$(dirname "$0")/.."

OUT="${1:-JevLauncher.dmg}"
DERIVED="build"
APP="$DERIVED/Build/Products/Release/JevLauncher.app"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/jevlauncher-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

xcodebuild -project JevLauncher.xcodeproj -scheme JevLauncher -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build -quiet

test -d "$APP" || { echo "build did not produce $APP" >&2; exit 1; }

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT"
hdiutil create -volname "Jev Launcher" -srcfolder "$STAGE" -ov -format UDZO -quiet "$OUT"
echo "$OUT ($(du -h "$OUT" | cut -f1 | tr -d ' '))"
