#!/bin/zsh
set -e
APP=~/silverroom-build/Build/Products/Debug-iphonesimulator/Silverroom.app
BID=com.nader.ioscollection.silverroom
OUT=${1:-~/take/silverroom-take3.mov}
T=~/take/tap
xcrun simctl uninstall booted $BID
xcrun simctl install booted $APP
xcrun simctl launch booted $BID
osascript -e 'tell application "Simulator" to activate'
$T move 1200 1000
sleep 2.5
rm -f $OUT
xcrun simctl io booted recordVideo --codec h264 $OUT > ~/take/rec3.log 2>&1 &
REC=$!
sleep 1.5
$T tap 828 672            # open photo
$T sleep 1700
$T tap 864 800            # Noir look
$T sleep 1500
$T tap 828 709            # Adjust tab
$T sleep 900
$T drag 828 836 884 836 700   # exposure slider
$T sleep 900
$T hold 938 619 1300      # hold to compare
$T sleep 900
$T tap 945 666            # Frame tab
$T sleep 1000
$T tap 706 797            # Rotate 90
$T sleep 1500
$T tap 950 797            # Square crop
$T sleep 2200
kill -INT $REC
wait $REC || true
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $OUT
