# macOS in Devin Cloud: Graphic Storyboard (dark)

A 27.5 second, 1920x1080, 30 fps launch video told as a graphic storyboard: sequential
panels with moving gutters, expressive panel resizing and margin captions. Every panel
that shows VoxelHearth uses a genuine recording of the native app captured on this Mac,
placed inside a reconstructed dark-mode Devin session UI.

Panel order: prompt -> Swift code -> Mac build running on Devin's Mac -> iPhone build
running in the Simulator -> full-frame Devin session with the Mac app and the Simulator side
by side in one shared world -> Devin end card. Each active panel pushes in to fill about 83%
of the frame, then eases back to its storyboard slot as quiet context.

## Files

| Path | Purpose |
| --- | --- |
| `macos-in-devin-cloud-graphic-storyboard.mp4` | Final render (H.264, yuv420p, 27.5 s) |
| `contact-sheet-1.png`, `contact-sheet-2.png` | 2 fps contact sheets of the final render (1920x1080 each) |
| `composition/config.js` | All editable constants: timings, captions, copy, colors, media paths, panel keyframes |
| `composition/storyboard.js` | Timeline engine: `window.renderFrame(t)` lays out panels for time `t` |
| `composition/ui.js` | Reconstructed Devin UI fragments (composer, Swift editor, session view incl. the side-by-side final view) |
| `composition/style.css`, `composition/index.html` | Stage, typography and dark palette |
| `media/voxelhearth-mac-desktop.mp4` | Raw macOS desktop recording (`screencapture -v`) |
| `media/voxelhearth-iphone-simulator.mp4` | Raw iPhone Simulator recording (`xcrun simctl io booted recordVideo`) |
| `assets/devin-*.png` | Supplied Devin lockup and avatar (white on dark) |
| `prep-media.sh` | Extracts deterministic 30 fps JPEG frame sequences from the raw recordings |
| `render.mjs` | Renders the composition frame by frame with Playwright Chromium |
| `encode.sh` | Encodes the PNG frames to MP4 and generates the contact sheets |
| `preview.mjs` | Renders single moments for quick review |

## Render

Requires Node 18+, ffmpeg and ffprobe on the PATH.

```sh
cd launch-videos/graphic-storyboard
npm install
npx playwright install chromium

./prep-media.sh      # media/mac-frames, media/iphone-frames (gitignored, regenerated from the raw recordings)
node render.mjs      # out/frames/00000.png ... (825 frames)
./encode.sh          # out/macos-in-devin-cloud-graphic-storyboard.mp4 + out/contact-sheet-*.png
```

Partial renders: `node render.mjs --from 9.6 --to 14 --every 1`.
Quick looks: `node preview.mjs 4.5 12.8 17.5 24` writes PNGs to `out/preview/`.
Open `composition/index.html` in a browser for a live loop, or append `?t=12.5` to
freeze a single moment.

## What to edit

Everything intended to change lives in `composition/config.js`:

- `fps`, `duration`, `width`, `height`: output format.
- `colors`: field, text, accent (`#2200ff`), Devin UI greys.
- `media`: frame-sequence folders and counts, logo assets.
- `footage.macStart`, `footage.iphoneStart`, `footage.macBothStart`, `footage.iphoneBothStart`:
  which second of each recording the Mac, iPhone and final side-by-side panels start on.
- `slots` and `hero`: the quiet storyboard slot rect per panel and the shared hero rects, plus
  the `computer`/`simulator` push-in (zoom + focus) that fills the hero with the Computer pane.
  The panel keyframes at the bottom of the file are built from these.
- `text`: headline, the exact typed prompt, session title, Devin replies, end URL.
- `captions`: margin captions with `t0`/`t1` and the x position of the panel they belong to.
- `panels.<name>.keys`: the storyboard choreography. Each keyframe holds `t`, `rect`
  `[x, y, w, h]`, opacity `o`, zoom `z`, focus point `f` in content pixels and optional
  `clip` insets for gutter reveals. Panels interpolate between keyframes with an eased
  curve, so moving a gutter is just changing a `rect`.
- `title` and `end`: opening and closing beats.

Typography uses NB International Pro if installed, otherwise Inter Tight, otherwise
Helvetica Neue. Monospace is used only inside the Swift editor panel.

## Footage provenance

VoxelHearth (github.com/dabit3/macos-experiments, `voxelhearth/`) was built from source
with `xcodegen` + `xcodebuild` for both the `VoxelHearth-macOS` and `VoxelHearth-iOS`
schemes. The bundled Node server was started locally, the Mac app hosted shared room
`DQK43`, and the iPhone 17 Simulator joined it. Both recordings show real play (camera
movement, breaking and placing blocks, torches). Takes are used at native speed with no
internal cuts or recoloring.
