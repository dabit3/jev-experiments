# Linear Mac sessions: launch video

A 30 second, 1920x1080, 30 fps, H.264 (yuv420p) dark-mode video for the Linear integration update:
typing `@Devin !mac Build ...` in a Linear issue comment starts a Mac-backed Devin session.

Story: headline -> rebuilt Linear issue page, `@devin` mention popover, `!mac` command typed and
sent -> Linear shows "Devin started by ...", the working row, the Devin Session resource and the
Devin delegate -> crossfade into the Devin session with a minimal build progress view (no code
editor) -> Computer tab, the real lumen-drift take in the iPhone 17 Simulator on Devin's Mac ->
one inspection window with captions -> verified result -> Devin end card.

Built from the accepted `optical-laboratory` package; the Simulator take, inspection window and
play section are the same. Demo app: `lumen-drift` from github.com/dabit3/macos-experiments.

## Layout

```
composition/   HTML/CSS/JS composition (deterministic, driven by window.seek(t))
  config.js    every editable constant (timing, text, media, Linear palette, build steps, focus
               regions, cursor, colors, layout)
  index.html   DOM skeleton: title card, Linear issue page, Devin UI with Progress (build) and
               Computer views, Mac desktop + Simulator + iPhone, inspection window, end card
  styles.css   Linear and Devin styling
  main.js      builds the scene from config.js and exposes window.seek(seconds)
render/        Playwright/Chromium frame renderer + ffmpeg encode
media/         raw Simulator take (1206x2622, 21.4 s, one continuous 1x recording) and its tap log,
               plus a genuine iPhone 17 Simulator home-screen capture from the same device
assets/        Inter Tight and the Devin logos
output/        linear-mac-sessions.mp4 and contact-sheet.png
```

## Render

Requirements: Node 18+, ffmpeg on PATH (or `FFMPEG=/path/to/ffmpeg`).

```sh
cd launch-videos/linear-mac-sessions/render
npm install
npx playwright install chromium
node render.mjs video          # extracts Simulator frames, renders 900 PNGs, encodes MP4 + contact sheet
node render.mjs still 6.0      # single frame at t=6 s -> output/still-6.00.png
node render.mjs frames         # only re-extract media/frames from the raw take
```

`media/frames/` and `output/frames/` are generated and ignored by git; `video` recreates them.

## What to edit (all in `composition/config.js`)

- `VIDEO` size, fps, duration.
- `MEDIA` raw take frame directory and dimensions, `takeOffset`, home screen, logos.
- `BRAND` Devin colors (from the Devin Figma file) plus inspection stroke and caption colors.
- `LINEAR` the Linear dark palette (background, panel, borders, text tiers, accent, mention chip).
- `TEXT` headline, workspace and sidebar labels, issue id/title/description, the mention query
  (`@devin`), the exact command typed after the mention chip, the "started by" and working copy,
  the resource name, Devin session title, reply, timeline steps and final message.
- `BUILD` the build progress labels and when each appears in the Progress view (the last entry
  with `done: true` turns the ring and bar green).
- `STEPS` timeline entries in the Devin chat and when each appears.
- `TIMING` every beat: title, Linear in, mention typing, popover, select, command typing, send,
  started/working/assign/resource rows, Linear out, Devin in, Computer tab, launch, inspection
  window in/out, final message, end card.
- `CAMERA` camera keys `{ t, x, y, s, ease }`; a key may target a DOM element instead of a point
  with `el: 'linearComposer', dx, dy` so the push-in follows the composer as the page grows.
- `INSPECTION`, `FOCUS`, `CURSOR`, `LAYOUT` as in the optical-laboratory package; `LINEAR_LAYOUT`
  sets the Linear sidebar width, panel inset, header height and column positions.

## Provenance of the footage

The Simulator take is the same genuine recording as `optical-laboratory`: `xcrun simctl io booted
recordVideo` on an iPhone 17 (iOS 26.5) Simulator while a screenshot-driven autopilot played the
real game; `media/lumen-drift-simulator-take.log` lists every tap. It is used at 1x with no cuts or
recoloring. The Linear interface is rebuilt in HTML/CSS from a reference clip; no reference footage
is used.
