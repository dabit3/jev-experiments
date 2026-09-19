// Editable constants for the terminal-first launch video.
// Everything the composition reads lives here: timings, copy, media paths, brand tokens.

export const OUTPUT = {
  width: 1920,
  height: 1080,
  fps: 30,
  durationSeconds: 29.0,
};

// Brand tokens (dark theme). Accent blue and ink come from the Devin Figma file.
export const BRAND = {
  field: '#0f0f11',        // deep dark brand field behind everything
  fieldEdge: '#08080a',
  ink: '#191919',
  text: '#f4f4f5',
  textMuted: 'rgba(244,244,245,0.56)',
  textFaint: 'rgba(244,244,245,0.32)',
  accent: '#2200ff',
  accentSoft: '#7b6cff',   // readable accent for text on dark
  green: '#3ddc84',
  panel: '#17171a',
  panelRaised: '#1d1d21',
  line: 'rgba(255,255,255,0.08)',
  lineStrong: 'rgba(255,255,255,0.14)',
  fontSans: '"Inter Tight", "Helvetica Neue", Helvetica, Arial, sans-serif',
  fontMono: '"JetBrains Mono", Menlo, monospace',
};

export const MEDIA = {
  lockup: '../assets/devin-lockup-white.png',
  avatar: '../assets/devin-avatar-white.png',
  // Frame sequence extracted from footage/rtx-afterdark-simulator-take.mp4 by render.mjs.
  footageFramesDir: '../build/footage',
  footageFramePattern: 'f%05d.png',
  footageFrameCount: 420,
  // Where in the raw take the frame sequence starts (seconds) and how many seconds to extract.
  footageInSeconds: 10.5,
  footageSeconds: 14.0,
};

export const COPY = {
  headline: 'macOS. Now in Devin Cloud.',
  sessionTitle: 'Build RTX Afterdark for iPhone',
  prompt: 'Build RTX Afterdark, a night driving arcade game for iPhone, run it in the Simulator and verify pause and resume',
  composerPlaceholder: 'Ask Devin to build features, fix bugs, or work on your code',
  environment: 'macOS',
  devinPlan: 'I will build RTX Afterdark in Swift, run it in the iOS Simulator on this Mac and verify pause and resume.',
  buildFile: 'GameSession.swift',
  // Genuine xcodebuild result captured while building this app on the Devin Mac.
  buildResult: '** BUILD SUCCEEDED **',
  steps: [
    { at: 13.2, text: 'Launching RTX Afterdark in the iOS Simulator' },
    { at: 16.2, text: 'Driving: steering, boost and brake respond' },
    { at: 21.9, text: 'Tapping Pause run' },
    { at: 23.0, text: 'Pause menu shows RESUME' },
    { at: 25.0, text: 'Tapping RESUME, the run continues' },
  ],
  result: 'RTX Afterdark builds, runs in the Simulator, and pause and resume work.',
  sectionLabels: [
    { at: 8.9, text: 'build' },
    { at: 12.8, text: 'run in the simulator' },
    { at: 21.4, text: 'verify pause and resume' },
    { at: 26.0, text: 'delivered' },
  ],
  cta: 'devin.ai',
};

// Real code from ios-rtx-afterdark/Sources/GameSession.swift, typed into the editor view.
export const CODE_LINES = [
  { t: [{ k: 'kw', s: 'func' }, { k: 'fn', s: ' pause' }, { k: 'p', s: '() {' }] },
  { t: [{ k: 'p', s: '    ' }, { k: 'kw', s: 'guard' }, { k: 'p', s: ' race.phase == ' }, { k: 'en', s: '.racing' }, { k: 'p', s: ' ' }, { k: 'kw', s: 'else' }, { k: 'p', s: ' { ' }, { k: 'kw', s: 'return' }, { k: 'p', s: ' }' }] },
  { t: [{ k: 'p', s: '    clearControls()' }] },
  { t: [{ k: 'p', s: '    race.phase = ' }, { k: 'en', s: '.paused' }] },
  { t: [{ k: 'p', s: '    audio.update(enabled: ' }, { k: 'kw', s: 'false' }, { k: 'p', s: ', speed: ' }, { k: 'num', s: '0' }, { k: 'p', s: ', boosting: ' }, { k: 'kw', s: 'false' }, { k: 'p', s: ')' }] },
  { t: [{ k: 'p', s: '}' }] },
  { t: [] },
  { t: [{ k: 'kw', s: 'func' }, { k: 'fn', s: ' resume' }, { k: 'p', s: '() {' }] },
  { t: [{ k: 'p', s: '    race.phase = ' }, { k: 'en', s: '.racing' }] },
  { t: [{ k: 'p', s: '}' }] },
  { t: [] },
  { t: [{ k: 'kw', s: 'func' }, { k: 'fn', s: ' menu' }, { k: 'p', s: '() {' }] },
  { t: [{ k: 'p', s: '    clearControls()' }] },
  { t: [{ k: 'p', s: '    race.preview(' }, { k: 'en', s: '.harbor' }, { k: 'p', s: ')' }] },
  { t: [{ k: 'p', s: '    race.phase = ' }, { k: 'en', s: '.title' }] },
  { t: [{ k: 'p', s: '    showGuide = ' }, { k: 'kw', s: 'false' }] },
  { t: [{ k: 'p', s: '}' }] },
];

// Timeline (seconds). Each scene is a window in which its animation runs.
export const T = {
  // Opening statement
  logoIn: [0.0, 0.7],
  headlineType: [0.55, 2.3],
  openingOut: [3.0, 3.55],
  // Caret drops and expands into the product window
  caretToLine: [3.15, 3.7],
  lineToWindow: [3.6, 4.35],
  uiIn: [4.05, 4.5],
  // Prompt
  promptType: [4.9, 7.9],
  cursorToSend: [8.0, 8.55],
  sendClick: 8.6,
  // Build
  planIn: 9.0,
  editorIn: [8.95, 9.45],
  codeType: [9.15, 11.7],
  buildResultIn: 11.9,
  // Run
  computerIn: [12.8, 13.3],
  footageStart: 13.0,
  // Result
  resultIn: 26.1,
  windowToLine: [27.0, 27.55],
  lineOut: [27.5, 27.85],
  // End card
  endIn: [27.7, 28.4],
};

// Camera keyframes: [time, cx, cy, scale]. Interpolated with smooth easing.
export const CAMERA = [
  [0.0, 960, 540, 1.0],
  [8.7, 960, 540, 1.0],    // home composer is already the hero at 1x
  [9.5, 1280, 575, 1.72],  // Swift editor fills the frame while code types (view = right pane width)
  [11.7, 1280, 575, 1.72],
  [12.2, 1280, 684, 1.72], // settle on the build result line
  [12.8, 1280, 684, 1.72],
  [13.9, 1134, 590, 1.36], // simulator running
  [21.4, 1134, 590, 1.36],
  [22.2, 1247, 600, 1.62], // pause menu
  [24.6, 1247, 600, 1.62],
  [25.4, 1134, 590, 1.36],
  [26.0, 1134, 590, 1.36],
  [26.9, 960, 540, 1.0],
];
