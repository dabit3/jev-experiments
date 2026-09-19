# Anamorphic Alignment: "macOS. Now in Devin Cloud."

Launch video for macOS in Devin Cloud, direction 9 (Anamorphic Alignment), light mode.
28 s, 1920x1080, 30 fps, H.264 yuv420p, silent.

- `anamorphic-alignment.mp4`: final render
- `anamorphic-alignment-contact-sheet.png`: 2 fps contact sheet of the render
- `footage/rtx-afterdark-simulator-raw.mp4`: the raw, uncut iPhone 17 Simulator take (39 s, 60 fps, `xcrun simctl io booted recordVideo`) of RTX Afterdark: title, driving, pause, resume

## Story

1. 0.0 to 4.5 s: fragments of the two title lines and thin planes sit oblique in paper space; a camera path cascades them into alignment (primary strips first, side planes 220 ms later) into "macOS. Now in Devin Cloud." inside a thin accent rectangle. The title lifts out as the product frame arrives.
2. 4.5 to 10 s: reconstructed Devin composer. Header, then composer, environment selector opens, hosted macOS submenu, cursor picks iOS Simulator, chip swaps Ubuntu to macOS, the RTX request is typed with a caret, send arms and is pressed.
3. 10 to 11.6 s: session view, Devin writes `GameSession.swift` (pause / resume / menu) in a highlighted code pane.
4. 11.6 to 26.1 s: the Simulator tab fills the pane with the genuine recording at 1x inside an iPhone frame. Framing keyframes move the whole frame only (push toward the pause tap, then toward resume, settle back). Native pixels are never altered.
5. 26.1 to 28 s: a dark plane wipes in behind the leaving frame; the Devin lockup and `devin.ai` resolve through a second alignment and drift to the close.

## Render

Requirements: Node 20+, ffmpeg, a Chrome that Puppeteer can download.

```sh
npm install
./extract-footage.sh      # raw take -> build/footage/f0001.jpg ... (30 fps, rotated to landscape)
node render.mjs --sheet   # -> build/anamorphic-alignment.mp4 and the contact sheet
```

Options: `node render.mjs --from 5 --to 12 --out build/part.mp4` renders a range.
`node stills.mjs 2.4 6.9 20.5` writes single frames to `build/stills/` for quick checks.

## Editable constants

Everything lives at the top of the `<script>` in `index.html`:

- `CONFIG`: every keyframe time in seconds (`alignStart`, `frameIn`, `typeStart`, `sendClick`, `footageStart`, `pauseAt`, `resumeAt`, `darkWipe`, ...), `prompt` text, `footageDir` and `footageFrames`.
- `ease()`: the single fast-out gentle-in curve used for every move.
- `SCATTER` / `END_SCATTER`: the pre-alignment offsets and rotations for the title and end-card planes.
- `keys` inside `renderFrame()`: the framing pushes around the Simulator footage as `[time, scale, originX, originY]`.
- CSS variables in `:root`: paper, ink, accent (`#2200ff`) and muted colours taken from the Devin Figma palette.
- `steps` inside `renderSession()` and `CODE_LINES`: the timeline messages and the Swift shown in the code pane.

Footage window: `extract-footage.sh` `START` (seconds into the raw take) and `FRAMES` must agree with `CONFIG.footageFrames`, `pauseAt` and `resumeAt`.

## Provenance

- Devin UI (composer, environment selector, session view, code pane) is reconstructed in HTML/CSS from reference screenshots; no reference video is used as footage.
- Fonts: Inter Tight for display, Inter for UI text, SF Mono / Menlo only inside the code pane.
- Logos: supplied Devin lockups and avatar marks in `assets/logo/`.
- App: `ios-rtx-afterdark` from `dabit3/private-experiments`, built with Xcode 26.6 for the iPhone 17 Simulator (iOS 26.5) and played for real; the recording is a single continuous take with no speed changes or cuts inside the used window.
