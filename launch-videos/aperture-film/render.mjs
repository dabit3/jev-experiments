// Renders composition/index.html frame by frame to PNG with headless Chrome.
// Usage: node render.mjs [--out frames/out] [--start 0] [--end DURATION] [--every 1] [--times 1.0,2.5]
import puppeteer from "puppeteer";
import { mkdirSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a, i, all) => (a.startsWith("--") ? [a.slice(2), all[i + 1] ?? "true"] : null)).filter(Boolean)
);

const configSrc = readFileSync(resolve(here, "composition/config.js"), "utf8");
const fps = Number(/fps:\s*(\d+)/.exec(configSrc)[1]);
const duration = Number(/duration:\s*([\d.]+)/.exec(configSrc)[1]);

const outDir = resolve(here, args.out ?? "frames/out");
mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  headless: true,
  args: ["--allow-file-access-from-files", "--disable-gpu-vsync", "--font-render-hinting=none", "--hide-scrollbars"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto("file://" + resolve(here, "composition/index.html"), { waitUntil: "load" });
await page.evaluate(() => window.__seek(0));

let times;
if (args.times) {
  times = args.times.split(",").map(Number);
} else {
  const start = Number(args.start ?? 0), end = Number(args.end ?? duration), every = Number(args.every ?? 1);
  times = [];
  for (let i = Math.round(start * fps); i < Math.round(end * fps); i += every) times.push(i / fps);
}

const t0 = Date.now();
for (let i = 0; i < times.length; i++) {
  const t = times[i];
  await page.evaluate((tt) => window.__seek(tt), t);
  const name = args.times ? `t${t.toFixed(2).replace(".", "_")}.png` : `f${String(Math.round(t * fps)).padStart(5, "0")}.png`;
  await page.screenshot({ path: resolve(outDir, name), type: "png", clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  if (i % 60 === 0) process.stdout.write(`\r${i + 1}/${times.length}  ${((Date.now() - t0) / 1000).toFixed(0)}s`);
}
process.stdout.write(`\rrendered ${times.length} frames to ${outDir} in ${((Date.now() - t0) / 1000).toFixed(0)}s\n`);
await browser.close();
