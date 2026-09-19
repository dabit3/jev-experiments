// Renders composition.html frame by frame to PNG.
// Usage: node render.mjs [outDir] [--preview t1,t2,...] [--start N --end M]
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const outDir = args.find((a) => !a.startsWith("--")) || path.join(here, "frames");
const previewArg = args.includes("--preview") ? args[args.indexOf("--preview") + 1] : null;
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "composition.html"));
await page.waitForFunction(() => window.ready === true, null, { timeout: 120000 });
const FPS = await page.evaluate(() => FPS);
const DURATION = await page.evaluate(() => DURATION);

if (previewArg) {
  for (const t of previewArg.split(",").map(Number)) {
    await page.evaluate((tt) => seek(tt), t);
    await page.screenshot({ path: path.join(outDir, `t${t.toFixed(2)}.png`) });
  }
} else {
  const total = Math.round(DURATION * FPS);
  const t0 = Date.now();
  for (let i = 0; i < total; i++) {
    await page.evaluate((tt) => seek(tt), i / FPS);
    await page.screenshot({ path: path.join(outDir, `${String(i + 1).padStart(4, "0")}.png`) });
    if (i % 60 === 0) console.log(`frame ${i}/${total} ${(Date.now() - t0) / 1000}s`);
  }
  console.log(`rendered ${total} frames`);
}
await browser.close();
