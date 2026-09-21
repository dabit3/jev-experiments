# Swiss Grid in Motion, Linear variant: "macOS. Now from Linear."

Dark-mode launch video (1920x1080, 30 fps, 30 s, H.264 yuv420p, silent) for the Linear integration update:
mentioning `@Devin !mac ...` in a Linear issue comment kicks off a Mac session in Devin Cloud (`!windows`
works the same way for Windows). Built as a deterministic HTML/CSS/JS composition and rendered frame by
frame with Playwright Chromium, then encoded with ffmpeg.

This is a variant of `../swiss-grid/` and keeps its grid, palette, session UI and footage. Two beats differ:

- The opening Devin composer is replaced by a reconstructed Linear issue page (sidebar, issue, properties,
  activity, comment composer with mention autocomplete). The Linear UI is rebuilt from scratch in HTML/CSS;
  no Linear footage or screenshots are used.
- The Swift code editor is replaced by a minimal "Devin is building." checklist animation.

Demo app: VoxelHearth (github.com/dabit3/macos-experiments, `voxelhearth`). Both recordings are genuine and
are the same takes as `../swiss-grid/media/` (Mac desktop take and iPhone Simulator take joined to the same
shared world); `extract-frames.sh` reads them from there.

## Files

| Path | What |
| --- | --- |
| `config.js` | Every editable constant: timing, Linear issue copy, mention/command/prompt, build steps, captions, colors, grid, media paths, crop positions |
| `index.html` | The composition (grid, Linear issue UI, build checklist, reconstructed Devin UI, phone frame, `window.seek(t)`) |
| `render.mjs` | Renders frames to `frames/out/` and encodes `out/swiss-grid-linear.mp4` plus `out/contact-sheet.png` |
| `extract-frames.sh` | Turns the raw recordings in `../swiss-grid/media/` into the JPEG frame sequences the page plays back |
| `assets/logos/` | Devin lockups and avatar marks (white on dark, black on light), alpha-trimmed |
| `assets/fonts/InterTight.ttf` | Inter Tight variable font (NB International Pro stand-in) |
| `out/swiss-grid-linear.mp4` | Final render |
| `out/contact-sheet.png` | 1920x1080 contact sheet, one frame per second |

## Render

```sh
cd launch-videos/swiss-grid-linear
npm install                 # playwright ^1.50 (Chromium is downloaded on first install)
npx playwright install chromium
sh extract-frames.sh        # writes frames/mac and frames/ios (about 200 MB, not committed)
node render.mjs             # 900 PNG frames -> out/swiss-grid-linear.mp4 + out/contact-sheet.png
node render.mjs --still 4.85 8.6 12.7   # PNG stills at those seconds into stills/
```

The page itself is deterministic: `window.seek(t)` lays out the frame for time `t` and `window.ready()`
resolves once fonts and the current media frames are decoded, so there is no wall-clock animation.

## What to edit (all in `config.js`)

- `t.*` scene start times (seconds): `open`, `composer` (Linear issue beat), `code` (build checklist beat),
  `session`, `both`, `test`, `result`, `end`. `duration` and `fps` set the output length.
- `copy.mention`, `copy.command`, `copy.prompt` the comment that gets typed (`@devin`, `!mac`, request).
  Change `command` to `!windows` for the Windows variant.
- `copy.linear.*` issue key, title, description and the "Starting Mac session..." status row.
- `copy.buildTitle`, `copy.buildSteps` the checklist rows in the build animation.
- `copy.*` headline, captions, session strings, result lines and CTA. Keep captions short; no em dashes.
- `color.*` brand field, ink, rules, and the light Devin UI palette; `font.*` families.
- `grid` margin, gutter and column width (12 columns). Every panel, caption and logo edge sits on these lines.
- `media.*` frame directories, counts and the raw-take offsets used by `extract-frames.sh`.
- `macCrop` cover width and vertical offset for the full-bleed Mac footage, plus the zoom scale and origin
  used when the Computer pane pushes in on the Mac window.

Linear camera (`LIN.zoom`, `LIN.landY`) and build animation pacing (`BUILD.stagger`, `BUILD.fillDur`) are
constants at the top of the script in `index.html`, next to the grid-derived panel rects.

## Story

1. Devin logo, then "macOS. / Now from Linear." revealed through rectangular masks.
2. The Linear issue VOX-12 slides up on the grid; the camera pushes in on the comment box; `@de` opens the
   mention menu, Devin is picked, then `!mac Build VoxelHearth, ...` is typed and sent.
3. The comment posts; Devin activity appears: "Starting Mac session...", then the linked Devin Session.
4. The panel wipes to a dark build checklist: clone, resolve packages, build macOS, build iPhone; "Build
   Succeeded" for both targets.
5. The session view (chat left, Computer pane right) slides in; VoxelHearth runs in a Mac window on the Mac
   desktop; the pane pushes in on the window.
6. Chat slides out, the Mac footage goes full-bleed and the iPhone Simulator (narrow column, cols 10 to 12)
   joins the same world.
7. Chat slides back with Devin's test summary; the session collapses to the top alignment line.
8. "Built, run and tested / from a Linear issue." then Devin lockup and devin.ai.
