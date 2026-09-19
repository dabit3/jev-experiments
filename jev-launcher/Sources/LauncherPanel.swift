import AppKit
import Combine
import Quartz
import SwiftUI

/// Borderless windows refuse key status by default; a launcher must accept it to receive typing.
final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

/// A floating, non-activating panel that sits above every window and every Space, like Spotlight.
@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate {
  static let panelWidth: CGFloat = 680
  static let headerHeight: CGFloat = 72
  static let scopeHeight: CGFloat = 40
  static let rowHeight: CGFloat = 56
  static let footerHeight: CGFloat = 40
  static let maxRows = 7
  static let emptyHeight: CGFloat = 96

  /// The panel grows and shrinks with its content, like Spotlight, instead of sitting in a fixed box.
  static func height(rows: Int, empty: Bool) -> CGFloat {
    let body = empty ? emptyHeight : rowHeight * CGFloat(min(max(rows, 1), maxRows)) + 12
    return headerHeight + scopeHeight + body + footerHeight
  }

  let model: LauncherModel
  private let panel: KeyablePanel
  private var keyMonitor: Any?
  private var subscriptions: Set<AnyCancellable> = []
  private var previewWindow: NSWindow?

  init(model: LauncherModel) {
    self.model = model
    panel = KeyablePanel(
      contentRect: NSRect(
        x: 0, y: 0, width: Self.panelWidth, height: Self.height(rows: 0, empty: true)),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered,
      defer: false)
    super.init()
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.delegate = self
    let host = NSHostingView(rootView: LauncherView(model: model))
    host.frame = panel.contentView?.bounds ?? .zero
    host.autoresizingMask = [.width, .height]
    panel.contentView = host
    model.onExecute = { [weak self] in self?.hide() }
    model.onPreview = { [weak self] url in self?.preview(url) }
    model.objectWillChange
      .receive(on: RunLoop.main)
      .map { [weak model] _ in
        guard let model else { return Self.height(rows: 0, empty: true) }
        return Self.height(
          rows: model.actionsVisible
            ? 6
            : model.savingWorkspace || model.confirmation != nil ? 3 : model.hits.count,
          empty: model.hits.isEmpty && !model.actionsVisible && model.confirmation == nil)
      }
      .removeDuplicates()
      .sink { [weak self] height in self?.resize(to: height) }
      .store(in: &subscriptions)
  }

  /// Keeps the top edge pinned so the query field never jumps while the list changes size.
  private func resize(to height: CGFloat) {
    guard panel.isVisible else { return }
    var frame = panel.frame
    frame.origin.y += frame.height - height
    frame.size.height = height
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().setFrame(frame, display: true)
    }
  }

  var isVisible: Bool { panel.isVisible }

  func toggle() {
    if panel.isVisible { hide() } else { show() }
  }

  func show() {
    model.panelWillShow()
    if let screen = NSScreen.main {
      let frame = screen.visibleFrame
      let height = Self.height(rows: model.hits.count, empty: model.hits.isEmpty)
      let top = frame.midY + frame.height * 0.22
      panel.setFrame(
        NSRect(
          x: frame.midX - Self.panelWidth / 2, y: top - height, width: Self.panelWidth,
          height: height),
        display: false)
    }
    panel.makeKeyAndOrderFront(nil)
    installKeyMonitor()
  }

  func hide() {
    panel.orderOut(nil)
    removeKeyMonitor()
    model.reset()
  }

  func windowDidResignKey(_ notification: Notification) {
    guard !model.isExecuting else { return }
    hide()
  }

  private func preview(_ url: URL) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.title = url.lastPathComponent
    let preview = QLPreviewView(frame: window.contentView?.bounds ?? .zero, style: .normal)!
    preview.autoresizingMask = [.width, .height]
    preview.previewItem = url as NSURL
    window.contentView = preview
    window.center()
    previewWindow?.close()
    previewWindow = window
    NSApplication.shared.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func installKeyMonitor() {
    removeKeyMonitor()
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.panel.isVisible else { return event }
      let command = event.modifierFlags.contains(.command)
      if command && !self.model.savingWorkspace {
        switch event.keyCode {
        case 40: self.model.actionsVisible.toggle()
        case 35: self.model.togglePin()
        case 16: self.model.previewSelection()
        case 15: self.model.revealSelection()
        case 8 where event.modifierFlags.contains(.shift): self.model.copySelection()
        case 49:
          if let candidate = self.model.topHit?.candidate { self.model.toggleMember(candidate) }
        default: return event
        }
        return nil
      }
      switch event.keyCode {
      case 53:  // Escape
        if !self.model.cancelOverlay() { self.hide() }
        return nil
      case 48 where !self.model.actionsVisible && !self.model.savingWorkspace:
        self.model.cycleScope(backward: event.modifierFlags.contains(.shift))
        return nil
      case 125:  // Down
        if self.model.savingWorkspace { return event }
        if self.model.actionsVisible {
          self.model.moveActionSelection(by: 1)
        } else {
          self.model.moveSelection(by: 1)
        }
        return nil
      case 126:  // Up
        if self.model.savingWorkspace { return event }
        if self.model.actionsVisible {
          self.model.moveActionSelection(by: -1)
        } else {
          self.model.moveSelection(by: -1)
        }
        return nil
      case 36, 76:  // Return, keypad Enter
        if self.model.savingWorkspace {
          self.model.saveWorkspace()
        } else if self.model.actionsVisible {
          self.model.performSelectedAction()
        } else {
          self.model.executeSelection()
        }
        return nil
      default:
        return event
      }
    }
  }

  private func removeKeyMonitor() {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
  }
}
