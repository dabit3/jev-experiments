import Foundation

public enum ActionPolicy {
  public static let keyNames = [
    "Return", "Escape", "Tab", "Space", "Up", "Down", "Left", "Right",
    "Command+N", "Command+T", "Command+L", "Command+A", "Command+C",
    "Command+V", "Command+Z", "Command+F", "Command+W", "Command+S",
    "Command+Shift+N",
  ]

  public static func isSensitive(_ text: String) -> Bool {
    let words = text.lowercased().split { !$0.isLetter }.map(String.init)
    let sensitive: Set<String> = [
      "delete", "erase", "remove", "trash", "send", "submit", "publish", "post",
      "buy", "purchase", "pay", "transfer", "install", "allow", "grant", "password",
      "terminal", "iterm", "warp", "script", "run", "execute",
    ]
    return !sensitive.isDisjoint(with: words)
  }

  public static func webURL(_ text: String) -> URL? {
    guard let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
      let host = url.host, !host.isEmpty, url.user == nil, url.password == nil
    else { return nil }
    return url
  }

  public static func textCandidates(_ goal: String) -> [String] {
    var results: [String] = []
    let quotePatterns = [
      "[\"“]([^\"”]+)[\"”]",
      "(?<!\\w)['‘](.+?)['’](?!\\w)",
    ]
    let hasQuotedText = quotePatterns.contains {
      goal.range(of: $0, options: .regularExpression) != nil
    }
    var patterns = quotePatterns.map { ($0, false) }
    if !hasQuotedText {
      patterns.append(("(?i)\\b(?:type|write|dictate|enter|saying)\\s+(.+)", true))
    }
    patterns += [
      ("(?i)https?://[^\\s\"<>]+", false),
      ("\\b[0-9]+\\s*[+*/×÷-]\\s*[0-9]+(?:\\s*[+*/×÷-]\\s*[0-9]+)*", false),
    ]
    for (pattern, stripDestination) in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
      for match in regex.matches(in: goal, range: NSRange(goal.startIndex..., in: goal)) {
        let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        if let swiftRange = Range(range, in: goal) {
          var value = String(goal[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
          if stripDestination {
            value = value.replacingOccurrences(
              of:
                "(?i)\\s+(?:in|into)\\s+(?:(?:the|this|my)\\s+)?(?:[\\w ]*?)(?:app|document|field|editor|textedit|notes|pages|mail|safari|chrome)\\.?$",
              with: "", options: .regularExpression)
          }
          if !value.isEmpty, !results.contains(value) { results.append(value) }
        }
      }
    }
    return Array(results.prefix(8))
  }

  public static func dictationText(_ goal: String) -> String {
    goal.replacingOccurrences(
      of: "^(?i:dictate|type)\\s+(?:(?i:the following (?:words|text)(?: exactly)?|this)\\s*:\\s*)?",
      with: "", options: .regularExpression)
  }

  public static func candidates(
    screen: ScreenState, apps: [String: String],
    texts: [String]
  ) -> [MacAction] {
    var actions = screen.elements.filter {
      $0.actionable && !($0.focused && $0.role.contains("Text"))
    }.map {
      MacAction(
        id: $0.id, kind: $0.role.contains("Text") ? .focus : .press,
        label: $0.summary, value: $0.id, needsConfirmation: isSensitive($0.label))
    }
    actions += apps.sorted { $0.key < $1.key }.enumerated().map {
      MacAction(
        id: "app\($0.offset)", kind: .launch, label: "Open \($0.element.key)",
        value: $0.element.value, needsConfirmation: isSensitive($0.element.key))
    }
    actions += texts.enumerated().map {
      MacAction(
        id: "text\($0.offset)", kind: .type, label: "Type: \($0.element)",
        value: $0.element)
    }
    actions += texts.filter { webURL($0) != nil }.enumerated().map {
      MacAction(
        id: "url\($0.offset)", kind: .openURL, label: "Open website \($0.element)",
        value: $0.element)
    }
    actions += keyNames.map {
      MacAction(
        id: "key\($0)", kind: .key, label: "Press \($0)", value: $0,
        needsConfirmation: ["Command+V", "Command+W", "Command+S"].contains($0))
    }
    actions += [
      MacAction(id: "scrollDown", kind: .scroll, label: "Scroll down", value: "-5"),
      MacAction(id: "scrollUp", kind: .scroll, label: "Scroll up", value: "5"),
      MacAction(id: "done", kind: .done, label: "The requested outcome is visible. Finish."),
      MacAction(
        id: "stuck", kind: .stuck, label: "Cannot proceed with these controls. Ask for help."),
    ]
    return actions
  }

  public static func requiresConfirmation(_ action: MacAction, screen: ScreenState) -> Bool {
    if action.needsConfirmation { return true }
    let shells = ["terminal", "iterm", "warp"]
    if shells.contains(where: { screen.app.lowercased().contains($0) }),
      action.kind == .type || action.kind == .key
    {
      return true
    }
    if action.kind == .key, action.value == "Return" {
      return !["com.apple.calculator", "com.apple.TextEdit", "com.apple.finder"]
        .contains(screen.bundleID)
    }
    return false
  }
}
