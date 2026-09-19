import AppKit
import Security
import SwiftUI
import TalkieCore

enum Credential: String, CaseIterable {
  case jev, openAI
  var environmentNames: [String] {
    self == .jev ? ["TYPESAFE_API_KEY", "JEV_API_KEY"] : ["OPENAI_API_KEY"]
  }
  var title: String { self == .jev ? "Jev" : "OpenAI" }
  var environmentValue: String? {
    environmentNames.compactMap { ProcessInfo.processInfo.environment[$0] }
      .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }
  func read() -> String {
    if let environmentValue { return environmentValue }
    let query: [String: CFTypeRef] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "ai.jev.talkie" as CFString,
      kSecAttrAccount as String: rawValue as CFString,
      kSecReturnData as String: kCFBooleanTrue,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return "" }
    return String(decoding: data, as: UTF8.self)
  }
  func save(_ value: String) throws {
    let query: [String: CFTypeRef] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "ai.jev.talkie" as CFString,
      kSecAttrAccount as String: rawValue as CFString,
    ]
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw TalkieError("Could not remove the \(title) key from Keychain.")
      }
      return
    }
    let data = Data(clean.utf8) as CFData
    var status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw TalkieError("Could not save the \(title) key to Keychain.")
    }
  }
}

@MainActor
final class Preferences: ObservableObject {
  @Published var speak: Bool { didSet { UserDefaults.standard.set(speak, forKey: "speak") } }
  @Published var screenContext: Bool {
    didSet { UserDefaults.standard.set(screenContext, forKey: "screenContext") }
  }
  @Published var keepHistory: Bool {
    didSet { UserDefaults.standard.set(keepHistory, forKey: "keepHistory") }
  }
  @Published var companion: Bool {
    didSet { UserDefaults.standard.set(companion, forKey: "companion") }
  }
  @Published var jevKey: String
  @Published var openAIKey: String
  init() {
    let defaults = UserDefaults.standard
    defaults.register(defaults: [
      "speak": true, "screenContext": true, "keepHistory": false, "companion": false,
    ])
    speak = defaults.bool(forKey: "speak")
    screenContext = defaults.bool(forKey: "screenContext")
    keepHistory = defaults.bool(forKey: "keepHistory")
    companion = defaults.bool(forKey: "companion")
    jevKey = Credential.jev.read()
    openAIKey = Credential.openAI.read()
  }
}

@MainActor
final class HistoryStore {
  private let url: URL
  init() {
    url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Talkie/conversations.json")
  }
  func load() -> [Conversation] {
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([Conversation].self, from: data)) ?? []
  }
  func save(_ conversations: [Conversation]) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try JSONEncoder().encode(Array(conversations.prefix(50))).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
  func clear() throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
