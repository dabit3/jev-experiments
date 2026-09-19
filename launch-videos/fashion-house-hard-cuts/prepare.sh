#!/bin/bash
# Extracts the raw Simulator take into 30 fps JPEG frames that the composition reads deterministically.
set -e
cd "$(dirname "$0")"
rm -rf take-frames && mkdir -p take-frames
ffmpeg -v error -i assets/silverroom-take.mp4 -vf fps=30 -q:v 2 take-frames/%04d.jpg
ls take-frames | wc -l
