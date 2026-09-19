import {
  VIDEO, MEDIA, BRAND, TEXT, STEPS, TIMING, CAMERA, INSPECTION, FOCUS, CURSOR, LAYOUT, CODE,
} from './config.js';

const $ = (id) => document.getElementById(id);
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const prog = (t, start, dur) => clamp((t - start) / dur);
const easeInOut = (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
const easeOut = (x) => 1 - Math.pow(1 - x, 3);
const lerp = (a, b, x) => a + (b - a) * x;
const pad4 = (n) => String(n).padStart(4, '0');
const frameSrc = (i) => `${MEDIA.framesDir}/${MEDIA.framePattern.replace('%04d', pad4(i))}`;

// ---------------------------------------------------------------- brand vars
const root = document.documentElement.style;
for (const [k, v] of Object.entries(BRAND)) {
  if (typeof v === 'string') root.setProperty(`--${k}`, v);
}
for (const [k, v] of Object.entries(BRAND.code)) {
  root.setProperty(`--code${k[0].toUpperCase()}${k.slice(1)}`, v);
}
root.setProperty('--chatWidth', `${LAYOUT.chatWidth}px`);
root.setProperty('--headerHeight', `${LAYOUT.headerHeight}px`);
root.setProperty('--menuBarHeight', `${LAYOUT.menuBarHeight}px`);
root.setProperty('--inspectionStroke', BRAND.inspectionStroke);
root.setProperty('--inspectionStrokeWidth', `${INSPECTION.strokeWidth}px`);

// ---------------------------------------------------------------- static DOM
$('titleMark').src = MEDIA.avatarWhite;
$('headline').textContent = TEXT.headline;
$('endLockup').src = MEDIA.lockupWhite;
$('endUrl').textContent = TEXT.endUrl;
$('sessionTitle').textContent = TEXT.sessionTitle;
$('composerPlaceholder').textContent = TEXT.composerPlaceholder;
$('composerModel').textContent = TEXT.composerModel;
$('codeFile').textContent = TEXT.codeFile;
$('simDevice').textContent = TEXT.simulatorDevice;
$('simOS').textContent = TEXT.simulatorOS;
$('menuClock').textContent = TEXT.menuClock;
$('menuItems').innerHTML = TEXT.menuBar.map((m) => `<span>${m}</span>`).join('');

const tabEls = TEXT.tabs.map((label) => {
  const el = document.createElement('span');
  el.className = 'tab';
  el.innerHTML = `<span class="glyph"></span>${label}`;
  $('tabs').appendChild(el);
  return el;
});

// Chat messages
const messages = $('messages');
function addMsg(cls, html) {
  const el = document.createElement('div');
  el.className = `msg ${cls}`;
  el.innerHTML = html;
  messages.appendChild(el);
  return el;
}
const userMsg = addMsg('user', TEXT.prompt);
const replyMsg = addMsg('devin', TEXT.devinReply);
const workedMsg = addMsg('devin', `<div class="worked"><span class="chev"></span>${TEXT.workedFor}</div>`);
const stepsWrap = document.createElement('div');
stepsWrap.className = 'steps';
workedMsg.appendChild(stepsWrap);
const stepEls = STEPS.map((s) => {
  const el = document.createElement('div');
  el.className = 'step';
  el.innerHTML = `<span class="check"></span><span>${s.label}</span>`;
  stepsWrap.appendChild(el);
  return el;
});
const finalMsg = addMsg('devin', TEXT.devinFinal);

// Code tokens
const KEYWORDS = new Set(['mutating', 'func', 'guard', 'else', 'return', 'self', 'if', 'var', 'let', 'private', 'in']);
function tokenize(src) {
  const re = /(\/\/.*$)|("(?:[^"\\]|\\.)*")|(\b\d+(?:\.\d+)?\b)|(\.[A-Za-z_]\w*)|(\b[A-Za-z_]\w*\b)|(\s+)|(.)/gm;
  const out = [];
  let m;
  while ((m = re.exec(src))) {
    const text = m[0];
    let cls = 'pn';
    if (m[1]) cls = 'cm';
    else if (m[2]) cls = 'str';
    else if (m[3]) cls = 'num';
    else if (m[4]) cls = 'fn';
    else if (m[5]) {
      if (KEYWORDS.has(text)) cls = 'kw';
      else if (/^[A-Z]/.test(text)) cls = 'ty';
      else if (src[re.lastIndex] === '(') cls = 'fn';
      else cls = 'plain';
    } else if (m[6]) cls = 'ws';
    out.push({ text, cls });
  }
  return out;
}
const codeTokens = tokenize(CODE);
const codeLength = CODE.length;
function renderCode(chars, showCaret) {
  let remaining = chars;
  let html = '<span class="ln">1</span>';
  let line = 1;
  for (const tok of codeTokens) {
    if (remaining <= 0) break;
    const text = tok.text.slice(0, remaining);
    remaining -= tok.text.length;
    const parts = text.split('\n');
    parts.forEach((part, i) => {
      if (i > 0) {
        line += 1;
        html += `\n<span class="ln">${line}</span>`;
      }
      if (part) html += tok.cls === 'ws' || tok.cls === 'plain' ? part : `<span class="${tok.cls}">${part}</span>`;
    });
  }
  if (showCaret) html += '<span class="caret-code"></span>';
  $('code').innerHTML = html;
}

// ---------------------------------------------------------------- layout
const screenAspect = MEDIA.sourceHeight / MEDIA.sourceWidth;
const mac = LAYOUT.macScreen;
const macEl = $('macScreen');
macEl.style.left = `${mac.x - LAYOUT.chatWidth}px`;
macEl.style.top = `${mac.y - LAYOUT.headerHeight}px`;
macEl.style.width = `${mac.w}px`;
macEl.style.height = `${mac.h}px`;

const tb = LAYOUT.simToolbar;
const tbEl = $('simToolbar');
tbEl.style.top = `${tb.top}px`;
tbEl.style.width = `${tb.w}px`;
tbEl.style.height = `${tb.h}px`;

const ph = LAYOUT.phone;
const screenW = ph.screenW;
const screenH = Math.round(screenW * screenAspect);
const phoneEl = $('phone');
phoneEl.style.top = `${ph.top}px`;
phoneEl.style.width = `${screenW + ph.bezel * 2}px`;
phoneEl.style.height = `${screenH + ph.bezel * 2}px`;
phoneEl.style.borderRadius = `${ph.radiusOuter}px`;
const screenEl = phoneEl.querySelector('.phone-screen');
screenEl.style.left = `${ph.bezel}px`;
screenEl.style.top = `${ph.bezel}px`;
screenEl.style.width = `${screenW}px`;
screenEl.style.height = `${screenH}px`;
screenEl.style.borderRadius = `${ph.radiusOuter - ph.bezel}px`;

// Simulator screen rectangle in Devin UI coordinates.
const SCREEN = {
  x: mac.x + mac.w / 2 - screenW / 2,
  y: mac.y + ph.top + ph.bezel,
  w: screenW,
  h: screenH,
};
const phonePoint = (nx, ny) => ({ x: SCREEN.x + nx * SCREEN.w, y: SCREEN.y + ny * SCREEN.h });

function elCenter(el, dx = 0, dy = 0) {
  const r = el.getBoundingClientRect();
  return { x: r.left + r.width / 2 + dx, y: r.top + r.height / 2 + dy };
}
const cursorKeys = CURSOR.map((k) => {
  if (k.phone) return { t: k.t, ...phonePoint(k.phone[0], k.phone[1]) };
  if (k.tab !== undefined) return { t: k.t, ...elCenter(tabEls[k.tab]) };
  if (k.el) return { t: k.t, ...elCenter($(k.el), k.dx, k.dy) };
  return k;
});
$('phoneHome').src = MEDIA.homeScreen;

const win = $('window');
win.style.left = `${INSPECTION.left}px`;
win.style.top = `${INSPECTION.top}px`;
win.style.width = `${INSPECTION.size}px`;
win.style.height = `${INSPECTION.size}px`;
const caption = $('caption');
caption.style.left = `${INSPECTION.left}px`;
caption.style.top = `${INSPECTION.captionTop}px`;
caption.style.width = `${INSPECTION.size}px`;
caption.style.fontSize = `${INSPECTION.captionSize}px`;

// ---------------------------------------------------------------- helpers
function cameraAt(t) {
  let cam = CAMERA[0];
  for (let i = 1; i < CAMERA.length; i++) {
    const k = CAMERA[i];
    if (t < k.t - k.ease) break;
    const p = easeInOut(prog(t, k.t - k.ease, k.ease || 1e-6));
    cam = { x: lerp(cam.x, k.x, p), y: lerp(cam.y, k.y, p), s: lerp(cam.s, k.s, p) };
  }
  return cam;
}
function uiToStage(p, cam) {
  return {
    x: VIDEO.width / 2 + (p.x - cam.x) * cam.s,
    y: VIDEO.height / 2 + (p.y - cam.y) * cam.s,
  };
}
function reveal(el, t, start, dur = 0.45, dy = 10) {
  const p = easeOut(prog(t, start, dur));
  el.style.opacity = p;
  el.style.transform = `translateY(${(1 - p) * dy}px)`;
}
function currentFocus(t) {
  let idx = -1;
  for (let i = 0; i < FOCUS.length; i++) if (t >= FOCUS[i].t) idx = i;
  if (idx < 0) return { region: FOCUS[0], prev: null, p: 1 };
  const region = FOCUS[idx];
  const prev = idx > 0 ? FOCUS[idx - 1] : null;
  const p = easeInOut(prog(t, region.t, INSPECTION.moveEase));
  return { region, prev, p, idx };
}
function cursorAt(t) {
  const keys = cursorKeys;
  if (t <= keys[0].t) return keys[0];
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i], b = keys[i + 1];
    if (t >= a.t && t <= b.t) {
      const p = easeInOut(prog(t, a.t, b.t - a.t || 1));
      return { x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p) };
    }
  }
  return keys[keys.length - 1];
}

const phoneImg = $('phoneImg');
const windowImg = $('windowImg');
let loadedSrc = null;

// ---------------------------------------------------------------- seek
async function seek(t) {
  // Title card
  const title = $('title');
  const tIn = easeOut(prog(t, TIMING.titleIn, 0.8));
  const tOut = easeInOut(prog(t, TIMING.titleOut, 0.7));
  title.style.opacity = tIn * (1 - tOut);
  title.style.transform = `translateY(${(1 - tIn) * 26 - t * 3}px) scale(${1 + t * 0.008 + tOut * 0.04})`;

  // Devin UI visibility and field of view
  const devin = $('devin');
  const uiIn = easeOut(prog(t, TIMING.uiIn, 0.7));
  const uiOut = easeInOut(prog(t, TIMING.endIn, 0.8));
  const cam = cameraAt(t);
  const s = cam.s * (1 + (1 - uiIn) * 0.03) * (1 - uiOut * 0.03);
  devin.style.opacity = uiIn * (1 - uiOut);
  devin.style.transform =
    `translate(${VIDEO.width / 2}px, ${VIDEO.height / 2}px) scale(${s}) translate(${-cam.x}px, ${-cam.y}px)`;

  // Composer typing
  const typing = prog(t, TIMING.typeStart, TIMING.typeEnd - TIMING.typeStart);
  const sent = t >= TIMING.send;
  const chars = sent ? 0 : Math.round(typing * TEXT.prompt.length);
  $('composerText').textContent = TEXT.prompt.slice(0, chars);
  $('composerPlaceholder').style.display = chars === 0 ? 'inline' : 'none';
  const caretOn = !sent && (typing > 0 && typing < 1 ? true : Math.floor(t * 2) % 2 === 0);
  $('caret').style.opacity = caretOn ? 1 : 0;

  // Messages and steps
  reveal(userMsg, t, TIMING.send);
  reveal(replyMsg, t, TIMING.reply);
  reveal(workedMsg, t, STEPS[0].t - 0.5);
  let lastVisible = -1;
  STEPS.forEach((step, i) => {
    reveal(stepEls[i], t, step.t, 0.4, 8);
    if (t >= step.t) lastVisible = i;
  });
  stepEls.forEach((el, i) => el.classList.toggle('active', i === lastVisible && t < TIMING.finalMessage));
  reveal(finalMsg, t, TIMING.finalMessage);

  // Tabs and pane views
  const codeActive = t >= TIMING.changesTab && t < TIMING.computerTab;
  tabEls.forEach((el, i) => el.classList.toggle('active', codeActive ? i === 1 : i === 2));
  const codeIn = easeOut(prog(t, TIMING.changesTab, 0.4));
  const codeOut = easeInOut(prog(t, TIMING.computerTab, 0.4));
  const codeView = $('codeView');
  codeView.style.opacity = codeIn * (1 - codeOut);
  codeView.style.transform = `translateY(${(1 - codeIn) * 14}px)`;
  codeView.style.zIndex = codeIn > 0 && codeOut < 1 ? 2 : 0;
  const typedCode = Math.round(prog(t, TIMING.codeStart, TIMING.codeEnd - TIMING.codeStart) * codeLength);
  renderCode(typedCode, t >= TIMING.codeStart && t < TIMING.codeEnd + 0.4);

  $('computerView').style.opacity = 1 - codeIn * (1 - codeOut);
  phoneImg.style.opacity = easeOut(prog(t, TIMING.launch, 0.35));

  // Cursor
  const c = cursorAt(t);
  $('cursor').style.transform = `translate(${c.x}px, ${c.y}px) scale(${1 / cam.s})`;

  // Simulator frame
  const takeT = t - MEDIA.takeOffset;
  const frame = clamp(Math.round(takeT * VIDEO.fps) + 1, 1, MEDIA.frameCount);
  const src = frameSrc(frame);
  if (src !== loadedSrc) {
    phoneImg.src = src;
    windowImg.src = src;
    await Promise.all([phoneImg.decode(), windowImg.decode()]).catch(() => {});
    loadedSrc = src;
  }

  // Inspection window
  const winIn = easeOut(prog(t, TIMING.windowIn, 0.5));
  const winOut = easeInOut(prog(t, TIMING.windowOut, 0.5));
  const winAlpha = winIn * (1 - winOut);
  win.style.opacity = winAlpha;
  win.style.transform = `translateX(${(1 - winIn) * 24}px)`;
  const overlay = $('overlay');
  overlay.innerHTML = '';
  caption.innerHTML = '';
  if (winAlpha > 0) {
    const { region, prev, p } = currentFocus(t);
    const from = prev || region;
    const cx = lerp(from.cx, region.cx, p);
    const cy = lerp(from.cy, region.cy, p);
    const w = lerp(from.w, region.w, p);
    // Crop in source pixels (square) and the window's magnified image
    const cropW = w * MEDIA.sourceWidth;
    const k = INSPECTION.size / cropW;
    const x0 = cx * MEDIA.sourceWidth - cropW / 2;
    const y0 = cy * MEDIA.sourceHeight - cropW / 2;
    windowImg.style.width = `${MEDIA.sourceWidth * k}px`;
    windowImg.style.height = `${MEDIA.sourceHeight * k}px`;
    windowImg.style.transform = `translate(${-x0 * k}px, ${-y0 * k}px)`;

    // Focus rectangle on the phone screen (stage coordinates) and leader line
    const nx = w, ny = (w * MEDIA.sourceWidth) / MEDIA.sourceHeight;
    const a = uiToStage(phonePoint(cx - nx / 2, cy - ny / 2), cam);
    const b = uiToStage(phonePoint(cx + nx / 2, cy + ny / 2), cam);
    const wx = INSPECTION.left;
    const wy = INSPECTION.top + INSPECTION.size / 2;
    const rectMidY = (a.y + b.y) / 2;
    overlay.innerHTML = `
      <rect x="${a.x}" y="${a.y}" width="${b.x - a.x}" height="${b.y - a.y}" fill="none"
        stroke="${BRAND.inspectionStroke}" stroke-width="${INSPECTION.strokeWidth}" opacity="${winAlpha}" />
      <path d="M ${wx} ${wy} H ${(wx + b.x) / 2} V ${rectMidY} H ${b.x}" fill="none"
        stroke="${BRAND.inspectionLeader}" stroke-width="2" opacity="${winAlpha}" />`;

    // Captions in the margin: crossfade between regions
    const fadeP = prog(t, region.t, INSPECTION.fade);
    const parts = [];
    if (prev && fadeP < 1) parts.push(`<div style="position:absolute;opacity:${(1 - fadeP) * winAlpha};transform:translateY(${-fadeP * 10}px)">${prev.caption}</div>`);
    parts.push(`<div style="position:absolute;opacity:${(prev ? fadeP : 1) * winAlpha};transform:translateY(${(1 - (prev ? fadeP : 1)) * 10}px)">${region.caption}</div>`);
    caption.innerHTML = parts.join('');
  }

  // End card
  const end = $('end');
  const eIn = easeOut(prog(t, TIMING.endIn + 0.25, 0.8));
  end.style.opacity = eIn;
  end.style.transform = `translateY(${(1 - eIn) * 18}px) scale(${0.98 + eIn * 0.02 + Math.max(0, t - TIMING.endIn) * 0.006})`;
}

window.seek = seek;
window.VIDEO = VIDEO;

const params = new URLSearchParams(location.search);
const t0 = params.has('t') ? parseFloat(params.get('t')) : 12.8;
document.fonts.ready.then(() => seek(t0));
