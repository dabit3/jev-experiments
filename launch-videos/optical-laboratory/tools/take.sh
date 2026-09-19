#!/bin/bash
# Records one continuous 1x take of Lumen Drift in the booted Simulator.
set -euo pipefail
OUT="${1:-/Users/devin/work/optical/take.mp4}"
APP=/Users/devin/repos/macos-experiments/lumen-drift/build/Build/Products/Debug-iphonesimulator/LumenDrift.app
AP=/Users/devin/work/optical/autopilot/autopilot
xcrun simctl uninstall booted ai.devin.demos.lumendrift || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted ai.devin.demos.lumendrift
sleep 3
rm -f "$OUT"
xcrun simctl io booted recordVideo --codec h264 --force "$OUT" &
REC=$!
sleep 0.6
T0=$(python3 -c 'import time;print(time.time())')
echo "REC_START $T0"
log() { python3 -c "import time;print('%s %.2f' % ('$1', time.time()-$T0))"; }
sleep 2.0
log TAP_START; "$AP" tap 0.5 0.809          # Start endless
sleep 0.4
"$AP" 7.5 "$T0"              # autopilot flies
log TAP_PAUSE; "$AP" tap 0.88 0.117         # Pause
sleep 1.7
log TAP_RESUME; "$AP" tap 0.5 0.527          # Resume flight
"$AP" 8 "$T0"
sleep 0.6
kill -INT $REC
wait $REC || true
ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration -of default=nw=1 "$OUT"
