# Swiss Grid in Motion: "macOS. Now in Devin Cloud."

Dark-mode launch video (1920x1080, 30 fps, 30 s, H.264 yuv420p, silent) built as a deterministic
HTML/CSS/JS composition and rendered frame by frame with Playwright Chromium, then encoded with ffmpeg.

Demo app: VoxelHearth (github.com/dabit3/macos-experiments, `voxelhearth`), built for macOS and for the
iPhone Simulator on Devin's Mac. Both recordings are genuine: the Mac app on the desktop and the iPhone
Simulator joined to the same shared world, with real block placement and camera movement.

## Files

| Path | What |
| --- | --- |
| `config.js` | Every editable constant: timing, captions, colors, grid, media paths, crop positions, brand copy |
| `index.html` | The composition (grid, reconstructed Devin UI, code editor, phone frame, `window.seek(t)`) |
| `render.mjs` | Renders frames to `frames/out/` and encodes `out/swiss-grid.mp4` plus `out/contact-sheet.png` |
| `extract-frames.sh` | Turns the raw recordings into the JPEG frame sequences the page plays back |
| `media/mac_take3.mp4` | Raw Mac desktop take (`screencapture -v`, 1600x1200 60 fps), re-encoded once to fit in git, no cuts or speed change |
| `media/ios_take4.mp4` | Raw iPhone Simulator take (`xcrun simctl io booted recordVideo`), re-encoded once to fit in git, no cuts or speed change |
| `assets/logos/` | Devin lockups and avatar marks (white on dark, black on light), alpha-trimmed |
| `assets/fonts/InterTight.ttf` | Inter Tight variable font (NB International Pro stand-in) |
| `out/swiss-grid.mp4` | Final render |
| `out/contact-sheet.png` | 1920x1080 contact sheet, one frame per second |

## Render

```sh
cd launch-videos/swiss-grid
npm install                 # playwright ^1.50 (Chromium is downloaded on first install)
npx playwright install chromium
sh extract-frames.sh        # writes frames/mac and frames/ios (about 200 MB, not committed)
node render.mjs             # 900 PNG frames -> out/swiss-grid.mp4 + out/contact-sheet.png
node render.mjs --still 4.5 13.5 21   # PNG stills at those seconds into stills/
```

The page itself is deterministic: `window.seek(t)` lays out the frame for time `t` and `window.ready()`
resolves once fonts and the current media frames are decoded, so there is no wall-clock animation.

## What to edit (all in `config.js`)

- `t.*` scene start times (seconds): `open`, `composer`, `code`, `session`, `both`, `test`, `result`, `end`.
  `duration` and `fps` set the output length.
- `copy.*` headline, prompt, captions, session strings, result lines and CTA. Keep captions short; no em dashes.
- `color.*` brand field, ink, rules, and the light Devin UI palette; `font.*` families.
- `grid` margin, gutter and column width (12 columns). Every panel, caption and logo edge sits on these lines.
- `media.*` frame directories, counts and the raw-take offsets used by `extract-frames.sh`.
- `macCrop` cover width and vertical offset for the full-bleed Mac footage, plus the zoom scale and origin
  used when the Computer pane pushes in on the Mac window.

Layout positions (panel rects, phone column, caption columns) are grid-derived constants at the top of the
script in `index.html`.

## Story

1. Devin logo, then "macOS. / Now in Devin Cloud." revealed through rectangular masks.
2. Devin composer slides up on the grid; the exact VoxelHearth prompt is typed; environment picker opens and
   macOS is selected (pane pushes in so it is not missed).
3. Code editor wipes in along the shared edge: Devin writes `Game.swift`; "Build Succeeded" for both targets.
4. The session view (chat left, Computer pane right) slides in; VoxelHearth runs in a Mac window on the Mac
   desktop; the pane pushes in on the window.
5. Chat slides out, the Mac footage goes full-bleed and the iPhone Simulator (narrow column, cols 10 to 12)
   joins the same world.
6. Chat slides back with Devin's test summary; the session collapses to the top alignment line.
7. "Built, run and tested / on a Mac in Devin Cloud." then Devin lockup and devin.ai.
