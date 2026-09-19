#!/usr/bin/env node
// Renders src/index.html frame by frame with Playwright and encodes with ffmpeg.
// Usage: node render.mjs [--frames-only] [--skip-footage] [--preview t1,t2,...]
import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync, existsSync, mkdirSync, rmSync, statSync } from 'node:fs';
import { dirname, join, extname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const { OUTPUT, MEDIA } = await import(join(here, 'src/config.js'));

const RAW_TAKE = join(here, 'footage/rtx-afterdark-simulator-take.mp4');
const BUILD = join(here, 'build');
const FRAMES = join(BUILD, 'frames');
const FOOTAGE = join(BUILD, 'footage');
const OUT_DIR = join(here, 'out');
const OUT_MP4 = join(OUT_DIR, 'macos-in-devin-cloud-terminal-first.mp4');
const OUT_SHEET = join(OUT_DIR, 'contact-sheet.png');

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const previewArg = args.find((a) => a.startsWith('--preview'));
const previewTimes = previewArg ? (previewArg.split('=')[1] || args[args.indexOf(previewArg) + 1]).split(',').map(Number) : null;

function run(cmd, cmdArgs) {
  const r = spawnSync(cmd, cmdArgs, { stdio: 'inherit' });
  if (r.status !== 0) throw new Error(`${cmd} failed (${r.status})`);
}

// 1. Footage: the raw Simulator take is a portrait container holding landscape content,
//    so rotate it upright, trim to the segment used, and extract 30 fps PNG frames.
if (!has('--skip-footage') || !existsSync(FOOTAGE)) {
  rmSync(FOOTAGE, { recursive: true, force: true });
  mkdirSync(FOOTAGE, { recursive: true });
  run('ffmpeg', ['-y', '-v', 'error', '-ss', String(MEDIA.footageInSeconds), '-t', String(MEDIA.footageSeconds), '-i', RAW_TAKE,
    '-vf', `transpose=2,fps=${OUTPUT.fps},scale=1600:-2`, join(FOOTAGE, MEDIA.footageFramePattern)]);
}

// 2. Static server so ES modules and fonts load without file:// restrictions.
const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.ttf': 'font/ttf', '.css': 'text/css' };
const server = createServer((req, res) => {
  const p = resolve(here, '.' + decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(here) || !existsSync(p) || statSync(p).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[extname(p)] || 'application/octet-stream' });
  res.end(readFileSync(p));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/src/index.html`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: OUTPUT.width, height: OUTPUT.height }, deviceScaleFactor: 1 });
page.on('pageerror', (e) => { console.error('page error:', e.message); process.exitCode = 1; });
await page.goto(url, { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);

const total = Math.round(OUTPUT.durationSeconds * OUTPUT.fps);
if (previewTimes) {
  mkdirSync(join(BUILD, 'preview'), { recursive: true });
  for (const t of previewTimes) {
    await page.evaluate((tt) => window.seek(tt), t);
    await page.screenshot({ path: join(BUILD, 'preview', `t${t.toFixed(2)}.png`) });
  }
  console.log(`previews in ${join(BUILD, 'preview')}`);
} else {
  rmSync(FRAMES, { recursive: true, force: true });
  mkdirSync(FRAMES, { recursive: true });
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await page.evaluate((tt) => window.seek(tt), i / OUTPUT.fps);
    await page.screenshot({ path: join(FRAMES, `f${String(i).padStart(5, '0')}.png`) });
    if (i % 60 === 0) console.log(`frame ${i}/${total}`);
  }
  console.log(`rendered ${total} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  if (!has('--frames-only')) {
    mkdirSync(OUT_DIR, { recursive: true });
    run('ffmpeg', ['-y', '-v', 'error', '-framerate', String(OUTPUT.fps), '-i', join(FRAMES, 'f%05d.png'),
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-preset', 'slow', '-r', String(OUTPUT.fps), '-movflags', '+faststart', OUT_MP4]);
    run('ffmpeg', ['-y', '-v', 'error', '-i', OUT_MP4, '-vf', 'fps=1,scale=384:-1,tile=5x6:padding=4:margin=4:color=0x0f0f11,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:0x0f0f11',
      '-frames:v', '1', '-update', '1', OUT_SHEET]);
    console.log(`wrote ${OUT_MP4} and ${OUT_SHEET}`);
  }
}
await browser.close();
server.close();
