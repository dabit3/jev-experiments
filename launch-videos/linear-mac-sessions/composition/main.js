import {
  VIDEO, MEDIA, BRAND, LINEAR, TEXT, BUILD, STEPS, TIMING, CAMERA, INSPECTION, FOCUS, CURSOR,
  LAYOUT, LINEAR_LAYOUT,
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
for (const [k, v] of Object.entries(BRAND)) root.setProperty(`--${k}`, v);
for (const [k, v] of Object.entries(LINEAR)) root.setProperty(`--ln${k[0].toUpperCase()}${k.slice(1)}`, v);
root.setProperty('--chatWidth', `${LAYOUT.chatWidth}px`);
root.setProperty('--headerHeight', `${LAYOUT.headerHeight}px`);
root.setProperty('--menuBarHeight', `${LAYOUT.menuBarHeight}px`);
for (const [k, v] of Object.entries(LINEAR_LAYOUT)) root.setProperty(`--ln${k[0].toUpperCase()}${k.slice(1)}`, `${v}px`);
root.setProperty('--inspectionStroke', BRAND.inspectionStroke);
root.setProperty('--inspectionStrokeWidth', `${INSPECTION.strokeWidth}px`);

// ---------------------------------------------------------------- static DOM
$('titleMark').src = MEDIA.avatarWhite;
$('headline').textContent = TEXT.headline;
$('endLockup').src = MEDIA.lockupWhite;
$('endUrl').textContent = TEXT.endUrl;
$('buildMark').src = MEDIA.avatarWhite;
for (const img of document.querySelectorAll('.ln-devin-img')) img.src = MEDIA.avatarWhite;

// Linear
$('lnWsMark').textContent = TEXT.authorInitials;
$('lnWsName').textContent = TEXT.workspace;
$('lnCrumb').textContent = TEXT.breadcrumb;
$('lnCrumbId').textContent = TEXT.issueId;
$('lnCrumbTitle').textContent = TEXT.issueTitle;
$('lnTitle').textContent = TEXT.issueTitle;
$('lnDesc').textContent = TEXT.issueDescription;
$('lnResource').textContent = TEXT.resource;
$('lnCreatedBy').textContent = TEXT.author;
$('lnCommentBy').textContent = TEXT.author;
$('lnCommentMention').textContent = `@${TEXT.mentionName}`;
$('lnCommentText').textContent = TEXT.command;
$('lnStartedName').textContent = TEXT.mentionName;
$('lnStartedBy').textContent = TEXT.startedBy;
$('lnStartedUser').textContent = TEXT.author;
$('lnWorkingText').textContent = TEXT.working;
$('lnPopName').textContent = TEXT.mentionName;
$('lnPopKind').textContent = TEXT.mentionKind;
$('lnPopLabel').textContent = TEXT.mentionLabel;
$('lnChip').textContent = `@${TEXT.mentionName}`;
$('lnPlaceholder').textContent = TEXT.composerPlaceholder;
TEXT.properties.forEach((p, i) => { $(`lnProp${i}`).textContent = p; });
$('lnAssigned').textContent = TEXT.assigned;
$('lnDelegateName').textContent = TEXT.mentionName;
for (const id of ['lnAvatarHead', 'lnAvatarCreated', 'lnAvatarComment', 'lnAvatarAssign']) $(id).textContent = TEXT.authorInitials;
$('lnWorkspaceHead').innerHTML = `Workspace<svg class="ln-ico ln-ico-sm"><use href="#i-down"/></svg>`;
$('lnTeamsHead').innerHTML = `Your teams<svg class="ln-ico ln-ico-sm"><use href="#i-down"/></svg>`;
$('lnTryHead').innerHTML = `Try<svg class="ln-ico ln-ico-sm"><use href="#i-down"/></svg>`;

const NAV_ICONS = { Inbox: 'inbox', 'My issues': 'issues', Reviews: 'reviews', Agent: 'agent', Projects: 'projects', Views: 'views', More: 'more', Home: 'home', Issues: 'issues', 'Import issues': 'issues', 'Invite people': 'plus' };
function navItem(label, opts = {}) {
  const el = document.createElement('div');
  el.className = `ln-nav-item${opts.indent ? ' indent' : ''}${opts.team ? ' ln-team' : ''}`;
  el.innerHTML = `<svg class="ln-ico"><use href="#i-${opts.icon || NAV_ICONS[label] || 'issues'}"/></svg><span>${label}</span>${opts.count ? `<span class="count">${opts.count}</span>` : ''}${opts.team ? '<span class="spacer"></span><svg class="ln-ico ln-ico-sm ln-muted"><use href="#i-down"/></svg>' : ''}`;
  return el;
}
TEXT.sidebar.forEach((l, i) => $('lnNav').appendChild(navItem(l, { count: i === 0 ? '1' : '' })));
TEXT.workspaceItems.forEach((l) => $('lnNavWorkspace').appendChild(navItem(l)));
$('lnNavTeam').appendChild(navItem(TEXT.teamName, { icon: 'team', team: true }));
TEXT.teamItems.forEach((l) => $('lnNavTeam').appendChild(navItem(l, { indent: true })));
['Import issues', 'Invite people'].forEach((l) => $('lnNavTry').appendChild(navItem(l)));
const inboxCount = $('lnNav').querySelector('.count');

// Devin
$('sessionTitle').textContent = TEXT.sessionTitle;
$('sessionSource').textContent = TEXT.sessionSource;
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

const messages = $('messages');
function addMsg(cls, html) {
  const el = document.createElement('div');
  el.className = `msg ${cls}`;
  el.innerHTML = html;
  messages.appendChild(el);
  return el;
}
const userMsg = addMsg('user', `<span class="ln-mention">@${TEXT.mentionName}</span>${TEXT.command}`);
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
$('phoneHome').src = MEDIA.homeScreen;

// Natural heights of the Linear blocks that grow into view.
const growEls = { res: $('lnResources'), comment: $('lnComment'), started: $('lnStarted'), delegate: $('lnDelegate') };
const natural = {};
for (const [k, el] of Object.entries(growEls)) {
  el.style.height = '';
  natural[k] = { h: el.getBoundingClientRect().height, m: parseFloat(getComputedStyle(el).marginTop) };
}
const lnMain = document.querySelector('.ln-main');
const lnBody = document.querySelector('.ln-body');
const lnComposer = $('linearComposer');

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
// Position of a DOM element in its UI layer's 1920x1080 space, measured live
// so it follows growing blocks and scrolling.
function uiCenter(el, dx = 0, dy = 0) {
  const layer = el.closest('.ui-layer');
  const lr = layer.getBoundingClientRect();
  const k = lr.width / VIDEO.width;
  const r = el.getBoundingClientRect();
  return { x: (r.left + r.width / 2 - lr.left) / k + dx, y: (r.top + r.height / 2 - lr.top) / k + dy };
}
function resolveKey(k) {
  if (k.phone) return { ...k, ...phonePoint(k.phone[0], k.phone[1]) };
  if (k.tab !== undefined) return { ...k, ...uiCenter(tabEls[k.tab]) };
  if (k.el) return { ...k, ...uiCenter($(k.el), k.dx, k.dy) };
  return k;
}
function cameraAt(t) {
  let cam = resolveKey(CAMERA[0]);
  for (let i = 1; i < CAMERA.length; i++) {
    const k = resolveKey(CAMERA[i]);
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
function grow(key, t, start, dur = 0.5) {
  const p = easeInOut(prog(t, start, dur));
  const el = growEls[key];
  el.style.height = `${natural[key].h * p}px`;
  el.style.marginTop = `${natural[key].m * p}px`;
  el.style.opacity = easeOut(prog(t, start + dur * 0.3, dur * 0.7));
  return p;
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
  const keys = CURSOR;
  if (t <= keys[0].t) return resolveKey(keys[0]);
  for (let i = 0; i < keys.length - 1; i++) {
    if (t >= keys[i].t && t <= keys[i + 1].t) {
      const a = resolveKey(keys[i]), b = resolveKey(keys[i + 1]);
      const p = easeInOut(prog(t, a.t, b.t - a.t || 1));
      return { x: lerp(a.x, b.x, p), y: lerp(a.y, b.y, p) };
    }
  }
  return resolveKey(keys[keys.length - 1]);
}
function crossfade(container, items, t, fade, cls = '') {
  let idx = -1;
  for (let i = 0; i < items.length; i++) if (t >= items[i].t) idx = i;
  container.innerHTML = '';
  if (idx < 0) return -1;
  const cur = items[idx], prev = idx > 0 ? items[idx - 1] : null;
  const p = easeInOut(prog(t, cur.t, fade));
  const parts = [];
  if (prev && p < 1) parts.push(`<div class="${prev.done ? 'done' : ''}" style="opacity:${(1 - p) * (1 - p)};transform:translateY(${-p * 18}px)">${prev.label || prev.caption}</div>`);
  const q = prev ? p : easeOut(prog(t, cur.t, fade));
  parts.push(`<div class="${cur.done ? 'done' : ''}" style="opacity:${q};transform:translateY(${(1 - q) * 14}px)">${cur.label || cur.caption}</div>`);
  container.innerHTML = parts.join('');
  return idx;
}
const fmtTimer = (s) => `00:${String(Math.max(0, Math.floor(s))).padStart(2, '0')}`;

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

  // ---- Linear content state (before measuring anything)
  const mentionChars = Math.round(prog(t, TIMING.mentionStart, TIMING.mentionEnd - TIMING.mentionStart) * TEXT.mentionQuery.length);
  const selected = t >= TIMING.select;
  const sent = t >= TIMING.send;
  const cmdChars = Math.round(prog(t, TIMING.typeStart, TIMING.typeEnd - TIMING.typeStart) * TEXT.command.length);
  let typed = '';
  if (!sent) typed = selected ? TEXT.command.slice(0, cmdChars) : TEXT.mentionQuery.slice(0, mentionChars);
  $('lnTyped').textContent = typed;
  $('lnChip').style.display = selected && !sent ? 'inline-block' : 'none';
  $('lnPlaceholder').style.display = typed === '' && !(selected && !sent) ? 'inline' : 'none';
  const typingNow = (t >= TIMING.mentionStart && t < TIMING.mentionEnd) || (t >= TIMING.typeStart && t < TIMING.typeEnd);
  const caretOn = !sent && t >= TIMING.linearIn && (typingNow || Math.floor(t * 2) % 2 === 0);
  $('lnCaret').style.opacity = caretOn ? 1 : 0;

  const pop = $('lnPopover');
  const popIn = easeOut(prog(t, TIMING.popoverIn, 0.3));
  const popOut = easeInOut(prog(t, TIMING.select, 0.22));
  pop.style.opacity = popIn * (1 - popOut);
  pop.style.transform = `translateY(${(1 - popIn) * 10 + popOut * 6}px) scale(${0.98 + popIn * 0.02})`;

  grow('comment', t, TIMING.send + 0.05, 0.55);
  grow('started', t, TIMING.started, 0.55);
  grow('res', t, TIMING.resource, 0.6);
  const workIn = easeOut(prog(t, TIMING.working, 0.4));
  $('lnWorking').style.opacity = workIn;
  document.querySelector('.ln-spinner').style.transform = `rotate(${(t * 300) % 360}deg)`;
  $('lnTimer').textContent = fmtTimer(t - TIMING.working);
  const assignP = easeInOut(prog(t, TIMING.assign, 0.45));
  document.querySelector('.ln-assign-empty').style.opacity = 1 - assignP;
  document.querySelector('.ln-assign-full').style.opacity = assignP;
  grow('delegate', t, TIMING.assign + 0.15, 0.45);
  inboxCount.textContent = t >= TIMING.started ? '2' : '1';

  // Auto-scroll the issue column so the composer stays in view (like Linear).
  const kLn = $('linear').getBoundingClientRect().width / VIDEO.width;
  const bodyH = lnBody.getBoundingClientRect().height / kLn;
  const composerBottom = (lnComposer.getBoundingClientRect().bottom - lnMain.getBoundingClientRect().top) / kLn + 36;
  const scroll = Math.max(0, composerBottom - bodyH);
  lnMain.style.transform = `translateY(${-scroll}px)`;

  // ---- Layers and camera
  const linear = $('linear');
  const devin = $('devin');
  const lnIn = easeOut(prog(t, TIMING.linearIn, 0.7));
  const lnOut = easeInOut(prog(t, TIMING.linearOut, 0.7));
  const dvIn = easeOut(prog(t, TIMING.devinIn, 0.7));
  const dvOut = easeInOut(prog(t, TIMING.endIn, 0.8));
  const cam = cameraAt(t);
  const sLn = cam.s * (1 + (1 - lnIn) * 0.03) * (1 + lnOut * 0.03);
  const sDv = cam.s * (1 - (1 - dvIn) * 0.03) * (1 - dvOut * 0.03);
  linear.style.opacity = lnIn * (1 - lnOut);
  linear.style.transform = `translate(${VIDEO.width / 2}px, ${VIDEO.height / 2}px) scale(${sLn}) translate(${-cam.x}px, ${-cam.y}px)`;
  devin.style.opacity = dvIn * (1 - dvOut);
  devin.style.transform = `translate(${VIDEO.width / 2}px, ${VIDEO.height / 2}px) scale(${sDv}) translate(${-cam.x}px, ${-cam.y}px)`;
  linear.style.visibility = lnIn * (1 - lnOut) > 0 ? 'visible' : 'hidden';

  // ---- Devin chat
  reveal(userMsg, t, TIMING.devinIn);
  reveal(replyMsg, t, TIMING.devinIn + 0.25);
  reveal(workedMsg, t, STEPS[0].t - 0.4);
  let lastVisible = -1;
  STEPS.forEach((step, i) => {
    reveal(stepEls[i], t, step.t, 0.4, 8);
    if (t >= step.t) lastVisible = i;
  });
  stepEls.forEach((el, i) => el.classList.toggle('active', i === lastVisible && t < TIMING.finalMessage));
  reveal(finalMsg, t, TIMING.finalMessage);

  // ---- Build view (Progress) and Computer view
  const buildActive = t < TIMING.computerTab;
  tabEls.forEach((el, i) => el.classList.toggle('active', buildActive ? i === 0 : i === 2));
  const buildOut = easeInOut(prog(t, TIMING.computerTab, 0.45));
  const buildView = $('buildView');
  buildView.style.opacity = 1 - buildOut;
  buildView.style.transform = `translateY(${-buildOut * 14}px)`;
  buildView.style.zIndex = buildOut < 1 ? 2 : 0;
  const bIdx = crossfade($('buildStatus'), BUILD, t, 0.4);
  const done = bIdx >= 0 && BUILD[bIdx].done;
  const doneP = done ? easeInOut(prog(t, BUILD[bIdx].t, 0.5)) : 0;
  const arcDeg = lerp(72, 360, doneP);
  const arcColor = done ? BRAND.success : BRAND.text;
  const spin = (t * 150) % 360;
  const arc = $('buildArc');
  const circ = 2 * Math.PI * 82.5;
  arc.setAttribute('stroke', arcColor);
  arc.setAttribute('stroke-dasharray', `${(arcDeg / 360) * circ} ${circ}`);
  arc.setAttribute('transform', `rotate(${spin} 84 84)`);
  const buildStart = BUILD[0].t - 0.3, buildEnd = BUILD[BUILD.length - 1].t + 0.3;
  $('buildFill').style.width = `${easeInOut(prog(t, buildStart, buildEnd - buildStart)) * 100}%`;
  $('buildFill').style.background = done ? BRAND.success : BRAND.text;
  $('computerView').style.opacity = buildOut;
  phoneImg.style.opacity = easeOut(prog(t, TIMING.launch, 0.35));

  // ---- Cursor (stage space)
  const c = uiToStage(cursorAt(t), cam);
  const cursor = $('cursor');
  cursor.style.transform = `translate(${c.x}px, ${c.y}px)`;
  cursor.style.opacity = Math.max(lnIn * (1 - lnOut), dvIn * (1 - dvOut));

  // ---- Simulator frame
  const takeT = t - MEDIA.takeOffset;
  const frame = clamp(Math.round(takeT * VIDEO.fps) + 1, 1, MEDIA.frameCount);
  const src = frameSrc(frame);
  if (src !== loadedSrc) {
    phoneImg.src = src;
    windowImg.src = src;
    await Promise.all([phoneImg.decode(), windowImg.decode()]).catch(() => {});
    loadedSrc = src;
  }

  // ---- Inspection window
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
    const cropW = w * MEDIA.sourceWidth;
    const k = INSPECTION.size / cropW;
    const x0 = cx * MEDIA.sourceWidth - cropW / 2;
    const y0 = cy * MEDIA.sourceHeight - cropW / 2;
    windowImg.style.width = `${MEDIA.sourceWidth * k}px`;
    windowImg.style.height = `${MEDIA.sourceHeight * k}px`;
    windowImg.style.transform = `translate(${-x0 * k}px, ${-y0 * k}px)`;

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

    const fadeP = prog(t, region.t, INSPECTION.fade);
    const parts = [];
    if (prev && fadeP < 1) parts.push(`<div style="position:absolute;opacity:${(1 - fadeP) * winAlpha};transform:translateY(${-fadeP * 10}px)">${prev.caption}</div>`);
    parts.push(`<div style="position:absolute;opacity:${(prev ? fadeP : 1) * winAlpha};transform:translateY(${(1 - (prev ? fadeP : 1)) * 10}px)">${region.caption}</div>`);
    caption.innerHTML = parts.join('');
  }

  // ---- End card
  const end = $('end');
  const eIn = easeOut(prog(t, TIMING.endIn + 0.25, 0.8));
  end.style.opacity = eIn;
  end.style.transform = `translateY(${(1 - eIn) * 18}px) scale(${0.98 + eIn * 0.02 + Math.max(0, t - TIMING.endIn) * 0.006})`;
}

window.seek = seek;
window.VIDEO = VIDEO;

const params = new URLSearchParams(location.search);
const t0 = params.has('t') ? parseFloat(params.get('t')) : 6.0;
document.fonts.ready.then(() => seek(t0));
