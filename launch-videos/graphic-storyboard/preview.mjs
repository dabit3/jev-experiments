// Renders single moments of the composition to out/preview/<t>.png for quick review.
// Usage: node preview.mjs 1.5 4.5 12.8 24
import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(here, "out", "preview");
mkdirSync(outDir, { recursive: true });

const times = process.argv.slice(2).map(Number);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
page.on("console", (m) => console.log("console:", m.text()));
page.on("pageerror", (e) => console.log("pageerror:", e.message));
await page.goto("file://" + path.join(here, "composition", "index.html") + "?render=1");
await page.waitForFunction(() => window.renderFrame);
for (const t of times) {
  await page.evaluate((tt) => window.renderFrame(tt), t);
  await page.screenshot({ path: path.join(outDir, `${t.toFixed(2)}.png`) });
}
await browser.close();
console.log(`wrote ${times.length} previews to ${outDir}`);
