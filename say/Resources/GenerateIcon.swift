import AppKit

func color(_ hex: UInt32) -> NSColor {
  NSColor(
    srgbRed: CGFloat((hex >> 16) & 255) / 255,
    green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: 1)
}

let ink = color(0x252522)
let secondary = color(0x67665F)
let accent = color(0x3049BD)

func render(size: NSSize, scale: Int = 1, draw: () -> Void) -> NSBitmapImageRep {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale,
    pixelsHigh: Int(size.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = AffineTransform(scale: CGFloat(scale))
  (transform as NSAffineTransform).concat()
  draw()
  NSGraphicsContext.restoreGraphicsState()
  bitmap.size = size
  return bitmap
}

func save(_ bitmap: NSBitmapImageRep, to url: URL) throws {
  try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

func text(
  _ value: String, x: CGFloat, top: CGFloat, width: CGFloat, size: CGFloat,
  weight: NSFont.Weight = .regular, foreground: NSColor = ink, canvasHeight: CGFloat,
  tracking: CGFloat = 0
) {
  (value as NSString).draw(
    in: NSRect(x: x, y: canvasHeight - top - size * 1.45, width: width, height: size * 1.45),
    withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: foreground, .kern: tracking,
    ])
}

func speechCursor(in rect: NSRect, foreground: NSColor) {
  func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: rect.minX + x * rect.width / 100, y: rect.maxY - y * rect.height / 100)
  }
  let shape = NSBezierPath()
  shape.move(to: point(30, 12))
  shape.line(to: point(70, 12))
  shape.curve(to: point(92, 34), controlPoint1: point(82.15, 12), controlPoint2: point(92, 21.85))
  shape.line(to: point(92, 49))
  shape.curve(
    to: point(74.65, 70.45), controlPoint1: point(92, 59.55), controlPoint2: point(84.57, 68.37))
  shape.line(to: point(86, 94))
  shape.line(to: point(50, 72))
  shape.line(to: point(30, 72))
  shape.curve(to: point(8, 50), controlPoint1: point(17.85, 72), controlPoint2: point(8, 62.15))
  shape.line(to: point(8, 34))
  shape.curve(to: point(30, 12), controlPoint1: point(8, 21.85), controlPoint2: point(17.85, 12))
  shape.close()
  foreground.setFill()
  shape.fill()
}

func saveMark(to url: URL) throws {
  let data = NSMutableData()
  var bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
  let consumer = CGDataConsumer(data: data as CFMutableData)!
  let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
  context.beginPDFPage(nil)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
  speechCursor(in: bounds, foreground: .black)
  NSGraphicsContext.restoreGraphicsState()
  context.endPDFPage()
  context.closePDF()
  try (data as Data).write(to: url)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let bitmap = render(size: NSSize(width: pixels, height: pixels)) {
      let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
      (transform as NSAffineTransform).concat()
      let tile = NSBezierPath(
        roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864),
        xRadius: 196, yRadius: 196)
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
      shadow.shadowBlurRadius = 28
      shadow.shadowOffset = NSSize(width: 0, height: -12)
      shadow.set()
      accent.setFill()
      tile.fill()
      NSShadow().set()
      NSGradient(starting: color(0x3B57DA), ending: color(0x22369E))!
        .draw(in: tile, angle: -75)
      color(0xAABAFB).withAlphaComponent(0.35).setStroke()
      tile.lineWidth = 3
      tile.stroke()
      speechCursor(
        in: NSRect(x: 202, y: 202, width: 620, height: 620), foreground: color(0xFFF9E9))
    }
    let suffix = scale == 2 ? "@2x" : ""
    try save(bitmap, to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}

if CommandLine.arguments.count > 2 {
  let artwork = URL(fileURLWithPath: CommandLine.arguments[2])
  try FileManager.default.createDirectory(at: artwork, withIntermediateDirectories: true)
  try saveMark(to: artwork.appendingPathComponent("SayMark.pdf"))
  for scale in [1, 2] {
    let background = render(size: NSSize(width: 760, height: 500), scale: scale) {
      NSGradient(starting: color(0xFAF7F1), ending: color(0xF1EDE5))!
        .draw(in: NSRect(x: 0, y: 0, width: 760, height: 500), angle: -70)
      text(
        "Say", x: 56, top: 34, width: 500, size: 66, weight: .bold, canvasHeight: 500, tracking: -3)
      text(
        "A voice companion for your Mac.", x: 58, top: 119, width: 600, size: 18,
        foreground: secondary, canvasHeight: 500)
      color(0xDEDAD2).setFill()
      NSRect(x: 56, y: 324, width: 648, height: 1).fill()
      NSRect(x: 56, y: 91, width: 648, height: 1).fill()
      text(
        "Drag Say to Applications.", x: 56, top: 196, width: 648, size: 14,
        weight: .medium, foreground: secondary, canvasHeight: 500)
      let arrow = NSBezierPath()
      arrow.move(to: NSPoint(x: 344, y: 214))
      arrow.line(to: NSPoint(x: 411, y: 214))
      arrow.move(to: NSPoint(x: 401, y: 224))
      arrow.line(to: NSPoint(x: 411, y: 214))
      arrow.line(to: NSPoint(x: 401, y: 204))
      accent.setStroke()
      arrow.lineWidth = 2
      arrow.lineCapStyle = .round
      arrow.lineJoinStyle = .round
      arrow.stroke()
      text(
        "Find Say in your menu bar.", x: 56, top: 438, width: 400, size: 13,
        foreground: secondary, canvasHeight: 500)
      var x: CGFloat = 500
      for (label, width) in [("⌃", CGFloat(40)), ("⌥", CGFloat(40)), ("Space", CGFloat(66))] {
        color(0xEAE6DE).setFill()
        NSBezierPath(
          roundedRect: NSRect(x: x, y: 37, width: width, height: 34), xRadius: 8, yRadius: 8
        ).fill()
        let font = NSFont.systemFont(ofSize: label == "Space" ? 12 : 19, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let labelSize = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(
          at: NSPoint(x: x + (width - labelSize.width) / 2, y: 37 + (34 - labelSize.height) / 2),
          withAttributes: attributes)
        x += width + 7
      }
    }
    try save(
      background,
      to: artwork.appendingPathComponent("InstallerBackground\(scale == 2 ? "@2x" : "").png"))
  }
  let banner = render(size: NSSize(width: 1440, height: 460)) {
    NSGradient(starting: color(0xFAF7F1), ending: color(0xF1EDE5))!
      .draw(in: NSRect(x: 0, y: 0, width: 1440, height: 460), angle: -30)
    text(
      "Say", x: 76, top: 68, width: 800, size: 144, weight: .bold, canvasHeight: 460, tracking: -7)
    text(
      "A voice companion for your Mac.", x: 82, top: 264, width: 860, size: 30,
      foreground: secondary, canvasHeight: 460)
    text(
      "HOLD TO TALK. RELEASE TO ASK.", x: 84, top: 356, width: 860, size: 12,
      weight: .medium, foreground: color(0x8B8479), canvasHeight: 460, tracking: 2)
    speechCursor(in: NSRect(x: 991, y: 80, width: 310, height: 310), foreground: accent)
  }
  try save(banner, to: artwork.appendingPathComponent("SayBanner.png"))
}
