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
    composer: 3.4,
    code: 8.8,
    session: 12.4,
    both: 19.6,
    test: 23.4,
    result: 26.2,
    end: 27.8,
  },

  // Copy (no em dashes anywhere)
  copy: {
    headline: ["macOS.", "Now in Devin Cloud."],
    prompt: "Build VoxelHearth, a voxel sandbox for macOS and iPhone with shared worlds, and run both",
    captions: {
      composer: "Ask for a Mac and iPhone app.",
      environment: "Pick macOS as the environment.",
      code: "Devin writes the Swift.",
      session: "VoxelHearth runs on Devin's Mac.",
      both: "The iPhone build joins the same world.",
      test: "Devin plays both. Blocks placed, camera moved.",
    },
    sessionTitle: "Build VoxelHearth",
    devinReply: "Building VoxelHearth for macOS and iPhone. I will run the Mac app on the desktop and the iPhone app in the Simulator, then play both in the shared world.",
    devinTest: "Tested both. Blocks placed and camera moved on the Mac and on the iPhone, in one shared world.",
    working: "Devin is working",
    awaiting: "Devin is awaiting instructions",
    result: ["Built, run and tested", "on a Mac in Devin Cloud."],
    cta: "devin.ai",
    buildStatus: ["Build Succeeded", "VoxelHearth-macOS", "VoxelHearth-iOS"],
  },
};
