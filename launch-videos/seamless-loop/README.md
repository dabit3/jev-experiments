# The Seamless Launch Loop (direction 10, light mode)

A 29.93 second, 1920x1080, 30 fps, silent H.264 (yuv420p) launch film for "macOS in Devin Cloud".
The final frame is pixel identical to the first, so the film plays as an unbroken loop.

Story: title card (Devin lockup, "macOS in Devin Cloud.", devin.ai) -> the headline leaves and the
lockup slides into the header of the composer, which assembles -> environment menu -> macOS selected
-> the Silverroom request is typed and sent -> Devin writes Swift -> Silverroom runs in the iOS
Simulator inside the Devin session view while Devin tests it -> the lockup returns, the headline
builds word by word and devin.ai follows -> the same title card, drifting, closes the loop.

## Files

- `index.html`: the whole composition (reconstructed Devin UI, motion, camera, loop). All timings,
  text, colors and media paths are constants at the top of the `<script>` block.
- `render.mjs`: extracts the take to a 30 fps JPEG sequence, renders every frame with Puppeteer to
  `out/`, then encodes `seamless-loop.mp4` with ffmpeg.
- `preview.mjs`: renders a handful of composition times to `preview/` for quick checks.
- `recording/silverroom-simulator-take.mp4`: the raw, unedited `xcrun simctl io booted recordVideo`
  take of Silverroom on an iPhone 17 Simulator (32.3 s, 1206x2622). It plays forward at 1x with
  no internal cuts, speed changes or recoloring.
- `assets/`: Devin lockup and avatar marks (black on light), Inter Tight and Inter as the brand
  face fallback.
- `seamless-loop.mp4`, `contact-sheet.png`: the rendered deliverable and a 1920x1080 contact sheet.

## Render

Requirements: Node 18+, ffmpeg on `PATH`.

```sh
cd launch-videos/seamless-loop
npm install
npm run render            # extract take frames, render 898 PNGs, encode seamless-loop.mp4
node render.mjs --skip-extract --start 800   # re-render a range after a small edit
npm run preview           # preview/tNN.NN.png stills for a few key times
```

Verify the loop and the container:

```sh
cmp out/00000.png out/00897.png
ffprobe -show_entries stream=codec_name,pix_fmt,width,height,r_frame_rate -show_entries format=duration seamless-loop.mp4
ffmpeg -i seamless-loop.mp4 -vf "fps=1,scale=320:180,tile=6x5,pad=1920:1080:0:90:color=#fcfcfc" -frames:v 1 contact-sheet.png
```

The encoder uses constant QP with adaptive quantization, mbtree and psy-rd disabled and forces a
keyframe on the last frame, so the identical first and last source frames also decode to identical
pixels (checked by hashing the decoded RGB of frame 0 and frame 897).

## Constants to edit (top of `index.html`)

| Constant | Meaning |
| --- | --- |
| `T`, `FPS` | Total duration and frame rate. The renderer produces `T * FPS + 1` frames; the last one is the loop frame. |
| `PROMPT`, `HEADLINE` | Typed request and the title card headline words. |
| `RECORDING_IN`, `DEMO_LENGTH` | Where in the raw take playback starts, and how many seconds play (1x, uncut). |
| `TL` | Every beat of the timeline: `[start, duration]` pairs or single click times, in seconds. |
| `LOCKUP_OPEN`, `LOCKUP_HEADER`, `HEADLINE_Y`, `DEVINAI_TOP`, `DRIFT` | Title card layout (lockup center and width, headline center, devin.ai top), the header lockup pose, and the slow brand drift amplitude. |
| `MESSAGES` | Devin chat lines in the session view and when they appear. |
| `CODE` | Swift lines shown in the Changes pane (from `silverroom/Silverroom/Models.swift`). |
| `PHONE`, `SCREEN`, `CAM` | Phone placement inside the Simulator pane and the camera path (`{t, x, y, s}` keyframes). |
| `CUR`, `CLICKS` | Cursor path and click times. |
| CSS variables `--bg`, `--ink`, `--muted`, `--accent` | Palette (paper `#fcfcfc`, ink `#191919`, accent `#2200ff`). |

`render.mjs` holds the take path (`recording/silverroom-simulator-take.mp4`) and the frame scale
(754x1640, 2x the on-screen phone) at its top.

## Take

Recorded on an iPhone 17 Simulator (Xcode 26.6) from `dabit3/macos-experiments/silverroom` after
`xcodebuild ... build`, `xcodebuild ... test` and `swift-format lint --strict` all passed. In one
continuous take: open a photo, choose Noir in Looks, drag the exposure slider, press and hold the
compare control (the ORIGINAL overlay appears) and release, open Frame, rotate 90 degrees, apply
the square crop. The composition plays the take from 14.0 s to its end and holds the final frame
for a few tenths of a second while the product animates out.
