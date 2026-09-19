// Renders index.html frame by frame with headless Chromium and encodes the MP4.
//   node render.mjs                render everything (frames + encode + contact sheet)
//   node render.mjs --still 12.4   render a single PNG at t=12.4s to out/still.png
//   node render.mjs --range 8 11   render only 8s..11s (encode is skipped)
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const CONFIG = new Function(`${readFileSync(resolve(here, 'config.js'), 'utf8')}; return CONFIG;`)();
const FPS = CONFIG.fps;
const OUT = resolve(here, 'out');
const FRAMES = resolve(here, CONFIG.take.framesDir);

const args = process.argv.slice(2);
const still = args.includes('--still') ? parseFloat(args[args.indexOf('--still') + 1]) : null;
const range = args.includes('--range') ? [parseFloat(args[args.indexOf('--range') + 1]), parseFloat(args[args.indexOf('--range') + 2])] : null;

// 1. extract the genuine Simulator take to JPEG frames (once)
if (!existsSync(FRAMES) || readdirSync(FRAMES).length < CONFIG.take.frameCount) {
  mkdirSync(FRAMES, { recursive: true });
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', resolve(here, CONFIG.take.src),
    '-vf', `fps=${FPS}`, '-q:v', '2', `${FRAMES}/f%04d.jpg`], { stdio: 'inherit' });
}

// 2. render
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(resolve(here, 'index.html')).href);
await page.evaluate(() => document.fonts.ready);
await page.evaluate(() => window.preloadFrames());

if (still !== null) {
  mkdirSync(OUT, { recursive: true });
  const times = args.slice(args.indexOf('--still') + 1).map(parseFloat).filter((x) => !Number.isNaN(x));
  for (const t of times) {
    await page.evaluate((t) => window.seek(t), t);
    await page.screenshot({ path: resolve(OUT, `still-${t.toFixed(2)}.png`), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
    console.log(`wrote out/still-${t.toFixed(2)}.png`);
  }
  await browser.close();
  process.exit(0);
}

const framesOut = resolve(OUT, 'frames');
if (!range) rmSync(framesOut, { recursive: true, force: true });
mkdirSync(framesOut, { recursive: true });
const total = Math.round(CONFIG.duration * FPS);
const from = range ? Math.round(range[0] * FPS) : 0;
const to = range ? Math.round(range[1] * FPS) : total;
const t0 = Date.now();
for (let i = from; i < to; i++) {
  await page.evaluate((t) => window.seek(t), i / FPS);
  await page.screenshot({ path: resolve(framesOut, `${String(i).padStart(5, '0')}.png`), clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  if (i % 60 === 0) console.log(`frame ${i}/${total}  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
}
await browser.close();
if (range) process.exit(0);

// 3. encode + contact sheet
const mp4 = resolve(OUT, 'margin-notes.mp4');
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', `${framesOut}/%05d.png`,
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-r', String(FPS), '-movflags', '+faststart', mp4], { stdio: 'inherit' });
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', mp4, '-vf', 'fps=1.21,scale=320:180,tile=6x6', '-frames:v', '1', '-update', '1',
  resolve(OUT, 'contact-sheet.png')], { stdio: 'inherit' });
console.log(`wrote ${mp4}`);
