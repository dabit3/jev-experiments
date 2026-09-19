import AppKit
import Combine
import SwiftUI

final class CompanionPanel: NSPanel {
  override var canBecomeKey: Bool { false }
}

final class CommandPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private var model: TalkieModel!
  private var window: NSWindow!
  private var companion: NSPanel!
  private var commandPanel: NSPanel!
  private var highlightPanel: NSPanel?
  private var statusItem: NSStatusItem!
  private let shortcut = GlobalShortcut()
  private var localMonitor: NSObjectProtocol?
  private var outsideMonitor: NSObjectProtocol?
  private var highlightTask: Task<Void, Never>?
  private var completionTask: Task<Void, Never>?
  private var showingCompletion = false
  private var modelSubscription: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    model = TalkieModel()
    buildMenu()
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = "Talkie"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 760, height: 560)
    window.delegate = self
    window.contentView = NSHostingView(rootView: RootView(model: model))
    window.setFrameAutosaveName("TalkieMain")
    if UserDefaults.standard.string(forKey: "NSWindow Frame TalkieMain") == nil { window.center() }
    companion = CompanionPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    companion.isOpaque = false
    companion.backgroundColor = .clear
    companion.hasShadow = true
    companion.level = .floating
    companion.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    companion.isMovableByWindowBackground = true
    companion.contentView = NSHostingView(rootView: CompanionView(model: model))
    positionCompanion()
    commandPanel = CommandPanel(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    commandPanel.title = "Ask Talkie"
    commandPanel.isOpaque = false
    commandPanel.backgroundColor = .clear
    commandPanel.hasShadow = true
    commandPanel.level = .floating
    commandPanel.hidesOnDeactivate = false
    commandPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    commandPanel.isMovableByWindowBackground = true
    commandPanel.contentView = NSHostingView(rootView: QuickView(model: model))
    model.showWindow = { [weak self] in self?.showResponse() }
    model.showHistory = { [weak self] in
      self?.model.showingSettings = false
      self?.showMain()
    }
    model.showSettings = { [weak self] in
      self?.model.showingSettings = true
      self?.showMain()
    }
    model.dismissQuick = { [weak self] in self?.dismissQuick() }
    model.showCompletion = { [weak self] in self?.showCompletion() }
    model.hideWindow = { [weak self] in
      self?.window.orderOut(nil)
      self?.commandPanel.orderOut(nil)
      self?.updateCompanion()
    }
    model.highlight = { [weak self] rect, label in self?.showHighlight(rect, label: label) }
    model.hideHighlight = { [weak self] in self?.highlightPanel?.orderOut(nil) }
    model.updateCompanion = { [weak self] in self?.updateCompanion() }
    modelSubscription = model.objectWillChange.sink { [weak self] in
      DispatchQueue.main.async {
        self?.resizeCommandPanel()
        self?.updateCompanion()
      }
    }
    shortcut.onDown = { [weak self] in
      guard let self else { return }
      self.commandPanel.orderOut(nil)
      self.positionCompanion()
      self.model.startListening()
    }
    shortcut.onUp = { [weak self] in self?.model.finishListening() }
    shortcut.onEscape = { [weak self] in self?.dismissQuick() }
    model.shortcutAvailable = shortcut.install()
    localMonitor =
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        if event.keyCode == 53 { MainActor.assumeIsolated { self?.dismissQuick() } }
        return event
      } as? NSObjectProtocol
    outsideMonitor =
      NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, !self.model.busy, !self.model.listening else { return }
          self.commandPanel.orderOut(nil)
          self.updateCompanion()
        }
      } as? NSObjectProtocol
    updateCompanion()
  }

  private func buildMenu() {
    let main = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About Talkie", action: #selector(showMain), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(
      withTitle: "Quit Talkie", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    main.addItem(appItem)
    let edit = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    for (name, action, key) in [
      ("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"),
      ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
      ("Select All", #selector(NSText.selectAll(_:)), "a"),
    ] { editMenu.addItem(withTitle: name, action: action, keyEquivalent: key) }
    edit.submenu = editMenu
    main.addItem(edit)
    NSApplication.shared.mainMenu = main
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "waveform", accessibilityDescription: "Talkie")
    statusItem.button?.target = self
    statusItem.button?.action = #selector(toggleQuick)
    statusItem.button?.toolTip = "Talkie · Hold Control Option Space to talk"
  }

  @objc func showMain() {
    commandPanel.orderOut(nil)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    model.refreshPermissions()
    updateCompanion()
  }

  @objc private func toggleQuick() {
    if commandPanel.isVisible { dismissQuick() } else { showQuick() }
  }

  private func showResponse() {
    if window.isVisible, !window.isMiniaturized { return }
    showQuick()
  }

  private func showQuick() {
    model.refreshPermissions()
    let screen =
      NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    guard let bounds = screen?.visibleFrame else { return }
    commandPanel.setFrame(
      NSRect(x: bounds.midX - 210, y: bounds.minY + 70, width: 420, height: model.quickHeight),
      display: true)
    commandPanel.makeKeyAndOrderFront(nil)
    updateCompanion()
  }

  private func resizeCommandPanel() {
    guard let commandPanel, commandPanel.isVisible else { return }
    var frame = commandPanel.frame
    guard frame.height != model.quickHeight else { return }
    frame.size.height = model.quickHeight
    commandPanel.setFrame(frame, display: true)
  }

  private func dismissQuick() {
    model.stop()
    completionTask?.cancel()
    showingCompletion = false
    commandPanel.orderOut(nil)
    updateCompanion()
  }

  private func showCompletion() {
    completionTask?.cancel()
    showingCompletion = true
    updateCompanion()
    completionTask = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      showingCompletion = false
      updateCompanion()
    }
  }

  private func updateCompanion() {
    guard let window, let companion, let model else { return }
    if commandPanel?.isVisible == true {
      companion.orderOut(nil)
      return
    }
    if window.isVisible, !window.isMiniaturized, window.frame.intersects(companion.frame) {
      companion.orderOut(nil)
      return
    }
    if model.preferences.companion || model.listening || model.busy || showingCompletion {
      companion.orderFrontRegardless()
    } else {
      companion.orderOut(nil)
    }
  }

  private func positionCompanion() {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    guard let bounds = screen?.visibleFrame else { return }
    let x = bounds.midX - 117.5
    let y = bounds.minY + 28
    companion.setFrame(NSRect(x: x, y: y, width: 235, height: 58), display: true)
  }

  private func showHighlight(_ rect: CGRect, label: String) {
    highlightTask?.cancel()
    highlightPanel?.orderOut(nil)
    let mainHeight = NSScreen.screens.first?.frame.height ?? 0
    let converted = CGRect(
      x: rect.minX - 6, y: mainHeight - rect.maxY - 6,
      width: max(24, rect.width + 12), height: max(24, rect.height + 12))
    let panel = NSPanel(
      contentRect: converted, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
      defer: false)
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.ignoresMouseEvents = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentView = NSHostingView(
      rootView:
        RoundedRectangle(cornerRadius: 9).stroke(Palette.orange, lineWidth: 3)
        .background(Palette.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .padding(2).accessibilityLabel(label)
    )
    panel.orderFrontRegardless()
    highlightPanel = panel
    highlightTask = Task {
      try? await Task.sleep(for: .seconds(4))
      if !Task.isCancelled { panel.orderOut(nil) }
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showQuick()
    return true
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    updateCompanion()
    return false
  }
  func windowDidResize(_ notification: Notification) { updateCompanion() }
  func windowDidMove(_ notification: Notification) { updateCompanion() }
  func windowDidMiniaturize(_ notification: Notification) { updateCompanion() }
  func windowDidDeminiaturize(_ notification: Notification) { updateCompanion() }
  func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

@main
enum TalkieApp {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
