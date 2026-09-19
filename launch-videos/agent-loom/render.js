// Renders index.html frame by frame with headless Chromium, then encodes with ffmpeg.
// Usage: node render.js [--preview t1,t2,...] [--out final.mp4]
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const preview = opt('--preview', null);
const out = opt('--out', path.join(__dirname, 'out', 'agent-loom.mp4'));
const framesDir = path.join(__dirname, 'out', 'frames');

(async () => {
  const config = require('./config.js');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: config.width, height: config.height }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(__dirname, 'index.html'));
  await page.waitForFunction(() => typeof window.render === 'function');
  await page.evaluate(() => document.fonts.ready);

  async function frame(t, file) {
    await page.evaluate(async (t) => {
      window.render(t);
      await Promise.all([...document.images].map((i) => (i.complete ? Promise.resolve() : new Promise((r) => { i.onload = r; i.onerror = r; }))));
      await Promise.all([...document.images].filter((i) => i.complete && i.naturalWidth).map((i) => i.decode().catch(() => {})));
    }, t);
    await page.screenshot({ path: file, type: 'png', clip: { x: 0, y: 0, width: config.width, height: config.height } });
  }

  fs.mkdirSync(path.join(__dirname, 'out'), { recursive: true });
  if (preview) {
    const dir = path.join(__dirname, 'out', 'preview');
    fs.mkdirSync(dir, { recursive: true });
    for (const s of preview.split(',')) {
      const t = parseFloat(s);
      await frame(t, path.join(dir, `p_${s.replace('.', '_')}.png`));
    }
    await browser.close();
    return;
  }

  fs.rmSync(framesDir, { recursive: true, force: true });
  fs.mkdirSync(framesDir, { recursive: true });
  const total = Math.round(config.duration * config.fps);
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await frame(i / config.fps, path.join(framesDir, `f${String(i).padStart(5, '0')}.png`));
    if (i % 60 === 0) console.log(`frame ${i}/${total} ${(Date.now() - t0) / 1000}s`);
  }
  await browser.close();
  execFileSync('ffmpeg', ['-y', '-framerate', String(config.fps), '-i', path.join(framesDir, 'f%05d.png'),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', '-r', String(config.fps), '-movflags', '+faststart', out], { stdio: 'inherit' });
  console.log('wrote', out);
})();
