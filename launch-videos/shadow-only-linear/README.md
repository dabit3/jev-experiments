# macOS from Linear, launch video (Shadow-Only Transitions, light mode)

A 29.4 second, 1920x1080, 30 fps H.264 launch video for `@Devin !mac` in Linear. It reuses the shadow-only template from `../shadow-only/` with a softer shadow, a reconstructed Linear issue page instead of the Devin composer, and a minimal "building" state instead of the code editor.

Story: shadow reveals the headline (macOS. Now from Linear.) -> shadow carries in a reconstructed Linear issue -> the cursor clicks the comment box, `@dev` opens the mention menu, Devin is picked -> ` !mac Build Lumen Drift, ...` types in and sends -> the comment posts and Linear shows the "Devin started" activity card -> a shadow carries in the Devin session ("Started from Linear") -> a minimal building animation (rings, progress, file names, then Build succeeded) -> a shadow crossing turns the Changes pane into the Computer pane -> genuine Lumen Drift Simulator footage at 1x inside an iPhone frame on Devin's Mac -> a second shadow swaps to a later excerpt of the same take -> a final shadow settles into the Devin lockup and devin.ai.

## Files

- `composition.html` The whole video. All timing, text, media paths, camera keyframes and step copy are constants at the top of the `<script>` block.
- `render.mjs` Playwright renderer. Seeks the composition frame by frame and screenshots to PNG.
- `extract.sh` Cuts the two excerpts of the take into `clipA/` and `clipB/` PNG sequences (30 fps, 540 px wide).
- `footage/lumen-drift-take.mp4` The single continuous iOS Simulator take of real Lumen Drift play (iPhone 17, iOS 26.5), same take as `../shadow-only/`. No cuts, no speed change.
- `assets/` Devin lockup and avatar (supplied), plus a wallpaper, menu bar and dock captured from the Mac desktop that ran the Simulator.
- `fonts/` Inter Tight and Inter (NB International Pro is not available on the render machine).
- `shadow-only-linear-launch.mp4` Final render. `contact-sheet.png` 1920x1080 contact sheet of the render.

## Render

```sh
npm install                 # installs playwright
npx playwright install chromium
./extract.sh                # writes clipA/ and clipB/ from footage/lumen-drift-take.mp4
node render.mjs frames      # 882 PNG frames, about 3 minutes
ffmpeg -framerate 30 -i frames/%04d.png -c:v libx264 -pix_fmt yuv420p -crf 16 -r 30 -movflags +faststart shadow-only-linear-launch.mp4
ffmpeg -i shadow-only-linear-launch.mp4 -vf "fps=1.02,scale=320:-1,tile=6x5" contact-sheet-raw.png
```

Preview specific moments without a full render:

```sh
node render.mjs preview --preview 1.8,6.3,8.5,10.4,13.4,17.5,24.0,28.6
```

## What to edit

All in `composition.html`, top of the script:

- `DURATION`, `FPS`
- `MENTION_TYPED`, `MENTION`, `REQUEST` what is typed in the Linear comment (`@dev` -> `@Devin` -> ` !mac Build ...`). Swap `!mac` for `!windows` in `REQUEST` and `commentHTML` to show the Windows flow.
- `SCROLL_AFTER_POST` how far the issue scrolls once the comment posts
- `CLIPS` frame directories and counts (keep in sync with `extract.sh`)
- `T` every scene time: shadow sweeps (`sweep1..sweep6`), headline, Linear in/out, cursor moves, mention open/pick, typing windows, send, comment post, Devin card, session in/out, `buildStart`/`buildDone`, clip A/B start, end card
- `FILES` file name pills shown while building, `STEPS` the Devin timeline entries
- `CAMERA` scale and focus keyframes

Colors live in the `:root` CSS variables (`--paper`, `--ink`, `--lin-*` for the Linear palette); the shadow tint is the gradient in `.shadow`.

## Demo app

Lumen Drift from `github.com/dabit3/macos-experiments` (`lumen-drift/`), built with `Scripts/build.sh` and launched with `Scripts/run.sh <simulator udid>`.
