// Luxury Editorial launch video: every editable constant lives here.
// Timings are seconds on the master timeline. Scenes are contiguous and
// transitions overlap by TRANSITION seconds.

export const VIDEO = { width: 1920, height: 1080, fps: 30 };

export const TOKENS = {
  field: '#0b0b0d',          // deep dark brand field
  fieldSoft: '#111114',
  ink: '#f2f1ec',            // editorial off-white
  inkMuted: 'rgba(242,241,236,0.56)',
  inkFaint: 'rgba(242,241,236,0.28)',
  hairline: 'rgba(242,241,236,0.12)',
  // Reconstructed Devin UI, dark theme
  ui: {
    bg: '#101013',
    panel: '#18181c',
    panelRaised: '#222227',
    border: 'rgba(255,255,255,0.11)',
    text: '#ececea',
    textMuted: '#8b8b8f',
    accent: '#5b6cff',       // brand blue lifted for dark surfaces (brand: #2200ff)
    success: '#4ccf8a',
  },
  fontSans: "'Inter Tight', 'Helvetica Neue', Helvetica, Arial, sans-serif",
  fontMono: "'JetBrains Mono', 'SF Mono', Menlo, monospace",
};

// Real Aster recording, extracted to JPEG frames at 30 fps starting at REC.offset seconds.
// Frame i (1-based) corresponds to recording time offset + (i-1)/fps.
export const REC = {
  dir: 'media/rec',
  offset: 12,
  fps: 30,
  frames: 540,
  width: 1600,
  height: 1200,
  // Aster window rect inside the desktop capture
  win: { x: 80, y: 80, w: 1440, h: 960 },
  // Approximate globe centre inside the desktop capture (for the cover crop)
  globe: { x: 615, y: 545 },
};

export const TRANSITION = 0.55;

export const SCENES = {
  cover:   { start: 0.0,  end: 3.6,  rec: 22.6 },
  prompt:  { start: 3.6,  end: 8.6 },
  code:    { start: 8.6,  end: 12.6 },
  session: { start: 12.6, end: 20.4, rec: 13.2 },
  demo:    { start: 20.4, end: 25.2, rec: 21.0 },
  result:  { start: 25.2, end: 27.4, rec: 27.0 },
  close:   { start: 27.4, end: 29.6 },
};
export const DURATION = SCENES.close.end;

export const COPY = {
  headline: ['macOS.', 'Now in', 'Devin Cloud.'],
  prompt: 'Build Aster, an orbital mechanics lab for macOS, and run it on the Mac',
  promptLede: 'One request.',
  codeLede: 'Devin writes the Swift.',
  sessionTitle: 'Build Aster for macOS',
  steps: [
    { at: 12.6, text: 'Cloned macos-experiments and read the Aster README', done: 12.6 },
    { at: 12.6, text: 'swift build -c release succeeded', done: 12.6 },
    { at: 12.6, text: 'Launched Aster.app on the Mac desktop', done: 12.6 },
    { at: 13.2, text: 'Loading the departure recipe', done: 16.6 },
    { at: 16.8, text: 'Executing the 460 m/s prograde burn', done: 18.4 },
    { at: 18.6, text: 'Burn complete. Resuming flight', done: 20.4 },
  ],
  demoWord: 'Live.',
  resultLede: 'Objective achieved.',
  cta: 'devin.ai',
};

export const MEDIA = {
  lockup: 'assets/devin-lockup-white.png',
  avatar: 'assets/devin-avatar-white.png',
};

// Swift shown in the editor scene (from aster/Sources/AsterCore/Orbit.swift, abridged)
export const CODE = [
  'public enum Orbit {',
  '  public static let mu = 398_600.4418',
  '  public static let earthRadius = 6_371.0',
  '  public static let goalAltitude = 2_400.0',
  '',
  '  public static func circular(altitude: Double = 450) -> FlightState {',
  '    let radius = earthRadius + altitude',
  '    return FlightState(position: Vector(radius, 0),',
  '                       velocity: Vector(0, sqrt(mu / radius)))',
  '  }',
  '',
  '  public static func burn(_ state: FlightState,',
  '                          prograde: Double, radial: Double) -> FlightState {',
  '    var next = state',
  '    next.velocity =',
  '      state.velocity + state.velocity.unit * (prograde / 1_000)',
  '      + state.position.unit * (radial / 1_000)',
  '    return next',
  '  }',
  '',
  '  public static func goalMet(_ state: FlightState) -> Bool {',
  '    let orbit = elements(state)',
  '    guard let apoapsis = orbit.apoapsis else { return false }',
  '    return !state.impacted',
  '      && abs(apoapsis - goalAltitude) <= 120',
  '      && orbit.periapsis >= 300',
  '  }',
  '}',
];
