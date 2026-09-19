#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
MODE="${1:-}"
case "$MODE" in
    ""|--build-only|--dmg) ;;
    *) printf 'Usage: bash run.sh [--build-only|--dmg]\n' >&2; exit 2 ;;
esac
swift build -c release
mkdir -p "$ROOT/build"
WORK="$(mktemp -d "$ROOT/build/.package.XXXXXX")"
cleanup() {
    rm -rf -- "$WORK"
}
trap cleanup EXIT
APP="$ROOT/build/Say.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift Resources/GenerateIcon.swift "$WORK/AppIcon.iconset" "$WORK/artwork"
iconutil -c icns "$WORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$WORK/artwork/SayMark.pdf" "$APP/Contents/Resources/SayMark.pdf"
cp .build/release/Say "$APP/Contents/MacOS/Say"
cp Resources/Info.plist "$APP/Contents/Info.plist"
IDENTITY="${SAY_SIGNING_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning \
        | awk -F'"' '/Developer ID Application|Apple Development/ { print $2; exit }')"
fi
if [ -z "$IDENTITY" ]; then
    IDENTITY="-"
    printf 'No signing certificate found. Using an ad-hoc signature, so macOS will ask for permissions again after every rebuild.\n' >&2
fi
codesign --force --sign "$IDENTITY" --identifier ai.jev.say "$APP"
codesign --verify --deep --strict "$APP"
printf 'Signed with: %s\n' "$IDENTITY"
if [ "$MODE" = "--dmg" ]; then
    VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
    ARCH="$(lipo -archs "$APP/Contents/MacOS/Say" | tr ' ' '-')"
    DMG="$ROOT/build/Say-$VERSION-$ARCH-$(date +%Y%m%d-%H%M%S).dmg"
    PYTHON="$ROOT/.build/dmg-tools/bin/python"
    if [ ! -x "$PYTHON" ]; then
        python3 -c 'import sys; sys.version_info >= (3, 10) or sys.exit("DMG packaging needs Python 3.10 or newer.")'
        python3 -m venv "$ROOT/.build/dmg-tools"
    fi
    "$PYTHON" -m pip install --disable-pip-version-check -r Resources/dmg-requirements.txt
    tiffutil -cathidpicheck "$WORK/artwork/InstallerBackground.png" \
        "$WORK/artwork/InstallerBackground@2x.png" -out "$WORK/artwork/InstallerBackground.tiff"
    "$PYTHON" Resources/PackageDMG.py "$APP" "$WORK/artwork/InstallerBackground.tiff" "$DMG"
    hdiutil verify "$DMG"
    printf '\nInstaller: %s\n' "$DMG"
elif [ "$MODE" != "--build-only" ]; then
    cleanup
    trap - EXIT
    pkill -x Say || true
    exec "$APP/Contents/MacOS/Say"
fi
