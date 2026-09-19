#!/bin/bash
# Turns the raw Aster desktop recording into the JPEG frame sequence the
# composition reads (media/rec/0001.jpg ...). Window, offset and length must
# match REC in config.js.
set -euo pipefail
cd "$(dirname "$0")"
SRC="${1:-media/aster-take1.mp4}"
OFFSET=12   # REC.offset
LENGTH=18   # REC.frames / REC.fps
mkdir -p media/rec
rm -f media/rec/*.jpg
ffmpeg -v error -y -ss "$OFFSET" -t "$LENGTH" -i "$SRC" -vf fps=30 -q:v 2 media/rec/%04d.jpg
echo "extracted $(ls media/rec | wc -l | tr -d ' ') frames to media/rec"
