// Lumen Drift autopilot: observes the Simulator screen, finds the nearest wave,
// and taps the lane button that collects the energy cell (never the hazard lane).
// Usage: autopilot <seconds> [tap x y]   (x, y normalized 0...1 on the phone screen)
import CoreGraphics
import Foundation
import ImageIO

// Phone screen rectangle inside the display, in the 1024x768 reference space.
let phoneX = 383.0, phoneY = 88.0, phoneW = 258.0, phoneH = 560.0
let display = CGDisplayBounds(CGMainDisplayID())
let sx = display.width / 1024.0, sy = display.height / 768.0

func tap(_ nx: Double, _ ny: Double) {
  let p = CGPoint(x: (phoneX + nx * phoneW) * sx, y: (phoneY + ny * phoneH) * sy)
  let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)
  move?.post(tap: .cghidEventTap)
  usleep(30_000)
  let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)
  let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)
  down?.post(tap: .cghidEventTap)
  usleep(60_000)
  up?.post(tap: .cghidEventTap)
}

func screenshot() -> CGImage? {
  let path = "/tmp/lumen-autopilot.png"
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
  task.arguments = ["simctl", "io", "booted", "screenshot", "--type=png", path]
  task.standardError = FileHandle.nullDevice
  task.standardOutput = FileHandle.nullDevice
  try? task.run()
  task.waitUntilExit()
  guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

struct Observation { var hazard: Int?; var energy: Int?; var y: Double }

func observe(_ img: CGImage) -> Observation? {
  let w = img.width, h = img.height
  guard let data = img.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return nil }
  let bpr = img.bytesPerRow, bpp = img.bitsPerPixel / 8
  let alphaFirst = img.alphaInfo == .first || img.alphaInfo == .premultipliedFirst || img.alphaInfo == .noneSkipFirst
  let littleEndian = img.bitmapInfo.contains(.byteOrder32Little)
  func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
    let o = y * bpr + x * bpp
    let b0 = Int(ptr[o]), b1 = Int(ptr[o + 1]), b2 = Int(ptr[o + 2]), b3 = Int(ptr[o + 3])
    if littleEndian { return alphaFirst ? (b2, b1, b0) : (b3, b2, b1) }
    return alphaFirst ? (b1, b2, b3) : (b0, b1, b2)
  }
  let y0 = Int(Double(h) * 0.44), y1 = Int(Double(h) * 0.66)
  let x0 = Int(Double(w) * 0.08), x1 = Int(Double(w) * 0.92)
  var coral: [(Int, Int)] = []
  var white: [(Int, Int)] = []
  var y = y0
  while y < y1 {
    var x = x0
    while x < x1 {
      let (r, g, b) = rgb(x, y)
      if r > 225 && g < 120 && b < 150 && g > 40 { coral.append((x, y)) }
      if r > 240 && g > 240 && b > 240 { white.append((x, y)) }
      x += 3
    }
    y += 3
  }
  guard let nearest = coral.map({ $0.1 }).max() else { return nil }
  let band = coral.filter { abs($0.1 - nearest) < h / 22 }
  guard band.count > 4 else { return nil }
  let hx = Double(band.map { $0.0 }.reduce(0, +)) / Double(band.count) / Double(w)
  let eband = white.filter { abs($0.1 - nearest) < h / 22 }
  var ex: Double? = nil
  if eband.count > 3 { ex = Double(eband.map { $0.0 }.reduce(0, +)) / Double(eband.count) / Double(w) }
  func lane(_ fx: Double) -> Int { fx < 0.45 ? 0 : (fx > 0.55 ? 2 : 1) }
  return Observation(hazard: lane(hx), energy: ex.map(lane), y: Double(nearest) / Double(h))
}

let args = CommandLine.arguments
if args.count >= 4, args[1] == "tap" {
  tap(Double(args[2])!, Double(args[3])!)
  exit(0)
}
let seconds = Double(args.count > 1 ? args[1] : "20") ?? 20
let t0 = args.count > 2 ? (Double(args[2]) ?? Date().timeIntervalSince1970) : Date().timeIntervalSince1970
let laneX = [0.2, 0.5, 0.8], laneY = 0.883
var current = 1
var handled = -1.0
let end = Date().addingTimeInterval(seconds)
while Date() < end {
  guard let img = screenshot(), let obs = observe(img), let hazard = obs.hazard else { usleep(80_000); continue }
  var target = current
  if let e = obs.energy, e != hazard { target = e }
  else if hazard == 1 { target = current == 1 ? 0 : current }
  else { target = 1 }
  if target != current || hazard == current {
    if target == hazard { target = (hazard + 1) % 3 }
    tap(laneX[target], laneY)
    print(String(format: "TAP_LANE%d %.2f  wave y=%.2f hazard=%d energy=%@", target, Date().timeIntervalSince1970 - t0, obs.y, hazard, obs.energy.map(String.init) ?? "?"))
    fflush(stdout)
    current = target
  }
  usleep(60_000)
}
