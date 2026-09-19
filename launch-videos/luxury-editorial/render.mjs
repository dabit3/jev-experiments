// Renders index.html frame by frame with Playwright, then encodes with ffmpeg.
// Usage: node render.mjs [--from SEC] [--to SEC] [--stills "1.0,4.2,..."] [--out out/final.mp4]
import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).map((a, i, arr) => (a.startsWith('--') ? [a.slice(2), arr[i + 1] ?? true] : [])).filter((x) => x.length));
const { VIDEO, DURATION } = await import(pathToFileURL(resolve(here, 'config.js')).href);

const framesDir = resolve(here, 'out/frames');
const out = resolve(here, args.out ?? 'out/final.mp4');
mkdirSync(resolve(here, 'out'), { recursive: true });

const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: VIDEO.width, height: VIDEO.height }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(resolve(here, 'index.html')).href + '?render');
await page.evaluate(() => document.fonts.ready);
await page.waitForFunction(() => typeof window.__seek === 'function');

if (args.stills) {
  mkdirSync(resolve(here, 'out/stills'), { recursive: true });
  for (const s of String(args.stills).split(',')) {
    const t = parseFloat(s);
    await page.evaluate((t) => window.__seek(t), t);
    await page.screenshot({ path: resolve(here, `out/stills/t${t.toFixed(2)}.png`) });
    console.log('still', t);
  }
  await browser.close();
  process.exit(0);
}

const from = parseFloat(args.from ?? '0'), to = parseFloat(args.to ?? String(DURATION));
const total = Math.round((to - from) * VIDEO.fps);
rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });
const t0 = Date.now();
for (let i = 0; i < total; i++) {
  const t = from + i / VIDEO.fps;
  await page.evaluate((t) => window.__seek(t), t);
  await page.screenshot({ path: `${framesDir}/${String(i).padStart(5, '0')}.png`, type: 'png' });
  if (i % 60 === 0) console.log(`frame ${i}/${total} t=${t.toFixed(2)} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
}
await browser.close();

const ff = spawnSync('ffmpeg', ['-y', '-framerate', String(VIDEO.fps), '-i', `${framesDir}/%05d.png`,
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', '-r', String(VIDEO.fps), '-movflags', '+faststart', out], { stdio: 'inherit' });
if (ff.status !== 0) process.exit(ff.status ?? 1);
console.log('wrote', out);
