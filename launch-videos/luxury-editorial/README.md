# macOS in Devin Cloud: Luxury Editorial launch video

Direction 5, `luxury-editorial`, dark theme. A 29.6 s, 1920x1080, 30 fps H.264 (yuv420p) spot built as an HTML/CSS/JS composition rendered frame by frame with Playwright and encoded with ffmpeg.

Demo app: **Aster**, the native macOS orbital mechanics lab from `dabit3/macos-experiments/aster`. The footage in `media/aster-take1.mp4` is a genuine ffmpeg avfoundation capture of the Mac desktop while Aster was built, launched and flown (load departure recipe, execute burn, resume flight, 600x time warp, objective complete). Nothing in it is sped up, cut or recolored.

## Files

| Path | What it is |
| --- | --- |
| `config.js` | Every editable constant: video size/fps, brand tokens, scene timings, copy, recording window, Swift snippet |
| `index.html` | The seven spreads (cover, prompt, code, Devin session, full-frame demo, result, close) |
| `styles.css` | Editorial type system plus the reconstructed dark Devin UI |
| `composition.js` | Deterministic `seek(t)` animation: eased motion, typing, cursor, zooms, spread sweeps |
| `render.mjs` | Playwright frame renderer plus ffmpeg encode |
| `extract-frames.sh` | Turns the raw recording into the JPEG frame sequence the composition reads |
| `assets/` | Devin lockup and avatar (white), bundled Inter Tight and JetBrains Mono |
| `media/aster-take1.mp4` | Raw 1600x1200 desktop recording of Aster (55 s) |
| `out/final.mp4` | Final render |
| `out/final-contact-sheet.png` | 1 fps contact sheet of the final render |

## Render

Requirements: Node 20+, ffmpeg on PATH.

```sh
npm install
npx playwright install chromium
npm run frames    # media/aster-take1.mp4 -> media/rec/0001.jpg ... (540 frames, 125 MB, not committed)
npm run render    # out/frames/*.png -> out/final.mp4
npm run sheet     # out/final-contact-sheet.png
```

Quick checks while iterating:

```sh
node render.mjs --stills "1.6,5.6,10.5,16.0,22.0,26.5"   # PNGs in out/stills
node render.mjs --from 12 --to 21 --out out/part.mp4     # partial render
```

## What to edit

All in `config.js`:

- `VIDEO`: output size and fps.
- `TOKENS`: field and ink colors, reconstructed Devin UI palette, font stacks.
- `SCENES`: start and end of each spread on the master timeline, plus `rec`, the recording timestamp (seconds into `aster-take1.mp4`) shown when that spread begins. `TRANSITION` is the sweep overlap.
- `COPY`: headline lines, the exact composer prompt, spread copy, Devin session steps (with their `at` and `done` times) and the closing CTA.
- `REC`: which 18 s of the recording are extracted (`offset`), the Aster window rect and globe centre used for the cover crop and full-frame demo.
- `CODE`: the Swift shown in the editor (taken from Aster's `Orbit.swift`).

Layout geometry (margins, type sizes, the Devin session grid) lives in `styles.css`; per-spread choreography (cursor path, zoom targets, typing speed) lives at the top of each scene function in `composition.js`.

## Typography

NB International Pro is not available in this environment, so the brief's fallback Inter Tight is bundled and used with tight tracking. JetBrains Mono appears only inside the code editor spread.
