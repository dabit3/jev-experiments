import AVFoundation
import Foundation
import XCTest

@testable import Say

@MainActor
class SayTestCase: XCTestCase {
  func makePreferences(
    connected: Bool = false,
    environment: @escaping (Credential) -> String? = { _ in nil },
    save: @escaping (Credential, String) throws -> Void = { _, _ in }
  ) throws -> Preferences {
    let name = "ai.jev.say.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    addTeardownBlock { defaults.removePersistentDomain(forName: name) }
    return Preferences(
      defaults: defaults,
      readCredential: { _ in connected ? "fixture-key" : "" },
      saveCredential: save,
      credentialEnvironment: environment,
      migrateLegacy: false)
  }

  func makeModel(
    connected: Bool = false,
    permissions: PermissionSnapshot = PermissionSnapshot(
      microphone: .notDetermined, accessibility: false, screenRecording: false),
    openSystemSettings: @escaping (URL) -> Bool = { _ in
      XCTFail("System Settings must not open during an unrelated test")
      return false
    }
  ) throws -> SayModel {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("SayTests-\(UUID().uuidString)", isDirectory: true)
    addTeardownBlock {
      if FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.removeItem(at: directory)
      }
    }
    return SayModel(
      preferences: try makePreferences(connected: connected),
      historyStore: HistoryStore(url: directory.appendingPathComponent("conversations.json")),
      permissions: { permissions }, openSystemSettings: openSystemSettings)
  }
}
