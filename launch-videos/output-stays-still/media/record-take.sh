#!/bin/bash
# Drives Silverroom in the Simulator window (Point Accurate, window at 572,58) with cliclick
# while simctl records the device screen. One continuous take, 1x. Reinstalls the app first
# so the take starts from a clean library.
set -e
OUT=${1:-/Users/devin/silverroom-take.mp4}
APP=/Users/devin/silverroom-build/Build/Products/Debug-iphonesimulator/Silverroom.app
BID=com.nader.ioscollection.silverroom
xcrun simctl terminate booted $BID 2>/dev/null || true
xcrun simctl uninstall booted $BID 2>/dev/null || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted $BID >/dev/null
sleep 2.5
osascript -e 'tell application "Simulator" to activate'
sleep 0.5
xcrun simctl io booted recordVideo --codec h264 --force "$OUT" &
REC=$!
sleep 1.5
# open the cove
cliclick c:800,653 w:2200
# Noir look
cliclick c:837,764 w:1800
# Adjust tab
cliclick c:800,674 w:1200
# drag exposure slider to the right
cliclick dd:800,798 w:120 dm:812,798 w:60 dm:826,798 w:60 dm:840,798 w:60 dm:854,798 w:60 dm:866,798 w:60 dm:876,798 w:60 dm:884,798 w:60 dm:889,798 w:120 du:889,798 w:1200
# hold to compare, release
cliclick dd:914,582 w:1500 du:914,582 w:1000
# Frame tab
cliclick c:917,629 w:1200
# rotate
cliclick c:678,764 w:1600
# square crop
cliclick c:921,764 w:4200
kill -INT $REC
wait $REC || true
echo done
