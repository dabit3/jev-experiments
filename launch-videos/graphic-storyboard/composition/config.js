// Graphic Storyboard: "macOS. Now in Devin Cloud."
// Every timing, caption, media path, panel rect and color lives here.
// Times are in seconds. Rects are [x, y, w, h] in the 1920x1080 frame.

window.CONFIG = {
  fps: 30,
  duration: 27.5,
  width: 1920,
  height: 1080,

  colors: {
    field: "#0f0f10",          // deep dark brand field behind the storyboard
    text: "#f4f4f5",
    muted: "#8b8b90",
    accent: "#2200ff",         // Devin brand blue (Figma)
    accentSoft: "#6b74ff",     // legible blue on dark surfaces
    ui: "#191919",             // Devin dark UI background (Figma)
    uiRaised: "#222224",
    uiLine: "rgba(255,255,255,0.08)",
    uiText: "#ececec",
    uiMuted: "#9a9a9f",
    green: "#3ddc84",
  },

  media: {
    macFrames: "../media/mac-frames/",       // screencapture -v, 30 fps jpg sequence
    macFrameCount: 480,
    iphoneFrames: "../media/iphone-frames/", // xcrun simctl recordVideo, 30 fps jpg sequence
    iphoneFrameCount: 540,
    lockup: "../assets/devin-lockup-white.png",
    avatar: "../assets/devin-avatar-white.png",
  },

  // Footage offsets: which second of each recording plays when a panel opens.
  footage: {
    macStart: 0.4,        // Mac panel
    iphoneStart: 0.6,     // iPhone panel
    macBothStart: 8.0,    // final panel, Mac half
    iphoneBothStart: 6.0, // final panel, iPhone half
  },

  text: {
    headline: "macOS. Now in Devin Cloud.",
    prompt: "Build VoxelHearth, a voxel sandbox for macOS and iPhone with shared worlds, and run both",
    sessionTitle: "Build VoxelHearth for macOS and iPhone",
    devinReply: "I will build VoxelHearth natively with SwiftUI and Metal, run the Mac app on my desktop and the iPhone app in the Simulator, then join both to one shared world.",
    devinDone: "VoxelHearth runs on both. I hosted room DQK43 from the Mac, joined it from the iPhone Simulator and placed torches from each device.",
    endUrl: "devin.ai",
  },

  // Margin captions (bottom margin, aligned to the hero panel's left edge).
  captions: [
    { t0: 3.6, t1: 6.4, x: 160, text: "Prompt" },
    { t0: 7.4, t1: 10.6, x: 160, text: "Devin writes Swift" },
    { t0: 12.0, t1: 15.2, x: 160, text: "Runs on Devin's Mac" },
    { t0: 16.6, t1: 19.8, x: 160, text: "Runs in the iPhone Simulator" },
  ],

  // Storyboard slots (quiet context) and the hero rect (active panel, about 83% of the frame).
  // Slot rects match each panel's content aspect so nothing is cropped while quiet.
  slots: {
    prompt: [72, 72, 700, 301],
    code: [796, 72, 1052, 301],
    mac: [72, 407, 876, 493],
    iphone: [972, 407, 876, 493],
  },
  hero: {
    prompt: [160, 196, 1600, 688],
    code: [160, 145, 1600, 791],
    session: [160, 60, 1600, 900],
    // Push-in that fills the hero rect with the Computer pane (content x 700..1920).
    computer: { z: 1.574, f: [1310, 540] },
    simulator: { z: 1.574, f: [1310, 546] },
  },

  // Panel choreography. Each keyframe holds rect, opacity (o), zoom (z),
  // focus point in content pixels (f) and optional clip insets [top,right,bottom,left].
  panels: {},

  title: { t0: 0.0, t1: 2.9 },
  end: { t0: 25.9, t1: 27.5 },

  // Typing schedules (seconds) for the composer and the Swift editor.
  typing: {
    prompt: { t0: 3.8, t1: 6.0 },
    code: { t0: 7.6, t1: 10.3 },
  },
  panelRadius: 16,
};

// Build the keyframes from slots + hero so gutter moves stay consistent.
(function (C) {
  const S = C.slots, H = C.hero, PC = H.computer, PS = H.simulator;
  const center = (f) => ({ z: 1, f });
  C.panels = {
    prompt: {
      content: [1000, 430],
      keys: [
        { t: 2.6, rect: S.prompt, o: 0, ...center([500, 215]), clip: [0, 700, 0, 0] },
        { t: 3.3, rect: S.prompt, o: 1, clip: [0, 0, 0, 0] },
        { t: 3.6, rect: S.prompt },
        { t: 4.4, rect: H.prompt },
        { t: 6.4, rect: H.prompt },
        { t: 7.2, rect: S.prompt, o: 0.6 },
        { t: 20.6, rect: S.prompt, o: 0.6 },
        { t: 21.4, rect: S.prompt, o: 0 },
      ],
    },
    code: {
      content: [1052, 520],
      keys: [
        { t: 6.6, rect: S.code, o: 0, ...center([526, 150]), clip: [0, 1052, 0, 0] },
        { t: 7.2, rect: S.code, o: 1, clip: [0, 0, 0, 0] },
        { t: 7.4, rect: S.code, f: [526, 150] },
        { t: 8.2, rect: H.code, f: [526, 260] },
        { t: 10.6, rect: H.code, f: [526, 260] },
        { t: 11.4, rect: S.code, o: 0.6, f: [526, 150] },
        { t: 20.6, rect: S.code, o: 0.6, f: [526, 150] },
        { t: 21.4, rect: S.code, o: 0 },
      ],
    },
    mac: {
      content: [1920, 1080],
      keys: [
        { t: 11.0, rect: S.mac, o: 0, ...center([960, 540]), clip: [493, 0, 0, 0] },
        { t: 11.6, rect: S.mac, o: 1, clip: [0, 0, 0, 0] },
        { t: 11.8, rect: S.mac },
        { t: 12.6, rect: H.session },
        { t: 13.4, rect: H.session },
        { t: 14.2, rect: H.session, ...PC },
        { t: 15.2, rect: H.session, ...PC },
        { t: 16.0, rect: S.mac, o: 0.6, ...PC },
        { t: 20.6, rect: S.mac, o: 0.6, ...PC },
        { t: 21.4, rect: S.mac, o: 0, ...PC },
      ],
    },
    iphone: {
      content: [1920, 1080],
      keys: [
        { t: 15.6, rect: S.iphone, o: 0, ...center([960, 540]), clip: [0, 876, 0, 0] },
        { t: 16.2, rect: S.iphone, o: 1, clip: [0, 0, 0, 0] },
        { t: 16.4, rect: S.iphone },
        { t: 17.2, rect: H.session },
        { t: 18.0, rect: H.session },
        { t: 18.8, rect: H.session, ...PS },
        { t: 19.8, rect: H.session, ...PS },
        { t: 20.6, rect: S.iphone, o: 0.6, ...PS },
        { t: 21.4, rect: S.iphone, o: 0, ...PS },
      ],
    },
    both: {
      content: [1920, 1080],
      keys: [
        { t: 20.6, rect: [0, 0, 1920, 1080], r: 0, o: 0, ...center([960, 540]), clip: [0, 0, 1080, 0] },
        { t: 21.0, rect: [0, 0, 1920, 1080], r: 0, o: 1, clip: [0, 0, 810, 0] },
        { t: 21.8, rect: [0, 0, 1920, 1080], r: 0, clip: [0, 0, 0, 0] },
        { t: 23.0, rect: [0, 0, 1920, 1080], r: 0 },
        { t: 24.0, rect: [0, 0, 1920, 1080], r: 0, ...PC },
        { t: 25.6, rect: [0, 0, 1920, 1080], r: 0, ...PC },
        { t: 26.3, rect: [0, 0, 1920, 1080], r: 0, o: 0, ...PC },
      ],
    },
  };
})(window.CONFIG);
