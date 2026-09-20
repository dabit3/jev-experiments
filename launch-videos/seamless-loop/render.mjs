// Renders index.html frame by frame with Puppeteer and encodes the MP4 with ffmpeg.
// Usage: node render.mjs [--skip-extract] [--frames-only] [--start N] [--end N]
import puppeteer from "puppeteer";
import { execFileSync } from "node:child_process";
import { mkdirSync, existsSync, readdirSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const RECORDING = path.join(here, "recording", "silverroom-simulator-take.mp4");
const FRAMES_DIR = path.join(here, "frames");      // extracted take frames (30 fps, 2x phone screen size)
const OUT_DIR = path.join(here, "out");            // rendered composition frames
const OUT_MP4 = path.join(here, "seamless-loop.mp4");
const FPS = 30;

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n, d) => (args.includes(n) ? Number(args[args.indexOf(n) + 1]) : d);

if (!flag("--skip-extract") || !existsSync(FRAMES_DIR)) {
  rmSync(FRAMES_DIR, { recursive: true, force: true });
  mkdirSync(FRAMES_DIR, { recursive: true });
  // Constant 30 fps JPEG sequence of the raw take. No trimming, speed or color changes.
  execFileSync("ffmpeg", ["-v", "error", "-y", "-i", RECORDING, "-vf", `fps=${FPS},scale=754:1640:flags=lanczos`, "-start_number", "0", "-q:v", "2", path.join(FRAMES_DIR, "%05d.jpg")], { stdio: "inherit" });
  console.log("extracted", readdirSync(FRAMES_DIR).length, "take frames");
}

mkdirSync(OUT_DIR, { recursive: true });
const browser = await puppeteer.launch({ headless: true, args: ["--force-device-scale-factor=1", "--hide-scrollbars", "--disable-lcd-text", "--font-render-hinting=none"] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "index.html"), { waitUntil: "load" });
await page.evaluate(() => document.fonts.ready);
const { FRAMES, T } = await page.evaluate(() => ({ FRAMES: window.COMP.FRAMES, T: window.COMP.T }));
const start = opt("--start", 0), end = opt("--end", FRAMES - 1);
console.log(`rendering frames ${start}..${end} of ${FRAMES} (T=${T}s)`);

for (let i = start; i <= end; i++) {
  const t = i / FPS;
  await page.evaluate(async (t) => { await window.COMP.render(t); await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))); }, t);
  await page.screenshot({ path: path.join(OUT_DIR, `${String(i).padStart(5, "0")}.png`), type: "png", clip: { x: 0, y: 0, width: 1920, height: 1080 } });
  if (i % 60 === 0) console.log("frame", i, `t=${t.toFixed(2)}`);
}
await browser.close();

if (!flag("--frames-only")) {
  // Constant QP with adaptive quantization, mbtree and psy off, plus a forced keyframe on the
  // final frame, so the identical first and last source PNGs also decode to identical pixels.
  const last = readdirSync(OUT_DIR).filter((f) => f.endsWith(".png")).length - 1;
  execFileSync("ffmpeg", ["-v", "error", "-y", "-framerate", String(FPS), "-i", path.join(OUT_DIR, "%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-qp", "15", "-preset", "slow", "-x264-params", "aq-mode=0:mbtree=0:psy-rd=0.0,0.0", "-force_key_frames", `expr:eq(n,${last})`, "-r", String(FPS), "-movflags", "+faststart", OUT_MP4], { stdio: "inherit" });
  console.log("wrote", OUT_MP4);
}
