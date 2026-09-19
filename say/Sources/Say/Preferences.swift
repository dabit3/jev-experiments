import AppKit
import SayCore
import Security
import SwiftUI

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
  static let service = "ai.jev.say"
  static let legacyService = "ai.jev.talkie"
  private var label: String { "Say (\(title) API key)" }

  private func query(service: String) -> [String: CFTypeRef] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service as CFString,
      kSecAttrAccount as String: rawValue as CFString,
    ]
  }

  private func stored(in service: String) -> String? {
    var query = query(service: service)
    query[kSecReturnData as String] = kCFBooleanTrue
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(decoding: data, as: UTF8.self)
  }

  func read() -> String {
    if let environmentValue { return environmentValue }
    if let value = stored(in: Self.service) { return value }
    guard let legacy = stored(in: Self.legacyService) else { return "" }
    if (try? save(legacy)) != nil, stored(in: Self.service) == legacy {
      SecItemDelete(query(service: Self.legacyService) as CFDictionary)
    }
    return legacy
  }

  func save(_ value: String) throws {
    let query = query(service: Self.service)
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw SayError("Could not remove the \(title) key from Keychain.")
      }
      return
    }
    let data = Data(clean.utf8) as CFData
    let attributes = [kSecValueData: data, kSecAttrLabel: label as CFString] as CFDictionary
    var status = SecItemUpdate(query as CFDictionary, attributes)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrLabel as String] = label as CFString
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw SayError("Could not save the \(title) key to Keychain.")
    }
  }
}

@MainActor
final class Preferences: ObservableObject {
  private let defaults: UserDefaults
  private let saveCredential: (Credential, String) throws -> Void
  let credentialEnvironment: (Credential) -> String?
  @Published var speak: Bool { didSet { defaults.set(speak, forKey: "speak") } }
  @Published var screenContext: Bool {
    didSet { defaults.set(screenContext, forKey: "screenContext") }
  }
  @Published var keepHistory: Bool {
    didSet { defaults.set(keepHistory, forKey: "keepHistory") }
  }
  @Published var companion: Bool {
    didSet { defaults.set(companion, forKey: "companion") }
  }
  @Published var jevKey: String
  @Published var openAIKey: String
  init(
    defaults: UserDefaults = .standard,
    readCredential: (Credential) -> String = { $0.read() },
    saveCredential: @escaping (Credential, String) throws -> Void = { try $0.save($1) },
    credentialEnvironment: @escaping (Credential) -> String? = { credential in
      credential.environmentNames.first {
        !(ProcessInfo.processInfo.environment[$0] ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
    },
    migrateLegacy: Bool = true
  ) {
    self.defaults = defaults
    self.saveCredential = saveCredential
    self.credentialEnvironment = credentialEnvironment
    let keys = ["speak", "screenContext", "keepHistory", "companion"]
    if migrateLegacy, keys.allSatisfy({ defaults.object(forKey: $0) == nil }),
      let legacy = defaults.persistentDomain(forName: Credential.legacyService)
    {
      for key in keys {
        if let value = legacy[key] { defaults.set(value, forKey: key) }
      }
    }
    defaults.register(defaults: [
      "speak": true, "screenContext": true, "keepHistory": false, "companion": false,
    ])
    speak = defaults.bool(forKey: "speak")
    screenContext = defaults.bool(forKey: "screenContext")
    keepHistory = defaults.bool(forKey: "keepHistory")
    companion = defaults.bool(forKey: "companion")
    jevKey = readCredential(.jev)
    openAIKey = readCredential(.openAI)
  }

  func key(for credential: Credential) -> String {
    credential == .jev ? jevKey : openAIKey
  }

  func setKey(_ value: String, for credential: Credential) throws {
    guard credentialEnvironment(credential) == nil else {
      throw SayError(
        "This key comes from your launch environment. Change it there and restart Say.")
    }
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    try saveCredential(credential, clean)
    if credential == .jev { jevKey = clean } else { openAIKey = clean }
  }
}

@MainActor
final class HistoryStore {
  private let url: URL
  init(url location: URL? = nil) {
    if let url = location {
      self.url = url
      return
    }
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0]
    url = support.appendingPathComponent("Say/conversations.json")
    let legacy = support.appendingPathComponent("Talkie/conversations.json")
    let files = FileManager.default
    guard !files.fileExists(atPath: url.path), files.fileExists(atPath: legacy.path) else { return }
    do {
      try files.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      try files.moveItem(at: legacy, to: url)
      let folder = legacy.deletingLastPathComponent()
      if try files.contentsOfDirectory(atPath: folder.path).isEmpty {
        try files.removeItem(at: folder)
      }
    } catch {
      NSLog("Could not move saved conversations from Talkie to Say: %@", error.localizedDescription)
    }
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
