#!/usr/bin/env bash
# Extracts the 30 fps frame sequence used by index.html from the raw Simulator take.
# The take is one continuous 1x recording; this only rotates the portrait-container
# capture to landscape (the app runs in landscape) and picks the window used in the cut.
set -euo pipefail
cd "$(dirname "$0")"

RAW="footage/rtx-afterdark-simulator-raw.mp4"
OUT="build/footage"
START=10.8        # seconds into the raw take where the cut begins (must match footage window in index.html)
FRAMES=435        # 14.5 s at 30 fps (CONFIG.footageFrames)

rm -rf "$OUT"; mkdir -p "$OUT"
ffmpeg -v error -y -ss "$START" -i "$RAW" \
  -vf "transpose=1,scale=2000:920,fps=30" \
  -frames:v "$FRAMES" -q:v 2 "$OUT/f%04d.jpg"
echo "Wrote $FRAMES frames to $OUT"
