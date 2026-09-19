#!/bin/bash
# Extracts the two 1x excerpts of the continuous Simulator take as PNG frame sequences.
# Edit CLIP_A_START / CLIP_B_START (seconds into the take) to pick different excerpts.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TAKE="${TAKE:-$HERE/footage/lumen-drift-take.mp4}"
CLIP_A_START="${CLIP_A_START:-6.5}"
CLIP_B_START="${CLIP_B_START:-30.0}"
LEN="${LEN:-6.25}"
mkdir -p "$HERE/clipA" "$HERE/clipB"
ffmpeg -v error -y -ss "$CLIP_A_START" -t "$LEN" -i "$TAKE" -vf "fps=30,scale=540:-2" "$HERE/clipA/%04d.png"
ffmpeg -v error -y -ss "$CLIP_B_START" -t "$LEN" -i "$TAKE" -vf "fps=30,scale=540:-2" "$HERE/clipB/%04d.png"
echo "clipA: $(ls "$HERE/clipA" | wc -l | tr -d ' ') frames, clipB: $(ls "$HERE/clipB" | wc -l | tr -d ' ') frames"
