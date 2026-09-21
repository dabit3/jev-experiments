# "@devin !mac, now in Linear": TypeSafe Motion Blueprint launch video

A 28.6 s, 1920x1080, 30 fps silent launch film for the Linear update that makes `@devin !mac` / `!windows` work
from a Linear comment: typing `@devin !mac Build ...` on an issue kicks off a macOS Devin session.

Built from the `../typesafe-blueprint` template (same paper, palette, pixel-block cuts, footage and end card).
The Devin new-session composer and the code-writing beat are replaced by a rebuilt Linear issue page and a minimal
"Devin is building" sequence. Everything on screen is reconstructed HTML/CSS; the only footage is the real
VoxelHearth macOS build on the Mac desktop and the iPhone build in the iOS Simulator (shared with the template).

- `out/linear-mac.mp4` - final render (H.264, yuv420p)
- `out/contact-sheet.png` - 1920x1080 contact sheet (2 fps, 8x7)

## Beats

| time | beat |
| --- | --- |
| 0.0 - 3.0 | title on blueprint paper: centred Devin lockup over `@devin !mac` / "Now in Linear." |
| 3.0 - 9.8 | rebuilt Linear issue page (sidebar, breadcrumb, properties, activity); the comment box is clicked, `@devin` is typed, the mention picker shows **Devin · Agent**, the command `!mac Build VoxelHearth ...` is typed and sent; the comment posts, **Devin** is assigned, a **Devin Session** resource appears and a "Devin started by ... / working" card lands |
| 9.8 - 14.0 | "Devin is building": four stage tiles (Clone / Build macOS / Build iPhone / Run) fill with cobalt pixel blocks in turn, a block progress rail and a mono status line |
| 14.0 - 19.6 | Devin session, Computer tab: iPhone Simulator on the Mac desktop (aperture reveal), two captions, push-in and hold |
| 19.6 - 25.4 | Computer tab: VoxelHearth macOS window, second player visible, session completes, push-in and hold |
| 25.4 - 28.6 | 0.4 s block wipe to black; end card: Devin lockup, `devin.ai`, `@devin !mac · @devin !windows` |

## Render

Requirements: Node 18+, `ffmpeg`, Playwright Chromium. Assets (fonts, logos, desktop, footage frames) are read from
`../typesafe-blueprint/assets`, so run that project's `npm run frames` first if `assets/frames` is missing.

```sh
npm install                 # playwright
npx playwright install chromium
npm run render              # index.html -> out/frames/000000.png ... (858 frames)
npm run encode              # out/frames -> out/linear-mac.mp4 + out/contact-sheet.png
npm run stills -- 3.6,6.5,9.5,12,16,22       # quick checks -> out/stills/tNN.NN.png
```

## What to edit

All constants live in `window.CONFIG` at the top of `index.html`:

- `text.*` - headline, the `mention` / `command` typed into Linear, issue id/title, author name, captions, build stages, end tag.
- `t.*` - every beat's start time (`toLinear`, `clickBox`, `mentionStart`, `pickDevin`, `cmdStart/End`, `send`, `devinStart`,
  `toBuild`, `buildStart` + `buildStage`, `toPhone`, `toMac`, `toBlack`, caption swaps, push-ins).
- `media.*` - asset paths (relative to this folder).

Other knobs: `TR` / `TR_END` and `ORD.*` for the pixel-block cuts; the Linear camera (`camTo(...)` in the LINEAR block,
targets measured from the DOM by `measureLinear()`); Linear layout under `/* Linear reconstruction */`
(`.lin > * { zoom }` scales the whole app); the build tiles under `/* Build scene */`.
