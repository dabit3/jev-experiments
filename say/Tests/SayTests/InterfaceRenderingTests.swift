import AppKit
import SayCore
import SwiftUI
import XCTest

@testable import Say

@MainActor
final class InterfaceRenderingTests: XCTestCase {
  private let output = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("build/snapshots", isDirectory: true)

  func testSettingsPanesRenderAtTheirWindowSizes() throws {
    let model = SayModel()
    for pane in SettingsPane.allCases {
      for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        let image = try render(pane.view(model: model), size: pane.size, appearance: appearance)
        XCTAssertEqual(image.size, pane.size)
        try save(image, as: "settings-\(pane.rawValue)-\(appearance == .aqua ? "light" : "dark")")
      }
    }
  }

  func testMainWindowAndPanelsRender() throws {
    let model = SayModel()
    let main = try render(RootView(model: model), size: CGSize(width: 920, height: 620))
    XCTAssertEqual(main.size, CGSize(width: 920, height: 620))
    try save(main, as: "main-window")
    let panel = try render(
      QuickView(model: model), size: CGSize(width: model.quickWidth, height: model.quickHeight))
    try save(panel, as: "voice-panel")
    let companion = try render(CompanionView(model: model), size: CGSize(width: 260, height: 60))
    try save(companion, as: "companion")
    let approval = try render(
      ApprovalView(
        model: model,
        pending: PendingAction(
          action: MacAction(id: "e1", kind: .press, label: "Button: Delete", value: "e1"),
          appName: "Notes")
      ).padding(16),
      size: CGSize(width: 340, height: 170))
    try save(approval, as: "approval")
  }

  private func render<Content: View>(
    _ view: Content, size: CGSize, appearance: NSAppearance.Name = .aqua
  ) throws -> NSImage {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(
      contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: appearance)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    host.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.appearance = window.appearance
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let image = NSImage(size: size)
    image.lockFocus()
    window.appearance?.performAsCurrentDrawingAppearance {
      NSColor.windowBackgroundColor.setFill()
      NSRect(origin: .zero, size: size).fill()
    }
    bitmap.draw(in: NSRect(origin: .zero, size: size))
    image.unlockFocus()
    return image
  }

  private func save(_ image: NSImage, as name: String) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let tiff = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: output.appendingPathComponent("\(name).png"))
  }
}
