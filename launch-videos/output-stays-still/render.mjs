// Renders index.html frame by frame with Playwright/Chromium and encodes with ffmpeg.
// Usage: node render.mjs            -> out/output-stays-still.mp4
//        node render.mjs --still 12.5  -> out/still-12.50.png (single frame preview)
import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import { mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30;
const DURATION = 27.0;                      // keep in sync with index.html
const OUT_DIR = path.join(here, 'out');
const FRAMES_DIR = path.join(OUT_DIR, 'frames');
const MP4 = path.join(OUT_DIR, 'output-stays-still.mp4');
const SHEET = path.join(OUT_DIR, 'contact-sheet.png');

mkdirSync(FRAMES_DIR, { recursive: true });

// Extract the raw take to JPEG frames once (index.html reads media/frames/NNNN.jpg)
if (!existsSync(path.join(here, 'media/frames/0001.jpg'))) {
  mkdirSync(path.join(here, 'media/frames'), { recursive: true });
  spawnSync('ffmpeg', ['-v', 'error', '-y', '-i', path.join(here, 'media/silverroom-take.mp4'), '-vf', `fps=${FPS}`, '-q:v', '2', path.join(here, 'media/frames/%04d.jpg')], { stdio: 'inherit' });
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto('file://' + path.join(here, 'index.html') + '?t=0');
await page.waitForTimeout(400);

const stillArg = process.argv.indexOf('--still');
if (stillArg > -1) {
  const t = parseFloat(process.argv[stillArg + 1]);
  await page.evaluate(t => window.seek(t), t);
  await page.waitForTimeout(50);
  const p = path.join(OUT_DIR, `still-${t.toFixed(2)}.png`);
  await page.screenshot({ path: p });
  console.log(p);
  await browser.close();
  process.exit(0);
}

const total = Math.round(DURATION * FPS);
for (let f = 0; f < total; f++) {
  await page.evaluate(t => window.seek(t), f / FPS);
  await page.screenshot({ path: path.join(FRAMES_DIR, String(f).padStart(4, '0') + '.png') });
  if (f % 60 === 0) console.log(`frame ${f}/${total}`);
}
await browser.close();

spawnSync('ffmpeg', ['-v', 'error', '-y', '-framerate', String(FPS), '-i', path.join(FRAMES_DIR, '%04d.png'),
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-r', String(FPS), '-movflags', '+faststart', MP4], { stdio: 'inherit' });
spawnSync('ffmpeg', ['-v', 'error', '-y', '-i', MP4, '-vf', 'fps=2,scale=320:-1,tile=6x9:padding=2:margin=2:color=white', '-frames:v', '1', SHEET], { stdio: 'inherit' });
console.log(MP4);
