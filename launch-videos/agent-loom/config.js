// Agent Loom launch video: every editable constant lives here.
// Times are seconds on the master timeline. Coordinates are 1920x1080 stage pixels
// unless noted as fractions of the phone screen (fx, fy).

const CONFIG = {
  fps: 30,
  duration: 29.8,
  width: 1920,
  height: 1080,

  colors: {
    paper: '#F4F0E8',
    ink: '#15130F',
    blue: '#2E62F5',
    uiText: '#111214',
    uiMuted: '#6B7280',
    uiPanel: '#F3F4F6',
    uiBorder: 'rgba(17,18,20,0.08)',
  },

  text: {
    headline1: 'macOS.',
    headline2: 'Now in Devin Cloud.',
    silverRequest: 'Build Silverroom, a photo darkroom for iPhone with Noir and Silver looks, then test it in the Simulator',
    rtxRequest: 'Build RTX Afterdark, a night driving arcade game for iPhone, run it in the Simulator and verify pause and resume',
    sessionTitle1: 'Silverroom for iPhone',
    sessionTitle2: 'RTX Afterdark for iPhone',
    devin1: 'Building Silverroom in Xcode, then testing it in the Simulator.',
    devin2: 'Running RTX Afterdark in the Simulator to verify pause and resume.',
    steps1: [
      [10.7, 'Opened a photo'],
      [12.2, 'Chose the Noir look'],
      [13.9, 'Dragged exposure'],
      [15.1, 'Held to compare'],
      [17.7, 'Rotated and cropped square'],
    ],
    steps2: [
      [19.6, 'Driving through Neon Harbor'],
      [21.8, 'Paused the run'],
      [23.8, 'Pressed Resume'],
    ],
    outcome: 'Built, run and tested on Devin\u2019s Mac.',
    url: 'devin.ai',
    hostedBefore: 'Ubuntu',
    hostedAfter: 'macOS',
    codeFile: 'Models.swift',
  },

  // Real Swift from Silverroom/Models.swift, shown in the reconstructed editor.
  code: [
    ['kw', 'enum'], ['ty', ' Film'], ['op', ': '], ['ty', 'String'], ['op', ', '], ['ty', 'Codable'], ['op', ', '], ['ty', 'CaseIterable'], ['op', ' {'], ['nl'],
    ['op', '  '], ['kw', 'case'], ['op', ' original, silver, noir, dune, faded'], ['nl'],
    ['nl'],
    ['op', '  '], ['kw', 'var'], ['op', ' title: '], ['ty', 'String'], ['op', ' {'], ['nl'],
    ['op', '    '], ['kw', 'switch'], ['op', ' '], ['kw', 'self'], ['op', ' {'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .original: '], ['st', '"Original"'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .silver: '], ['st', '"Silver"'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .noir: '], ['st', '"Noir"'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .dune: '], ['st', '"Dune"'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .faded: '], ['st', '"Faded"'], ['nl'],
    ['op', '    }'], ['nl'],
    ['op', '  }'], ['nl'],
    ['nl'],
    ['op', '  '], ['kw', 'var'], ['op', ' note: '], ['ty', 'String'], ['op', ' {'], ['nl'],
    ['op', '    '], ['kw', 'switch'], ['op', ' '], ['kw', 'self'], ['op', ' {'], ['nl'],
    ['op', '    '], ['kw', 'case'], ['op', ' .noir: '], ['st', '"Deep blacks. A little more drama."'], ['nl'],
  ],

  media: {
    silverDir: 'media/silver/',
    silverFrames: 261,
    rtxDir: 'media/rtx/',
    rtxFrames: 197,
    lockup: 'media/logo/lockup-black.png',
    mark: 'media/logo/mark-black.png',
  },

  t: {
    // Scene A: headline
    hlWordStart: 0.25, hlWordStep: 0.16, hlWordDur: 0.5,
    hlExit: 2.15, hlExitDur: 0.5,

    // Scene B: composer
    cRise: 2.45, cRiseDur: 0.65, cPartLag: [0.10, 0.18, 0.25],
    cursorIn: 3.15, cursorToHosted: 3.75,
    menuOpen: 3.82, menuDur: 0.28,
    camPushIn: 3.7, camPushInDur: 0.6, camZoom: 1.34,
    cursorToMac: 4.15, cursorMacArrive: 4.55, macSelect: 4.62,
    menuClose: 4.85, camBack: 4.9, camBackDur: 0.7,
    cursorToInput: 4.95, cursorInputArrive: 5.35, cursorHide: 5.45,
    typeStart: 5.35, typeEnd: 7.85,
    cursorToSubmit: 7.75, cursorSubmitArrive: 8.1, submitPress: 8.15, submitPressDur: 0.22,
    cExit: 8.35, cExitDur: 0.5,

    // Scene C: session
    sRise: 8.4, sRiseDur: 0.7,
    codeStart: 8.5, codeEnd: 9.95,
    editorOut: 9.85, editorOutDur: 0.6,
    silverStart: 10.15,
    blueDraw: 10.1, blueDrawDur: 1.5,
    rotateStart: 18.35, rotateDur: 0.6,
    rtxStart: 18.9,
    inkDraw: 18.9, inkDrawDur: 1.4,
    chatSwap: 18.5,
    sExit: 25.05, sExitDur: 0.6,

    // Camera pushes in the session: fx/fy are fractions of the phone screen.
    pushZoom: 1.2, pushIn: 0.38, pushOut: 0.45, drift: 0.025,
    pushes: [
      { t: 11.7, d: 1.2, fx: 0.50, fy: 0.66 },  // Noir in the Looks strip
      { t: 13.4, d: 1.3, fx: 0.62, fy: 0.71 },  // exposure slider
      { t: 14.75, d: 1.3, fx: 0.86, fy: 0.50 }, // hold to compare, release
      { t: 16.5, d: 1.0, fx: 0.52, fy: 0.78 },  // Frame tools, rotate
      { t: 17.6, d: 1.0, fx: 0.86, fy: 0.78 },  // square crop
      { t: 19.4, d: 1.0, fx: 0.14, fy: 0.84 },  // steering
      { t: 21.1, d: 1.3, fx: 0.95, fy: 0.12 },  // pause
      { t: 23.1, d: 1.3, fx: 0.42, fy: 0.60 },  // resume
    ],

    // Scene D: weave
    wLeadStart: 25.2, wLeadDur: 0.6,
    wGridStart: 25.55, wGridDur: 1.4,
    outcomesIn: 26.0, outcomesInDur: 0.6,
    outTextIn: 26.25, outTextDur: 0.5,
    wExit: 27.6, wExitDur: 0.5,

    // Scene E: end card
    logoIn: 28.0, logoDur: 0.6,
    urlIn: 28.16, urlDur: 0.6,
  },

  layout: {
    composer: { left: 340, top: 316, width: 1240 },
    session: { left: 80, top: 60, width: 1760, height: 960, chatWidth: 640 },
    phoneScale: 0.9,
    outcome: { portraitScale: 0.68, landscapeScale: 0.96, gap: 96, centerY: 620 },
    weave: { x0: 220, x1: 1700, y0: 330, y1: 910, stepX: 185, stepY: 145, stroke: 12, cross: 22 },
  },
};

if (typeof module !== 'undefined') module.exports = CONFIG;
