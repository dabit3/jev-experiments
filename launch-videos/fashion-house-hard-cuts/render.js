// Renders index.html frame by frame with Playwright (Chromium) to frames/NNNNN.png.
// Usage:
//   node render.js                 render every frame
//   node render.js --at 1.0,12.5   render stills at the given seconds to preview/
//   node render.js --from 10 --to 14
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : def;
};
const FPS = 30;
const url = 'file://' + path.join(__dirname, 'index.html');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  await page.goto(url);
  await page.waitForFunction(() => typeof window.seek === 'function' && document.fonts.status === 'loaded');
  const total = await page.evaluate(() => window.TOTAL);

  if (args.includes('--at')) {
    fs.mkdirSync(path.join(__dirname, 'preview'), { recursive: true });
    for (const s of opt('--at').split(',')) {
      const t = parseFloat(s);
      await page.evaluate((t) => window.seek(t), t);
      await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
      await page.screenshot({ path: path.join(__dirname, 'preview', `t${t.toFixed(2)}.png`) });
      console.log('preview', t);
    }
    await browser.close();
    return;
  }

  const from = parseFloat(opt('--from', '0'));
  const to = parseFloat(opt('--to', String(total)));
  const outDir = path.join(__dirname, 'frames');
  fs.mkdirSync(outDir, { recursive: true });
  const first = Math.round(from * FPS);
  const last = Math.min(Math.round(to * FPS), Math.round(total * FPS)) - 1;
  const started = Date.now();
  for (let f = first; f <= last; f++) {
    const t = f / FPS;
    await page.evaluate((t) => window.seek(t), t);
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    await page.screenshot({ path: path.join(outDir, String(f).padStart(5, '0') + '.png') });
    if (f % 60 === 0) console.log(`frame ${f}/${last} (${((Date.now() - started) / 1000).toFixed(0)}s)`);
  }
  await browser.close();
  console.log('done', last - first + 1, 'frames');
})();
