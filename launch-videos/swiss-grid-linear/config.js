// Editable constants for the Swiss Grid launch video.
// Times are seconds, sizes are pixels in the 1920x1080 frame.
window.CONFIG = {
  fps: 30,
  duration: 30,
  width: 1920,
  height: 1080,

  // Brand tokens
  color: {
    field: "#0B0B0D",
    ink: "#F4F4F2",
    muted: "#9A9AA2",
    rule: "rgba(255,255,255,0.09)",
    uiBg: "#FFFFFF",
    uiInk: "#1C1C1E",
    uiMuted: "#7A7A80",
    uiLine: "#E6E6E8",
    uiSoft: "#F2F2F3",
    uiBlue: "#3B6EF6",
    uiBlueSoft: "#EAF0FF",
    uiOrange: "#E8862B",
    editorBg: "#141417",
    editorLine: "#242429",
  },
  font: {
    family: "InterTight, 'Inter Tight', 'Helvetica Neue', Helvetica, Arial, sans-serif",
    mono: "'SF Mono', Menlo, Consolas, monospace",
  },

  // Grid: 12 columns, 96px margins, 24px gutters, 122px columns (step 146)
  grid: { margin: 96, gutter: 24, col: 122, top: 84, bottom: 996 },

  // Media (paths relative to index.html). Frames are extracted by extract-frames.sh
  media: {
    macFrames: "frames/mac/",       // %04d.jpg starting at 0001
    macFrameCount: 438,
    iosFrames: "frames/ios/",
    iosFrameCount: 216,
    // Where the real footage starts inside the raw recordings (used by extract-frames.sh)
    macRawOffset: 0.8,
    iosRawOffset: 18.2,
  },

  // Mac footage crop inside the Devin computer pane (cover mode). Footage is 4:3.
  macCrop: { coverWidth: 1680, offsetY: -50, zoomScale: 1.2, zoomOriginX: "50%", zoomOriginY: "40%" },

  // Scene timings (start seconds)
  t: {
    open: 0.0,
    composer: 3.4,   // Linear issue beat
    code: 9.8,       // build state beat (replaces the code editor)
    session: 13.2,
    both: 20.0,
    test: 23.8,
    result: 26.4,
    end: 28.0,
  },

  // Copy (no em dashes anywhere)
  copy: {
    headline: ["macOS.", "Now from Linear."],
    // Linear comment: mention + command + request. The mention is rendered as a Linear chip.
    mention: "@devin",
    command: "!mac",
    prompt: "Build VoxelHearth, a voxel sandbox for macOS and iPhone with shared worlds, and run both",
    linear: {
      key: "VOX-12",
      title: "VoxelHearth for macOS and iPhone",
      description: "A voxel sandbox with shared worlds. Native macOS app plus an iPhone build against the same world server.",
      starting: "Starting Mac session...",
    },
    buildTitle: "Devin is building.",
    buildSteps: ["Clone macos-experiments", "Resolve Swift packages", "Build VoxelHearth for macOS", "Build VoxelHearth for iPhone"],
    captions: {
      composer: "Mention Devin in a Linear issue.",
      environment: "!mac starts a Mac session.",
      code: "Devin builds both targets.",
      session: "VoxelHearth runs on Devin's Mac.",
      both: "The iPhone build joins the same world.",
      test: "Devin plays both. Blocks placed, camera moved.",
    },
    sessionTitle: "VOX-12 VoxelHearth",
    devinReply: "Building VoxelHearth for macOS and iPhone. I will run the Mac app on the desktop and the iPhone app in the Simulator, then play both in the shared world.",
    devinTest: "Tested both. Blocks placed and camera moved on the Mac and on the iPhone, in one shared world.",
    working: "Devin is working",
    awaiting: "Devin is awaiting instructions",
    result: ["Built, run and tested", "from a Linear issue."],
    cta: "devin.ai",
    buildStatus: ["Build Succeeded", "VoxelHearth-macOS", "VoxelHearth-iOS"],
  },
};
