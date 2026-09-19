import AppKit
import SayCore
import XCTest

@testable import Say

@MainActor
final class AppExperienceTests: SayTestCase {
  func testOpeningApplicationShowsSetupWithoutStartingListener() throws {
    let model = try makeModel()
    var selected: SettingsPane?
    var openedListener = false
    model.showSettings = { selected = $0 }
    model.showListener = { openedListener = true }
    model.openApplication()
    XCTAssertEqual(selected, .connections)
    XCTAssertFalse(openedListener)
    XCTAssertFalse(model.listening)
  }

  func testConfiguredApplicationOpensGeneralSettings() throws {
    let model = try makeModel(connected: true)
    var selected: SettingsPane?
    model.showSettings = { selected = $0 }
    model.openApplication()
    XCTAssertEqual(selected, .general)
    XCTAssertFalse(model.listening)
  }

  func testMenuExposesQuitAndSettingsWithoutEnteringListener() throws {
    let model = try makeModel(connected: true)
    var events: [String] = []
    model.showSettings = { _ in events.append("settings") }
    model.showListener = { events.append("listener") }
    model.quitApplication = { events.append("quit") }
    let controller = AppMenuController(model: model, about: {})
    let menu = controller.menu
    let settings = try item("settings", in: menu)
    let quit = try item("quit", in: menu)
    XCTAssertEqual(settings.keyEquivalent, ",")
    XCTAssertEqual(quit.keyEquivalent, "q")
    XCTAssertTrue(quit.isEnabled)
    XCTAssertFalse(quit.isHidden)
    try perform(settings)
    XCTAssertEqual(events, ["settings"])
    XCTAssertFalse(model.listening)
    try perform(quit)
    XCTAssertEqual(events, ["settings", "quit"])
  }

  func testOpenListenerOnlyPresentsItsInterface() throws {
    let model = try makeModel(connected: true)
    var presented = false
    model.showListener = { presented = true }
    let controller = AppMenuController(model: model, about: {})
    let listener = try item("listener", in: controller.menu)
    try perform(listener)
    XCTAssertTrue(presented)
    XCTAssertFalse(model.listening)
    XCTAssertFalse(model.busy)
  }

  func testQuitCancelsWorkBeforeTerminating() throws {
    let model = try makeModel()
    model.busy = true
    model.pending = PendingAction(
      action: MacAction(id: "test", kind: .press, label: "Delete"), appName: "Notes")
    var terminated = false
    model.quitApplication = {
      XCTAssertFalse(model.busy)
      XCTAssertNil(model.pending)
      terminated = true
    }
    let controller = AppMenuController(model: model, about: {})
    XCTAssertFalse(try item("stop", in: controller.menu).isHidden)
    let quit = try item("quit", in: controller.menu)
    try perform(quit)
    XCTAssertTrue(terminated)
  }

  func testSettingsCancelsWorkAndKeepsRequestedPane() throws {
    let model = try makeModel()
    model.busy = true
    var selected: SettingsPane?
    model.showSettings = { selected = $0 }
    model.openSettings(.privacy)
    XCTAssertFalse(model.busy)
    XCTAssertEqual(selected, .privacy)
  }

  func testClosingListenerClearsNoticesAndCancelsWork() throws {
    let model = try makeModel()
    model.notice = "Fixture notice"
    model.busy = true
    var hidden = false
    model.dismissQuick = {
      XCTAssertNil(model.notice)
      XCTAssertFalse(model.busy)
      hidden = true
    }
    model.dismissListener()
    XCTAssertTrue(hidden)
  }

  func testSettingsClearsStaleErrorsWithoutDeletingHistory() throws {
    let model = try makeModel()
    let message = Message(role: "assistant", text: "Fixture error", isError: true)
    model.conversations[0].messages = [message]
    model.quickReply = message
    model.notice = "Fixture notice"
    model.openSettings(.connections)
    XCTAssertNil(model.notice)
    XCTAssertNil(model.quickReply)
    XCTAssertEqual(model.messages.count, 1)
  }

  func testMissingKeysRouteToSetupBeforeRequestingMicrophone() throws {
    let model = try makeModel()
    var selected: SettingsPane?
    model.showSettings = { selected = $0 }
    model.startListening()
    XCTAssertEqual(selected, .connections)
    XCTAssertFalse(model.listening)
    XCTAssertNil(model.notice)
  }

  func testCredentialChangesAreExplicitAndNeverTouchRealKeychain() throws {
    var writes: [String] = []
    let preferences = try makePreferences(save: { _, value in writes.append(value) })
    XCTAssertTrue(writes.isEmpty)
    try preferences.setKey(" fixture-value \n", for: .openAI)
    XCTAssertEqual(preferences.openAIKey, "fixture-value")
    XCTAssertEqual(writes, ["fixture-value"])
    try preferences.setKey("", for: .openAI)
    XCTAssertEqual(writes, ["fixture-value", ""])
  }

  func testEnvironmentCredentialsCannotBeOverwritten() throws {
    var writes = 0
    let preferences = try makePreferences(
      connected: true, environment: { _ in "OPENAI_API_KEY" }, save: { _, _ in writes += 1 })
    XCTAssertThrowsError(try preferences.setKey("replacement", for: .openAI))
    XCTAssertEqual(writes, 0)
    XCTAssertEqual(preferences.openAIKey, "fixture-key")
  }

  func testFailedCredentialSavePreservesCurrentKey() throws {
    let preferences = try makePreferences(
      connected: true,
      save: { _, _ in
        throw SayError("Test save failure")
      })
    XCTAssertThrowsError(try preferences.setKey("replacement", for: .openAI))
    XCTAssertEqual(preferences.openAIKey, "fixture-key")
  }

  private func perform(_ item: NSMenuItem) throws {
    let action = try XCTUnwrap(item.action)
    XCTAssertNotNil(item.target)
    XCTAssertTrue(NSApplication.shared.sendAction(action, to: item.target, from: item))
  }

  private func item(_ id: String, in menu: NSMenu) throws -> NSMenuItem {
    try XCTUnwrap(menu.items.first { $0.identifier?.rawValue == id })
  }
}
