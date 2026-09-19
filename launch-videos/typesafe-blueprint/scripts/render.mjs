// Renders index.html frame by frame to PNG with Playwright (Chromium).
//   node scripts/render.mjs                 -> out/frames/000000.png ... (full film)
//   node scripts/render.mjs --stills 0.5,3.2,8  -> out/stills/t0.50.png ... (quick checks)
import { chromium } from 'playwright';
import { mkdirSync, existsSync, readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const html = readFileSync(resolve(root, 'index.html'), 'utf8');
const cfg = JSON.parse(html.match(/fps:\s*(\d+)/) ? `{"fps":${html.match(/fps:\s*(\d+)/)[1]},"duration":${html.match(/duration:\s*([\d.]+)/)[1]}}` : '{"fps":30,"duration":27.5}');

const args = process.argv.slice(2);
const stillsArg = args.indexOf('--stills');
const stills = stillsArg >= 0 ? args[stillsArg + 1].split(',').map(Number) : null;

const browser = await chromium.launch({ args: ['--font-render-hinting=none', '--force-color-profile=srgb', '--disable-lcd-text'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto('file://' + resolve(root, 'index.html'), { waitUntil: 'load' });
await page.waitForFunction(() => window.READY === true, null, { timeout: 120000 });

async function shot(t, path) {
  await page.evaluate(t => window.seek(t), t);
  await page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
  await page.screenshot({ path, type: 'png', clip: { x: 0, y: 0, width: 1920, height: 1080 } });
}

if (stills) {
  const dir = resolve(root, 'out/stills'); mkdirSync(dir, { recursive: true });
  for (const t of stills) { await shot(t, resolve(dir, `t${t.toFixed(2)}.png`)); }
  console.log('stills ->', dir);
} else {
  const dir = resolve(root, 'out/frames'); mkdirSync(dir, { recursive: true });
  const n = Math.round(cfg.duration * cfg.fps);
  const t0 = Date.now();
  for (let i = 0; i < n; i++) {
    await shot(i / cfg.fps, resolve(dir, String(i).padStart(6, '0') + '.png'));
    if (i % 60 === 0) console.log(`frame ${i}/${n}  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  }
  console.log('frames ->', dir, n);
}
await browser.close();
