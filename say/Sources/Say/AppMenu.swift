import AppKit

@MainActor
final class AppMenuController: NSObject, NSMenuDelegate {
  let menu = NSMenu()
  private let model: SayModel
  private let about: () -> Void
  private let statusItem = NSMenuItem(title: "Say", action: nil, keyEquivalent: "")
  private let stopItem = NSMenuItem(title: "Stop Task", action: nil, keyEquivalent: "")

  init(model: SayModel, about: @escaping () -> Void) {
    self.model = model
    self.about = about
    super.init()
    menu.delegate = self
    menu.autoenablesItems = false
    statusItem.isEnabled = false
    menu.addItem(statusItem)
    menu.addItem(.separator())
    add("Open Listener…", id: "listener", action: #selector(openListener), symbol: "mic")
    stopItem.target = self
    stopItem.action = #selector(stop)
    stopItem.identifier = NSUserInterfaceItemIdentifier("stop")
    menu.addItem(stopItem)
    menu.addItem(.separator())
    add("Settings…", id: "settings", action: #selector(openSettings), key: ",", symbol: "gearshape")
    add("History…", id: "history", action: #selector(openHistory), symbol: "clock")
    menu.addItem(.separator())
    add("About Say", id: "about", action: #selector(showAbout))
    add("Quit Say", id: "quit", action: #selector(quit), key: "q")
    menuWillOpen(menu)
  }

  func menuWillOpen(_ menu: NSMenu) {
    statusItem.title =
      model.voice.finishing
      ? "Say · Transcribing"
      : model.listening ? "Say · Listening" : model.busy ? "Say · Working" : "Say"
    stopItem.isHidden = !model.listening && !model.busy && model.pending == nil
    stopItem.title =
      model.voice.finishing
      ? "Cancel Transcription"
      : model.listening ? "Cancel Recording" : "Stop Task"
  }

  private func add(
    _ title: String, id: String, action: Selector, key: String = "", symbol: String? = nil
  ) {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.identifier = NSUserInterfaceItemIdentifier(id)
    item.target = self
    if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    menu.addItem(item)
  }

  @objc private func openListener() { model.openListener() }
  @objc private func openSettings() { model.openSettings() }
  @objc private func openHistory() { model.showHistory?() }
  @objc private func showAbout() { about() }
  @objc private func stop() { model.stop() }
  @objc private func quit() { model.quit() }
}
