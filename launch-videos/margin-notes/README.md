# Margin Notes: macOS in Devin Cloud

Launch video for "macOS in Devin Cloud" in the Margin Notes direction: the product occupies a warm paper page, the explanation lives in the right margin as short notes on leader lines.

- 1920x1080, 30 fps, H.264 (yuv420p), silent, 29.2 s
- Light theme (paper page, Devin light UI)
- Demo app: Silverroom (github.com/dabit3/macos-experiments, `silverroom`), recorded for real in the iOS Simulator
- Final render: `out/margin-notes.mp4`, contact sheet: `out/contact-sheet.png`

## What is real

- `assets/silverroom-take.mov` is one continuous 1x `xcrun simctl io booted recordVideo` take of Silverroom on an iPhone 17 Pro Simulator: open a photo, Noir look, exposure drag, hold to compare and release, Frame tools, rotate, square crop. It plays uncut inside the reconstructed Devin session window (whole phone left, enlarged detail panel right).
- The Swift typed into the Changes tab is taken from `silverroom/Silverroom/ImageEngine.swift` (the film saturation switch and the `CIColorControls` filter). The build strip below it is an Xcode-style progress view inside the Devin session, not a Terminal capture. The app was built for real with `xcodebuild` before recording.
- The Devin composer, environment selector and session window are rebuilt in HTML/CSS; the Devin lockups and marks are the supplied brand files.

## Files

| File | Purpose |
| --- | --- |
| `config.js` | Every editable constant: timings, copy, colors, media paths, detail-panel focus keyframes, margin notes |
| `index.html` | The composition. Exposes `window.seek(t)` so the renderer can draw any timestamp deterministically |
| `render.mjs` | Extracts the take to JPEG frames, drives Chromium with Playwright, screenshots every frame, encodes with ffmpeg, writes the contact sheet |
| `assets/` | Simulator take, Devin logos |
| `capture/` | How the take was recorded: `tap.swift` (CoreGraphics tap/drag/hold helper, `swiftc -O tap.swift -o tap`) and `record-take.sh` (installs the built app, starts `simctl recordVideo`, drives the interaction sequence). Screen coordinates assume the Simulator window placement used on the recording Mac |
| `out/` | Render output (`margin-notes.mp4`, `contact-sheet.png`); PNG frames and stills are gitignored |

## Requirements

- macOS or Linux with Node 18+
- ffmpeg and ffprobe on `PATH`
- Playwright with its Chromium build: `npm install && npx playwright install chromium`
- Fonts: the composition asks for `NB International Pro`, then `Inter Tight`, then `Helvetica Neue`. The delivered render used Helvetica Neue on macOS. Install NB International Pro locally to render with the brand face; nothing else changes.

## Render

```sh
cd launch-videos/margin-notes
npm install
npx playwright install chromium

# full render: extracts frames from the take on first run, then writes out/margin-notes.mp4 and out/contact-sheet.png
npm run render

# one or more stills for checking a moment (written to out/still-<t>.png)
node render.mjs --still 6.0 12.5 28.6

# a time range only (seconds), useful while iterating
node render.mjs --range 8 11
```

Encoding uses `-c:v libx264 -pix_fmt yuv420p -crf 16 -r 30 -movflags +faststart`. The contact sheet is 1920x1080 (`fps=1.21,scale=320:180,tile=6x6`); for a denser check run `ffmpeg -i out/margin-notes.mp4 -vf "fps=2,scale=320:-1,tile=6x10" -frames:v 1 -update 1 sheet.png`.

## Editing

All constants live in `config.js`:

- `duration`, `fps`: master length and frame rate. `timeline.outro.end` should match `duration`.
- `text.*`: headline, composer placeholder, typed prompt, margin notes, session chat copy, build strip labels and URL.
- `code`: the Swift lines typed into the Changes tab (27 px monospace, syntax highlighted in `index.html`).
- `colors.paper`: page color. UI colors are in the `<style>` block of `index.html`.
- `timeline.title | composer | build | sim | outro`: scene in/out and beat times in seconds. Composer beats: `cursorStart`, `menuOpen`, `hoverMac`, `macPick`, `noteIn/noteOut`, `typeStart/typeEnd`, `send`. Build beats: `codeStart/codeEnd` (typing), `buildStart/buildEnd` (progress to Build Succeeded), `noteIn/noteOut` (Built with Xcode).
- `simZoom`, `zoomOrigin`: camera pushes onto the phone (take time) for the Noir, exposure and rotate beats, and the stage point they scale around so the window chrome stays in frame.
- `take`: path, frame count, duration and pixel size of the Simulator recording. If you swap the take, delete `frames/` and update `frameCount` (`duration * 30`) and `width/height`.
- `focus`: detail-panel crop keyframes in take time (`t` seconds into the take, `cx/cy/w` as fractions of the source frame, `tr` travel time).
- `simNotes`: one margin note at a time in take time, each fully clearing before the next.

Motion helpers (`easeOut`, `easeInOut`, `seg`) and layout constants such as `layout.marginX` (left edge of the reserved right margin) are also in the source; primary moves are 350 to 700 ms, children shorter, nothing linear or bouncy.

## Checks

```sh
npm run check   # syntax check for render.mjs and config.js
ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate,pix_fmt out/margin-notes.mp4
```
