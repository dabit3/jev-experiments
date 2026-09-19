import AppKit
import SayCore
import SwiftUI
import XCTest

@testable import Say

@MainActor
final class InterfaceRenderingTests: SayTestCase {
  private let output = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("build/snapshots", isDirectory: true)

  func testSettingsPanesRenderAtTheirWindowSizes() throws {
    let model = try makeModel(connected: true)
    for pane in SettingsPane.allCases {
      for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        let image = try render(pane.view(model: model), size: pane.size, appearance: appearance)
        XCTAssertEqual(image.size, pane.size)
        try save(image, as: "settings-\(pane.rawValue)-\(appearance == .aqua ? "light" : "dark")")
      }
    }
  }

  func testMainWindowAndPanelsRender() throws {
    let model = try makeModel(connected: true)
    let main = try render(RootView(model: model), size: CGSize(width: 920, height: 620))
    XCTAssertEqual(main.size, CGSize(width: 920, height: 620))
    try save(main, as: "main-window")
    model.conversations[0].messages = [
      Message(role: "user", text: "Open Calculator"),
      Message(
        role: "assistant", text: "Calculator is open.", activities: [Activity("Opened Calculator")]),
    ]
    try save(
      try render(RootView(model: model), size: CGSize(width: 920, height: 620)),
      as: "history-conversation")
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

  func testListenerStatesAndCredentialEditorRenderWithoutAccessingDevices() throws {
    let model = try makeModel()
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      let suffix = appearance == .aqua ? "light" : "dark"
      try save(
        try render(
          QuickView(model: model), size: CGSize(width: model.quickWidth, height: model.quickHeight),
          appearance: appearance), as: "listener-setup-\(suffix)")
      model.notice = "I did not catch anything. Hold the shortcut while speaking and try again."
      try save(
        try render(
          QuickView(model: model), size: CGSize(width: model.quickWidth, height: model.quickHeight),
          appearance: appearance), as: "listener-notice-\(suffix)")
      model.notice = nil
      model.pending = PendingAction(
        action: MacAction(id: "fixture", kind: .press, label: "Send the message to Alex"),
        appName: "Mail")
      try save(
        try render(
          QuickView(model: model), size: CGSize(width: model.quickWidth, height: model.quickHeight),
          appearance: appearance), as: "listener-approval-\(suffix)")
      model.pending = nil
    }
    var saves = 0
    try save(
      try render(
        CredentialEditor(title: "OpenAI") { _ in saves += 1 },
        size: CGSize(width: 440, height: 220)), as: "credential-editor")
    XCTAssertEqual(saves, 0)
    XCTAssertFalse(model.listening)
  }

  func testNativeSettingsToolbarPreservesPaneSizeAndTitle() throws {
    _ = NSApplication.shared
    let model = try makeModel(connected: true)
    let controller = SettingsWindowController(model: model)
    let window = try XCTUnwrap(controller.window)
    defer { window.close() }
    for pane in SettingsPane.allCases {
      controller.select(pane)
      XCTAssertEqual(controller.selectedPane, pane)
      XCTAssertEqual(window.title, pane.title)
      XCTAssertEqual(window.contentRect(forFrameRect: window.frame).size, pane.size)
      XCTAssertNotNil(window.toolbar)
      XCTAssertFalse(model.listening)
    }
  }

  private func render<Content: View>(
    _ view: Content, size: CGSize, appearance: NSAppearance.Name = .aqua
  ) throws -> NSImage {
    _ = NSApplication.shared
    let content = view.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light)
    let controller = NSHostingController(rootView: content)
    let window = NSWindow(contentViewController: controller)
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: appearance)
    window.setContentSize(size)
    defer { window.close() }
    let host = controller.view
    host.frame = CGRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    window.alphaValue = 0
    window.ignoresMouseEvents = true
    window.orderBack(nil)
    window.displayIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
    host.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    let captured = try XCTUnwrap(bitmap.cgImage)
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: captured.width, height: captured.height, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let bounds = CGRect(x: 0, y: 0, width: captured.width, height: captured.height)
    context.setFillColor(
      (appearance == .darkAqua ? NSColor(white: 0.12, alpha: 1) : .white).cgColor)
    context.fill(bounds)
    context.draw(captured, in: bounds)
    let canvas = NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
    canvas.size = size
    let image = NSImage(size: size)
    image.addRepresentation(canvas)
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
