// Renders composition/index.html frame by frame with headless Chromium and
// encodes the result with ffmpeg. Usage:
//   node render.mjs frames        extract Simulator frames from the raw take
//   node render.mjs still 12.8    write output/still-12.80.png
//   node render.mjs video         render every frame and encode output/*.mp4
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync, existsSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const compositionUrl = pathToFileURL(resolve(root, 'composition/index.html')).href;
const framesDir = resolve(root, 'media/frames');
const rawTake = resolve(root, 'media/lumen-drift-simulator-take.mp4');
const renderDir = resolve(root, 'output/frames');
const outMp4 = resolve(root, 'output/optical-laboratory.mp4');
const outSheet = resolve(root, 'output/contact-sheet.png');

const { VIDEO } = await import(pathToFileURL(resolve(root, 'composition/config.js')).href);
const ffmpeg = process.env.FFMPEG || 'ffmpeg';

function extractFrames() {
  mkdirSync(framesDir, { recursive: true });
  execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', rawTake, '-vf', `fps=${VIDEO.fps}`, '-q:v', '2', `${framesDir}/f%04d.jpg`], { stdio: 'inherit' });
  console.log(`${readdirSync(framesDir).length} frames in ${framesDir}`);
}

async function openPage() {
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: VIDEO.width, height: VIDEO.height }, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.error('page error:', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.error('console:', m.text()); });
  await page.goto(compositionUrl);
  await page.waitForFunction(() => typeof window.seek === 'function');
  await page.evaluate(() => document.fonts.ready);
  return { browser, page };
}

async function still(t) {
  const { browser, page } = await openPage();
  await page.evaluate((tt) => window.seek(tt), t);
  mkdirSync(resolve(root, 'output'), { recursive: true });
  const file = resolve(root, `output/still-${t.toFixed(2)}.png`);
  await page.screenshot({ path: file });
  console.log(file);
  await browser.close();
}

async function video() {
  if (!existsSync(framesDir) || readdirSync(framesDir).length === 0) extractFrames();
  rmSync(renderDir, { recursive: true, force: true });
  mkdirSync(renderDir, { recursive: true });
  const { browser, page } = await openPage();
  const total = Math.round(VIDEO.duration * VIDEO.fps);
  const started = Date.now();
  for (let i = 0; i < total; i++) {
    await page.evaluate((tt) => window.seek(tt), i / VIDEO.fps);
    await page.screenshot({ path: `${renderDir}/${String(i).padStart(5, '0')}.png` });
    if (i % 60 === 0) console.log(`frame ${i}/${total}  ${((Date.now() - started) / 1000).toFixed(0)}s`);
  }
  await browser.close();
  execFileSync(ffmpeg, [
    '-v', 'error', '-y', '-framerate', String(VIDEO.fps), '-i', `${renderDir}/%05d.png`,
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', '-r', String(VIDEO.fps),
    '-movflags', '+faststart', outMp4,
  ], { stdio: 'inherit' });
  execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', outMp4, '-vf', 'fps=1,scale=320:-1,tile=6x5,pad=1920:1080:0:90:0x0b0d12', '-frames:v', '1', outSheet], { stdio: 'inherit' });
  console.log(outMp4);
  console.log(outSheet);
}

const [cmd, arg] = process.argv.slice(2);
if (cmd === 'frames') extractFrames();
else if (cmd === 'still') await still(parseFloat(arg ?? '12.8'));
else if (cmd === 'video') await video();
else console.log('usage: node render.mjs frames | still <seconds> | video');
