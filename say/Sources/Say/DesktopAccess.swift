import AppKit
import ApplicationServices
import SayCore
import ScreenCaptureKit
import Vision

@MainActor
final class DesktopAccess {
  private var elements: [String: AXUIElement] = [:]
  private(set) var targetPID: pid_t = 0
  static var trusted: Bool { AXIsProcessTrusted() }
  static func requestTrust() {
    _ = AXIsProcessTrustedWithOptions(
      [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
  }

  func snapshot(app: NSRunningApplication?) -> ScreenState {
    elements = [:]
    guard let app else { return ScreenState() }
    targetPID = app.processIdentifier
    let root = AXUIElementCreateApplication(targetPID)
    AXUIElementSetMessagingTimeout(root, 0.25)
    let focusedWindow = element(root, kAXFocusedWindowAttribute)
    let focusedControl = element(root, kAXFocusedUIElementAttribute)
    var state = ScreenState(
      app: app.localizedName ?? "App", bundleID: app.bundleIdentifier ?? "",
      window: focusedWindow.map { string($0, kAXTitleAttribute) } ?? "")
    guard Self.trusted else { return state }
    let started = Date()
    var visited = 0
    func walk(_ node: AXUIElement, depth: Int) {
      guard depth < 18, visited < 700, state.elements.count < 150,
        Date().timeIntervalSince(started) < 1.8
      else { return }
      visited += 1
      let role = string(node, kAXRoleAttribute)
      let subrole = string(node, kAXSubroleAttribute)
      if subrole == "AXSecureTextField" { return }
      let title = string(node, kAXTitleAttribute)
      let description = string(node, kAXDescriptionAttribute)
      let label = String((title.isEmpty ? description : title).prefix(180))
      let value = String(string(node, kAXValueAttribute).prefix(500))
      let enabled = bool(node, kAXEnabledAttribute) ?? true
      var actionNames: CFArray?
      AXUIElementCopyActionNames(node, &actionNames)
      let actions = actionNames as? [String] ?? []
      let interactive =
        enabled
        && (actions.contains(where: {
          [kAXPressAction, kAXPickAction, kAXConfirmAction, kAXShowMenuAction].contains($0)
        })
          || ["AXTextField", "AXTextArea", "AXComboBox", "AXRow", "AXCell"].contains(role))
      if !label.isEmpty || !value.isEmpty || interactive {
        let id = "e\(state.elements.count)"
        let entry = ScreenElement(
          id: id, role: role, label: label, value: value,
          frame: frame(node),
          focused: focusedControl.map { CFEqual($0, node) } == true
            || bool(node, kAXFocusedAttribute) == true,
          actionable: interactive)
        state.elements.append(entry)
        elements[id] = node
      }
      if role == "AXStaticText" || role == "AXImage" { return }
      for child in children(node).prefix(80) { walk(child, depth: depth + 1) }
    }
    if let focusedWindow { walk(focusedWindow, depth: 0) } else { walk(root, depth: 0) }
    if let menu = element(root, kAXMenuBarAttribute) { walk(menu, depth: 0) }
    return state
  }

  func perform(_ action: MacAction) async throws {
    try Task.checkCancellation()
    if action.kind == .launch {
      guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: action.value)
      else {
        throw SayError("That app is no longer installed.")
      }
      let config = NSWorkspace.OpenConfiguration()
      config.activates = true
      _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
      return
    }
    if action.kind == .openURL {
      guard let url = ActionPolicy.webURL(action.value), NSWorkspace.shared.open(url) else {
        throw SayError("That website could not be opened.")
      }
      return
    }
    guard Self.trusted else {
      throw SayError.accessibilityRequired
    }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
      throw SayError(
        "The active app changed. I stopped before sending input to the wrong window.")
    }
    switch action.kind {
    case .press, .focus:
      guard let element = elements[action.value] else {
        throw SayError("That control is no longer available.")
      }
      if action.kind == .focus {
        let result = AXUIElementSetAttributeValue(
          element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if result == .success { return }
      }
      for verb in [kAXPressAction, kAXPickAction, kAXConfirmAction, kAXShowMenuAction] {
        if AXUIElementPerformAction(element, verb as CFString) == .success { return }
      }
      guard let rect = frame(element), rect.width > 0, rect.height > 0 else {
        throw SayError("This app does not expose a usable action for that control.")
      }
      let point = CGPoint(x: rect.midX, y: rect.midY)
      CGEvent(
        mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point,
        mouseButton: .left)?
        .post(tap: .cghidEventTap)
      CGEvent(
        mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point,
        mouseButton: .left)?
        .post(tap: .cghidEventTap)
    case .type:
      let app = AXUIElementCreateApplication(targetPID)
      if let focused = element(app, kAXFocusedUIElementAttribute) {
        guard string(focused, kAXSubroleAttribute) != "AXSecureTextField" else {
          throw SayError("Say does not type into password fields.")
        }
        if AXUIElementSetAttributeValue(
          focused, kAXSelectedTextAttribute as CFString, action.value as CFString
        ) == .success {
          return
        }
      }
      for character in action.value {
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
          throw SayError("Typing stopped because the active app changed.")
        }
        let units = Array(String(character).utf16)
        for down in [true, false] {
          let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
          units.withUnsafeBufferPointer {
            event?.keyboardSetUnicodeString(
              stringLength: units.count, unicodeString: $0.baseAddress)
          }
          event?.post(tap: .cghidEventTap)
        }
        try await Task.sleep(for: .milliseconds(3))
      }
    case .key:
      guard let chord = Self.chords[action.value] else {
        throw SayError("Unsupported keyboard shortcut.")
      }
      for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: chord.0, keyDown: down)
        event?.flags = chord.1
        event?.post(tap: .cghidEventTap)
      }
    case .scroll:
      CGEvent(
        scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
        wheel1: Int32(action.value) ?? 0, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    case .done, .stuck, .launch, .openURL: break
    }
  }

  static let chords: [String: (CGKeyCode, CGEventFlags)] = [
    "Return": (36, []), "Escape": (53, []), "Tab": (48, []), "Space": (49, []),
    "Up": (126, []), "Down": (125, []), "Left": (123, []), "Right": (124, []),
    "Command+N": (45, .maskCommand), "Command+T": (17, .maskCommand),
    "Command+L": (37, .maskCommand), "Command+A": (0, .maskCommand),
    "Command+C": (8, .maskCommand), "Command+V": (9, .maskCommand),
    "Command+Z": (6, .maskCommand), "Command+F": (3, .maskCommand),
    "Command+W": (13, .maskCommand), "Command+S": (1, .maskCommand),
    "Command+Shift+N": (45, [.maskCommand, .maskShift]),
  ]

  static func installedApps() -> [String: String] {
    var apps: [String: String] = [:]
    for directory in [
      "/Applications", "/System/Applications", "/System/Applications/Utilities",
      NSHomeDirectory() + "/Applications",
    ] {
      let urls =
        (try? FileManager.default.contentsOfDirectory(
          at: URL(fileURLWithPath: directory),
          includingPropertiesForKeys: nil)) ?? []
      for url in urls where url.pathExtension == "app" {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
          id != Bundle.main.bundleIdentifier
        else { continue }
        apps[url.deletingPathExtension().lastPathComponent] = id
      }
    }
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
      if let name = app.localizedName, let id = app.bundleIdentifier,
        id != Bundle.main.bundleIdentifier
      {
        apps[name] = id
      }
    }
    return apps
  }

  private func string(_ element: AXUIElement, _ name: String) -> String {
    var result: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &result)
    if let string = result as? String { return string }
    if let number = result as? NSNumber { return number.stringValue }
    return ""
  }
  private func bool(_ element: AXUIElement, _ name: String) -> Bool? {
    var result: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &result)
    return result as? Bool
  }
  private func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success,
      let result, CFGetTypeID(result) == AXUIElementGetTypeID()
    else { return nil }
    return unsafeDowncast(result, to: AXUIElement.self)
  }
  private func children(_ element: AXUIElement) -> [AXUIElement] {
    var result: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &result)
    return result as? [AXUIElement] ?? []
  }
  private func frame(_ element: AXUIElement) -> CGRect? {
    var position: CFTypeRef?
    var size: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
    guard let position, let size,
      CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }
    var point = CGPoint.zero
    var dimensions = CGSize.zero
    guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
      AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions)
    else { return nil }
    return CGRect(origin: point, size: dimensions)
  }
}

enum ScreenText {
  static func read(targetPID: pid_t) async throws -> [String] {
    guard CGPreflightScreenCaptureAccess() else { return [] }
    let content = try await SCShareableContent.excludingDesktopWindows(
      true, onScreenWindowsOnly: true)
    guard
      let window = content.windows.first(where: {
        $0.owningApplication?.processID == targetPID && $0.windowLayer == 0
      })
    else { return [] }
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let configuration = SCStreamConfiguration()
    configuration.width = min(1600, Int(window.frame.width * 2))
    configuration.height = min(1200, Int(window.frame.height * 2))
    configuration.showsCursor = false
    let image = try await SCScreenshotManager.captureImage(
      contentFilter: filter, configuration: configuration)
    return try await Task.detached(priority: .userInitiated) {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      try VNImageRequestHandler(cgImage: image).perform([request])
      return Array(
        (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.prefix(100))
    }.value
  }
}
