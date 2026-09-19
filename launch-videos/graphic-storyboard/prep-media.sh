#!/usr/bin/env bash
# Extracts the real VoxelHearth recordings into 30 fps JPEG frame sequences.
# The composition swaps <img> sources per frame, which keeps rendering deterministic.
set -euo pipefail
cd "$(dirname "$0")"

MAC_SRC=media/voxelhearth-mac-desktop.mp4        # screencapture -v of the Mac desktop
IPHONE_SRC=media/voxelhearth-iphone-simulator.mp4 # xcrun simctl io booted recordVideo
MAC_SECONDS=16
IPHONE_SECONDS=18

rm -rf media/mac-frames media/iphone-frames
mkdir -p media/mac-frames media/iphone-frames

ffmpeg -v error -y -i "$MAC_SRC" -t "$MAC_SECONDS" -vf fps=30 -q:v 3 media/mac-frames/%04d.jpg
ffmpeg -v error -y -i "$IPHONE_SRC" -t "$IPHONE_SECONDS" -vf "fps=30,scale=720:-2" -q:v 3 media/iphone-frames/%04d.jpg

echo "mac frames:    $(ls media/mac-frames | wc -l | tr -d ' ')"
echo "iphone frames: $(ls media/iphone-frames | wc -l | tr -d ' ')"
