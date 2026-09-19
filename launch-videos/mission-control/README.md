# Mission Control launch video (dark)

28 second, 1920x1080, 30 fps, H.264 launch video for "macOS. Now in Devin Cloud."
Built as a control room: one large primary display (RTX Afterdark for iPhone) and two
smaller bays (Lumen Drift for iPhone, Aster for macOS), each inside a reconstructed Devin
session viewer. The bays summarise the same sequential stages as the primary display
(request, Devin writing Swift, app running, verified) rather than implying concurrency.

All footage is real: the three apps were built with Xcode 26.6 and recorded at 1x in the
iOS Simulator (`xcrun simctl io booted recordVideo`) or on the Mac desktop (`screencapture -v`).
Raw takes live in `raw/`.

## Render

```sh
cd launch-videos/mission-control
npm install            # playwright (Chromium) only
npx playwright install chromium
node render.mjs                        # -> out/mission-control.mp4
node render.mjs --still 13.6 --out out/still.png   # one frame for inspection
node render.mjs --from 10 --to 14 --out out/clip.mp4
ffmpeg -i out/mission-control.mp4 -vf "fps=1,scale=320:180,tile=6x5" -frames:v 1 out/contact-sheet.png
```

`render.mjs` loads `index.html?headless=1` in headless Chromium at 1920x1080, calls
`window.render(t)` for every frame, screenshots to PNG and encodes with
`ffmpeg -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30`. Open `index.html` directly in a
browser to play the timeline live, or `index.html?t=12.3` to inspect one instant.

## Footage

`extract-frames.sh` turns the raw recordings into the 15 second, 30 fps JPEG sequences in
`frames/` that the composition reads (offsets and rotation are the constants at the top of
the script). `frames/` is not committed (about 90 MB of JPEGs); run `./extract-frames.sh`
once after cloning and again after replacing anything in `raw/`. The Lumen Drift take in
`raw/` is the full continuous 1x recording re-encoded at CRF 20 to fit under GitHub's file
size limit; the other two are the untouched captures.

| Clip | Source | In point | Notes |
| --- | --- | --- | --- |
| `frames/rtx` | `raw/rtx-afterdark.mp4` | 27.0 s | landscape game, rotated from the portrait Simulator capture; pause at ~6.5 s, resume at ~9.5 s into the clip |
| `frames/lumen` | `raw/lumen-drift.mp4` | 13.0 s | portrait play |
| `frames/aster` | `raw/aster.mov` | 6.5 s | Mac window interaction |

## What to edit

Everything editable is in `config.js`:

- `fps`, `width`, `height`, `duration`
- `headline`, `endUrl`, `captions` (text and the time each one appears)
- `t.*` stage timings (title, layout in, environment pick, typing, send, building, running, result, hero, end)
- `t.zooms`: the three camera push-ins on the primary Simulator (play, pause, resume), each `[in start, in end, out start, out end]`
- `layout`: primary display geometry, bay geometry as small status tiles during the request and full bays afterwards, and `zoomPhoneWidth` (fraction of the frame the phone spans when pushed in)
- `colors` (sampled from the Devin dark UI)
- `clips` (frame folders, frame counts, device kind)
- `sessions.*` per app: typed prompt, Devin reply, timeline steps, file name and Swift code shown in the Changes tab
- `environments`, `mac.*` menus, `bayStatus`, per-app `blurb` shown on the request tiles

## Output

`out/mission-control.mp4` (H.264, yuv420p, 1920x1080, 30 fps, 28 s, silent) and
`out/mission-control-contact-sheet.png`.
