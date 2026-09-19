#!/usr/bin/env bash
# Encodes out/frames/*.png into the final MP4 and builds a 1920x1080 contact sheet.
set -euo pipefail
cd "$(dirname "$0")"

FPS=30
OUT=out/macos-in-devin-cloud-graphic-storyboard.mp4

ffmpeg -v error -y -framerate "$FPS" -pattern_type glob -i 'out/frames/*.png' \
  -c:v libx264 -pix_fmt yuv420p -crf 16 -r "$FPS" -movflags +faststart "$OUT"

# 2 fps contact sheets, 6x5 tiles of 320x180 = 1920x1080 PNG each (two sheets cover 30 s).
rm -f out/contact-sheet-*.png
ffmpeg -v error -y -i "$OUT" -vf "fps=2,scale=320:180,tile=6x5" out/contact-sheet-%d.png

ffprobe -v error -show_entries stream=width,height,r_frame_rate,pix_fmt:format=duration -of default=nw=1 "$OUT"
ls -la "$OUT" out/contact-sheet*.png
