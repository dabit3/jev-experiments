#!/usr/bin/env bash
# Encodes out/frames/*.png -> out/linear-mac.mp4 (H.264, yuv420p, 30 fps, silent)
# and a 1920x1080 contact sheet (2 fps, 6x5 tiles) -> out/contact-sheet.png
set -euo pipefail
cd "$(dirname "$0")/.."
FPS=$(sed -nE 's/^[[:space:]]*fps:[[:space:]]*([0-9]+).*/\1/p' index.html | head -1)
mkdir -p out
ffmpeg -y -v error -framerate "$FPS" -i out/frames/%06d.png \
  -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart \
  -vf "format=yuv420p" out/linear-mac.mp4
ffmpeg -y -v error -i out/linear-mac.mp4 \
  -vf "fps=2,scale=240:135,tile=8x7,pad=1920:1080:0:67:color=black" -frames:v 1 -update 1 out/contact-sheet.png
ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate,codec_name,pix_fmt \
  -of default=noprint_wrappers=1 out/linear-mac.mp4
ls -la out/linear-mac.mp4 out/contact-sheet.png
