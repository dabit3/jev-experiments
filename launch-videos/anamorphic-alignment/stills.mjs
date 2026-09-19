// Renders individual timestamps to build/stills/*.png for quick design QA.
// Usage: node stills.mjs 0.4 1.2 2.4 5.9 ...
import puppeteer from "puppeteer";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const here = resolve(new URL(".", import.meta.url).pathname);
const dir = resolve(here, "build/stills");
mkdirSync(dir, { recursive: true });
const times = process.argv.slice(2).map(Number);
const browser = await puppeteer.launch({ headless: true, args: ["--allow-file-access-from-files", "--font-render-hinting=none"] });
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
page.on("pageerror", (e) => console.error("pageerror", e.message));
page.on("console", (m) => { if (m.type() === "error") console.error("console", m.text()); });
await page.goto("file://" + resolve(here, "index.html") + "?t=0", { waitUntil: "networkidle0" });
for (const t of times) {
  await page.evaluate((t) => window.seek(t), t);
  const p = `${dir}/t${t.toFixed(2).replace(".", "_")}.png`;
  await page.screenshot({ path: p, type: "png" });
  console.log(p);
}
await browser.close();
