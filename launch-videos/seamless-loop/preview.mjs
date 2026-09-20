// Renders a handful of composition times to preview/ for quick visual checks.
// Usage: node preview.mjs 0 1.2 3.5 ...
import puppeteer from "puppeteer";
import { mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const times = process.argv.slice(2).map(Number);
mkdirSync(path.join(here, "preview"), { recursive: true });
const browser = await puppeteer.launch({ headless: true, args: ["--force-device-scale-factor=1", "--hide-scrollbars"] });
const page = await browser.newPage();
page.on("pageerror", (e) => console.error("pageerror", e.message));
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto("file://" + path.join(here, "index.html"), { waitUntil: "load" });
await page.evaluate(() => document.fonts.ready);
for (const t of times) {
  await page.evaluate(async (t) => { await window.COMP.render(t); await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))); }, t);
  await page.screenshot({ path: path.join(here, "preview", `t${t.toFixed(2)}.png`), type: "png" });
}
await browser.close();
