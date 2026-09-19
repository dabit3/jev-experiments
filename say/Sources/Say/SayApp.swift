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
  private var model: SayModel!
  private var settings: SettingsWindowController!
  private var window: NSWindow!
  private var companion: NSPanel!
  private var commandPanel: NSPanel!
  private var highlightPanel: NSPanel?
  private var statusItem: NSStatusItem!
  private var appMenu: AppMenuController!
  private let shortcut = GlobalShortcut()
  private var localMonitor: NSObjectProtocol?
  private var outsideMonitor: NSObjectProtocol?
  private var highlightTask: Task<Void, Never>?
  private var completionTask: Task<Void, Never>?
  private var showingCompletion = false
  private var modelSubscription: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    model = SayModel()
    settings = SettingsWindowController(model: model)
    buildMenu()
    let root = NSHostingController(rootView: RootView(model: model))
    root.title = "Say"
    window = NSWindow(contentViewController: root)
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.toolbarStyle = .unified
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.setContentSize(NSSize(width: 920, height: 620))
    window.setFrameAutosaveName("SayMain")
    if UserDefaults.standard.string(forKey: "NSWindow Frame SayMain") == nil { window.center() }
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
    commandPanel.title = "Ask Say"
    commandPanel.isOpaque = false
    commandPanel.backgroundColor = .clear
    commandPanel.hasShadow = true
    commandPanel.level = .floating
    commandPanel.hidesOnDeactivate = false
    commandPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    commandPanel.isMovableByWindowBackground = true
    commandPanel.contentView = NSHostingView(rootView: QuickView(model: model))
    model.showWindow = { [weak self] in self?.showResponse() }
    model.showListener = { [weak self] in self?.openListener() }
    model.showHistory = { [weak self] in self?.showMain() }
    model.showSettings = { [weak self] pane in self?.presentSettings(pane) }
    model.quitApplication = { NSApplication.shared.terminate(nil) }
    model.dismissQuick = { [weak self] in self?.hideListener() }
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
      guard let self, !self.model.listening else { return }
      self.commandPanel.orderOut(nil)
      self.settings.window?.orderOut(nil)
      self.window.orderOut(nil)
      self.positionCompanion()
      self.model.startListening()
    }
    shortcut.onUp = { [weak self] in self?.model.finishListening() }
    shortcut.onEscape = { [weak self] in
      guard let self, self.commandPanel.isVisible || self.model.listening || self.model.busy else {
        return
      }
      self.model.dismissListener()
    }
    model.shortcutAvailable = shortcut.install()
    localMonitor =
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        if event.keyCode == 53, event.window === self?.commandPanel {
          MainActor.assumeIsolated { self?.model.dismissListener() }
          return nil
        }
        return event
      } as? NSObjectProtocol
    outsideMonitor =
      NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
        [weak self] _ in
        MainActor.assumeIsolated {
          guard let self, !self.model.busy, !self.model.listening else { return }
          if self.commandPanel.isVisible { self.model.notice = nil }
          self.commandPanel.orderOut(nil)
          self.updateCompanion()
        }
      } as? NSObjectProtocol
    updateCompanion()
    model.openApplication()
  }

  private func buildMenu() {
    let main = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About Say", action: #selector(showAbout), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit Say", action: #selector(quitSay), keyEquivalent: "q")
    for item in appMenu.items where item.action != nil { item.target = self }
    appItem.submenu = appMenu
    main.addItem(appItem)
    let file = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(
      withTitle: "New Conversation", action: #selector(newConversation), keyEquivalent: "n")
    fileMenu.addItem(withTitle: "History", action: #selector(showMain), keyEquivalent: "")
    fileMenu.addItem(
      withTitle: "Open Listener…", action: #selector(openListener), keyEquivalent: "")
    for item in fileMenu.items { item.target = self }
    fileMenu.addItem(NSMenuItem.separator())
    fileMenu.addItem(
      withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    file.submenu = fileMenu
    main.addItem(file)
    let edit = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    for (name, action, key) in [
      ("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"),
      ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
      ("Select All", #selector(NSText.selectAll(_:)), "a"),
    ] { editMenu.addItem(withTitle: name, action: action, keyEquivalent: key) }
    edit.submenu = editMenu
    main.addItem(edit)
    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(
      withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(
      withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    windowItem.submenu = windowMenu
    main.addItem(windowItem)
    NSApplication.shared.mainMenu = main
    NSApplication.shared.windowsMenu = windowMenu
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menuIcon = SayBrand.mark.copy() as? NSImage
    menuIcon?.size = NSSize(width: 20, height: 20)
    statusItem.button?.image = menuIcon
    self.appMenu = AppMenuController(model: model) { [weak self] in self?.showAbout() }
    statusItem.menu = self.appMenu.menu
    statusItem.button?.toolTip = "Say controls and settings"
  }

  @objc func showMain() {
    if model.listening || model.busy || model.pending != nil { model.stop() }
    commandPanel.orderOut(nil)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    model.refreshPermissions()
    updateCompanion()
  }

  @objc private func openSettings() { model.openSettings() }

  private func presentSettings(_ pane: SettingsPane?) {
    commandPanel.orderOut(nil)
    settings.show(pane: pane)
    updateCompanion()
  }

  @objc private func quitSay() { model.quit() }

  @objc private func showAbout() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
  }

  @objc private func newConversation() {
    model.newConversation()
    showMain()
  }

  @objc private func openListener() {
    settings.window?.orderOut(nil)
    window.orderOut(nil)
    showQuick()
  }

  private func showResponse() { showQuick() }

  private func showQuick() {
    model.refreshPermissions()
    let screen =
      NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    guard let bounds = screen?.visibleFrame else { return }
    commandPanel.setFrame(
      NSRect(
        x: bounds.midX - model.quickWidth / 2, y: bounds.minY + 36,
        width: model.quickWidth, height: model.quickHeight),
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

  private func hideListener() {
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
    let x = bounds.midX - 130
    let y = bounds.minY + 28
    companion.setFrame(NSRect(x: x, y: y, width: 260, height: 60), display: true)
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
        RoundedRectangle(cornerRadius: 9).stroke(.white, lineWidth: 5)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.black, lineWidth: 2))
        .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
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
    model.openApplication()
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
enum SayApp {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
