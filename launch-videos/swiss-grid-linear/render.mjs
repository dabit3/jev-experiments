// Renders index.html frame by frame with Playwright (Chromium) to frames/out/%04d.png,
// then encodes out/swiss-grid-linear.mp4 with ffmpeg. Usage: node render.mjs [--still 12.5]
import { chromium } from "playwright";
import { execSync } from "node:child_process";
import { mkdirSync, rmSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const cfgSrc = readFileSync(path.join(here, "config.js"), "utf8");
const fps = Number(/fps:\s*(\d+)/.exec(cfgSrc)[1]);
const duration = Number(/duration:\s*([\d.]+)/.exec(cfgSrc)[1]);
const args = process.argv.slice(2);
const stillIdx = args.indexOf("--still");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "index.html"));
await page.evaluate(() => document.fonts.ready);

async function frame(t, file) {
  await page.evaluate(async (t) => { window.seek(t); await window.ready(); }, t);
  await page.screenshot({ path: file, clip: { x: 0, y: 0, width: 1920, height: 1080 } });
}

if (stillIdx >= 0) {
  const times = args.slice(stillIdx + 1).map(Number);
  mkdirSync(path.join(here, "stills"), { recursive: true });
  for (const t of times) await frame(t, path.join(here, "stills", `still_${t.toFixed(2)}.png`));
  await browser.close();
  process.exit(0);
}

const outDir = path.join(here, "frames", "out");
rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });
const total = Math.round(duration * fps);
const t0 = Date.now();
for (let i = 0; i < total; i++) {
  await frame(i / fps, path.join(outDir, String(i).padStart(4, "0") + ".png"));
  if (i % 60 === 0) console.log(`frame ${i}/${total} ${(Date.now() - t0) / 1000}s`);
}
await browser.close();

mkdirSync(path.join(here, "out"), { recursive: true });
execSync(`ffmpeg -y -v error -framerate ${fps} -i "${outDir}/%04d.png" -c:v libx264 -pix_fmt yuv420p -crf 16 -r ${fps} -movflags +faststart "${path.join(here, "out", "swiss-grid-linear.mp4")}"`, { stdio: "inherit" });
execSync(`ffmpeg -y -v error -i "${path.join(here, "out", "swiss-grid-linear.mp4")}" -vf "fps=1,scale=320:180,tile=6x5,pad=1920:1080:0:90:0x0B0B0D" "${path.join(here, "out", "contact-sheet.png")}"`, { stdio: "inherit" });
console.log("done", path.join(here, "out", "swiss-grid-linear.mp4"));
