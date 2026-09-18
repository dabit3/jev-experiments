# The Aperture Film

Devin launch video for "macOS in Devin Cloud", direction 7. Light theme. 1920x1080, 30 fps, H.264 (yuv420p), 29.8 s, silent.

One rounded aperture in a paper matte changes shape for the whole film while the product sits behind it: a slit on the environment selector of a reconstructed Devin composer, the full composer, a Swift editor, a portrait window on the genuine Silverroom Simulator take inside the reconstructed Devin session (the aperture then widens across the session with every camera push), the full session view, then the dark brand field with the white Devin lockup and devin.ai.

## Layout

```
composition/
  index.html   reconstructed Devin UI (composer, editor, session view) and outro, all HTML/CSS
  style.css    palette, type, layout
  config.js    editable constants: timings, copy, colors, media paths
  film.js      deterministic composition; exposes window.__seek(t) for frame capture
assets/
  fonts/       Inter Tight (UI), JetBrains Mono (code editor only)
  logo/        supplied Devin lockups and avatar marks
  raw/silverroom-take.mp4   genuine iPhone 17 Pro Simulator recording (xcrun simctl io recordVideo), untouched
out/
  aperture-film.mp4, contact-sheet.png   final render
render.mjs     Puppeteer frame renderer
```

## Render

Requires Node 18+, ffmpeg and Chrome (downloaded by Puppeteer on install).

```sh
npm install
npm run build          # frames:take -> render -> encode -> sheet
```

Steps individually:

- `npm run frames:take` extracts the used portion of the raw take to `frames/take/` as 30 fps PNGs (the take is not retimed or recolored; only the head, before the photo is opened, is trimmed).
- `npm run render` captures every frame of `composition/index.html` to `frames/out/` via `window.__seek(t)`.
- `npm run encode` encodes `out/aperture-film.mp4` with `libx264 -pix_fmt yuv420p -crf 16 -r 30`.
- `npm run sheet` writes a 1920x1080 contact sheet.

Preview a few moments without a full render:

```sh
node render.mjs --out frames/preview --times 0.6,3.5,9.0,16.0,26.3,29.6
```

## What to edit

Everything tunable lives in `composition/config.js`:

- `fps`, `duration`, `width`, `height`
- `colors` (paper matte, page, ink, blue chip, success, working, dark field)
- `text` (headline, typed prompt, session title, Devin reply, timeline steps, URL)
- `media` (logo paths, take frames directory and count)
- `t` (every beat of the timeline in seconds: aperture openings and closings, menu, typing, submit, code, footage start, outro)

If you change the take trim in `package.json` (`-ss`, `-t`), update `media.takeFrameCount` (frames = seconds x 30) and, if the touch points move, the `sessionCamera` keys in `film.js` (expressed in seconds from `t.footageStart`).

## Take

Silverroom (github.com/dabit3/macos-experiments, `silverroom`) built with Xcode for the iPhone 17 Pro Simulator (iOS 26.5) and recorded in one continuous 1x take: open a photo, choose Noir in the Looks strip, drag the exposure slider, hold and release compare, open Frame, rotate 90 degrees, apply a square crop.
