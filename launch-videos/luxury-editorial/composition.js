import { VIDEO, TOKENS, REC, TRANSITION, SCENES, DURATION, COPY, CODE } from './config.js';

// ---------- tokens -> css vars ----------
const root = document.documentElement.style;
root.setProperty('--field', TOKENS.field);
root.setProperty('--ink', TOKENS.ink);
root.setProperty('--ink-muted', TOKENS.inkMuted);
root.setProperty('--ink-faint', TOKENS.inkFaint);
root.setProperty('--hairline', TOKENS.hairline);
root.setProperty('--ui-bg', TOKENS.ui.bg);
root.setProperty('--ui-panel', TOKENS.ui.panel);
root.setProperty('--ui-panel-raised', TOKENS.ui.panelRaised);
root.setProperty('--ui-border', TOKENS.ui.border);
root.setProperty('--ui-text', TOKENS.ui.text);
root.setProperty('--ui-text-muted', TOKENS.ui.textMuted);
root.setProperty('--ui-accent', TOKENS.ui.accent);
root.setProperty('--ui-success', TOKENS.ui.success);
root.setProperty('--font-sans', TOKENS.fontSans);
root.setProperty('--font-mono', TOKENS.fontMono);

// ---------- helpers ----------
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const prog = (t, t0, dur) => clamp((t - t0) / dur);
const easeInOut = (p) => (p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2);
const easeOut = (p) => 1 - Math.pow(1 - p, 4);
const easeIn = (p) => p * p * p;
const lerp = (a, b, p) => a + (b - a) * p;
const $ = (s) => document.querySelector(s);
const IN = 0.6, OUT = 0.6, LEAD = 0.2; // in-transition [start-LEAD, start-LEAD+IN], out [end-LEAD, end-LEAD+OUT]

const pendingImages = new Set();
function setRecFrame(img, recTime) {
  const i = clamp(Math.round((recTime - REC.offset) * REC.fps) + 1, 1, REC.frames);
  const src = `${REC.dir}/${String(i).padStart(4, '0')}.jpg`;
  if (!img.src.endsWith(src)) { img.src = src; pendingImages.add(img); }
}
function riseIn(el, p) { el.style.transform = `translateY(${(1 - p) * 110}%)`; el.style.opacity = String(p > 0 ? 1 : 0); }
function fadeUp(el, p, dy = 24) { el.style.opacity = String(p); el.style.transform = `translateY(${(1 - p) * dy}px)`; }
function wipe(el, pIn, pOut) {
  // reveal from left to right, then exit toward the right
  const r = (1 - pIn) * 100, l = pOut * 100;
  el.style.clipPath = `inset(0 ${r}% 0 ${l}%)`;
}
function spanify(el, text) { el.textContent = text; }

// ---------- static setup ----------
const headline = $('.headline');
headline.innerHTML = COPY.headline.map((l) => `<span class="line"><span>${l}</span></span>`).join('');
spanify($('#prompt-copy .lede .rise'), COPY.promptLede);
spanify($('#code-copy .lede .rise'), COPY.codeLede);
spanify($('#result-copy .lede .rise'), COPY.resultLede);
$('#session-title').textContent = COPY.sessionTitle;
$('#session-prompt').textContent = COPY.prompt;
$('.cta').textContent = COPY.cta;
$('#steps').innerHTML = COPY.steps.map((s) => `<li><span class="mark"></span><span>${s.text}</span></li>`).join('');

// Swift highlighter (small, deterministic)
const KW = /\b(public|static|let|var|func|return|guard|else|enum|struct|import|if|true|false|nil)\b/g;
function highlight(line) {
  const esc = line.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  return esc
    .replace(/\b(\d[\d_]*\.?\d*)\b/g, '<span class="tk-num">$1</span>')
    .replace(KW, '<span class="tk-kw">$1</span>')
    .replace(/\b([A-Z][A-Za-z]+)\b/g, '<span class="tk-ty">$1</span>')
    .replace(/\b([a-z][A-Za-z]*)(?=\()/g, '<span class="tk-fn">$1</span>');
}
$('#code-lines').innerHTML = CODE.map((l) => `<li data-full="${l.replace(/"/g, '&quot;')}"></li>`).join('');
const codeLis = [...document.querySelectorAll('#code-lines li')];
const codeTotal = CODE.reduce((a, l) => a + Math.max(l.length, 1), 0);

// ---------- scenes ----------
const scenes = {};
for (const k of Object.keys(SCENES)) scenes[k] = document.getElementById(`s-${k}`);

function sceneWindow(k, t) {
  const s = SCENES[k];
  const on = t >= s.start - LEAD && t < s.end - LEAD + OUT;
  const pIn = easeInOut(prog(t, s.start - LEAD, IN));
  const pOut = easeInOut(prog(t, s.end - LEAD, OUT));
  // each scene is an opaque spread that sweeps in from the left over the previous one
  scenes[k].style.clipPath = `inset(0 ${(1 - pIn) * 100}% 0 0)`;
  return { on, pIn, pOut, u: t - s.start, s };
}

// 1 cover
function cover(t) {
  const { on, pIn, pOut, u } = sceneWindow('cover', t);
  scenes.cover.classList.toggle('on', on); if (!on) return;
  const img = $('#s-cover .rec');
  setRecFrame(img, SCENES.cover.rec + Math.max(0, u));
  const sc = lerp(2.45, 2.58, easeInOut(prog(u, 0, 3.6)));
  // keep globe centre at (560, 520) inside the 920x1080 crop
  const tx = 560 - REC.globe.x * sc, ty = 520 - REC.globe.y * sc;
  img.style.transform = `translate(${tx}px, ${ty}px) scale(${sc})`;
  wipe($('#s-cover .cover-img'), easeOut(prog(t, 0.0, 0.9)), 0);
  const lines = headline.querySelectorAll('.line > span');
  lines.forEach((el, i) => {
    const p = easeOut(prog(t, 0.25 + i * 0.14, 0.9));
    riseIn(el, p);
    el.style.opacity = String(1 - pOut);
  });
  headline.style.transform = `translateY(${-pOut * 24}px)`;
  const lk = $('#s-cover .lockup');
  lk.style.opacity = String(prog(t, 0.4, 0.6) * (1 - pOut));
}

// 2 prompt
const promptText = $('#prompt-text'), caret = $('#prompt-caret'), cursor = $('#prompt-cursor');
const envPop = $('#env-pop'), envChip = $('#env-chip'), envLabel = $('#env-chip .env-label'), sendBtn = $('#send-btn');
const popItems = [...document.querySelectorAll('.pop-item')];
const wrap = $('#composer-wrap');
const WRAP = { x: 640, y: 256 };      // matches .composer-wrap in styles.css
const ZOOM = { scale: 1.25, at: { x: 700, y: 640 } }; // where the env chip sits while zoomed
let P = null;                          // measured local positions inside composer-wrap
function measurePrompt() {
  wrap.style.transform = 'none';
  envPop.classList.add('on'); envPop.style.transform = 'none';
  const base = wrap.getBoundingClientRect();
  const c = (el) => { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2 - base.left, y: r.top + r.height / 2 - base.top }; };
  P = { chip: c(envChip), mac: c(popItems.find((li) => li.dataset.v === 'macOS')), send: c(sendBtn) };
  P.rest = { x: P.send.x - 30, y: P.send.y + 120 };
  envPop.classList.remove('on');
}
function prompt(t) {
  const { on, pIn, pOut, u } = sceneWindow('prompt', t);
  scenes.prompt.classList.toggle('on', on); if (!on) return;
  measurePrompt(); // every frame: fonts may finish loading after the first layout
  // choreography (scene-local seconds)
  const T = { cursorTo: 0.5, click: 1.15, zoomIn: 1.0, hoverMac: 1.75, pick: 2.25, close: 2.5, zoomOut: 2.55, type0: 3.05, type1: 4.45, send: 4.6 };
  // camera: zoom about the env chip, moving it to ZOOM.at so the composer stays in frame
  const zp = u < T.zoomOut ? easeInOut(prog(u, T.zoomIn, 0.7)) : 1 - easeInOut(prog(u, T.zoomOut, 0.6));
  const z = lerp(1, ZOOM.scale, zp);
  const chipAbs = { x: WRAP.x + P.chip.x, y: WRAP.y + P.chip.y };
  const target = { x: lerp(chipAbs.x, ZOOM.at.x, zp), y: lerp(chipAbs.y, ZOOM.at.y, zp) };
  const tx = target.x - WRAP.x - P.chip.x * z, ty = target.y - WRAP.y - P.chip.y * z;
  wrap.style.transform = `translate(${tx}px, ${ty}px) scale(${z})`;
  const toAbs = (p) => ({ x: WRAP.x + tx + p.x * z, y: WRAP.y + ty + p.y * z });
  // copy
  riseIn($('#prompt-copy .lede .rise'), easeOut(prog(u, 0.2, 0.8)));
  $('#prompt-copy').style.opacity = String((1 - pOut) * (1 - zp));
  // composer wipe in / out
  // cursor path
  let cp;
  if (u < T.cursorTo) cp = P.rest;
  else if (u < T.click) { const p = easeInOut(prog(u, T.cursorTo, T.click - T.cursorTo)); cp = { x: lerp(P.rest.x, P.chip.x, p), y: lerp(P.rest.y, P.chip.y, p) }; }
  else if (u < T.hoverMac + 0.5) { const p = easeInOut(prog(u, T.hoverMac, 0.45)); cp = { x: lerp(P.chip.x, P.mac.x, p), y: lerp(P.chip.y, P.mac.y, p) }; }
  else if (u < T.type0) cp = P.mac;
  else { const p = easeInOut(prog(u, T.type1 - 0.4, 0.5)); cp = { x: lerp(P.mac.x, P.send.x, p), y: lerp(P.mac.y, P.send.y, p) }; }
  const zc = toAbs(cp);
  const press = (u > T.click && u < T.click + 0.12) || (u > T.pick && u < T.pick + 0.12) || (u > T.send && u < T.send + 0.14);
  cursor.style.transform = `translate(${zc.x}px, ${zc.y}px) scale(${press ? 0.86 : 1})`;
  cursor.style.opacity = String(u > T.cursorTo - 0.2 ? prog(u, T.cursorTo - 0.2, 0.3) * (1 - pOut) : 0);
  // popover
  const popOpen = u >= T.click && u < T.close;
  envPop.classList.toggle('on', popOpen);
  if (popOpen) { const p = easeOut(prog(u, T.click, 0.22)); envPop.style.transform = `scale(${lerp(0.94, 1, p)})`; envPop.style.opacity = String(p); }
  envChip.classList.toggle('hot', u >= T.click - 0.15 && u < T.close);
  const picked = u >= T.pick;
  popItems.forEach((li) => {
    li.classList.toggle('sel', li.dataset.v === (picked ? 'macOS' : 'Linux'));
    li.classList.toggle('hover', li.dataset.v === 'macOS' && u >= T.hoverMac + 0.3 && u < T.close);
  });
  envLabel.textContent = picked ? 'macOS' : 'Linux';
  // typing
  const n = Math.round(COPY.prompt.length * prog(u, T.type0, T.type1 - T.type0));
  promptText.textContent = COPY.prompt.slice(0, n);
  caret.style.opacity = String(u > T.type0 - 0.3 && u < T.send + 0.1 ? (Math.floor(u * 2.5) % 2 === 0 || (u > T.type0 && u < T.type1) ? 1 : 0) : 0);
  sendBtn.style.transform = `scale(${u > T.send && u < T.send + 0.18 ? 0.9 : 1})`;
  sendBtn.style.opacity = String(n > 0 ? 1 : 0.35);
}

// 3 code
const EDITOR = { bar: 54, pad: 18, line: 31, minLines: 4 }; // matches .editor-bar / .editor-body / #code-lines
function code(t) {
  const { on, pIn, pOut, u } = sceneWindow('code', t);
  scenes.code.classList.toggle('on', on); if (!on) return;
  riseIn($('#code-copy .lede .rise'), easeOut(prog(u, 0.45, 0.8)));
  $('#code-copy').style.opacity = String(1 - pOut);
  const chars = Math.floor(codeTotal * easeInOut(prog(u, 0.15, 3.0)));
  let acc = 0, curIdx = -1;
  codeLis.forEach((li, i) => {
    const full = CODE[i]; const len = Math.max(full.length, 1);
    const reached = chars >= acc; // line exists once typing has reached it
    const shown = clamp(chars - acc, 0, len); acc += len;
    li.style.visibility = reached ? '' : 'hidden';
    const txt = full.slice(0, shown);
    li.innerHTML = `<span class="code">${highlight(txt) || ' '}</span>`;
    if (shown > 0 && shown < len) curIdx = i; else if (shown === len && curIdx === -1 && chars < codeTotal && i === codeLis.length - 1) curIdx = i;
    li.classList.remove('cur');
  });
  if (curIdx >= 0) codeLis[curIdx].classList.add('cur');
  else if (chars >= codeTotal) codeLis[codeLis.length - 1].classList.add('cur');
  // the panel is sized to the lines written so far and grows from its centre as code arrives
  const visible = codeLis.filter((li) => li.style.visibility !== 'hidden').length;
  const h = EDITOR.bar + EDITOR.pad * 2 + Math.max(visible, EDITOR.minLines) * EDITOR.line;
  const ed = $('#editor');
  ed.style.height = `${h}px`;
  ed.style.top = `${Math.round((VIDEO.height - h) / 2)}px`;
}

// 4 session
const stepLis = [...document.querySelectorAll('#steps li')];
function session(t) {
  const { on, pIn, pOut, u } = sceneWindow('session', t);
  scenes.session.classList.toggle('on', on); if (!on) return;
  const img = $('#session-mac .rec');
  setRecFrame(img, SCENES.session.rec + Math.max(0, u));
  // slow push-in on the desktop capture, drifting toward the Aster mission panel
  const pz = easeInOut(prog(u, 0.4, 7.2));
  const s = 0.76 * lerp(1, 1.14, pz);
  const fx = lerp(REC.width / 2, 900, pz), fy = lerp(REC.height / 2, 620, pz); // focal point, desktop coords
  img.style.transform = `translate(${608 - fx * s}px, ${456 - fy * s}px) scale(${s})`;
  COPY.steps.forEach((s, i) => {
    const li = stepLis[i];
    const p = easeOut(prog(t, s.at, 0.5));
    li.style.opacity = String(p); li.style.transform = `translateY(${(1 - p) * 8}px)`;
    li.classList.toggle('done', t >= s.done);
    li.classList.toggle('active', t >= s.at && t < s.done);
    if (t >= s.at && t < s.done) li.querySelector('.mark').style.transform = `rotate(${(t * 360) % 360}deg)`;
    else li.querySelector('.mark').style.transform = '';
  });
}

// 5 demo
function demo(t) {
  const { on, pIn, pOut, u } = sceneWindow('demo', t);
  scenes.demo.classList.toggle('on', on); if (!on) return;
  const img = $('#demo-rec');
  setRecFrame(img, SCENES.demo.rec + Math.max(0, u));
  // Aster window (1440x960 at 80,80) scaled to full width; drift downward slightly
  const sc = 1920 / REC.win.w;
  const y0 = 108, y1 = 150; // window-space rows scrolled out at start/end
  const yoff = lerp(y0, y1, easeInOut(prog(u, 0, 4.8)));
  img.style.transform = `translate(${-REC.win.x * sc}px, ${-(REC.win.y + yoff) * sc}px) scale(${sc})`;
}

// 6 result
function result(t) {
  const { on, pIn, pOut, u } = sceneWindow('result', t);
  scenes.result.classList.toggle('on', on); if (!on) return;
  const img = $('#result-img .rec');
  setRecFrame(img, SCENES.result.rec + Math.max(0, u));
  // mission panel in desktop capture: roughly x 1275..1500, y 280..700. Show it large.
  const sc = lerp(2.55, 2.45, easeInOut(prog(u, 0, 2.6)));
  const cx = 1348, cy = 470; // panel centre (desktop coords)
  img.style.transform = `translate(${420 - cx * sc}px, ${540 - cy * sc}px) scale(${sc})`;
  riseIn($('#result-copy .lede .rise'), easeOut(prog(u, 0.15, 0.85)));
  $('#result-copy').style.opacity = String(1 - pOut);
}

// 7 close
function close(t) {
  const { on, u } = sceneWindow('close', t);
  scenes.close.classList.toggle('on', on); if (!on) return;
  const lk = $('#s-close .lockup-big'), cta = $('.cta');
  const p = easeOut(prog(u, 0.05, 1.0));
  lk.style.opacity = String(p);
  lk.style.transform = `translate(-50%, -50%) translateY(${(1 - p) * 30}px) scale(${lerp(0.985, 1.0, easeOut(prog(u, 0, 2.2)))})`;
  fadeUp(cta, easeOut(prog(u, 0.45, 0.9)), 18);
}

async function seek(t) {
  cover(t); prompt(t); code(t); session(t); demo(t); result(t); close(t);
  const imgs = [...pendingImages]; pendingImages.clear();
  await Promise.all(imgs.map((img) => img.decode().catch(() => {})));
  await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  return true;
}
window.__seek = seek;
window.__duration = DURATION;
window.__fps = VIDEO.fps;

// preview mode: ?play plays the timeline in real time
if (location.search.includes('play')) {
  const t0 = performance.now();
  const loop = async () => { const t = ((performance.now() - t0) / 1000) % DURATION; await seek(t); requestAnimationFrame(loop); };
  loop();
} else if (location.search.includes('t=')) {
  seek(parseFloat(new URLSearchParams(location.search).get('t')));
} else {
  seek(0);
}
