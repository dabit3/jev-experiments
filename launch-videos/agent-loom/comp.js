// Deterministic renderer: window.render(t) lays out every frame from the master time t.
(function () {
  const C = CONFIG, T = C.t, L = C.layout, X = C.text;
  const $ = (id) => document.getElementById(id);
  const clamp01 = (v) => Math.max(0, Math.min(1, v));
  const seg = (t, a, d) => clamp01((t - a) / d);
  const lerp = (a, b, k) => a + (b - a) * k;
  const easeOutQuint = (k) => 1 - Math.pow(1 - k, 5);
  const easeOutCubic = (k) => 1 - Math.pow(1 - k, 3);
  const easeInOutCubic = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
  const easeInCubic = (k) => k * k * k;
  const smooth = (k) => k * k * (3 - 2 * k);

  // ---------- build static DOM ----------
  function words(el, text) {
    el.innerHTML = '';
    return text.split(' ').map((w) => { const s = document.createElement('span'); s.className = 'w'; s.textContent = w; el.appendChild(s); return s; });
  }
  const hlWords = [...words($('hl1'), X.headline1), ...words($('hl2'), X.headline2)];

  const comp = $('composer');
  comp.style.left = L.composer.left + 'px'; comp.style.top = L.composer.top + 'px'; comp.style.width = L.composer.width + 'px';
  const cParts = comp.querySelectorAll('.c-part');

  const sess = $('session');
  sess.style.left = L.session.left + 'px'; sess.style.top = L.session.top + 'px';
  sess.style.width = L.session.width + 'px'; sess.style.height = L.session.height + 'px';

  $('uMsg1').textContent = X.silverRequest;
  $('uMsg2').textContent = X.rtxRequest;
  $('dMsg1').querySelector('div').textContent = X.devin1;
  $('dMsg2').querySelector('div').textContent = X.devin2;
  function buildSteps(container, list) {
    return list.map(([time, label]) => {
      const d = document.createElement('div'); d.className = 'step';
      d.innerHTML = '<svg viewBox="0 0 24 24"><path d="M5 12l5 5 9-10"/></svg><span></span>';
      d.querySelector('span').textContent = label; container.appendChild(d);
      return { time, el: d };
    });
  }
  const steps1 = buildSteps($('steps1'), X.steps1);
  const steps2 = buildSteps($('steps2'), X.steps2);
  $('hostedLabel').textContent = X.hostedBefore;
  $('outText').textContent = X.outcome;
  $('url').textContent = X.url;
  $('lockup').src = C.media.lockup;
  document.querySelector('.e-tab').textContent = X.codeFile;

  // Code: flatten into chars with classes.
  const codeChars = [];
  C.code.forEach((tok) => {
    if (tok[0] === 'nl') { codeChars.push(['nl', '\n']); return; }
    for (const ch of tok[1]) codeChars.push([tok[0], ch]);
  });
  function renderCode(n) {
    let html = '', cur = null, buf = '';
    const flush = () => { if (buf) { html += cur === 'op' || cur === 'nl' ? esc(buf) : `<span class="${cur}">${esc(buf)}</span>`; buf = ''; } };
    for (let i = 0; i < n && i < codeChars.length; i++) {
      const [cls, ch] = codeChars[i];
      const c2 = cls === 'nl' ? 'op' : cls;
      if (c2 !== cur) { flush(); cur = c2; }
      buf += ch;
    }
    flush();
    $('code').innerHTML = html + '<span class="caret"></span>';
  }
  const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

  // Preload frames.
  const pad = (n) => String(n).padStart(4, '0');
  const silverSrc = (i) => `${C.media.silverDir}f${pad(Math.min(Math.max(i, 1), C.media.silverFrames))}.jpg`;
  const rtxSrc = (i) => `${C.media.rtxDir}f${pad(Math.min(Math.max(i, 1), C.media.rtxFrames))}.jpg`;
  $('outSilver').src = silverSrc(C.media.silverFrames);
  $('outRtx').src = rtxSrc(C.media.rtxFrames);

  // Weave geometry.
  const W = L.weave;
  const ws = $('weaveSvg');
  const NS = 'http://www.w3.org/2000/svg';
  const mk = (tag, attrs) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); ws.appendChild(e); return e; };
  const leadBlue = mk('path', { d: `M -40 120 C 200 140, 240 ${W.y0 - 20}, ${W.x0} ${W.y0}`, fill: 'none', stroke: C.colors.blue, 'stroke-width': W.stroke, 'stroke-linecap': 'round' });
  const leadInk = mk('path', { d: `M 1960 120 C 1700 140, 1680 ${W.y0 - 20}, ${W.x1} ${W.y0}`, fill: 'none', stroke: C.colors.ink, 'stroke-width': W.stroke, 'stroke-linecap': 'round' });
  const hStr = [], vStr = [], overSegs = [];
  const hy = []; for (let y = W.y0; y <= W.y1 + 0.1; y += W.stepY) hy.push(y);
  const vx = []; for (let x = W.x0; x <= W.x1 + 0.1; x += W.stepX) vx.push(x);
  hy.forEach((y) => hStr.push(mk('line', { x1: W.x0, y1: y, x2: W.x1, y2: y, stroke: C.colors.blue, 'stroke-width': W.stroke, 'stroke-linecap': 'round' })));
  vx.forEach((x) => vStr.push(mk('line', { x1: x, y1: W.y0, x2: x, y2: W.y1, stroke: C.colors.ink, 'stroke-width': W.stroke, 'stroke-linecap': 'round' })));
  const half = W.cross;
  hy.forEach((y, j) => vx.forEach((x, i) => {
    if ((i + j) % 2 !== 0) return;
    const g = mk('g', {});
    const bg = document.createElementNS(NS, 'line'); const fg = document.createElementNS(NS, 'line');
    [bg, fg].forEach((l) => { l.setAttribute('x1', x - half); l.setAttribute('x2', x + half); l.setAttribute('y1', y); l.setAttribute('y2', y); l.setAttribute('stroke-linecap', 'butt'); });
    bg.setAttribute('stroke', C.colors.paper); bg.setAttribute('stroke-width', W.stroke + 8);
    fg.setAttribute('stroke', C.colors.blue); fg.setAttribute('stroke-width', W.stroke);
    g.appendChild(bg); g.appendChild(fg); overSegs.push({ g, i, j });
  }));
  const hLen = W.x1 - W.x0, vLen = W.y1 - W.y0;
  hStr.forEach((l) => { l.setAttribute('stroke-dasharray', hLen); });
  vStr.forEach((l) => { l.setAttribute('stroke-dasharray', vLen); });
  [leadBlue, leadInk].forEach((p) => { const len = p.getTotalLength(); p.dataset.len = len; p.setAttribute('stroke-dasharray', len); });

  // Outcome phones.
  const outP = document.querySelectorAll('#outcomes .phone');
  const O = L.outcome;
  const pw = 442 * O.portraitScale, lw = 914 * O.landscapeScale;
  const total = pw + O.gap + lw;
  outP[0].style.transform = `translate(${-total / 2 + pw / 2}px, ${O.centerY - 540}px) scale(${O.portraitScale})`;
  outP[1].style.transform = `translate(${total / 2 - lw / 2}px, ${O.centerY - 540}px) scale(${O.landscapeScale})`;

  // Session threads.
  const thBlue = $('thBlue'), thInk = $('thInk');
  [thBlue, thInk].forEach((p) => {
    const rest = p.cloneNode(); rest.removeAttribute('id'); rest.style.opacity = 0.2; p.parentNode.insertBefore(rest, p);
    const len = p.getTotalLength(); p.dataset.len = len; p.setAttribute('stroke-dasharray', len);
  });

  // Geometry lookups (measured once, DOM is static in size).
  const stageRect = () => $('stage').getBoundingClientRect();
  const center = (el) => { const r = el.getBoundingClientRect(), s = stageRect(); return { x: r.left - s.left + r.width / 2, y: r.top - s.top + r.height / 2 }; };
  const geo = {};
  function measure() {
    // Measure with the composer and menu visible and un-transformed.
    ['headline', 'composerCam', 'sessionCam', 'weave', 'endcard'].forEach((id) => { $(id).style.transform = 'none'; $(id).classList.remove('hidden'); $(id).style.opacity = 1; });
    comp.style.transform = 'none'; $('menu').style.transform = 'none'; $('menu').classList.remove('hidden');
    const hosted = $('hosted');
    const hr = hosted.getBoundingClientRect(), s = stageRect();
    const menu = $('menu');
    menu.style.left = (hr.left - s.left - 10) + 'px';
    menu.style.top = (hr.top - s.top - 16 - menu.offsetHeight) + 'px';
    geo.hosted = center(hosted);
    geo.mac = center($('mMac'));
    geo.menu = center(menu);
    geo.submit = center($('submit'));
    const b = $('cText').getBoundingClientRect();
    geo.input = { x: b.left - s.left + 8, y: b.top - s.top + 22 };
    const pane = document.querySelector('.s-pane').getBoundingClientRect();
    geo.pane = { x: pane.left - s.left, y: pane.top - s.top, w: pane.width, h: pane.height };
  }
  measure();

  // ---------- helpers ----------
  function setVis(el, on) { el.classList.toggle('hidden', !on); }
  function cursorAt(x, y, opacity, press) {
    const c = $('cursor');
    c.style.opacity = opacity;
    c.style.transform = `translate(${x - 5}px, ${y - 3}px) scale(${press ? 0.86 : 1})`;
  }
  function moveCursor(t, from, to, a, b) {
    const k = easeInOutCubic(seg(t, a, b - a));
    return { x: lerp(from.x, to.x, k), y: lerp(from.y, to.y, k) };
  }

  // Camera push envelope for the session scene.
  function pushState(t) {
    for (const p of T.pushes) {
      if (t < p.t || t > p.t + p.d + T.pushOut) continue;
      let env;
      if (t < p.t + T.pushIn) env = easeOutCubic(seg(t, p.t, T.pushIn));
      else if (t < p.t + p.d) env = 1;
      else env = 1 - easeInOutCubic(seg(t, p.t + p.d, T.pushOut));
      const hold = clamp01((t - p.t) / p.d);
      return { env, p, hold };
    }
    return { env: 0, p: null, hold: 0 };
  }

  // ---------- render ----------
  window.render = function (t) {
    const hl = $('headline'), cc = $('composerCam'), sc = $('sessionCam'), wv = $('weave'), ec = $('endcard');
    const cur = $('cursor');
    cur.style.opacity = 0;

    // Scene A
    const hlOn = t < T.hlExit + T.hlExitDur;
    setVis(hl, hlOn);
    if (hlOn) {
      const ex = easeInOutCubic(seg(t, T.hlExit, T.hlExitDur));
      hlWords.forEach((w, i) => {
        const k = easeOutQuint(seg(t, T.hlWordStart + i * T.hlWordStep, T.hlWordDur));
        w.style.opacity = k * (1 - ex);
        w.style.transform = `translateY(${lerp(34, 0, k) - 60 * ex}px)`;
      });
      const mk = easeOutQuint(seg(t, 0.08, 0.6));
      $('hlMark').style.opacity = mk * (1 - ex);
      $('hlMark').style.transform = `translateY(${lerp(24, 0, mk) - 60 * ex}px) scale(${lerp(0.9, 1, mk)})`;
    }

    // Scene B
    const cOn = t >= T.cRise && t < T.cExit + T.cExitDur;
    setVis(cc, cOn);
    if (cOn) {
      const rise = easeOutQuint(seg(t, T.cRise, T.cRiseDur));
      const exit = easeInOutCubic(seg(t, T.cExit, T.cExitDur));
      comp.style.opacity = rise * (1 - exit);
      comp.style.transform = `translateY(${lerp(90, 0, rise) - 110 * exit}px) scale(${lerp(0.96, 1, rise) - 0.03 * exit})`;
      cParts.forEach((p, i) => {
        const k = easeOutQuint(seg(t, T.cRise + T.cPartLag[i], T.cRiseDur));
        p.style.opacity = k; p.style.transform = `translateY(${lerp(26, 0, k)}px)`;
      });
      // camera push toward menu
      let z = 1;
      if (t < T.camBack) z = lerp(1, T.camZoom, easeInOutCubic(seg(t, T.camPushIn, T.camPushInDur)));
      else z = lerp(T.camZoom, 1, easeInOutCubic(seg(t, T.camBack, T.camBackDur)));
      cc.style.transformOrigin = `${geo.menu.x}px ${geo.menu.y + 60}px`;
      cc.style.transform = `scale(${z})`;
      // menu
      const menu = $('menu');
      const mo = t < T.menuClose ? easeOutQuint(seg(t, T.menuOpen, T.menuDur)) : 1 - easeInCubic(seg(t, T.menuClose, 0.22));
      setVis(menu, mo > 0.001);
      menu.style.opacity = mo; menu.style.transform = `translateY(${lerp(14, 0, mo)}px) scale(${lerp(0.94, 1, mo)})`;
      const macHover = t >= T.cursorMacArrive - 0.06 && t < T.menuClose;
      $('mMac').classList.toggle('hover', macHover);
      const selected = t >= T.macSelect;
      $('mMac').classList.toggle('sel', selected); $('mUbuntu').classList.toggle('sel', !selected);
      $('hostedLabel').textContent = t >= T.macSelect + 0.12 ? X.hostedAfter : X.hostedBefore;
      $('hosted').classList.toggle('hover', t >= T.cursorToHosted - 0.05 && t < T.menuClose);
      // typing
      const n = Math.round(X.silverRequest.length * smooth(seg(t, T.typeStart, T.typeEnd - T.typeStart)));
      $('cTyped').textContent = X.silverRequest.slice(0, n);
      $('cPlaceholder').style.opacity = n > 0 ? 0 : 1;
      $('caret').style.opacity = (t >= T.typeStart - 0.4 && (t < T.typeEnd || Math.floor(t * 2.2) % 2 === 0)) ? 1 : 0;
      // submit press
      const pressK = t >= T.submitPress ? Math.sin(Math.PI * seg(t, T.submitPress, T.submitPressDur)) : 0;
      $('submit').style.transform = `scale(${1 - 0.16 * pressK})`;
      // cursor
      const start = { x: 1250, y: 820 };
      if (t >= T.cursorIn && t < T.cursorHide) {
        let pos;
        if (t < T.cursorToMac) pos = moveCursor(t, start, geo.hosted, T.cursorIn, T.cursorToHosted);
        else if (t < T.cursorToInput) pos = moveCursor(t, geo.hosted, geo.mac, T.cursorToMac, T.cursorMacArrive);
        else pos = moveCursor(t, geo.mac, geo.input, T.cursorToInput, T.cursorInputArrive);
        const fadeIn = seg(t, T.cursorIn, 0.25), fadeOut = 1 - seg(t, T.cursorHide - 0.2, 0.2);
        const press = (t >= T.menuOpen - 0.06 && t < T.menuOpen + 0.1) || (t >= T.macSelect - 0.06 && t < T.macSelect + 0.1);
        cursorAt(pos.x, pos.y, Math.min(fadeIn, fadeOut) * (1 - exit), press);
      } else if (t >= T.cursorToSubmit && t < T.cExit + 0.2) {
        const pos = moveCursor(t, { x: geo.submit.x - 140, y: geo.submit.y + 150 }, geo.submit, T.cursorToSubmit, T.cursorSubmitArrive);
        cursorAt(pos.x, pos.y, seg(t, T.cursorToSubmit, 0.2) * (1 - exit), pressK > 0.3);
      }
    }

    // Scene C
    const sOn = t >= T.sRise && t < T.sExit + T.sExitDur;
    setVis(sc, sOn);
    if (sOn) {
      const rise = easeOutQuint(seg(t, T.sRise, T.sRiseDur));
      const exit = easeInOutCubic(seg(t, T.sExit, T.sExitDur));
      sess.style.opacity = rise * (1 - exit);
      sess.style.transform = `translateY(${lerp(70, 0, rise)}px) scale(${lerp(0.97, 1, rise) - 0.04 * exit})`;
      // editor vs computer
      const codeN = Math.round(codeChars.length * seg(t, T.codeStart, T.codeEnd - T.codeStart));
      renderCode(codeN);
      // editor pushes up and out of the pane while the computer view pushes in from below
      const push = easeInOutCubic(seg(t, T.editorOut, T.editorOutDur));
      $('editor').style.transform = `translateY(${-push * geo.pane.h}px)`; setVis($('editor'), push < 0.999);
      $('computer').style.transform = `translateY(${(1 - push) * geo.pane.h}px)`;
      // chat blocks
      const swap = easeInOutCubic(seg(t, T.chatSwap, 0.4));
      const block1 = [$('uMsg1'), $('dMsg1'), $('steps1')], block2 = [$('uMsg2'), $('dMsg2'), $('steps2')];
      block1.forEach((el) => { setVis(el, swap < 1); el.style.opacity = 1 - swap; });
      block2.forEach((el) => { setVis(el, swap > 0); });
      const um1 = easeOutQuint(seg(t, T.sRise + 0.15, 0.5));
      $('uMsg1').style.transform = `translateY(${lerp(20, 0, um1)}px)`; $('uMsg1').style.opacity = um1 * (1 - swap);
      const dm1 = easeOutQuint(seg(t, T.sRise + 0.4, 0.5));
      $('dMsg1').style.transform = `translateY(${lerp(20, 0, dm1)}px)`; $('dMsg1').style.opacity = dm1 * (1 - swap);
      const um2 = easeOutQuint(seg(t, T.chatSwap + 0.25, 0.5));
      $('uMsg2').style.transform = `translateY(${lerp(20, 0, um2)}px)`; $('uMsg2').style.opacity = um2;
      const dm2 = easeOutQuint(seg(t, T.chatSwap + 0.5, 0.5));
      $('dMsg2').style.transform = `translateY(${lerp(20, 0, dm2)}px)`; $('dMsg2').style.opacity = dm2;
      [...steps1, ...steps2].forEach((s) => { const k = easeOutQuint(seg(t, s.time, 0.45)); s.el.style.opacity = k; s.el.style.transform = `translateX(${lerp(-14, 0, k)}px)`; });
      $('sTitle').textContent = swap > 0.5 ? X.sessionTitle2 : X.sessionTitle1;
      // footage
      const si = Math.floor((t - T.silverStart) * C.fps) + 1;
      $('imgSilver').src = silverSrc(si);
      const ri = Math.floor((t - T.rtxStart) * C.fps) + 1;
      $('imgRtx').src = rtxSrc(ri);
      // phone rotation and swap
      const rot = easeInOutCubic(seg(t, T.rotateStart, T.rotateDur));
      const pP = $('phoneP'), pL = $('phoneL');
      const landscape = t >= T.rotateStart + T.rotateDur;
      setVis(pP, !landscape); setVis(pL, landscape);
      const ps = L.phoneScale;
      pP.style.transform = `scale(${ps}) rotate(${-90 * rot}deg)`;
      pP.style.opacity = 1;
      $('imgSilver').style.opacity = 1 - easeInOutCubic(seg(t, T.rotateStart, 0.3));
      pL.style.transform = `scale(${ps})`;
      $('imgRtx').style.opacity = easeOutCubic(seg(t, T.rotateStart + T.rotateDur, 0.35));
      // threads
      const bd = easeInOutCubic(seg(t, T.blueDraw, T.blueDrawDur));
      const idr = easeInOutCubic(seg(t, T.inkDraw, T.inkDrawDur));
      thBlue.setAttribute('stroke-dashoffset', thBlue.dataset.len * (1 - bd));
      thInk.setAttribute('stroke-dashoffset', thInk.dataset.len * (1 - idr));
      thBlue.style.visibility = bd > 0 ? 'visible' : 'hidden';
      thInk.style.visibility = idr > 0 ? 'visible' : 'hidden';
      thInk.style.opacity = 1;
      thBlue.style.opacity = t >= T.inkDraw ? lerp(1, 0.35, idr) : 1;
      // camera
      const st = pushState(t);
      const lagSt = pushState(t - 0.16);
      let z = 1, ox = geo.pane.x + geo.pane.w / 2, oy = geo.pane.y + geo.pane.h / 2, dx = 0, dy = 0;
      if (st.p) {
        z = lerp(1, T.pushZoom, st.env);
        const screenW = (landscape ? 874 : 402) * ps, screenH = (landscape ? 402 : 874) * ps;
        ox = geo.pane.x + geo.pane.w / 2 + (st.p.fx - 0.5) * screenW;
        oy = geo.pane.y + geo.pane.h / 2 + (st.p.fy - 0.5) * screenH;
        const ph = st.hold * st.p.d;
        dx = Math.sin(ph * 1.7) * T.drift * 100 * st.env;
        dy = Math.cos(ph * 1.3) * T.drift * 80 * st.env;
      }
      sc.style.transformOrigin = `${ox}px ${oy}px`;
      sc.style.transform = `translate(${dx}px, ${dy}px) scale(${z})`;
      $('threads').style.transform = `translate(${-dx * 0.6 + lagSt.env * -6}px, ${-dy * 0.6 + lagSt.env * 10}px)`;
    }

    // Scene D
    const wOn = t >= T.wLeadStart && t < T.wExit + T.wExitDur;
    setVis(wv, wOn);
    if (wOn) {
      const exit = easeInOutCubic(seg(t, T.wExit, T.wExitDur));
      wv.style.opacity = 1 - exit;
      const drift = (t - T.wLeadStart);
      wv.style.transform = `translate(${Math.sin(drift * 0.9) * 8}px, ${Math.cos(drift * 0.7) * 5}px) scale(${1 + drift * 0.004})`;
      const lead = easeInOutCubic(seg(t, T.wLeadStart, T.wLeadDur));
      [leadBlue, leadInk].forEach((p) => { p.setAttribute('stroke-dashoffset', p.dataset.len * (1 - lead)); p.style.opacity = lead > 0 ? 1 : 0; });
      const g = seg(t, T.wGridStart, T.wGridDur);
      const nH = hStr.length, nV = vStr.length;
      const hProg = hStr.map((l, j) => { const k = easeInOutCubic(clamp01((g - j * 0.03) / 0.55)); l.setAttribute('stroke-dashoffset', hLen * (1 - k)); l.style.opacity = k > 0 ? 1 : 0; return k; });
      const vProg = vStr.map((l, i) => { const k = easeInOutCubic(clamp01((g - 0.25 - (nV - 1 - i) * 0.012) / 0.5)); l.setAttribute('stroke-dashoffset', vLen * (1 - k)); l.style.opacity = k > 0 ? 1 : 0; return k; });
      overSegs.forEach(({ g: el, i, j }) => {
        const xFrac = (vx[i] - W.x0) / hLen, yFrac = (hy[j] - W.y0) / vLen;
        const on = hProg[j] >= xFrac + 0.02 && vProg[i] >= yFrac + 0.02;
        el.style.opacity = on ? 1 : 0;
      });
      const oi = easeOutQuint(seg(t, T.outcomesIn, T.outcomesInDur));
      $('outcomes').style.opacity = oi;
      $('outcomes').style.transform = `translateY(${lerp(30, 0, oi)}px) scale(${lerp(0.94, 1, oi)})`;
      const ti = easeOutQuint(seg(t, T.outTextIn, T.outTextDur));
      $('outText').style.opacity = ti; $('outText').style.transform = `translateY(${lerp(24, 0, ti)}px)`;
    }

    // Scene E
    const eOn = t >= T.logoIn;
    setVis(ec, eOn);
    if (eOn) {
      const li = easeOutQuint(seg(t, T.logoIn, T.logoDur));
      const ui = easeOutQuint(seg(t, T.urlIn, T.urlDur));
      const d = t - T.logoIn;
      ec.style.transform = `translate(${Math.sin(d * 0.8) * 6}px, ${-d * 3}px) scale(${1 + d * 0.006})`;
      $('lockup').style.opacity = li; $('lockup').style.transform = `translateY(${lerp(26, 0, li)}px) scale(${lerp(0.96, 1, li)})`;
      $('url').style.opacity = ui; $('url').style.transform = `translateY(${lerp(22, 0, ui)}px)`;
    }
  };

  window.CONFIG = C;
  render(0);
})();
