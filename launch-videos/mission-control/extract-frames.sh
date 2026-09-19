#!/bin/bash
# Turns the raw recordings in raw/ into the 30 fps JPEG sequences the composition reads.
# Ranges and sizes must match CONFIG.clips in config.js.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p frames/rtx frames/lumen frames/aster
# RTX Afterdark: simctl wrote the landscape game in portrait device coordinates, so rotate it upright.
ffmpeg -y -v error -ss 27 -t 15 -i raw/rtx-afterdark.mp4 -vf "transpose=2,fps=30,scale=1200:-2" -q:v 3 frames/rtx/%04d.jpg
ffmpeg -y -v error -ss 13 -t 15 -i raw/lumen-drift.mp4 -vf "fps=30,scale=-2:900" -q:v 3 frames/lumen/%04d.jpg
ffmpeg -y -v error -ss 6.5 -t 15 -i raw/aster.mov -vf "fps=30" -q:v 3 frames/aster/%04d.jpg
ls frames/rtx | wc -l; ls frames/lumen | wc -l; ls frames/aster | wc -l
