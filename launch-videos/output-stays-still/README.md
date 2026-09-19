# Launch video: The Output Stays Still

Direction 8 of the "macOS in Devin Cloud" launch series, light theme.
The finished Silverroom build sits in a reconstructed Devin iOS Simulator pane on the right and never moves or rescales. Everything else (the Devin composer, the heading, the dark control panel with the enlarged crop, the outro lockup) moves around it.

- Output: `final/output-stays-still.mp4`, 1920x1080, 30 fps, H.264 yuv420p, 27.0 s, silent
- Scale: opening lockup plus 80 px headline, composer 940 px wide (49 percent) with 34 px prompt text, phone 706 px tall (65 percent), control panel fills the left column edge to edge with 26 px code, end lockup 768 px wide (40 percent) with 48 px devin.ai
- Contact sheet: `final/contact-sheet.png` (30 frames, 0.9 s apart)
- Demo app: Silverroom from `dabit3/macos-experiments`, built with Xcode 26.6 for the iOS 26.5 Simulator (iPhone 17)

## Footage

`media/silverroom-take.mp4` is one continuous `xcrun simctl io booted recordVideo` take (1206x2622, about 17.5 s) driven by `media/record-take.sh` (cliclick against the Simulator window). It plays at 1x with no internal cuts, speed changes or recoloring, both inside the anchored phone and in the enlarged crop. The sequence is: open the cove photo, choose Noir, open Adjust and drag Exposure, hold and release compare, open Frame, rotate 90 degrees, apply the square crop.

## Render

```sh
cd launch-videos/output-stays-still
npm install                      # playwright 1.50.1
npx playwright install chromium
ffmpeg -i media/silverroom-take.mp4 -vf fps=30 -q:v 2 media/frames/%04d.jpg
node render.mjs                  # -> out/output-stays-still.mp4 + out/contact-sheet.png
node render.mjs --still 12.5     # single frame preview -> out/still-12.50.png
```

`render.mjs` loads `index.html` in headless Chromium at 1920x1080, calls `window.seek(t)` for each of the 810 frames, screenshots them to `out/frames/`, then encodes with `ffmpeg -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30`. Rendering is deterministic: every frame is a pure function of `t`.

Fonts: the composition uses Inter Tight (install the variable font, for example to `~/Library/Fonts/InterTight[wght].ttf`) and falls back to Helvetica Neue. NB International Pro was not available on the render machine. Code uses SF Mono / Menlo.

## What to edit

All tunables are at the top of the `<script>` in `index.html`:

- `FPS`, `DURATION`: output timing (keep in sync with `render.mjs`)
- `TAKE_FRAMES_DIR`, `TAKE_FRAME_COUNT`, `TAKE_START`: where the extracted take frames live and when the take starts playing (the phone shows the first frame before that)
- `HEADING`, `PROMPT`: the heading text and the typed request
- `T`: every timing window in seconds (opening lockup, heading word cadence, resolve into the composer, pointer moves, menus, typing, panel in/out, code typing, lockup and URL)
- `OPEN`: where the large opening lockup and 80 px headline sit before they resolve into the composer header
- `CROP`: the crop keyframes for the control panel (`x`,`y` are normalized centers in the take frame, `z` is zoom, `dur` is the ease duration)
- `DRIFT`: the continuous camera drift (about three percent) that reverses at each act boundary
- CSS custom properties in `:root`: paper, ink, panel and accent colors sampled from the Devin UI screenshots
- Layout geometry for the pane, phone and composer is in the CSS block right below

Motion uses a single fast-out gentle-in ease for all primary moves (350 to 700 ms) and delays secondary elements by 100 to 250 ms. There are no linear tweens or bounces.

## Assets

`assets/` holds the supplied Devin lockup and square avatar marks. The Devin UI (composer, environment menu, session pane) is reconstructed in HTML and CSS; no reference video or screenshot is used as footage.
