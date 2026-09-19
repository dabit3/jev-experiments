import AppKit
import Foundation

/// Runs the chosen candidate. All execution is code; Jev only picks.
enum Executor {
  struct Outcome: Sendable {
    let succeeded: Bool
    let message: String
  }

  @MainActor
  static func perform(_ candidate: Candidate) async -> Outcome {
    if let problem = validationError(candidate) {
      return Outcome(succeeded: false, message: problem)
    }
    switch candidate.payload {
    case .app(let url):
      return await withCheckedContinuation { continuation in
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
          continuation.resume(
            returning: Outcome(
              succeeded: error == nil,
              message: error?.localizedDescription ?? "Opened \(candidate.title)"))
        }
      }
    case .file(let url):
      return await open([url], application: NSWorkspace.shared.urlForApplication(toOpen: url))
    case .url(let url):
      return await open([url], application: browser(for: url))
    case .group(let members):
      var urls: [URL] = []
      var failures: [String] = []
      for member in members {
        if case .url(let url) = member.payload {
          urls.append(url)
        } else {
          let outcome = await perform(member)
          if !outcome.succeeded { failures.append(outcome.message) }
        }
      }
      if let first = urls.first {
        let outcome = await open(urls, application: browser(for: first))
        if !outcome.succeeded { failures.append(outcome.message) }
      }
      return Outcome(
        succeeded: failures.isEmpty,
        message: failures.isEmpty
          ? "Opened \(members.count) items" : failures.joined(separator: "; "))
    case .webSearch(let query):
      var components = URLComponents(string: "https://www.google.com/search")!
      components.queryItems = [URLQueryItem(name: "q", value: query)]
      guard let url = components.url else {
        return Outcome(succeeded: false, message: "Could not build the search URL.")
      }
      return await open([url], application: NSWorkspace.shared.urlForApplication(toOpen: url))
    case .calculation(_, let result):
      NSPasteboard.general.clearContents()
      let copied = NSPasteboard.general.setString(result, forType: .string)
      return Outcome(
        succeeded: copied, message: copied ? "Copied \(result)" : "Could not copy result.")
    case .shortcut(let name):
      return await Task.detached {
        command("/usr/bin/shortcuts", ["run", name], success: "Ran shortcut \(name)")
      }.value
    case .send(let delivery):
      return Sharing.perform(delivery)
    case .reminder(let reminder):
      return await Reminders.create(reminder)
    case .toggle(.doNotDisturb):
      let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension")!
      let opened = NSWorkspace.shared.open(url)
      return Outcome(
        succeeded: opened,
        message: opened ? "Opened Focus settings" : "Could not open Focus settings.")
    case .toggle(let toggle):
      return await Task.detached { performToggle(toggle) }.value
    }
  }

  static func validationError(_ candidate: Candidate) -> String? {
    switch candidate.payload {
    case .file(let url), .app(let url):
      return url.isFileURL && FileManager.default.fileExists(atPath: url.path)
        ? nil : "\(candidate.title) is no longer at its saved location."
    case .url(let url):
      return ["https", "http"].contains(url.scheme?.lowercased() ?? "")
        && url.host != nil ? nil : "Only HTTP and HTTPS links can be opened."
    case .send(let delivery):
      guard let url = delivery.attachment else { return nil }
      return url.isFileURL && FileManager.default.fileExists(atPath: url.path)
        ? nil : "\(url.lastPathComponent) is no longer at its saved location."
    case .group(let members):
      guard !members.isEmpty, members.count <= Ranker.maximumSetSize,
        members.allSatisfy(\.isOpenable)
      else { return "This group does not contain a valid set of files, apps or links." }
      return members.compactMap(validationError).first
    default: return nil
    }
  }

  static func copyText(_ candidate: Candidate) -> String? {
    switch candidate.payload {
    case .file(let url), .app(let url): return url.path
    case .url(let url): return url.absoluteString
    case .calculation(_, let result): return result
    case .group(let members): return members.compactMap(copyText).joined(separator: "\n")
    default: return nil
    }
  }

  @MainActor
  private static func browser(for url: URL) -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome")
      ?? NSWorkspace.shared.urlForApplication(toOpen: url)
  }

  @MainActor
  private static func open(_ urls: [URL], application: URL?) async -> Outcome {
    guard let application else {
      return Outcome(succeeded: false, message: "No application is available to open this item.")
    }
    return await withCheckedContinuation { continuation in
      NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: .init()) {
        _, error in
        continuation.resume(
          returning: Outcome(
            succeeded: error == nil, message: error?.localizedDescription ?? "Opened"))
      }
    }
  }

  private static func performToggle(_ toggle: SystemToggle) -> Outcome {
    switch toggle {
    case .toggleDarkMode:
      return command(
        "/usr/bin/osascript",
        [
          "-e",
          "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode",
        ], success: "Toggled Dark Mode")
    case .wifiOn, .wifiOff:
      guard let device = wifiDevice() else {
        return Outcome(succeeded: false, message: "No Wi-Fi interface found on this Mac")
      }
      return command(
        "/usr/sbin/networksetup", ["-setairportpower", device, toggle == .wifiOn ? "on" : "off"],
        success: toggle == .wifiOn ? "Wi-Fi on" : "Wi-Fi off")
    case .doNotDisturb:
      return Outcome(succeeded: false, message: "Open Focus settings from the launcher.")
    case .sleep:
      return command(
        "/usr/bin/osascript", ["-e", "tell application \"System Events\" to sleep"],
        success: "Sleeping")
    case .lockScreen:
      return command(
        "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
        ["-suspend"], success: "Locking screen")
    case .emptyTrash:
      return command(
        "/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"],
        success: "Emptied Trash")
    case .showHiddenFiles, .hideHiddenFiles:
      let value = toggle == .showHiddenFiles ? "true" : "false"
      let result = command(
        "/usr/bin/defaults", ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", value],
        success: "Updated Finder")
      guard result.succeeded else { return result }
      return command(
        "/usr/bin/killall", ["Finder"],
        success: toggle == .showHiddenFiles ? "Showing hidden files" : "Hiding hidden files")
    }
  }

  /// The BSD device name of the Wi-Fi hardware port, parsed from `networksetup`.
  static func wifiDevice() -> String? {
    guard let output = run("/usr/sbin/networksetup", ["-listallhardwareports"]) else { return nil }
    return parseWifiDevice(output)
  }

  static func parseWifiDevice(_ listing: String) -> String? {
    var sawWifi = false
    for line in listing.split(separator: "\n") {
      if line.hasPrefix("Hardware Port:") {
        sawWifi = line.contains("Wi-Fi") || line.contains("AirPort")
      } else if sawWifi, line.hasPrefix("Device:") {
        return line.dropFirst("Device:".count).trimmingCharacters(in: .whitespaces)
      }
    }
    return nil
  }

  @discardableResult
  static func run(_ executable: String, _ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
    defer { timeout.cancel() }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func command(_ executable: String, _ arguments: [String], success: String)
    -> Outcome
  {
    let output = run(executable, arguments)
    return Outcome(
      succeeded: output != nil,
      message: output != nil ? success : "Could not complete the action. Check macOS permissions.")
  }
}
