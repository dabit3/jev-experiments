// Renders composition/index.html frame by frame to out/frames/*.png with Playwright.
// Usage: node render.mjs [--from 0] [--to 27] [--every 1] [--out out/frames]
import { chromium } from "playwright";
import { mkdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).reduce((acc, a, i, arr) => {
    if (a.startsWith("--")) acc.push([a.slice(2), arr[i + 1]]);
    return acc;
  }, []),
);

const outDir = path.resolve(here, args.out || "out/frames");
mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "composition", "index.html") + "?render=1");
await page.waitForFunction(() => window.CONFIG && window.renderFrame);
const { fps, duration } = await page.evaluate(() => ({ fps: window.CONFIG.fps, duration: window.CONFIG.duration }));

const from = Number(args.from ?? 0);
const to = Number(args.to ?? duration);
const every = Number(args.every ?? 1);
const first = Math.round(from * fps);
const last = Math.min(Math.round(to * fps), Math.round(duration * fps)) - 1;

const started = Date.now();
for (let i = first; i <= last; i += every) {
  const t = i / fps;
  await page.evaluate((tt) => window.renderFrame(tt), t);
  await page.screenshot({ path: path.join(outDir, String(i).padStart(5, "0") + ".png"), type: "png" });
  if (i % 60 === 0) {
    const el = ((Date.now() - started) / 1000).toFixed(0);
    console.log(`frame ${i}/${last} (${t.toFixed(2)}s) ${el}s elapsed`);
  }
}
await browser.close();
console.log(`done: ${Math.floor((last - first) / every) + 1} frames -> ${outDir}`);
