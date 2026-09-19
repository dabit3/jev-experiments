/* macOS in Devin Cloud: fashion-house hard cuts.
   Everything below `CONFIG` is editable: timings (seconds), copy, media paths, camera poses. */

const CONFIG = {
  fps: 30,
  takeFramesDir: 'take-frames',   // JPEG frames extracted from assets/silverroom-take.mp4 at 30 fps (see prepare.sh)
  takeFrameCount: 451,
  takeIn: 2.1,                    // seconds into the raw take where the demo starts (editor opens right here)

  copy: {
    headline: ['macOS', 'in', 'Devin', 'Cloud'],
    prompt: 'Build Silverroom, a photo darkroom for iPhone with Noir and Silver looks, then test it in the Simulator',
    building: 'Building Silverroom with SwiftUI and Core Image, then running it in the iPhone 17 Pro Simulator.',
    testing: 'Silverroom builds cleanly. Testing the Noir look, exposure, compare and the Frame tools in the Simulator.',
    statusBuilding: 'Devin is writing code',
    statusTesting: 'Devin is testing in the Simulator',
    url: 'devin.ai',
    // test steps that appear in the chat, keyed to raw take time (seconds)
    steps: [
      { take: 2.2, text: 'Opened The cove' },
      { take: 4.2, text: 'Applied the Noir look' },
      { take: 7.1, text: 'Raised exposure' },
      { take: 9.5, text: 'Held compare and released' },
      { take: 12.2, text: 'Rotated the frame' },
      { take: 13.7, text: 'Applied a square crop' },
    ],
  },

  // scene boundaries (video seconds). Each boundary is a hard cut.
  t: {
    title: 0.0,
    select: 2.6,
    compose: 5.2,
    code: 8.6,
    demo: 10.6,       // take plays continuously from here at 1x
    end: 24.3,
    out: 26.5,
  },

  // demo poses, in video seconds (absolute). Camera = focus point in scene px + scale.
  // The Devin shell is 1840x1000 at (40,40); the phone is 380x788 inside the Computer pane. Every pose keeps the
  // phone inside the Devin session: full-pane poses show the tab bar, sidebar edge and Live bar; detail poses stay
  // inside the phone screen.
  poses: [
    { name: 'looks-detail', start: 10.6, simX: 'right', crop: null,
      cam: { from: { fx: 1627, fy: 728, s: 4.0 }, to: { fx: 1627, fy: 736, s: 4.12 } } },
    { name: 'phone-right-strip', start: 13.0, simX: 'right', crop: 'strip',
      cam: { from: { fx: 980, fy: 532, s: 1.0 }, to: { fx: 1010, fy: 572, s: 1.08 } } },
    { name: 'phone-left-compare', start: 15.5, simX: 'left', crop: 'photo',
      cam: { from: { fx: 940, fy: 532, s: 1.0 }, to: { fx: 930, fy: 560, s: 1.08 } } },
    { name: 'frame-push', start: 18.2, simX: 'left', crop: 'photo', continuous: true, cropOut: 0.5,
      cam: { from: { fx: 930, fy: 560, s: 1.08 }, mid: { fx: 1000, fy: 700, s: 1.7 }, to: { fx: 987, fy: 790, s: 4.0 }, midAt: 0.45 } },
    { name: 'full-phone', start: 22.1, simX: 'center', crop: null, paper: true,
      cam: { from: { fx: 960, fy: 540, s: 1.05 }, to: { fx: 960, fy: 540, s: 1.0 }, settle: 0.9, drift: 0.99 } },
  ],

  // hierarchical motion
  motion: { primary: 0.55, childDelay: 0.15, child: 0.45, push: 0.03 },

  // Simulator window positions inside the Computer pane (pane px, left edge of the 380px phone)
  simLeft: { right: 680, left: 40, center: 363 },
  simTop: 6,

  // enlarged live crops: region of the phone screen in 300x652 units and magnification, placed in pane px
  crops: {
    strip: { x: 0, y: 365, w: 300, h: 183, mag: 2.0, left: 40, top: 420 },
    photo: { x: 24, y: 102, w: 252, h: 176, mag: 2.1, left: 520, top: 260 },
  },

  code: [
    '<span class="k">func</span> <span class="f">filtered</span>(_ source: <span class="t">CIImage</span>, settings raw: <span class="t">EditSettings</span>) -> <span class="t">CIImage</span> {',
    '  <span class="k">let</span> settings = raw.normalized',
    '  <span class="k">var</span> image = source',
    '  <span class="k">if</span> settings.exposure != <span class="n">0</span> {',
    '    image = image.applyingFilter(',
    '      <span class="s">"CIExposureAdjust"</span>, parameters: [kCIInputEVKey: settings.exposure])',
    '  }',
    '  <span class="k">let</span> saturation: <span class="t">Double</span> =',
    '    <span class="k">switch</span> settings.film {',
    '    <span class="k">case</span> .silver, .noir: <span class="n">0</span>',
    '    <span class="k">case</span> .dune: <span class="n">0.82</span>',
    '    <span class="k">case</span> .faded: <span class="n">0.65</span>',
    '    <span class="k">case</span> .original: <span class="n">1</span>',
    '    }',
    '  <span class="k">let</span> filmContrast: <span class="t">Double</span> =',
    '    <span class="k">switch</span> settings.film {',
    '    <span class="k">case</span> .silver: <span class="n">1.04</span>',
    '    <span class="k">case</span> .noir: <span class="n">1.23</span>',
    '    <span class="k">case</span> .dune: <span class="n">1.04</span>',
    '    <span class="k">case</span> .faded: <span class="n">0.89</span>',
    '    <span class="k">case</span> .original: <span class="n">1</span>',
    '    }',
  ],
};

/* ------------------------------------------------------------------ helpers */
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const cubicOut = (x) => 1 - Math.pow(1 - x, 3);
const quadInOut = (x) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2);
const lerp = (a, b, k) => a + (b - a) * k;
// progress 0..1 of an animation starting at `start` lasting `dur`, eased
const prog = (t, start, dur, ease = cubicOut) => ease(clamp01((t - start) / dur));
const $ = (id) => document.getElementById(id);

function enter(el, k, travel = 40, axis = 'y') {
  const d = (1 - k) * travel;
  el.style.opacity = k;
  el.style.transform = axis === 'y' ? `translateY(${d}px)` : `translateX(${d}px)`;
}
function camera(scene, fx, fy, s) {
  scene.querySelector('.cam').style.transform = `translate(${960 - fx * s}px, ${540 - fy * s}px) scale(${s})`;
}
function show(id) {
  document.querySelectorAll('.scene').forEach((s) => s.classList.toggle('on', s.id === id));
}
function pad(n) { return String(n).padStart(4, '0'); }
function takeSrc(takeTime) {
  const idx = Math.max(1, Math.min(CONFIG.takeFrameCount, Math.round(takeTime * CONFIG.fps) + 1));
  return `${CONFIG.takeFramesDir}/${pad(idx)}.jpg`;
}
async function setImg(img, src) {
  if (img.getAttribute('src') !== src) {
    img.src = src;
    try { await img.decode(); } catch (e) { /* ignore */ }
  }
}

/* ------------------------------------------------------------------ scenes */
const M = CONFIG.motion;

function sceneTitle(t) {
  show('s-title');
  const sc = $('s-title');
  const local = t - CONFIG.t.title;
  const dur = CONFIG.t.select - CONFIG.t.title;
  enter(sc.querySelector('.mark'), prog(local, 0, M.primary), 44);
  sc.querySelectorAll('.word').forEach((w, i) => enter(w, prog(local, M.childDelay + i * 0.14, M.primary), 56));
  const s = lerp(1, 1 + M.push, clamp01(local / dur));
  camera(sc, 960, 540, s);
}

function sceneSelect(t) {
  show('s-select');
  const sc = $('s-select');
  const local = t - CONFIG.t.select;
  const dur = CONFIG.t.compose - CONFIG.t.select;
  // shell rises into place
  enter($('sel-composer'), prog(local, 0, M.primary), 70);
  // menu grows from its anchor (top-right at the send chevron)
  const menu = $('sel-menu');
  menu.style.left = '1010px';
  menu.style.top = '566px';
  const mk = prog(local, M.childDelay, M.primary);
  menu.style.opacity = mk;
  menu.style.transform = `scale(${lerp(0.72, 1, mk)}) translateY(${(1 - mk) * -12}px)`;
  ['mi-ubuntu', 'mi-macos', 'mi-windows'].forEach((id, i) => enter($(id), prog(local, 0.30 + i * 0.08, M.child), 16));
  // pointer eases to macOS and selects it
  const pk = prog(local, 0.9, 0.65);
  const px = lerp(1560, 1262, pk);
  const py = lerp(980, 764, pk);
  const press = local >= 1.75 && local < 1.9 ? 0.9 : 1;
  const ptr = $('sel-pointer');
  ptr.style.transform = `translate(${px}px, ${py}px) scale(${press})`;
  const selected = local >= 1.82;
  const hover = local >= 1.5;
  $('mi-macos').classList.toggle('sel', hover);
  $('mi-ubuntu').classList.toggle('sel', false);
  $('mi-ubuntu').querySelector('.check').style.display = selected ? 'none' : 'block';
  $('mi-macos').querySelector('.check').style.display = selected ? 'block' : 'none';
  $('sel-chip-text').textContent = selected ? 'macOS' : 'Ubuntu';
  $('sel-chip-icon').innerHTML = selected ? document.querySelector('#s-compose .chip').innerHTML.split('</svg>')[0] + '</svg>' : '';
  // camera: close detail with a subtle push
  const k = clamp01(local / dur);
  camera(sc, lerp(1300, 1292, k), lerp(700, 712, k), lerp(1.8, 1.8 * (1 + M.push), k));
}

function sceneCompose(t) {
  show('s-compose');
  const sc = $('s-compose');
  const local = t - CONFIG.t.compose;
  const dur = CONFIG.t.code - CONFIG.t.compose;
  enter($('cmp-composer'), prog(local, 0, M.primary), 80);
  enter(sc.querySelector('.lockup'), prog(local, M.childDelay, M.child), 30);
  enter(sc.querySelector('.toggle'), prog(local, M.childDelay, M.child), 30);
  // typing
  const typeStart = 0.55, typeDur = 1.9;
  const n = Math.round(CONFIG.copy.prompt.length * clamp01((local - typeStart) / typeDur));
  const txt = $('cmp-text');
  const caretOn = local < 2.95 && (Math.floor(local * 2.2) % 2 === 0 || (local > typeStart && local < typeStart + typeDur));
  txt.innerHTML = `${CONFIG.copy.prompt.slice(0, n)}<span class="caret" style="opacity:${caretOn ? 1 : 0}"></span>`;
  // send pulses
  const pulse = clamp01((local - 2.55) / 0.34);
  const ps = 1 + 0.14 * Math.sin(pulse * Math.PI);
  $('cmp-send').style.transform = `scale(${ps})`;
  $('cmp-send').style.background = pulse > 0 && pulse < 1 ? '#000' : '#262626';
  // text clears upward
  const clear = prog(local, 2.92, 0.36);
  txt.style.transform = `translateY(${-clear * 70}px)`;
  txt.style.opacity = 1 - clear;
  const k = clamp01(local / dur);
  camera(sc, 960, lerp(478, 462, k), lerp(1.0, 1 + M.push, k));
}

let chatBuilt = false;
function buildChat() {
  if (chatBuilt) return;
  chatBuilt = true;
  $('chat-user').textContent = CONFIG.copy.prompt;
  const steps = $('chat-steps');
  CONFIG.copy.steps.forEach((s) => {
    const d = document.createElement('div');
    d.className = 'step';
    d.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9.5"/><path d="M8 12.5l2.8 2.8L16.5 9"/></svg><span>${s.text}</span>`;
    steps.appendChild(d);
  });
}

function sceneCode(t) {
  show('s-session');
  buildChat();
  const sc = $('s-session');
  const local = t - CONFIG.t.code;
  const dur = CONFIG.t.demo - CONFIG.t.code;
  $('code-pane').style.display = 'block';
  $('desk').style.display = 'none';
  $('live').style.display = 'none';
  $('tab-file').classList.add('on');
  $('tab-computer').classList.remove('on');
  $('chat-devin').textContent = CONFIG.copy.building;
  $('chat-status').querySelector('span').textContent = CONFIG.copy.statusBuilding;
  $('chat-steps').style.display = 'none';
  enter($('shell'), prog(local, 0, M.primary), 60);
  enter($('chat-devin'), prog(local, M.childDelay, M.child), 24);
  // code types on, line by line
  const perLine = 0.06, start = 0.35;
  const lines = CONFIG.code.length;
  const visible = Math.min(lines, Math.floor((local - start) / perLine) + 1);
  let html = '';
  for (let i = 0; i < lines; i++) {
    const k = prog(local, start + i * perLine, 0.28);
    const last = i === visible - 1 && visible < lines;
    html += `<span class="cl" style="opacity:${k};transform:translateX(${(1 - k) * 14}px)">${CONFIG.code[i]}${last ? '<span class="caret"></span>' : ''}</span>`;
  }
  $('code-pre').innerHTML = html;
  const k = clamp01(local / dur);
  camera(sc, lerp(1100, 1094, k), lerp(490, 500, k), lerp(1.2, 1.2 * (1 + M.push), k));
}

function currentPose(t) {
  const ps = CONFIG.poses;
  let i = ps.length - 1;
  while (i > 0 && t < ps[i].start) i--;
  const end = i + 1 < ps.length ? ps[i + 1].start : CONFIG.t.end;
  return { pose: ps[i], end, index: i };
}

async function sceneDemo(t) {
  show('s-session');
  buildChat();
  const sc = $('s-session');
  const takeTime = CONFIG.takeIn + (t - CONFIG.t.demo);
  $('code-pane').style.display = 'none';
  $('desk').style.display = 'block';
  $('live').style.display = 'flex';
  $('tab-file').classList.remove('on');
  $('tab-computer').classList.add('on');
  $('chat-devin').textContent = CONFIG.copy.testing;
  $('chat-devin').style.opacity = 1;
  $('chat-devin').style.transform = 'none';
  $('shell').style.opacity = 1;
  $('shell').style.transform = 'none';
  $('chat-status').querySelector('span').textContent = CONFIG.copy.statusTesting;
  $('chat-steps').style.display = 'block';
  // steps appear as the take reaches them
  const stepEls = $('chat-steps').children;
  CONFIG.copy.steps.forEach((s, i) => {
    const k = prog(takeTime, s.take, M.child);
    stepEls[i].style.display = k > 0 ? 'flex' : 'none';
    enter(stepEls[i], k, 18);
  });
  $('live-fill').style.width = `${(takeTime / 15.04) * 100}%`;

  const { pose, end, index } = currentPose(t);
  const local = t - pose.start;
  const dur = end - pose.start;
  const prev = index > 0 ? CONFIG.poses[index - 1] : null;
  const cutHere = !pose.continuous;   // entrances only on real cuts
  // Simulator window: primary element, enters from the side it sits on
  const sim = $('sim');
  const simLeft = CONFIG.simLeft[pose.simX];
  sim.style.left = `${simLeft}px`;
  sim.style.top = `${CONFIG.simTop}px`;
  sim.style.width = '380px';
  const sk = cutHere ? prog(local, 0, M.primary) : 1;
  const dir = pose.simX === 'left' ? -1 : 1;
  sim.style.opacity = 1;
  sim.style.transform = index === 0 ? 'none' : `translateX(${(1 - sk) * 90 * dir}px)`;
  // enlarged live crop: child element, follows 150 ms later with smaller travel
  const crop = $('crop');
  if (pose.crop) {
    const c = CONFIG.crops[pose.crop];
    crop.style.display = 'block';
    crop.style.left = `${c.left}px`;
    crop.style.top = `${c.top}px`;
    crop.style.width = `${c.w * c.mag}px`;
    crop.style.height = `${c.h * c.mag}px`;
    const img = $('take-b');
    img.style.width = `${300 * c.mag}px`;
    img.style.height = `${652 * c.mag}px`;
    img.style.left = `${-c.x * c.mag}px`;
    img.style.top = `${-c.y * c.mag}px`;
    let ck = cutHere || (prev && prev.crop !== pose.crop) ? prog(local, M.childDelay, M.child) : 1;
    if (pose.cropOut) ck = 1 - prog(local, 0, pose.cropOut);   // child leaves as the camera pushes into the phone
    crop.style.opacity = ck;
    crop.style.transform = `translateX(${(1 - ck) * -40 * dir}px)`;
  } else {
    crop.style.display = 'none';
  }
  // camera
  const c = pose.cam;
  let fx, fy, s;
  if (c.settle) {
    const k1 = prog(local, 0, c.settle);
    const k2 = clamp01((local - c.settle) / Math.max(0.001, dur - c.settle));
    fx = c.to.fx; fy = c.to.fy;
    s = lerp(lerp(c.from.s, c.to.s, k1), c.drift, k1 >= 1 ? k2 : 0);
  } else if (c.mid) {
    const k = clamp01(local / dur);
    if (k < c.midAt) {
      const kk = quadInOut(k / c.midAt);
      fx = lerp(c.from.fx, c.mid.fx, kk); fy = lerp(c.from.fy, c.mid.fy, kk); s = lerp(c.from.s, c.mid.s, kk);
    } else {
      const kk = quadInOut((k - c.midAt) / (1 - c.midAt));
      fx = lerp(c.mid.fx, c.to.fx, kk); fy = lerp(c.mid.fy, c.to.fy, kk); s = lerp(c.mid.s, c.to.s, kk);
    }
  } else {
    const k = clamp01(local / dur);
    const kk = quadInOut(k);
    fx = lerp(c.from.fx, c.to.fx, kk); fy = lerp(c.from.fy, c.to.fy, kk); s = lerp(c.from.s, c.to.s, kk);
  }
  camera(sc, fx, fy, s);
  // frames
  const src = takeSrc(takeTime);
  await Promise.all([setImg($('take-a'), src), pose.crop ? setImg($('take-b'), src) : Promise.resolve()]);
}

function sceneEnd(t) {
  show('s-end');
  const sc = $('s-end');
  const local = t - CONFIG.t.end;
  const dur = CONFIG.t.out - CONFIG.t.end;
  const drift = -14 * clamp01(local / dur);
  const lk = prog(local, 0, M.primary);
  const lock = sc.querySelector('.lockup');
  lock.style.opacity = lk;
  lock.style.transform = `translateY(${(1 - lk) * 56 + drift}px)`;
  const uk = prog(local, M.childDelay, M.primary);
  const url = sc.querySelector('.url');
  url.textContent = CONFIG.copy.url;
  url.style.opacity = uk;
  url.style.transform = `translateY(${(1 - uk) * 36 + drift * 0.7}px)`;
  camera(sc, 960, 540, 1);
}

/* ------------------------------------------------------------------ seek */
window.seek = async function seek(t) {
  const T = CONFIG.t;
  if (t < T.select) sceneTitle(t);
  else if (t < T.compose) sceneSelect(t);
  else if (t < T.code) sceneCompose(t);
  else if (t < T.demo) sceneCode(t);
  else if (t < T.end) await sceneDemo(t);
  else sceneEnd(t);
  await document.fonts.ready;
  return true;
};
window.CONFIG = CONFIG;
window.TOTAL = CONFIG.t.out;

// interactive preview: ?t=12.3 or press keys to scrub
const params = new URLSearchParams(location.search);
if (params.has('t')) seek(parseFloat(params.get('t')));
else if (params.has('play')) {
  const t0 = performance.now();
  (function loop() {
    const t = ((performance.now() - t0) / 1000) % CONFIG.t.out;
    seek(t).then(() => requestAnimationFrame(loop));
  })();
} else seek(0);
