// Renders index.html frame by frame with Puppeteer, then encodes with ffmpeg.
// Usage: node render.mjs [--from 0] [--to 28] [--out build/out.mp4] [--sheet]
import puppeteer from "puppeteer";
import { execSync } from "node:child_process";
import { mkdirSync, existsSync, rmSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a, i, arr) => a.startsWith("--") ? [a.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true] : []).filter(Boolean));
const here = resolve(new URL(".", import.meta.url).pathname);
const framesDir = resolve(here, "build/frames");
const out = resolve(here, args.out || "build/anamorphic-alignment.mp4");

if (existsSync(framesDir)) rmSync(framesDir, { recursive: true });
mkdirSync(framesDir, { recursive: true });

const browser = await puppeteer.launch({ headless: true, args: ["--allow-file-access-from-files", "--disable-web-security", "--font-render-hinting=none", "--enable-gpu-rasterization"] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto("file://" + resolve(here, "index.html") + "?t=0", { waitUntil: "networkidle0" });
const { fps, duration } = await page.evaluate(() => ({ fps: window.CONFIG.fps, duration: window.CONFIG.duration }));
const from = parseFloat(args.from ?? 0), to = parseFloat(args.to ?? duration);
const total = Math.round((to - from) * fps);
console.log(`Rendering ${total} frames at ${fps} fps (${from}s to ${to}s)`);
const t0 = Date.now();
for (let i = 0; i < total; i++) {
  const t = from + i / fps;
  await page.evaluate((t) => window.seek(t), t);
  await page.screenshot({ path: `${framesDir}/f${String(i + 1).padStart(5, "0")}.png`, type: "png", clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  if (i % 60 === 0) console.log(`  frame ${i + 1}/${total}  ${((Date.now() - t0) / 1000).toFixed(1)}s`);
}
await browser.close();

execSync(`ffmpeg -v error -y -framerate ${fps} -i "${framesDir}/f%05d.png" -c:v libx264 -pix_fmt yuv420p -crf 16 -r ${fps} -movflags +faststart "${out}"`, { stdio: "inherit" });
console.log("Wrote", out);
if (args.sheet) {
  const sheet = out.replace(/\.mp4$/, "-contact-sheet.png");
  execSync(`ffmpeg -v error -y -i "${out}" -vf "fps=2,scale=320:-1,tile=6x10,scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white" -frames:v 1 -update 1 "${sheet}"`, { stdio: "inherit" });
  console.log("Wrote", sheet);
}
