# Agent Loom (launch video, macOS in Devin Cloud)

Direction 11, light mode. Two workstreams (Silverroom, RTX Afterdark) run as separate threads inside a reconstructed Devin UI, then converge into a woven backing that holds both native outcomes.

Final render: `out/agent-loom.mp4` (1920x1080, 30 fps, H.264 yuv420p, 29.8 s, silent). Contact sheet: `out/contact-sheet.png`.

## Layout

- `index.html`, `style.css`, `comp.js`: the composition. `comp.js` exposes `window.render(t)` which sets every element deterministically for time `t` in seconds.
- `config.js`: every editable constant (timings, copy, colors, media paths, layout). Edit this first.
- `render.js`: drives headless Chromium via Playwright, screenshots each frame, encodes with ffmpeg.
- `media/silver/`, `media/rtx/`: JPEG frame sequences extracted from the raw takes (30 fps, 1x, no internal cuts). `media/logo/`: supplied Devin lockup and mark.
- `raw/silverroom-take.mp4`, `raw/rtx-afterdark-take.mp4`: the untouched `xcrun simctl io booted recordVideo` recordings (iPhone 16 Pro, iOS 26.5 Simulator, Xcode 26.6).

## Render

```sh
npm install            # playwright ^1.x; then: npx playwright install chromium
node render.js         # writes out/frames/*.png and out/agent-loom.mp4
node render.js --preview 4.4,12.5,27.0   # single frames to out/preview/
ffmpeg -i out/agent-loom.mp4 -vf "fps=2,scale=320:-1,tile=6x5,pad=1920:1080:0:90:color=0xF4F0E8" -frames:v 1 out/contact-sheet.png
```

Requires Node 20+, ffmpeg, and Helvetica Neue (present on macOS). The brand face NB International Pro is not installed; swap the `font-family` in `style.css` if you have it.

## Re-extracting footage

The frame sequences are trimmed from the raw takes with ffmpeg. Change the seek/duration and re-run; then update `media.silverFrames` / `media.rtxFrames` in `config.js`.

```sh
ffmpeg -ss 2.9 -i raw/silverroom-take.mp4 -t 8.7 -vf "fps=30,scale=402:874" -q:v 2 media/silver/f%04d.jpg
ffmpeg -ss 8.9 -i raw/rtx-afterdark-take.mp4 -t 6.57 -vf "fps=30,transpose=2,scale=874:402" -q:v 2 media/rtx/f%04d.jpg
```

## Editable constants (`config.js`)

- `duration`, `fps`: total length and frame rate.
- `colors`: paper, ink, accent blue, UI grays.
- `text`: headline lines, both composer requests, session titles, Devin messages, outcome line, URL.
- `media`: frame directories, frame counts, logo paths.
- `timeline`: every keyframe. Scene A headline (`hlWordStart`, `hlWordStep`, `hlExit`), Scene B composer (`cRise`, `cPartLag`, `menuOpen`, `macSelect`, `typeStart`, `typeEnd`, `submitPress`, `cExit`), Scene C session (`sRise`, `codeStart`, `silverStart`, `rotateStart`, `rtxStart`, `blueDraw`, `inkDraw`, `pushes[]` with the touch points the camera pushes toward), Scene D weave (`wLeadStart`, `wGridStart`, `outcomeIn`, `wExit`), Scene E end card (`logoIn`, `urlIn`).
- `code`: the Swift tokens shown in the editor.
- `layout`: composer and session window geometry, phone scale, weave grid extents and stroke.

## Notes

The Devin composer and session views are reconstructions built in HTML for crispness; they are not screen captures. Only the phone screens are real Simulator footage.
