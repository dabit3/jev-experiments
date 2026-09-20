import CoreGraphics
import Foundation

public enum Mode: String, CaseIterable, Codable, Sendable {
  case auto = "Auto"
  case talk = "Talk"
  case act = "Act"
  case research = "Research"
  case dictate = "Dictate"
}

public struct ScreenElement: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let role: String
  public let label: String
  public let value: String
  public let frame: CGRect?
  public let focused: Bool
  public let actionable: Bool

  public init(
    id: String, role: String, label: String, value: String = "",
    frame: CGRect? = nil, focused: Bool = false, actionable: Bool = false
  ) {
    self.id = id
    self.role = role
    self.label = label
    self.value = value
    self.frame = frame
    self.focused = focused
    self.actionable = actionable
  }

  public var summary: String {
    "\(role.replacingOccurrences(of: "AX", with: "")): \(label)"
      + (value.isEmpty ? "" : " = \(value)")
      + (focused ? " [focused]" : "")
  }
}

public struct ScreenState: Codable, Sendable {
  public var app: String
  public var bundleID: String
  public var window: String
  public var elements: [ScreenElement]
  public var visibleText: [String]

  public init(
    app: String = "", bundleID: String = "", window: String = "",
    elements: [ScreenElement] = [], visibleText: [String] = []
  ) {
    self.app = app
    self.bundleID = bundleID
    self.window = window
    self.elements = elements
    self.visibleText = visibleText
  }

  public var digest: String {
    "\(app) — \(window)\n" + elements.map { "\($0.id) \($0.summary)" }.joined(separator: "\n")
      + "\n" + visibleText.joined(separator: "\n")
  }
}

public enum ActionKind: String, Codable, Sendable {
  case press, focus, type, key, launch, openURL, scroll, done, stuck
}

public struct MacAction: Codable, Equatable, Sendable, Identifiable {
  public var id: String
  public var kind: ActionKind
  public var label: String
  public var value: String
  public var needsConfirmation: Bool

  public init(
    id: String, kind: ActionKind, label: String, value: String = "",
    needsConfirmation: Bool = false
  ) {
    self.id = id
    self.kind = kind
    self.label = label
    self.value = value
    self.needsConfirmation = needsConfirmation
  }
}

public struct Activity: Codable, Identifiable, Sendable {
  public var id = UUID()
  public var text: String
  public var milliseconds: Int?
  public init(_ text: String, milliseconds: Int? = nil) {
    self.text = text
    self.milliseconds = milliseconds
  }
}

public enum RecoveryAction: String, Codable, Sendable {
  case accessibilitySettings

  public var title: String { "Open Accessibility Settings" }

  public var systemSettingsURL: URL {
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
  }
}

public struct Message: Codable, Identifiable, Sendable {
  public var id = UUID()
  public var role: String
  public var text: String
  public var date = Date()
  public var activities: [Activity] = []
  public var sources: [WebSource] = []
  public var isError = false
  public var recovery: RecoveryAction?
  public init(
    role: String, text: String, activities: [Activity] = [],
    sources: [WebSource] = [], isError: Bool = false, recovery: RecoveryAction? = nil
  ) {
    self.role = role
    self.text = text
    self.activities = activities
    self.sources = sources
    self.isError = isError
    self.recovery = recovery
  }

  public init(error: Error, activities: [Activity] = []) {
    self.init(
      role: "assistant", text: error.localizedDescription, activities: activities,
      isError: true, recovery: (error as? SayError)?.recovery)
  }
}

public struct WebSource: Codable, Hashable, Sendable {
  public var title: String
  public var url: String
  public init(title: String, url: String) {
    self.title = title
    self.url = url
  }
}

public struct Conversation: Codable, Identifiable, Sendable {
  public var id = UUID()
  public var date = Date()
  public var messages: [Message] = []
  public init() {}
  public var title: String {
    String(messages.first(where: { $0.role == "user" })?.text.prefix(48) ?? "New conversation")
  }
}

public struct SayError: LocalizedError, Sendable {
  public let message: String
  public let recovery: RecoveryAction?

  public init(_ message: String, recovery: RecoveryAction? = nil) {
    self.message = message
    self.recovery = recovery
  }

  public static let accessibilityRequired = SayError(
    "Allow Say in System Settings → Privacy & Security → Accessibility, then try again.",
    recovery: .accessibilitySettings)

  public var errorDescription: String? { message }
}
