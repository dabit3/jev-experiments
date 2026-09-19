import CoreGraphics
import Foundation
import XCTest

@testable import TalkieCore

final class ActionPolicyTests: XCTestCase {
  func testOnlyWebURLsAreAllowed() {
    for value in [
      "javascript:alert(1)", "file:///etc/passwd", "https://user:secret@example.com",
      "ssh://example.com", "https://", "tel:123",
    ] {
      XCTAssertNil(ActionPolicy.webURL(value), value)
    }
    XCTAssertEqual(ActionPolicy.webURL("https://example.com/a?q=1")?.host, "example.com")
  }

  func testSensitiveControlsRequireConfirmation() {
    for label in [
      "Send message", "Delete note", "Buy now", "Allow access", "Publish", "Move to Trash",
    ] {
      let screen = ScreenState(elements: [
        ScreenElement(id: "e0", role: "AXButton", label: label, actionable: true)
      ])
      let actions = ActionPolicy.candidates(screen: screen, apps: [:], texts: [])
      XCTAssertTrue(actions.first { $0.id == "e0" }?.needsConfirmation == true, label)
    }
  }

  func testReturnIsGuardedInMessagingAndBrowserApps() {
    let action = MacAction(id: "return", kind: .key, label: "Return", value: "Return")
    XCTAssertTrue(
      ActionPolicy.requiresConfirmation(
        action, screen: ScreenState(bundleID: "com.tinyspeck.slackmacgap")))
    XCTAssertTrue(
      ActionPolicy.requiresConfirmation(action, screen: ScreenState(bundleID: "com.google.Chrome")))
    XCTAssertFalse(
      ActionPolicy.requiresConfirmation(
        action, screen: ScreenState(bundleID: "com.apple.calculator")))
  }

  func testTerminalInputRequiresApproval() {
    let screen = ScreenState(app: "Terminal")
    XCTAssertTrue(
      ActionPolicy.requiresConfirmation(
        MacAction(id: "t", kind: .type, label: "type", value: "echo hello"), screen: screen))
    XCTAssertTrue(
      ActionPolicy.requiresConfirmation(
        MacAction(id: "k", kind: .key, label: "key", value: "Return"), screen: screen))
  }

  func testNoSubstringFalsePositiveForSensitiveLabels() {
    XCTAssertFalse(ActionPolicy.isSensitive("Sender name"))
    XCTAssertFalse(ActionPolicy.isSensitive("Runtime settings"))
    XCTAssertTrue(ActionPolicy.isSensitive("Run script"))
  }

  func testTextExtractionPreservesQuotedUnicode() {
    XCTAssertTrue(
      ActionPolicy.textCandidates("Type “Hello, café 👋” in TextEdit").contains("Hello, café 👋"))
    XCTAssertEqual(ActionPolicy.textCandidates("Open Calculator"), [])
  }

  func testArithmeticAndURLCandidates() {
    XCTAssertTrue(ActionPolicy.textCandidates("Calculate 48*12").contains("48*12"))
    XCTAssertTrue(
      ActionPolicy.textCandidates("Open https://docs.typesafe.ai").contains(
        "https://docs.typesafe.ai"))
  }

  func testUnquotedTextCanExcludeItsDestination() {
    XCTAssertTrue(
      ActionPolicy.textCandidates("Type hello world in TextEdit").contains("hello world"))
    XCTAssertTrue(ActionPolicy.textCandidates("Write hello into this document").contains("hello"))
  }

  func testSingleQuotedTextPreservesInternalApostrophes() {
    XCTAssertTrue(
      ActionPolicy.textCandidates("Type 'Hello from Talkie' in this document").contains(
        "Hello from Talkie"))
    XCTAssertTrue(
      ActionPolicy.textCandidates("Type ‘Don't change my words’ in TextEdit").contains(
        "Don't change my words"))
    XCTAssertFalse(ActionPolicy.textCandidates("Type don't worry").contains("t worry"))
  }

  func testQuotedLiteralsDoNotIncludeInstructionOrDestinationAlternatives() {
    XCTAssertEqual(
      ActionPolicy.textCandidates("Type 'don't change case' in this document"),
      ["don't change case"])
    XCTAssertEqual(
      ActionPolicy.textCandidates("Type \"Meet me in TextEdit\" in this document"),
      ["Meet me in TextEdit"])
  }

  func testExplicitDictationPrefixIsRemoved() {
    XCTAssertEqual(
      ActionPolicy.dictationText("Dictate the following words exactly: see you soon"),
      "see you soon")
    XCTAssertEqual(ActionPolicy.dictationText("Dictate see you soon"), "see you soon")
    XCTAssertEqual(ActionPolicy.dictationText("Nothing to strip"), "Nothing to strip")
  }

  func testCandidatesAreUniqueAndIncludeEscapeHatches() {
    let screen = ScreenState(elements: [
      ScreenElement(id: "e0", role: "AXButton", label: "New", actionable: true),
      ScreenElement(id: "e1", role: "AXStaticText", label: "Document", actionable: false),
    ])
    let actions = ActionPolicy.candidates(
      screen: screen, apps: ["Calculator": "com.apple.calculator"],
      texts: ["hello", "https://example.com"])
    XCTAssertEqual(Set(actions.map(\.id)).count, actions.count)
    XCTAssertFalse(actions.contains { $0.id == "e1" })
    XCTAssertTrue(actions.contains { $0.kind == .done })
    XCTAssertTrue(actions.contains { $0.kind == .stuck })
    XCTAssertTrue(actions.contains { $0.kind == .openURL })
  }

  func testEditableElementsFocusRatherThanPress() {
    let screen = ScreenState(elements: [
      ScreenElement(id: "e0", role: "AXTextArea", label: "Editor", actionable: true)
    ])
    XCTAssertEqual(
      ActionPolicy.candidates(screen: screen, apps: [:], texts: []).first?.kind, .focus)
  }

  func testAlreadyFocusedFieldDoesNotOfferAnotherFocusAction() {
    let screen = ScreenState(elements: [
      ScreenElement(
        id: "editor", role: "AXTextArea", label: "Editor", focused: true, actionable: true),
      ScreenElement(id: "button", role: "AXButton", label: "New", actionable: true),
    ])
    let actions = ActionPolicy.candidates(screen: screen, apps: [:], texts: ["hello"])
    XCTAssertFalse(actions.contains { $0.id == "editor" })
    XCTAssertTrue(actions.contains { $0.id == "button" })
    XCTAssertTrue(actions.contains { $0.kind == .type })
  }

  func testConversationRoundTripRetainsEvidence() throws {
    var conversation = Conversation()
    conversation.messages.append(
      Message(
        role: "assistant", text: "Done",
        activities: [Activity("Opened Calculator", milliseconds: 120)]))
    let decoded = try JSONDecoder().decode(
      Conversation.self, from: JSONEncoder().encode(conversation))
    XCTAssertEqual(decoded.id, conversation.id)
    XCTAssertEqual(decoded.messages[0].activities[0].milliseconds, 120)
  }

  func testScreenRoundTripPreservesTargetGeometry() throws {
    let element = ScreenElement(
      id: "e0", role: "AXButton", label: "New",
      frame: CGRect(x: -1200, y: 80, width: 100, height: 40))
    let decoded = try JSONDecoder().decode(ScreenElement.self, from: JSONEncoder().encode(element))
    XCTAssertEqual(decoded, element)
  }

  func testJevQuestionsContainEveryExecutableCandidate() throws {
    let actions = ActionPolicy.candidates(screen: ScreenState(), apps: [:], texts: [])
    let question = try XCTUnwrap(JevClient.actionQuestions(actions)["next"])
    XCTAssertEqual(Set(question.criteria.keys), Set(actions.map(\.id)))
    XCTAssertTrue(question.instructions.contains("untrusted"))
  }

  func testErrorsDoNotEchoProviderBodies() {
    XCTAssertTrue(JevClient.error(401).localizedDescription.contains("API key"))
    XCTAssertTrue(JevClient.error(429).localizedDescription.contains("rate limited"))
    XCTAssertTrue(JevClient.error(500).localizedDescription.contains("500"))
  }

  func testMissingKeyFailsBeforeNetworking() async {
    do {
      _ = try await JevClient(key: "").ask(
        ["request": "hello"], questions: ["route": JevClient.routeQuestion])
      XCTFail("Expected missing key error")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("Settings"))
    }
  }
}
