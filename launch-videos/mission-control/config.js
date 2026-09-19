// Mission Control launch video. Every editable constant lives here.
// Times are seconds on the composition timeline. Frame paths are relative to index.html.

window.CONFIG = {
  fps: 30,
  width: 1920,
  height: 1080,
  duration: 28,

  colors: {
    field: "#08090b",          // deep dark brand field
    fieldGlow: "#12151c",
    text: "#f4f4f5",
    muted: "#8b8f98",
    faint: "#4b4f58",
    panel: "#131417",
    panelEdge: "rgba(255,255,255,0.07)",
    side: "#0f1013",
    bubble: "#1c1d22",
    chip: "rgba(59,130,246,0.16)",
    chipText: "#7fb0ff",
    accent: "#3b82f6",
    green: "#3dd68c",
    desktopTop: "#1a2140",
    desktopBottom: "#0b0d17",
    code: {
      bg: "#0e0f12",
      keyword: "#ff7ab2",
      type: "#7ee1ff",
      fn: "#b9a4ff",
      string: "#ffd28a",
      comment: "#5c6370",
      plain: "#e6e6e9",
      lineNo: "#3a3d45",
    },
  },

  // Real recordings, pre extracted to 30 fps JPEG sequences by extract-frames.sh
  clips: {
    rtx:   { dir: "frames/rtx",   frames: 450, w: 1200, h: 552, sourceStart: 27.0 },
    lumen: { dir: "frames/lumen", frames: 450, w: 414,  h: 900, sourceStart: 13.0 },
    aster: { dir: "frames/aster", frames: 450, w: 1400, h: 900, sourceStart: 6.5 },
  },

  // Panel geometry in stage pixels. The primary display stays put; bays start as
  // small status tiles during the request and expand to full bays when it is sent.
  layout: {
    primary: { x: 60, y: 52, w: 1240, h: 880 },
    bayFull: [{ x: 1330, y: 52, w: 530, h: 412 }, { x: 1330, y: 520, w: 530, h: 412 }],
    bayTile: [{ x: 1330, y: 52, w: 530, h: 124 }, { x: 1330, y: 204, w: 530, h: 124 }],
    // Push-in on the Simulator: how much of the frame width the phone should span
    zoomPhoneWidth: 0.78,
    zoomTopInset: 6,        // primary panel top edge while pushed in
    zoomBottomLimit: 984,   // phone bottom must stay above the caption
  },

  // Stage boundaries. The primary display and both bays move through them together.
  t: {
    titleIn: 0.0,
    titleOut: 2.5,
    layoutIn: 2.7,
    envOpen: 3.5,     // environment menu opens in the composer
    envPick: 4.15,    // cursor clicks macOS
    typeStart: 4.6,   // typing the request
    send: 6.95,       // request sent, home composer becomes the session view
    building: 7.9,    // Changes tab, Swift being written
    running: 11.9,    // Computer tab, real recordings start
    result: 23.4,     // Devin reports the verified result
    hero: 24.0,       // bays consolidate away, primary becomes the hero
    endIn: 26.3,      // end card starts crossfading in
    end: 28.0,
    // Camera push-ins on the primary Simulator: [in start, in end, out start, out end]
    zooms: [
      [12.4, 13.3, 15.4, 16.3],   // playing
      [17.6, 18.3, 19.4, 20.1],   // pause (pause menu appears at 18.4)
      [20.7, 21.4, 23.2, 24.3],   // resume (driving again at 21.4)
    ],
  },

  // Caption under the primary display. Each entry replaces the previous one.
  captions: [
    { t: 3.3,  text: "Pick macOS, ask for a native iPhone game" },
    { t: 7.9,  text: "Devin writes the Swift" },
    { t: 11.9, text: "Devin plays it in the iOS Simulator" },
    { t: 18.1, text: "Pauses the run" },
    { t: 21.1, text: "Resumes and verifies it" },
    { t: 24.2, text: "Built, run and verified on a Mac in Devin Cloud" },
  ],

  // Short stage word shown on each bay, in a fixed position.
  bayStatus: [
    { t: 2.7,  text: "Request" },
    { t: 7.9,  text: "Building" },
    { t: 11.9, text: "Running" },
    { t: 23.4, text: "Verified" },
  ],

  headline: "macOS. Now in Devin Cloud.",
  environments: ["Linux", "macOS"],
  endUrl: "devin.ai",

  sessions: {
    rtx: {
      app: "RTX Afterdark",
      device: "iphone-landscape",
      clip: "rtx",
      prompt: "Build RTX Afterdark, a night driving arcade game for iPhone, run it in the Simulator and verify pause and resume",
      reply: "On it. Building it in SwiftUI, then running it in the iPhone 17 Simulator.",
      finalReply: "RTX Afterdark runs in the Simulator. Pause and resume verified.",
      file: "GameSession.swift",
      code: [
        "final class GameSession: ObservableObject {",
        "    @Published var race = RaceEngine()",
        "    @Published var steering = 0.0",
        "    @Published var boostHeld = false",
        "    private let audio = EngineAudio()",
        "",
        "    func pause() {",
        "        guard race.phase == .racing",
        "        else { return }",
        "        clearControls()",
        "        race.phase = .paused",
        "        audio.update(enabled: false,",
        "                     speed: 0)",
        "    }",
        "",
        "    func resume() {",
        "        race.phase = .racing",
        "    }",
        "}",
      ],
      // Timeline items in the chat. Items appear at these times.
      steps: [
        { t: 8.1,  text: "Created RTXAfterdarkApp.swift", diff: "+38" },
        { t: 8.8,  text: "Created RaceEngine.swift", diff: "+212" },
        { t: 9.5,  text: "Created RoadRenderer.swift", diff: "+164" },
        { t: 10.2, text: "Created GameSession.swift", diff: "+131" },
        { t: 11.0, text: "Built for the iPhone 17 Simulator" },
        { t: 12.1, text: "Launched it in the Simulator" },
        { t: 13.1, text: "Tapped Start Run and drove" },
        { t: 18.5, text: "Tapped pause, menu shown" },
        { t: 21.5, text: "Tapped Resume, driving again" },
      ],
    },
    lumen: {
      app: "Lumen Drift",
      blurb: "Native iPhone arcade game",
      device: "iphone-portrait",
      clip: "lumen",
      file: "GameScene.swift",
      code: [
        "final class GameScene: SKScene {",
        "    let ship = ShipNode()",
        "    var lane = 1",
        "",
        "    func shift(to next: Int) {",
        "        lane = clamp(next, 0, 2)",
        "        ship.run(.moveTo(x: laneX(lane),",
        "                         duration: 0.12))",
        "    }",
      ],
    },
    aster: {
      app: "Aster",
      blurb: "Native macOS orbital lab",
      device: "mac",
      clip: "aster",
      file: "MissionController.swift",
      code: [
        "final class MissionController {",
        "    var probe = Orbit.leo",
        "",
        "    func burn(dv: Double) {",
        "        probe.velocity +=",
        "            probe.heading * dv",
        "        recompute()",
        "    }",
        "}",
      ],
    },
  },

  // Reconstructed macOS desktop chrome inside the Computer pane
  mac: {
    finderMenu: ["Finder", "File", "Edit", "View", "Go", "Window", "Help"],
    simulatorMenu: ["Simulator", "File", "Edit", "Device", "I/O", "Features", "Debug", "Window", "Help"],
    clock: "Thu 17 Sep  11:41 PM",
  },
};
