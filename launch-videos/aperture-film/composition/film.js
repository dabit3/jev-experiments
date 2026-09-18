/* The Aperture Film: deterministic time-driven composition.
   window.__seek(t) lays out the frame at time t (seconds) and resolves when it is ready to capture. */
(() => {
  const C = window.CONFIG;
  const T = C.t;
  const W = C.width, H = C.height;

  const $ = (id) => document.getElementById(id);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, x) => a + (b - a) * x;
  const eOut = (x) => 1 - Math.pow(1 - x, 4); // fast-out, gentle-in
  const eInOut = (x) => (x < 0.5 ? 8 * x * x * x * x : 1 - Math.pow(-2 * x + 2, 4) / 2);
  const lin = (x) => x;
  const seg = (t, a, b, fn = eOut) => fn(clamp((t - a) / (b - a), 0, 1));

  // Piecewise keyframe track. keys: [[time, value], ...]; value: number | number[] | rect
  function track(keys, t, fn = eOut) {
    if (t <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const [t1, v1] = keys[i];
      if (t <= t1) {
        const [t0, v0] = keys[i - 1];
        const x = fn((t - t0) / (t1 - t0));
        return mix(v0, v1, x);
      }
    }
    return keys[keys.length - 1][1];
  }
  function mix(a, b, x) {
    if (typeof a === "number") return lerp(a, b, x);
    if (Array.isArray(a)) return a.map((v, i) => lerp(v, b[i], x));
    const o = {};
    for (const k in a) o[k] = lerp(a[k], b[k], x);
    return o;
  }

  // ---------- Camera ----------
  // Camera focal point (world) and zoom. Screen = 960 + z * (p - c).
  let cam = { x: W / 2, y: H / 2, z: 1 };
  function applyCamera(c) {
    cam = c;
    $("world").style.transform = `translate(${W / 2 - c.z * c.x}px, ${H / 2 - c.z * c.y}px) scale(${c.z})`;
  }
  const toScreen = (c, x, y) => [W / 2 + c.z * (x - c.x), H / 2 + c.z * (y - c.y)];
  function rectToScreen(c, r) {
    const [x0, y0] = toScreen(c, r.x, r.y);
    return { x: x0, y: y0, w: r.w * c.z, h: r.h * c.z };
  }
  const pad = (r, px, py = px) => ({ x: r.x - px, y: r.y - py, w: r.w + 2 * px, h: r.h + 2 * py });
  const union = (a, b) => {
    const x = Math.min(a.x, b.x), y = Math.min(a.y, b.y);
    return { x, y, w: Math.max(a.x + a.w, b.x + b.w) - x, h: Math.max(a.y + a.h, b.y + b.h) - y };
  };
  const center = (r) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
  const zeroAt = (p) => ({ x: p.x, y: p.y, w: 0, h: 0 });
  const FULL = { x: 0, y: 0, w: W, h: H };

  function applyAperture(r, radius) {
    const x0 = clamp(r.x, 0, W), y0 = clamp(r.y, 0, H);
    const x1 = clamp(r.x + r.w, 0, W), y1 = clamp(r.y + r.h, 0, H);
    const w = Math.max(0, x1 - x0), h = Math.max(0, y1 - y0);
    const rr = radius == null ? clamp(Math.min(w, h) * 0.13, 0, 46) : radius;
    $("aperture").style.clipPath = `inset(${y0}px ${W - x1}px ${H - y1}px ${x0}px round ${rr}px)`;
  }

  // ---------- Static layout measurement (world coordinates) ----------
  const R = {};
  function measure() {
    applyCamera({ x: W / 2, y: H / 2, z: 1 });
    const rect = (el) => {
      const b = el.getBoundingClientRect();
      return { x: b.left, y: b.top, w: b.width, h: b.height };
    };
    show("composer");
    R.chip = rect($("env-chip"));
    R.box = rect(document.querySelector(".composer-box"));
    R.head = rect(document.querySelector(".composer-head"));
    R.submit = rect($("submit"));
    R.text = rect(document.querySelector(".composer-text"));
    $("menu").style.opacity = 1;
    $("hosted").style.opacity = 1;
    R.menu = union(rect($("menu")), rect($("hosted")));
    R.macRow = rect($("h-mac"));
    show("code");
    R.editor = rect(document.querySelector(".editor"));
    show("session");
    R.screen = rect(document.querySelector(".phone-screen"));
    R.phone = rect($("phone"));
  }
  function show(id) {
    for (const s of document.querySelectorAll(".scene")) s.classList.toggle("on", s.id === id);
  }

  // ---------- Content setup ----------
  const cursor = document.createElement("div");
  cursor.id = "cursor";
  document.querySelector("#composer .page").appendChild(cursor);

  $("headline-text").textContent = C.text.headline;
  $("placeholder").textContent = C.text.placeholder;
  document.querySelector(".s-title").textContent = C.text.sessionTitle;
  $("s-user").textContent = C.text.prompt;
  $("s-reply").textContent = C.text.devinReply;
  document.querySelector(".s-composer-ph").textContent = C.text.placeholder;
  $("s-steps").innerHTML = C.text.steps
    .map((s, i) => `<div class="step ${i === 2 ? "working" : "done"}" id="step-${i}"><i></i><span>${s}</span></div>`)
    .join("");
  $("url").textContent = C.text.url;

  // Swift excerpt from Silverroom's ImageEngine.swift, tokenised as [class, text] pairs.
  const CODE = [
    [["k", "func"], ["", " "], ["f", "filtered"], ["", "(_ source: "], ["t", "CIImage"], ["", ", settings raw: "], ["t", "EditSettings"], ["", ") -> "], ["t", "CIImage"], ["", " {"]],
    [["", "  "], ["k", "let"], ["", " settings = raw.normalized"]],
    [["", "  "], ["k", "var"], ["", " image = source"]],
    [["", "  "], ["k", "if"], ["", " settings.exposure != "], ["n", "0"], ["", " {"]],
    [["", "    image = image."], ["f", "applyingFilter"], ["", "("]],
    [["", "      "], ["s", "\"CIExposureAdjust\""], ["", ", parameters: ["], ["t", "kCIInputEVKey"], ["", ": settings.exposure])"]],
    [["", "  }"]],
    [["", "  "], ["k", "let"], ["", " saturation: "], ["t", "Double"], ["", " ="]],
    [["", "    "], ["k", "switch"], ["", " settings.film {"]],
    [["", "    "], ["k", "case"], ["", " .silver, .noir: "], ["n", "0"]],
    [["", "    "], ["k", "case"], ["", " .dune: "], ["n", "0.82"]],
    [["", "    "], ["k", "case"], ["", " .faded: "], ["n", "0.65"]],
    [["", "    "], ["k", "case"], ["", " .original: "], ["n", "1"]],
    [["", "    }"]],
    [["", "  "], ["k", "let"], ["", " filmContrast: "], ["t", "Double"], ["", " = settings.film == .noir ? "], ["n", "1.23"], ["", " : "], ["n", "1"]],
    [["", "  image = image."], ["f", "applyingFilter"], ["", "("], ["s", "\"CIColorControls\""], ["", ","]],
    [["", "    parameters: ["], ["t", "kCIInputSaturationKey"], ["", ": saturation,"]],
    [["", "                 "], ["t", "kCIInputContrastKey"], ["", ": filmContrast])"]],
  ];
  const codeTotal = CODE.reduce((n, line) => n + line.reduce((m, tok) => m + tok[1].length, 0), 0);
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
  function renderCode(chars) {
    let left = chars, html = "", lines = 0;
    for (let i = 0; i < CODE.length; i++) {
      if (left <= 0 && i > 0) break;
      lines++;
      for (const [cls, txt] of CODE[i]) {
        if (left <= 0) break;
        const part = txt.slice(0, left);
        left -= part.length;
        html += cls ? `<span class="${cls}">${esc(part)}</span>` : esc(part);
      }
      if (left <= 0) { html += `<span class="code-caret"></span>`; break; }
      html += "\n";
    }
    $("code-lines").innerHTML = html;
    return lines;
  }

  // ---------- Per-scene state ----------
  const PROMPT = C.text.prompt;

  function composerState(t) {
    const chipC = center(R.chip);
    // Chip press
    const press = seg(t, T.chipClick, T.chipClick + 0.08, lin) * (1 - seg(t, T.chipClick + 0.08, T.chipClick + 0.25));
    $("env-chip").style.transform = `scale(${1 - 0.04 * press})`;

    // Menu in / out (primary leads, hosted follows with less travel)
    const mIn = seg(t, T.menuOpen, T.menuOpen + 0.36), mOut = seg(t, T.menuClose, T.menuClose + 0.3);
    const hIn = seg(t, T.menuOpen + 0.1, T.menuOpen + 0.46), hOut = seg(t, T.menuClose + 0.06, T.menuClose + 0.36);
    const m = mIn * (1 - mOut), h = hIn * (1 - hOut);
    $("menu").style.opacity = m;
    $("menu").style.transform = `translateY(${-14 * (1 - mIn) + -8 * mOut}px) scale(${0.97 + 0.03 * m})`;
    $("hosted").style.opacity = h;
    $("hosted").style.transform = `translateY(${-8 * (1 - hIn) + -5 * hOut}px) scale(${0.98 + 0.02 * h})`;
    $("h-mac").classList.toggle("hover", t >= T.macClick - 0.12 && t < T.menuClose + 0.4);
    $("h-ubuntu").classList.toggle("checked", t < T.macClick);
    $("h-mac").classList.toggle("checked", t >= T.macClick);

    // Ubuntu lifts out, macOS drops in
    const up = seg(t, T.macClick, T.macClick + 0.3), down = seg(t, T.macClick + 0.1, T.macClick + 0.42);
    for (const id of ["lbl-ubuntu", "ico-ubuntu"]) {
      $(id).style.opacity = 1 - up; $(id).style.transform = `translateY(${-16 * up}px)`;
    }
    for (const id of ["lbl-mac", "ico-mac"]) {
      $(id).style.opacity = down; $(id).style.transform = `translateY(${16 * (1 - down)}px)`;
    }

    // Typing
    const n = Math.round(seg(t, T.typeStart, T.typeEnd, lin) * PROMPT.length);
    $("prompt-text").textContent = PROMPT.slice(0, n);
    $("placeholder").style.display = n > 0 ? "none" : "inline";
    const blink = t < T.typeStart ? Math.floor(t * 2.2) % 2 === 0 : t < T.submitPress;
    $("caret").style.opacity = blink ? 1 : 0;

    // Submit press
    const sp = seg(t, T.submitPress, T.submitPress + 0.08, lin) * (1 - seg(t, T.submitPress + 0.08, T.submitPress + 0.3));
    $("submit").style.transform = `scale(${1 - 0.1 * sp})`;

    // Cursor path (world coordinates)
    const macC = center(R.macRow), subC = center(R.submit);
    const path = [
      [T.cursorIn, [chipC.x + 300, chipC.y + 190]],
      [T.chipClick - 0.05, [chipC.x + 6, chipC.y + 8]],
      [T.menuOpen + 0.4, [chipC.x + 6, chipC.y + 8]],
      [T.macClick - 0.08, [macC.x - 40, macC.y + 6]],
      [T.menuClose + 0.25, [macC.x - 40, macC.y + 6]],
      [T.typeStart - 0.05, [R.text.x + 320, R.text.y + 58]],
      [T.typeEnd - 0.25, [R.text.x + 320, R.text.y + 58]],
      [T.submitPress - 0.06, [subC.x + 2, subC.y + 4]],
    ];
    const p = track(path, t);
    const cOp = seg(t, T.cursorIn, T.cursorIn + 0.25) * (1 - seg(t, T.typeStart + 0.05, T.typeStart + 0.3)) + seg(t, T.typeEnd - 0.4, T.typeEnd - 0.15);
    cursor.style.opacity = clamp(cOp, 0, 1);
    cursor.style.transform = `translate(${p[0]}px, ${p[1]}px)`;

    // Camera: hold on the selector, settle out a beat after the aperture widens, drift along the prompt.
    const boxC = center(union(R.head, R.box));
    const camera = track(
      [
        [0, { x: chipC.x, y: chipC.y - 34, z: 2.9 }],
        [T.headlineOut, { x: chipC.x + 10, y: chipC.y - 30, z: 2.7 }],
        [T.apertureToComposer[1] + 0.12, { x: boxC.x, y: boxC.y + 6, z: 1.14 }],
        [T.typeStart, { x: boxC.x, y: boxC.y + 6, z: 1.14 }],
        [T.typeEnd, { x: boxC.x + 40, y: boxC.y - 8, z: 1.1 }],
        [T.submitPress + 0.2, { x: boxC.x + 50, y: boxC.y + 8, z: 1.13 }],
      ],
      t
    );
    applyCamera(camera);

    // Aperture (screen space, evaluated against the current camera)
    const S = (r) => rectToScreen(camera, r);
    const chipR = pad(S(R.chip), 30, 22);
    const slit = { x: chipR.x + chipR.w * 0.24, y: chipR.y + chipR.h * 0.2, w: chipR.w * 0.52, h: chipR.h * 0.6 };
    const compR = pad(S(union(R.head, R.box)), 40, 36);
    const compMenuR = pad(S(union(union(R.head, R.box), R.menu)), 40, 36);
    const keys = [
      [T.slitIn, zeroAt(center(slit))],
      [T.slitIn + 0.12, slit],
      [T.slitIn + 0.45, chipR],
      [T.apertureToComposer[0], chipR],
      [T.apertureToComposer[1], compR],
      [T.menuOpen - 0.05, compR],
      [T.menuOpen + 0.35, compMenuR],
      [T.menuClose, compMenuR],
      [T.menuClose + 0.4, compR],
      [T.apertureClose1[0], compR],
      [T.apertureClose1[1], zeroAt(center(compR))],
    ];
    applyAperture(track(keys, t));
  }

  function codeState(t) {
    const chars = Math.round(seg(t, T.codeType[0], T.codeType[1], lin) * codeTotal);
    const lines = renderCode(chars);
    const camera = track(
      [
        [T.codeOpen[0], { x: W / 2, y: H / 2 - 30, z: 1.0 }],
        [T.apertureClose2[1], { x: W / 2 + 10, y: H / 2 + 10, z: 1.05 }],
      ],
      t,
      lin
    );
    applyCamera(camera);
    // The opening only ever shows the tab bar plus the lines typed so far; it grows with the code.
    const typedH = (C.editorTabsH + C.editorPadTop + lines * C.editorLineH + 26) * camera.z;
    const full = rectToScreen(camera, R.editor);
    const ed = pad({ x: full.x, y: full.y, w: full.w, h: Math.min(full.h, typedH) }, 20, 18);
    const keys = [
      [T.codeOpen[0], zeroAt(center(ed))],
      [T.codeOpen[1], ed],
      [T.apertureClose2[0], ed],
      [T.apertureClose2[1], zeroAt(center(ed))],
    ];
    applyAperture(track(keys, t));
  }

  // Touch points on the app screen as fractions of the phone screen (u across, v down).
  const P = (u, v) => ({ x: R.screen.x + u * R.screen.w, y: R.screen.y + v * R.screen.h });

  // The whole Devin session stays on screen; pushes are gentle so the sidebar, tabs and Live pill
  // remain visible at the edges. At z = 1 the camera is centred on the full session view.
  const ZMAX = 1.34;
  function sessionCamera(f) {
    const k = (u, v, z) => {
      const p = P(u, v);
      const s = ((z - 1) / (ZMAX - 1)) * 0.86;
      return { x: W / 2 + (p.x - W / 2) * s, y: H / 2 + (p.y - H / 2) * s, z };
    };
    return track(
      [
        [-0.5, k(0.5, 0.5, 1.0)],
        [0.35, k(0.5, 0.5, 1.0)],
        [0.95, k(0.5, 0.5, 1.07)], // tap the photo, full phone in view
        [1.7, k(0.5, 0.45, 1.05)], // image develops
        [2.4, k(0.5, 0.45, 1.05)],
        [3.0, k(0.55, 0.6, 1.08)], // Noir in the Looks strip, full phone in view
        [3.7, k(0.55, 0.6, 1.08)],
        [4.3, k(0.5, 0.7, 1.22)], // Adjust tab
        [5.0, k(0.53, 0.74, ZMAX)], // exposure slider
        [5.8, k(0.55, 0.74, ZMAX)],
        [6.9, k(0.5, 0.5, 1.0)],
        [8.0, k(0.5, 0.5, 1.0)],
        [8.7, k(0.58, 0.45, 1.26)], // hold to compare
        [10.1, k(0.58, 0.45, 1.26)],
        [11.0, k(0.5, 0.55, 1.02)],
        [11.15, k(0.5, 0.55, 1.02)],
        [11.7, k(0.6, 0.66, 1.3)], // Frame tools
        [12.9, k(0.6, 0.66, 1.3)],
        [13.4, k(0.42, 0.55, 1.16)], // rotate
        [14.9, k(0.42, 0.55, 1.16)],
        [15.4, k(0.55, 0.6, 1.24)], // square crop
      ],
      f
    );
  }

  function sessionState(t) {
    const f = t - T.footageStart;
    // Genuine take frame at 1x. Frames before the start hold the first frame; after the end the last frame holds.
    const idx = clamp(Math.floor(f * C.fps) + 1, 1, C.media.takeFrameCount);
    const src = `${C.media.takeFramesDir}f${String(idx).padStart(4, "0")}.png`;
    const img = $("take");
    if (img.getAttribute("src") !== src) img.setAttribute("src", src);

    // Timeline steps appear as the work happens
    const stepAt = [-1, 0.6, 2.6];
    stepAt.forEach((s, i) => {
      const a = seg(f, s, s + 0.4);
      const el = $(`step-${i}`);
      el.style.opacity = a;
      el.style.transform = `translateY(${8 * (1 - a)}px)`;
    });
    const finished = f >= T.outroFullCanvas[0] - T.footageStart + 0.3;
    $("step-2").classList.toggle("working", !finished);
    $("step-2").classList.toggle("done", finished);

    // Camera: eased pushes toward touch points, then out to the full session view.
    const o0 = T.outroFullCanvas[0] - T.footageStart, o1 = T.outroFullCanvas[1] - T.footageStart;
    let camera = sessionCamera(Math.min(f, o0));
    if (f > o0) camera = mix(camera, { x: W / 2, y: H / 2, z: 1 }, seg(f, o0, o1, eInOut));
    applyCamera(camera);

    // Aperture: opens as a portrait window on the whole phone, then widens with every push across the
    // Devin session (sidebar, tabs, Live pill) while trailing the camera slightly.
    const lagCam = f > o0 ? camera : sessionCamera(Math.min(f, o0) - 0.05);
    const phoneR = pad(rectToScreen(lagCam, R.phone), 44, 34);
    const inset = track(
      [
        [2.2, 52],
        [5.0, 48],
        [8.7, 46],
        [11.7, 40],
        [15.4, 36],
      ],
      Math.min(f, o0)
    );
    const wideR = { x: inset, y: inset, w: W - 2 * inset, h: H - 2 * inset };
    const wide = track(
      [
        [-0.5, 0],
        [0.6, 0],
        [2.2, 1],
      ],
      Math.min(f, o0)
    );
    let ap = mix(phoneR, wideR, wide);
    let radius = lerp(46, 24, wide);
    if (f > o0) {
      const x = seg(f, o0, o1, eInOut);
      ap = mix(ap, FULL, x);
      radius = lerp(radius, 0, x);
    }
    const openIn = seg(t, T.footageOpen[0], T.footageOpen[1]);
    if (openIn < 1) ap = mix(zeroAt(center(ap)), ap, openIn);
    applyAperture(ap, radius);
  }

  function outroState(t) {
    const toDark = seg(t, T.outroToDark[0], T.outroToDark[1]);
    const apEl = $("aperture");
    apEl.style.transform = `scale(${1 - 0.1 * toDark})`;
    apEl.style.opacity = 1 - seg(t, T.outroToDark[0], T.outroToDark[1] - 0.15);
    $("dark").style.opacity = seg(t, T.outroToDark[0], T.outroToDark[0] + 0.6);

    const li = seg(t, T.logoIn[0], T.logoIn[1]);
    const drift = 1 + 0.015 * seg(t, T.logoIn[1], C.duration, lin);
    $("outro-logo").style.opacity = li;
    $("outro-logo").style.transform = `scale(${(0.82 + 0.18 * li) * drift})`;

    const u = seg(t, T.urlIn, T.urlIn + 0.45);
    $("url").style.opacity = u;
    $("url").style.transform = `translateY(${12 * (1 - u)}px) scale(${drift})`;
  }

  function headlineState(t) {
    const out = seg(t, T.headlineOut, T.headlineOut + 0.5);
    const inn = seg(t, 0, 0.7);
    const drift = 1 + 0.02 * seg(t, 0, T.headlineOut, lin);
    const el = $("headline");
    el.style.opacity = inn * (1 - out);
    el.style.transform = `translateY(${24 * (1 - inn) - 60 * out}px) scale(${drift * (1 - 0.04 * out)})`;
    $("aperture").style.visibility = t < T.slitIn ? "hidden" : "visible";
  }

  function apply(t) {
    headlineState(t);
    if (t < T.apertureClose1[1]) {
      show("composer");
      composerState(t);
    } else if (t < T.apertureClose2[1]) {
      show("code");
      codeState(t);
    } else {
      show("session");
      sessionState(t);
    }
    outroState(t);
  }

  let ready = false;
  async function init() {
    await document.fonts.ready;
    // Force both fonts to load by measuring text that uses them.
    measure();
    ready = true;
  }
  const initP = init();

  window.__seek = async (t) => {
    await initP;
    apply(t);
    const img = $("take");
    if (img.getAttribute("src")) {
      try { await img.decode(); } catch (e) { /* frame missing; keep going */ }
    }
    await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
    return true;
  };
  window.__duration = C.duration;

  // Scrub with a slider when opened in a browser.
  if (location.hash === "#scrub") {
    const s = document.createElement("input");
    s.type = "range"; s.min = 0; s.max = C.duration; s.step = 1 / C.fps; s.value = 0;
    s.style.cssText = "position:fixed;left:20px;bottom:20px;width:600px;z-index:99";
    s.oninput = () => window.__seek(parseFloat(s.value));
    document.body.appendChild(s);
    window.__seek(0);
  } else {
    window.__seek(0);
  }
})();
