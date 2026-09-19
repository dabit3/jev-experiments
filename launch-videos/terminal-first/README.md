# macOS in Devin Cloud, terminal-first launch video

Dark, terminal-first cinema treatment of the "macOS. Now in Devin Cloud." announcement.
The story: prompt, Devin writes Swift, the real RTX Afterdark build runs in the iOS Simulator
inside a reconstructed Devin session, Devin pauses and resumes the game, delivered.

- Output: `out/macos-in-devin-cloud-terminal-first.mp4` (29 s, 1920x1080, 30 fps, H.264 yuv420p, silent)
- Contact sheet: `out/contact-sheet.png`
- Demo app: `ios-rtx-afterdark` from `dabit3/private-experiments`, built with Xcode 26.6 for the iPhone 17 Simulator (iOS 26.5)

## Footage

`footage/rtx-afterdark-simulator-take.mp4` is the untouched `xcrun simctl io booted recordVideo`
take (38 s, one continuous 1x recording: title, Start Run, driving, Pause run, RESUME, driving).
The Simulator writes a portrait container even when the device is landscape, so `render.mjs`
rotates it upright with `transpose=2` and extracts a 30 fps frame sequence for the segment used
(`MEDIA.footageInSeconds` .. `+ MEDIA.footageSeconds`). Nothing inside the segment is sped up,
cut or recolored.

The "** BUILD SUCCEEDED **" line in the editor view is the genuine result of the `xcodebuild`
run that produced the app for this recording.

## Render

```sh
cd launch-videos/terminal-first
npm install                 # playwright 1.49.1
npx playwright install chromium
npm run render              # footage frames -> build/frames -> out/*.mp4 + contact sheet
```

Options for `node render.mjs`:

- `--skip-footage` reuse the extracted footage frames in `build/footage`
- `--frames-only` render PNG frames without encoding
- `--preview 1.5,8.3,22.8` write single frames at those times to `build/preview`

Requires Node 20+, ffmpeg on PATH, and the Playwright Chromium build.

## What to edit

Everything editable is in `src/config.js`:

- `OUTPUT` size, fps and duration
- `BRAND` dark-field colors, accent, fonts (Inter Tight for UI and headlines, JetBrains Mono only inside the editor view)
- `MEDIA` logo paths and the footage in point / length
- `COPY` headline, session title, typed prompt, Devin plan text, timeline steps, section labels, result line, CTA
- `CODE_LINES` the Swift shown in the editor (real code from `GameSession.swift`)
- `T` every scene timing: caret morph, prompt typing, cursor path, editor, Simulator, result, end card
- `CAMERA` zoom keyframes `[time, centerX, centerY, scale]`

`src/index.html` holds the reconstructed Devin UI (session bar, chat timeline, composer, Changes
editor, Computer pane with Mac desktop, Simulator title and iPhone frame) and the deterministic
`window.seek(t)` renderer that `render.mjs` drives frame by frame.
