# Optical Laboratory: macOS in Devin Cloud launch video

Direction 3 of the launch-video series. A 29 second, 1920x1080, 30 fps, H.264 (yuv420p) dark-mode
video that tells the story prompt -> Devin writes Swift -> the app runs in the iOS Simulator on
Devin's Mac inside the Devin session UI -> Devin plays and verifies it. One outlined inspection
window magnifies the genuine Simulator recording and connects to the region it enlarges, with a
caption in the right margin for each inspected action.

Demo app: `lumen-drift` from github.com/dabit3/macos-experiments (SwiftUI + SpriteKit, iPhone).

## Layout

```
composition/   HTML/CSS/JS composition (deterministic, driven by window.seek(t))
  config.js    every editable constant (timing, text, media, focus regions, cursor, colors, layout)
  index.html   DOM skeleton: title card, Devin UI, code view, Mac desktop + Simulator + iPhone,
               inspection window, end card
  styles.css   brand styling
  main.js      builds the scene from config.js and exposes window.seek(seconds)
render/        Playwright/Chromium frame renderer + ffmpeg encode
media/         raw Simulator take (1206x2622, 21.4 s, one continuous 1x recording) and its tap
               log, plus a genuine iPhone 17 Simulator home-screen capture from the same device
assets/        fonts (Inter Tight, JetBrains Mono for code only) and Devin logos
tools/         the screenshot-driven autopilot and recording script used to capture the take
output/        optical-laboratory.mp4 and contact-sheet.png
```

## Render

Requirements: Node 18+, ffmpeg on PATH (or `FFMPEG=/path/to/ffmpeg`).

```sh
cd launch-videos/optical-laboratory/render
npm install
npx playwright install chromium
node render.mjs video          # extracts Simulator frames, renders 870 PNGs, encodes MP4 + contact sheet
node render.mjs still 13.2     # single frame at t=13.2 s -> output/still-13.20.png
node render.mjs frames         # only re-extract media/frames from the raw take
```

`media/frames/` (JPEG frames of the raw take at 30 fps) and `output/frames/` are generated and
ignored by git; `video` recreates them when missing.

## What to edit (all in `composition/config.js`)

- `VIDEO` size, fps, duration.
- `MEDIA` raw take frame directory and dimensions, `takeOffset` (seconds of the take that play
  before the app launches in the composition), home screen, logos, fonts.
- `BRAND` colors sampled from the Devin Figma file (`#191919` panels, `#20f` accent) plus the
  inspection stroke and caption colors.
- `TEXT` headline, exact composer prompt, Devin reply, final message; `STEPS` the timeline
  entries and when each appears.
- `TIMING` every beat: title, UI enter, typing, send, Changes/Computer tab switches, launch,
  observation window in/out, final message, end card.
- `CAMERA` the camera path over the Devin UI: keys of `{ t, x, y, s, ease }` (UI point at frame
  center, scale, glide seconds). Full view is `s: 1`; the composer hero beat is `s: 2`, the code view `s: 1.4`, and the
  pan that opens the right margin for the inspection window.
- `INSPECTION` window position, size, stroke, caption position and size, fade and move easing.
- `FOCUS` the inspection path: `{ t, cx, cy, w, caption }` in normalized Simulator screen
  coordinates. The crop is square and always sampled from the 1206x2622 source, so the 560 px
  window never exceeds source resolution (the narrowest crop, 0.34 of 1206 px, is 410 source px
  shown at 560 px).
- `CURSOR` cursor keyframes (UI elements, tabs, or normalized phone taps).
- `LAYOUT` chat width, header height, Mac screen rectangle, Simulator toolbar and iPhone frame.
- `CODE` the Swift shown in the Changes view (typed out and syntax highlighted at render time).

## Provenance of the footage

The take was recorded with `xcrun simctl io booted recordVideo` on an iPhone 17 (iOS 26.5)
Simulator while `tools/autopilot.swift` played the real game through CoreGraphics taps chosen from
live screenshots. `media/lumen-drift-simulator-take.log` lists every tap with its timestamp. The
footage is used at 1x with no cuts or recoloring; the composition simply starts the take at
`MEDIA.takeOffset` so the launch aligns with the story.
