// Linear Mac sessions: every editable production constant lives here.
// Times are seconds on the composition timeline. Coordinates for the Linear
// and Devin UIs are in their own 1920x1080 space; phone focus points are
// normalized (0..1) on the Simulator screen, with crop widths as a fraction
// of the screen width.

export const VIDEO = { width: 1920, height: 1080, fps: 30, duration: 30.0 };

export const MEDIA = {
  // Frames extracted from the raw Simulator recording at VIDEO.fps
  // (see render/render.mjs). Frame 1 is the first frame of the take.
  framesDir: '../media/frames',
  framePattern: 'f%04d.jpg',
  frameCount: 641,
  sourceWidth: 1206,
  sourceHeight: 2622,
  // takeTime = compositionTime - takeOffset
  takeOffset: 13.35,
  // Real iOS home screen captured from the same Simulator (shown before launch)
  homeScreen: '../media/simulator-home.png',
  lockupWhite: '../assets/logos/devin-lockup-white.png',
  avatarWhite: '../assets/logos/devin-avatar-white.png',
  fontSans: '../assets/fonts/InterTight.ttf',
};

export const BRAND = {
  field: '#0A0A0C',
  text: '#ECECEE',
  textSecondary: '#8B8B94',
  textMuted: '#5E5E66',
  panel: '#121215',
  panelRaised: '#1A1A1F',
  hairline: 'rgba(255, 255, 255, 0.08)',
  hairlineStrong: 'rgba(255, 255, 255, 0.14)',
  accent: '#2200FF',
  accentSoft: 'rgba(96, 108, 255, 0.22)',
  accentText: '#9AA4FF',
  success: '#3DD68C',
  live: '#FF453A',
  inspectionStroke: 'rgba(255, 255, 255, 0.92)',
  inspectionLeader: 'rgba(255, 255, 255, 0.42)',
};

// Linear dark theme palette (sampled from Linear's dark appearance).
export const LINEAR = {
  bg: '#0F1011',
  panel: '#191A1C',
  panelRaised: '#1F2023',
  border: 'rgba(255, 255, 255, 0.08)',
  borderStrong: 'rgba(255, 255, 255, 0.13)',
  text: '#F7F8F8',
  textSecondary: '#8A8F98',
  textMuted: '#62666D',
  accent: '#5E6AD2',
  accentSoft: 'rgba(94, 106, 210, 0.22)',
  mentionBg: 'rgba(255, 255, 255, 0.08)',
  workspaceMark: '#3FB950',
  devinMark: '#5E6AD2',
};

export const TEXT = {
  headline: 'Mac sessions. Now from Linear.',
  endUrl: 'devin.ai',
  // Linear issue
  workspace: 'Nader',
  breadcrumb: 'My issues',
  issueId: 'NAD-41',
  issueTitle: 'Lumen Drift, a lane dodging arcade game for iPhone',
  issueDescription: 'Glowing lanes, energy pickups, pause and resume. Should run in the iOS Simulator.',
  author: 'Nader Dabit',
  authorInitials: 'ND',
  mentionQuery: '@devin',
  mentionName: 'Devin',
  mentionKind: 'Agent',
  mentionLabel: 'Devin Playbooks',
  // Typed after the mention chip; "!mac" starts the session on Devin's Mac
  command: ' !mac Build Lumen Drift, a glowing lane dodging arcade game for iPhone, and play it in the Simulator',
  composerPlaceholder: 'Leave a comment...',
  startedBy: 'started by',
  working: 'Devin is working on your request...',
  resource: 'Devin Session',
  sidebar: ['Inbox', 'My issues', 'Reviews', 'Agent'],
  workspaceItems: ['Projects', 'Views', 'More'],
  teamName: "Nader's Workspace",
  teamItems: ['Home', 'Issues', 'Projects', 'Views'],
  properties: ['Backlog', 'Set priority', 'Assign'],
  assigned: 'Nader Dabit',
  // Devin session
  sessionTitle: 'Lumen Drift for iPhone',
  sessionSource: 'Linear NAD-41',
  devinReply:
    'I will build Lumen Drift with SwiftUI and SpriteKit, then play it in the iPhone Simulator on my Mac.',
  devinFinal:
    'Lumen Drift runs in the Simulator. Steering, energy pickups, and pause and resume all work.',
  workedFor: 'Worked for 6m 48s',
  tabs: ['Progress', 'Changes', 'Computer', 'PR #241'],
  simulatorDevice: 'iPhone 17',
  simulatorOS: 'iOS 26.5',
  menuBar: ['Simulator', 'File', 'Edit', 'Device', 'I/O', 'Window'],
  menuClock: 'Sun 20 Sep  4:12 PM',
};

// Minimal build animation in the Devin pane: one status line at a time.
export const BUILD = [
  { t: 10.9, label: 'Cloning macos-experiments' },
  { t: 11.7, label: 'Generating the Xcode project' },
  { t: 12.5, label: 'Compiling Swift for the iOS Simulator' },
  { t: 13.35, label: 'Build succeeded', done: true },
];

// Timeline steps shown in the chat column (t = when the row appears).
export const STEPS = [
  { t: 10.9, label: 'Cloned macos-experiments' },
  { t: 11.7, label: 'Created LumenDrift.xcodeproj' },
  { t: 12.5, label: 'xcodebuild for iOS Simulator' },
  { t: 13.35, label: 'BUILD SUCCEEDED' },
  { t: 14.3, label: 'Booted iPhone 17 Simulator and launched the app' },
  { t: 15.75, label: 'Tapped Start endless' },
  { t: 18.35, label: 'Steered between lanes to collect energy' },
  { t: 23.85, label: 'Paused the flight' },
  { t: 25.65, label: 'Resumed the flight' },
];

export const TIMING = {
  titleIn: 0.0,
  titleOut: 2.2,       // title starts fading, Linear fades in
  linearIn: 2.3,
  mentionStart: 3.4,   // "@devin" typed
  mentionEnd: 3.85,
  popoverIn: 3.95,
  select: 4.5,         // Devin (Agent) chosen, becomes a mention chip
  typeStart: 4.7,      // command typed after the chip
  typeEnd: 7.1,
  send: 7.5,           // comment posted
  started: 8.3,        // "Devin started by Nader Dabit"
  working: 8.75,       // working row + timer
  assign: 9.05,        // assignee changes to Nader Dabit / Devin
  resource: 9.3,       // Devin Session resource appears
  linearOut: 10.45,    // crossfade Linear -> Devin session
  devinIn: 10.55,
  computerTab: 13.9,   // Simulator pane opens
  launch: 14.3,        // app launches in the Simulator (home screen -> take)
  windowIn: 15.45,
  windowOut: 25.8,
  finalMessage: 26.7,
  endIn: 27.6,         // end card crossfade begins
  endHold: 30.0,
};

// Camera over the UI layers. Each key is where the camera has arrived by time
// t: (x, y) is the UI point placed at the center of the frame and s the scale.
// `el` centers on a DOM element instead (resolved at layout time). `ease` is
// how many seconds the glide to that key takes. At s = 1 the UI fills the frame.
export const CAMERA = [
  { t: 2.3, x: 960, y: 540, s: 1.0, ease: 0 },                       // full Linear issue
  { t: 4.1, el: 'linearComposer', dx: 0, dy: -130, s: 1.6, ease: 1.0 }, // composer hero: mention and command
  { t: 8.7, x: 960, y: 540, s: 1.0, ease: 0.9 },                     // back out: activity, resource, assignee
  { t: 15.85, x: 1580, y: 540, s: 1.0, ease: 0.9 },                  // pan left: margin for the inspection window
  { t: 26.9, x: 960, y: 540, s: 1.0, ease: 0.9 },                    // return to the complete interface
];

// The single inspection window (stage px).
export const INSPECTION = {
  left: 1332,
  top: 150,
  size: 560,         // about 30% of the frame width, square
  strokeWidth: 2,
  captionTop: 770,   // dedicated text margin under the window
  captionSize: 42,
  fade: 0.35,        // caption crossfade seconds
  moveEase: 0.9,     // seconds to glide between focus regions
};

// Focus regions on the Simulator screen. cx, cy are normalized on the screen,
// w is the crop width as a fraction of the screen width (the crop is square).
// The window shows each region from its t until the next region's t.
export const FOCUS = [
  { t: 15.15, cx: 0.5, cy: 0.80, w: 0.86, caption: 'Devin taps Start endless' },
  { t: 16.65, cx: 0.5, cy: 0.70, w: 0.66, caption: 'Steers between lanes and collects energy' },
  { t: 19.55, cx: 0.29, cy: 0.15, w: 0.52, caption: 'Score climbs with every clean lane' },
  { t: 22.55, cx: 0.86, cy: 0.117, w: 0.34, caption: 'Pauses the run' },
  { t: 24.05, cx: 0.5, cy: 0.535, w: 0.86, caption: 'Resumes from the pause menu' },
];

// Cursor path (UI coordinates, shared by both layers). "el" entries resolve
// against DOM elements, "phone" entries against the Simulator screen.
export const CURSOR = [
  { t: 2.3, x: 1500, y: 700 },
  { t: 3.3, el: 'linearComposerText', dx: 60, dy: 10 },
  { t: 7.05, el: 'linearComposerText', dx: 60, dy: 10 },
  { t: 7.45, el: 'linearSend' },
  { t: 8.2, el: 'linearSend' },
  { t: 9.6, x: 1420, y: 900 },
  { t: 10.4, x: 1420, y: 900 },
  { t: 11.2, x: 1300, y: 760 },
  { t: 13.4, x: 1300, y: 760 },
  { t: 13.85, tab: 2 },                       // Computer tab
  { t: 14.65, tab: 2 },
  { t: 15.25, phone: [0.5, 0.809] },          // Start endless (tap at 15.37)
  { t: 17.55, phone: [0.5, 0.809] },
  { t: 17.95, phone: [0.2, 0.883] },          // lane LEFT (tap at 17.98)
  { t: 20.55, phone: [0.2, 0.883] },
  { t: 20.9, phone: [0.5, 0.883] },           // lane CENTER (tap at 20.91)
  { t: 22.95, phone: [0.5, 0.883] },
  { t: 23.4, phone: [0.88, 0.117] },          // pause (tap at 23.42)
  { t: 24.75, phone: [0.88, 0.117] },
  { t: 25.23, phone: [0.5, 0.527] },          // resume (tap at 25.25)
  { t: 25.45, phone: [0.5, 0.527] },
  { t: 25.69, phone: [0.8, 0.883] },          // lane RIGHT (tap at 25.69)
  { t: 27.15, phone: [0.8, 0.883] },
  { t: 27.5, phone: [0.5, 0.883] },           // lane CENTER (tap at 27.49)
  { t: 27.95, phone: [0.5, 0.883] },
  { t: 28.2, phone: [0.2, 0.883] },           // lane LEFT (tap at 28.17)
  { t: 28.4, phone: [0.2, 0.883] },
  { t: 28.57, phone: [0.8, 0.883] },          // lane RIGHT (tap at 28.55)
];

// Devin UI layout (UI space). The phone screen is derived from these.
export const LAYOUT = {
  chatWidth: 620,
  headerHeight: 64,
  macScreen: { x: 650, y: 80, w: 1240, h: 980 },
  menuBarHeight: 34,
  simToolbar: { w: 300, h: 44, top: 20 },
  phone: { screenW: 386, bezel: 14, radiusOuter: 64, top: 76 },
};

// Linear layout (UI space).
export const LINEAR_LAYOUT = {
  sidebarWidth: 300,
  panelInset: 12,
  headerHeight: 68,
  mainLeft: 72,
  mainWidth: 900,
  propertiesLeft: 1040,
};
