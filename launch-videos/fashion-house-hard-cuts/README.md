# macOS in Devin Cloud: fashion-house hard cuts

Launch video for "macOS in Devin Cloud". Light theme, deliberate poses, hard cuts only.
Demo app: Silverroom (github.com/dabit3/macos-experiments, `silverroom`), recorded for real in the iPhone 17 Pro Simulator.

- `final.mp4` is the rendered video (1920x1080, 30 fps, H.264 yuv420p, 26.5 s, silent).
- `contact-sheet.png` is a 2 fps contact sheet of the final render.
- `assets/silverroom-take.mp4` is the raw, untouched Simulator recording (one continuous take at 1x).

## Render

Requires Node 18+, ffmpeg, and Chromium via Playwright.

```sh
cd launch-videos/fashion-house-hard-cuts
npm install                 # installs playwright
npx playwright install chromium
./prepare.sh                # raw take -> take-frames/NNNN.jpg at 30 fps
node render.js              # index.html -> frames/NNNNN.png (about 2.5 minutes)
ffmpeg -y -framerate 30 -i frames/%05d.png -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30 -movflags +faststart final.mp4
ffmpeg -y -i final.mp4 -vf "fps=2,scale=320:-1,tile=6x9" -frames:v 1 -update 1 contact-sheet.png
```

Preview stills without a full render: `node render.js --at 1.8,4.6,14.2` writes to `preview/`.
Scrub in a browser: open `index.html?t=14.2`, or `index.html?play` for a realtime loop.

## What to edit

Everything tunable lives in `CONFIG` at the top of `composition.js`:

- `t`: scene boundaries in seconds (every boundary is a hard cut). `out` is the total length.
- `takeIn`: where in the raw take the demo starts. The take plays continuously at 1x from `t.demo`.
- `copy`: headline words, the composer request, chat copy, step labels (keyed to raw take seconds), end URL.
- `poses`: the demo poses. Each has a start time, which side the Simulator window sits on (`simX`), which enlarged live crop is shown (`crop`), and a camera path (`from`/`mid`/`to` as focus point in scene px plus scale).
- `crops`: the source rectangle on the 300x652 phone screen and magnification for the enlarged live crops.
- `motion`: primary entry 550 ms, children 150 ms later, 3 percent camera push.
- `code`: the syntax highlighted Swift lines typed in the build pose.

Colors and type are CSS custom properties at the top of `index.html` (`--paper`, `--ink`, `--accent`, `--font`, ...).
Logos live in `assets/` (black on paper, white on the dark end card).

## Recording the take

The Silverroom take was recorded with `xcrun simctl io booted recordVideo --codec h264 --mask ignored` while a small CGEvent
helper drove the Simulator: open The cove, choose Noir, drag exposure, hold compare and release, open Frame, rotate 90, square crop.
