# macOS in Devin Cloud: "TypeSafe Motion Blueprint" launch video

A 27.8 s, 1920x1080, 30 fps silent launch film for the "macOS in Devin Cloud" announcement.
Demo app: **VoxelHearth** (voxel sandbox for macOS + iPhone with shared worlds, from `dabit3/macos-experiments`).

Everything on screen is a reconstructed Devin UI (new-session composer, environment menu, session view with
Changes / Computer panes). The only "footage" is real: the VoxelHearth macOS build running on the Mac desktop and
the VoxelHearth iPhone build running in the iOS Simulator, both recorded on the Mac that built them.

- `out/typesafe-blueprint.mp4` - final render (H.264, yuv420p)
- `out/contact-sheet.png` - 1920x1080 contact sheet (2 fps, 8x7)
- `footage/voxelhearth-iphone-simulator.mp4` - raw iOS Simulator recording (re-encoded, no edits)
- `footage/voxelhearth-mac-desktop.mp4` - raw Mac desktop recording (re-encoded, no edits)

## Beats

| time | beat |
| --- | --- |
| 0.0 - 3.0 | title on blueprint paper: centred Devin lockup over "macOS. / Now in Devin Cloud." |
| 3.0 - 7.7 | new-session composer; the request is typed; environment menu opens and **macOS** is picked |
| 7.7 - 12.5 | session view, Changes tab: Devin writes `Game.swift` (Swift, real VoxelHearth code) |
| 12.5 - 18.5 | Computer tab: iPhone Simulator on the Mac desktop (pixel-block aperture reveal), two captions, push-in to the phone and hold |
| 18.5 - 24.4 | Computer tab: VoxelHearth macOS window on the Mac desktop, second player visible, session completes, push-in to the game window and hold |
| 24.4 - 27.8 | 0.4 s block wipe to black; end card: Devin lockup, `devin.ai` |

## Render

Requirements: Node 18+, `ffmpeg`, Playwright Chromium.

```sh
npm install                 # playwright
npx playwright install chromium
npm run frames              # footage/*.mp4 -> assets/frames/{mac,iphone}/NNNN.jpg  (only if assets/frames is missing)
npm run render              # index.html -> out/frames/000000.png ... (834 frames, ~2.5 min)
npm run encode              # out/frames -> out/typesafe-blueprint.mp4 + out/contact-sheet.png
```

Quick checks without a full render:

```sh
npm run stills -- 2.6,7.4,9.5,15.5,20,26     # -> out/stills/tNN.NN.png
open "index.html?play"                         # loop in a browser (Chromium/Safari)
open "index.html?t=15.5"                       # a single frame
```

The composition is one self-contained file: `index.html` (HTML + CSS + JS). It is deterministic: `window.seek(t)`
sets the whole frame for time `t`, and the render script screenshots each frame at 30 fps. Footage is played back
from extracted JPEG frame sequences (not `<video>`) so every frame is exact.

## What to edit

All constants live in `window.CONFIG` at the top of `index.html`:

- `fps`, `duration` - output timing (the render/encode scripts read `fps` from the file).
- `cell` - pixel-block cell size for the checkerboard transitions (1920/cell must be an integer).
- `color.*` - palette. `accent` is the single saturated brand colour (`#2200FF` from the Devin Figma).
- `text.*` - headline, typed prompt, captions, Devin's chat messages, code file name, URL.
- `t.*` - every beat's start time in seconds (`toComposer`, `toCode`, `toPhone`, `toMac`, `toBlack`, caption swaps, push-ins).
  Captions always drop out before a push-in starts and before the closing wipe.
- `media.*` - frame-sequence folders and `frameCount`, desktop screenshot, logo files.
- `code` - the Swift lines that are typed in the Changes pane.

Other knobs:

- `TR` / `TR_END` (in the script) - pixel-block transition length for cuts / for the closing wipe; `ORD.*` - which block
  order each cut uses (`orderSweep`, `orderRandom`, `orderAperture(cx, cy)`).
- Camera push-ins are the `cam(...)` calls at the end of `renderSession` (scale + origin per beat).
- Layout of the reconstructed UI is plain CSS under `/* Devin session window */`, `/* New-session composer */`, `/* End card */`.
- `scripts/extract-frames.sh` - `MAC_START` / `PHONE_START` choose which moment of the recordings is used.

## Fonts

Inter Tight (variable) and JetBrains Mono (variable) are vendored in `assets/fonts/` as stand-ins for the brand faces
(NB International Pro and Geist Mono in Figma), which are not redistributable here.
