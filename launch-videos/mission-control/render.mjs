// Renders index.html frame by frame with Playwright and encodes an H.264 MP4 with ffmpeg.
// Usage: node render.mjs [--out out/mission-control.mp4] [--from 0] [--to 28] [--still 12.4]
import { chromium } from "playwright";
import { spawnSync } from "node:child_process";
import { mkdirSync, rmSync, readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).map((a, i, arr) => (a.startsWith("--") ? [a.slice(2), arr[i + 1]] : [])).filter((x) => x.length));

const cfgSrc = readFileSync(path.join(here, "config.js"), "utf8");
const fps = Number(/fps:\s*(\d+)/.exec(cfgSrc)[1]);
const duration = Number(/duration:\s*([\d.]+)/.exec(cfgSrc)[1]);
const width = Number(/width:\s*(\d+)/.exec(cfgSrc)[1]);
const height = Number(/height:\s*(\d+)/.exec(cfgSrc)[1]);

const out = args.out || path.join(here, "out", "mission-control.mp4");
const from = Number(args.from ?? 0);
const to = Number(args.to ?? duration);
const framesDir = path.join(here, "out", "png");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "index.html") + "?headless=1");
await page.evaluate(() => document.fonts.ready);

if (args.still !== undefined) {
  const t = Number(args.still);
  await page.evaluate((t) => window.render(t), t);
  const stillPath = args.out || path.join(here, "out", `still-${t}.png`);
  mkdirSync(path.dirname(stillPath), { recursive: true });
  await page.screenshot({ path: stillPath });
  console.log("wrote", stillPath);
  await browser.close();
  process.exit(0);
}

rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });
const first = Math.round(from * fps);
const last = Math.round(to * fps);
const t0 = Date.now();
for (let f = first; f < last; f++) {
  const t = f / fps;
  await page.evaluate((t) => window.render(t), t);
  await page.screenshot({ path: path.join(framesDir, `${String(f).padStart(5, "0")}.png`) });
  if (f % 60 === 0) console.log(`frame ${f}/${last} (${((Date.now() - t0) / 1000).toFixed(1)}s)`);
}
await browser.close();

mkdirSync(path.dirname(out), { recursive: true });
const ff = spawnSync("ffmpeg", [
  "-y", "-v", "error",
  "-framerate", String(fps), "-start_number", String(first), "-i", path.join(framesDir, "%05d.png"),
  "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-r", String(fps), "-movflags", "+faststart",
  out,
], { stdio: "inherit" });
if (ff.status !== 0) process.exit(ff.status ?? 1);
console.log("wrote", out);
