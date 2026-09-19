// Every editable constant for the Margin Notes launch video lives here.
// Times are seconds on the master timeline unless noted as "vt" (seconds into the Simulator take).
const CONFIG = {
  fps: 30,
  duration: 29.2,

  colors: {
    paper: '#F4EFE7',
  },

  text: {
    headline: 'macOS. Now in Devin Cloud.',
    placeholder: 'Ask Devin to build features, fix bugs, or work on your code',
    prompt: 'Build Silverroom, a photo darkroom for iPhone with Noir and Silver looks, then test it in the Simulator',
    noteMac: 'macOS selected',
    noteXcode: 'Built with Xcode',
    url: 'devin.ai',
    sessionTitle: 'Silverroom for iPhone',
    devinReply: 'Writing Silverroom in SwiftUI and Core Image, building it with Xcode, then testing it in the iOS Simulator.',
    steps: ['Writing ImageEngine.swift', 'Building with Xcode', 'Launched on iPhone 17 Pro', 'Testing looks, exposure and framing'],
    codeFile: 'Silverroom/ImageEngine.swift',
    building: 'Building Silverroom for iPhone 17 Pro',
    built: 'Build Succeeded',
  },

  // Swift shown being written in the Changes tab (from Silverroom/ImageEngine.swift)
  code: [
    'let saturation: Double =',
    '  switch settings.film {',
    '  case .silver, .noir: 0',
    '  case .dune: 0.82',
    '  case .faded: 0.65',
    '  case .original: 1',
    '  }',
    'image = image.applyingFilter(',
    '  "CIColorControls",',
    '  parameters: [',
    '    kCIInputSaturationKey: saturation,',
    '    kCIInputContrastKey: 1,',
    '  ])',
  ],

  layout: {
    marginX: 1480, // left edge of the reserved right margin where notes live
  },

  // genuine Simulator take, pre-extracted to JPEG frames by render.mjs
  take: {
    src: 'assets/silverroom-take.mov',
    framesDir: 'frames',
    frameCount: 437,
    duration: 14.56,
    width: 1206,
    height: 2622,
  },

  timeline: {
    title: { in: 0.0, out: 1.9 },
    composer: {
      in: 2.5, cursorStart: 3.4, menuOpen: 3.8, hoverMac: 4.25, macPick: 4.5,
      noteIn: 4.75, noteOut: 7.15, typeStart: 4.85, typeEnd: 6.85, send: 7.05, out: 7.3,
    },
    // Devin session window opens on the Changes tab: Swift is written, then Xcode builds it
    build: { in: 7.8, codeStart: 8.05, codeEnd: 9.3, buildStart: 9.15, buildEnd: 9.9, noteIn: 9.9, noteOut: 10.95 },
    // the same window switches to the Computer tab and plays the take
    sim: { in: 11.3, videoStart: 11.5, recenter: 25.55, out: 26.5 },
    outro: { wipe: 26.3, lockup: 26.95, url: 27.6, end: 29.2 },
  },

  // camera pushes onto the phone during these beats (vt); scale is the push amount.
  // zoomOrigin (stage px) keeps the Devin window chrome inside the frame while pushed in.
  simZoom: [
    { in: 3.2, out: 7.3, scale: 1.04 },
    { in: 10.6, out: 12.3, scale: 1.04 },
  ],
  zoomOrigin: { x: 600, y: 540 },

  // detail-panel focus keyframes (vt). cx/cy/w are fractions of the source frame; the crop
  // arrives at each keyframe at time t after moving for tr seconds.
  focus: [
    { t: 0.0, cx: 0.5, cy: 0.40, w: 0.85 },
    { t: 2.3, cx: 0.5, cy: 0.27, w: 0.80, tr: 0.7 },
    { t: 3.5, cx: 0.5, cy: 0.625, w: 0.70, tr: 0.6 },
    { t: 5.4, cx: 0.5, cy: 0.585, w: 0.70, tr: 0.6 },
    { t: 7.4, cx: 0.5, cy: 0.31, w: 0.85, tr: 0.6 },
    { t: 9.9, cx: 0.5, cy: 0.62, w: 0.70, tr: 0.6 },
    { t: 11.3, cx: 0.5, cy: 0.27, w: 0.80, tr: 0.6 },
    { t: 12.9, cx: 0.5, cy: 0.27, w: 0.72, tr: 0.6 },
  ],

  // one margin note at a time (vt). y is a fraction of the detail panel height.
  simNotes: [
    { text: 'Opening a photo', in: 1.3, out: 2.9, y: 0.42 },
    { text: 'Noir look', in: 3.5, out: 4.7, y: 0.5 },
    { text: 'Exposure up', in: 5.5, out: 6.9, y: 0.5 },
    { text: 'Hold to compare', in: 7.5, out: 8.9, y: 0.45 },
    { text: 'Rotated', in: 10.9, out: 11.9, y: 0.5 },
    { text: 'Square crop', in: 12.6, out: 13.6, y: 0.5 },
  ],
};
