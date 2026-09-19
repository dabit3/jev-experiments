import Foundation

/// The kinds of action the launcher can take. The raw values are the Jev `action` choice options.
enum ActionKind: String, CaseIterable, Codable, Sendable {
  case openApp = "open_app"
  case openFile = "open_file"
  case openURL = "open_url"
  case webSearch = "web_search"
  case calculate = "calculate"
  case systemToggle = "system_toggle"
  case runShortcut = "run_shortcut"
  case unclear = "unclear"

  var label: String {
    switch self {
    case .openApp: return "App"
    case .openFile: return "File"
    case .openURL: return "Link"
    case .webSearch: return "Web"
    case .calculate: return "Calc"
    case .systemToggle: return "System"
    case .runShortcut: return "Shortcut"
    case .unclear: return "?"
    }
  }

  /// One-line rubric sent to Jev for the `action` Choice question.
  var rubric: String {
    switch self {
    case .openApp: return "Launch or switch to an installed application."
    case .openFile: return "Open a document, folder or file from disk."
    case .openURL: return "Reopen a web page the user has visited before, from browser history."
    case .webSearch: return "Look something up on the web; a question or topic, not a local item."
    case .calculate: return "Evaluate arithmetic, percentages or unit-free math."
    case .systemToggle:
      return "Change a system setting: appearance, wi-fi, focus, sleep, lock, trash, hidden files."
    case .runShortcut: return "Run a user-created macOS Shortcut by name."
    case .unclear: return "Too little typed or too ambiguous to tell what kind of action is meant."
    }
  }
}

/// Something the launcher can execute. Produced by the local index or synthesized from the query.
struct Candidate: Identifiable, Hashable, Codable, Sendable {
  enum Payload: Hashable, Codable, Sendable {
    case app(URL)
    case file(URL)
    case url(URL)
    case webSearch(String)
    case calculation(expression: String, result: String)
    case toggle(SystemToggle)
    case shortcut(String)
    /// Several candidates opened together; synthesized by the ranker when Jev judges that the
    /// query describes a set rather than one item.
    indirect case group([Candidate])
  }

  let id: String
  let title: String
  let subtitle: String
  let kind: ActionKind
  let keywords: [String]
  let payload: Payload
  /// Days since the item was last modified or visited; used to describe recency to Jev in words
  /// and to apply a time window such as "in the past 24 hours". Nil for timeless items.
  let ageDays: Double?
  let modifiedAt: Date?
  let lastOpenedAt: Date?
  let addedAt: Date?

  init(
    id: String, title: String, subtitle: String, kind: ActionKind, keywords: [String] = [],
    payload: Payload, ageDays: Double? = nil, modifiedAt: Date? = nil,
    lastOpenedAt: Date? = nil, addedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.kind = kind
    self.keywords = keywords
    self.payload = payload
    self.ageDays = ageDays
    self.modifiedAt = modifiedAt
    self.lastOpenedAt = lastOpenedAt
    self.addedAt = addedAt
  }

  var isOpenable: Bool {
    switch payload {
    case .app, .file, .url: return true
    default: return false
    }
  }

  var fileURL: URL? {
    switch payload {
    case .app(let url), .file(let url): return url
    default: return nil
    }
  }

  func age(for intent: FileRecency, now: Date) -> Double? {
    guard case .file = payload else { return ageDays }
    let date: Date?
    switch intent {
    case .opened: date = lastOpenedAt
    case .added: date = addedAt ?? modifiedAt
    case .modified: date = modifiedAt
    }
    if let date { return max(0, now.timeIntervalSince(date)) / 86_400 }
    return intent == .opened ? nil : ageDays
  }

  /// Lower-cased text the fuzzy matcher searches: title words plus keywords.
  var searchTerms: [String] {
    var terms = title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(
      String.init)
    terms.append(contentsOf: keywords.map { $0.lowercased() })
    return terms
  }
}

/// A fixed system toggle executed by code (AppleScript, shell or a settings URL). Never by Jev.
enum SystemToggle: String, CaseIterable, Hashable, Codable, Sendable {
  case toggleDarkMode
  case wifiOn
  case wifiOff
  case doNotDisturb
  case sleep
  case lockScreen
  case emptyTrash
  case showHiddenFiles
  case hideHiddenFiles

  var title: String {
    switch self {
    case .toggleDarkMode: return "Toggle Dark Mode"
    case .wifiOn: return "Turn Wi-Fi On"
    case .wifiOff: return "Turn Wi-Fi Off"
    case .doNotDisturb: return "Do Not Disturb"
    case .sleep: return "Sleep"
    case .lockScreen: return "Lock Screen"
    case .emptyTrash: return "Empty Trash"
    case .showHiddenFiles: return "Show Hidden Files"
    case .hideHiddenFiles: return "Hide Hidden Files"
    }
  }

  var subtitle: String {
    switch self {
    case .toggleDarkMode: return "Switch appearance between light and dark"
    case .wifiOn: return "Enable the Wi-Fi radio"
    case .wifiOff: return "Disable the Wi-Fi radio"
    case .doNotDisturb: return "Open Focus settings to silence notifications"
    case .sleep: return "Put the Mac to sleep now"
    case .lockScreen: return "Lock the screen immediately"
    case .emptyTrash: return "Permanently delete everything in the Trash"
    case .showHiddenFiles: return "Reveal dotfiles and hidden items in Finder"
    case .hideHiddenFiles: return "Hide dotfiles and hidden items in Finder"
    }
  }

  var keywords: [String] {
    switch self {
    case .toggleDarkMode: return ["dark", "light", "theme", "appearance", "night", "mode"]
    case .wifiOn: return ["wifi", "wi-fi", "wireless", "network", "on", "enable", "connect"]
    case .wifiOff: return ["wifi", "wi-fi", "wireless", "network", "off", "disable", "airplane"]
    case .doNotDisturb: return ["dnd", "focus", "quiet", "silence", "notifications", "mute"]
    case .sleep: return ["sleep", "nap", "rest", "suspend", "standby"]
    case .lockScreen: return ["lock", "afk", "away", "secure", "screen"]
    case .emptyTrash: return ["trash", "bin", "delete", "clean", "purge"]
    case .showHiddenFiles: return ["hidden", "dotfiles", "invisible", "reveal", "finder"]
    case .hideHiddenFiles: return ["hidden", "dotfiles", "invisible", "conceal", "finder"]
    }
  }

  var candidate: Candidate {
    Candidate(
      id: "toggle:\(rawValue)", title: title, subtitle: subtitle, kind: .systemToggle,
      keywords: keywords, payload: .toggle(self))
  }
}
