#!/bin/sh
# Extracts the JPEG frame sequences that index.html plays back.
# Offsets/durations here are the media constants; keep them in sync with config.js (media.macRawOffset / iosRawOffset).
set -e
cd "$(dirname "$0")"
MAC=${MAC:-media/mac_take3.mp4}
IOS=${IOS:-media/ios_take4.mp4}
rm -rf frames/mac frames/ios
mkdir -p frames/mac frames/ios
# Mac desktop take (1600x1200, 60 fps) -> 30 fps, 1728 px wide, from 0.8 s for 14.6 s
ffmpeg -v error -y -ss 0.8 -t 14.6 -i "$MAC" -vf "fps=30,scale=1728:-2" -q:v 2 frames/mac/%04d.jpg
# iPhone Simulator take (1206x2622, 60 fps) -> 30 fps, 660 px wide, from 18.2 s for 7.2 s
ffmpeg -v error -y -ss 18.2 -t 7.2 -i "$IOS" -vf "fps=30,scale=660:-2" -q:v 2 frames/ios/%04d.jpg
echo "mac frames: $(ls frames/mac | wc -l | tr -d ' ')  ios frames: $(ls frames/ios | wc -l | tr -d ' ')"
