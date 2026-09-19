# macOS in Devin Cloud, launch video (Shadow-Only Transitions, light mode)

A 28.4 second, 1920x1080, 30 fps H.264 launch video. Every scene change is carried by a soft diagonal shadow from an unseen plane; the interface stays spatially calm underneath it.

Story: shadow reveals the headline -> shadow carries in a reconstructed Devin composer -> environment switches Ubuntu to macOS -> the Lumen Drift request types in and sends -> a Devin session shows Swift being written -> a shadow crossing turns the Changes pane into the Computer pane -> genuine Lumen Drift Simulator footage plays at 1x inside an iPhone frame on Devin's Mac desktop -> a second shadow crossing swaps to a later excerpt of the same take while the phone keeps its crop and anchor -> a final shadow settles into the Devin lockup, and devin.ai.

## Files

- `composition.html` The whole video. All timing, text, media paths, camera keyframes and step copy are constants at the top of the `<script>` block.
- `render.mjs` Playwright renderer. Seeks the composition frame by frame and screenshots to PNG.
- `extract.sh` Cuts the two excerpts of the take into `clipA/` and `clipB/` PNG sequences (30 fps, 540 px wide).
- `footage/lumen-drift-take.mp4` The single continuous iOS Simulator take of real Lumen Drift play, recorded with `xcrun simctl io booted recordVideo` on an iPhone 17 (iOS 26.5) Simulator. Re-encoded with libx264 crf 20 so it fits in the repository; no cuts, no speed change.
- `assets/` Devin lockup and avatar (supplied), plus a wallpaper, menu bar and dock captured from the Mac desktop that ran the Simulator.
- `fonts/` Inter Tight and Inter (NB International Pro is not available on the render machine).
- `shadow-only-launch.mp4` Final render. `contact-sheet.png` 1920x1080 contact sheet of the render.

## Render

```sh
npm install                 # installs playwright
npx playwright install chromium
./extract.sh                # writes clipA/ and clipB/ from footage/lumen-drift-take.mp4
node render.mjs frames      # 852 PNG frames, about 3 minutes
ffmpeg -framerate 30 -i frames/%04d.png -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30 -movflags +faststart shadow-only-launch.mp4
ffmpeg -i shadow-only-launch.mp4 -vf "fps=1.06,scale=320:-1,tile=6x5" contact-sheet-raw.png
```

Preview specific moments without a full render:

```sh
node render.mjs preview --preview 1.6,6.3,9.9,15.0,24.0,27.4
```

## What to edit

All in `composition.html`, top of the script:

- `DURATION`, `FPS`
- `PROMPT` the request typed into the composer
- `CLIPS` frame directories and counts (keep in sync with `extract.sh`)
- `T` every scene time: shadow sweeps (`sweep1..sweep6`), headline build and exit, composer in/out, cursor moves, menu open/pick, typing window, session in/out, code start, clip A/B start, end card
- `STEPS` the Devin timeline entries and when they appear
- `CODE` the Swift shown in the code view
- `CAMERA` scale and focus keyframes for the slow push toward touch points and the pull back before transitions

Colors live in the `:root` CSS variables (`--paper`, `--ink`, `--blue`, and so on); the shadow tint is the gradient in `.shadow`.

## Demo app

Lumen Drift from `github.com/dabit3/macos-experiments` (`lumen-drift/`), built with `Scripts/build.sh` and launched with `Scripts/run.sh <simulator udid>`. The take is one continuous run: title screen, endless mode, lane taps, energy pickups and the game over panel.
