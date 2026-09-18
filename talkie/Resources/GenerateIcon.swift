import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    let tile = NSBezierPath(
      roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864),
      xRadius: 196, yRadius: 196)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1).setFill()
    tile.fill()
    NSShadow().set()
    NSGradient(
      starting: NSColor(calibratedRed: 1, green: 0.98, blue: 0.94, alpha: 1),
      ending: NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.81, alpha: 1)
    )!.draw(in: tile, angle: -90)
    NSColor.white.withAlphaComponent(0.8).setStroke()
    tile.lineWidth = 3
    tile.stroke()
    let heights: [CGFloat] = [140, 290, 440, 290, 140]
    for (index, height) in heights.enumerated() {
      let rect = NSRect(
        x: 240 + CGFloat(index) * 112, y: 512 - height / 2, width: 96, height: height)
      let bar = NSBezierPath(roundedRect: rect, xRadius: 48, yRadius: 48)
      NSGradient(
        starting: NSColor(calibratedRed: 0.93, green: 0.42, blue: 0.24, alpha: 1),
        ending: NSColor(calibratedRed: 0.76, green: 0.25, blue: 0.12, alpha: 1)
      )!.draw(in: bar, angle: -90)
    }
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    try bitmap.representation(using: .png, properties: [:])!
      .write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}
