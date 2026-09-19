#!/usr/bin/env bash
# Extracts the frame sequences the composition plays back (deterministic seeking).
#   footage/voxelhearth-mac-desktop.mp4    -> assets/frames/mac/0001.jpg    ... (1600x1200)
#   footage/voxelhearth-iphone-simulator.mp4 -> assets/frames/iphone/0001.jpg ... (603x1311)
# Edit MAC_START / PHONE_START to pick a different moment of the recordings.
set -euo pipefail
cd "$(dirname "$0")/.."
FPS=30
COUNT=211            # must match CONFIG.media.frameCount in index.html
MAC_START=1.7        # seconds into the Mac recording
PHONE_START=12.0     # seconds into the iPhone Simulator recording

mkdir -p assets/frames/mac assets/frames/iphone
ffmpeg -y -v error -ss "$MAC_START" -i footage/voxelhearth-mac-desktop.mp4 \
  -vf "fps=$FPS,scale=1600:1200" -frames:v "$COUNT" -q:v 3 assets/frames/mac/%04d.jpg
ffmpeg -y -v error -ss "$PHONE_START" -i footage/voxelhearth-iphone-simulator.mp4 \
  -vf "fps=$FPS,scale=603:1311" -frames:v "$COUNT" -q:v 3 assets/frames/iphone/%04d.jpg
ls assets/frames/mac | wc -l; ls assets/frames/iphone | wc -l
