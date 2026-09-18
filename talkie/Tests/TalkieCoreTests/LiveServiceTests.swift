import Foundation
import XCTest

@testable import TalkieCore

final class LiveServiceTests: XCTestCase {
  private func jev() throws -> JevClient {
    guard ProcessInfo.processInfo.environment["TALKIE_LIVE_TESTS"] == "1" else {
      throw XCTSkip("Set TALKIE_LIVE_TESTS=1 to exercise real providers.")
    }
    let environment = ProcessInfo.processInfo.environment
    let key = environment["TYPESAFE_API_KEY"] ?? environment["JEV_API_KEY"] ?? ""
    guard !key.isEmpty else { throw XCTSkip("No Jev API key available.") }
    return JevClient(key: key)
  }

  func testLiveRouting() async throws {
    let client = try jev()
    for (request, expected) in [
      ("Open Calculator", "act"),
      ("Type hello world in TextEdit", "act"),
      ("Explain what this dialog means", "talk"),
      ("Research the current macOS release and cite sources", "research"),
      ("Where is the new tab button?", "point"),
      ("Dictate the following words exactly: see you soon", "dictate"),
    ] {
      let result = try await client.ask(
        ["request": request], questions: ["route": JevClient.routeQuestion])
      XCTAssertEqual(result.answers["route"]?.choice, expected, request)
      print("LIVE route \(expected): \(result.milliseconds) ms")
    }
  }

  func testLiveActionChoosesInstalledApp() async throws {
    let client = try jev()
    let actions = ActionPolicy.candidates(
      screen: ScreenState(app: "Finder"),
      apps: ["Calculator": "com.apple.calculator", "Safari": "com.apple.Safari"], texts: [])
    struct State: Encodable, Sendable {
      var goal: String
      var screen: ScreenState
      var history: [String]
    }
    let result = try await client.ask(
      State(goal: "Open Calculator", screen: ScreenState(app: "Finder"), history: []),
      questions: JevClient.actionQuestions(actions))
    let chosen = actions.first { $0.id == result.answers["next"]?.choice }
    XCTAssertEqual(chosen?.kind, .launch)
    XCTAssertEqual(chosen?.value, "com.apple.calculator")
    print("LIVE launch: \(result.milliseconds) ms")
  }

  func testLiveActionTypesLiteralIntoFocusedEditor() async throws {
    let client = try jev()
    let screen = ScreenState(
      app: "TextEdit", bundleID: "com.apple.TextEdit", window: "Untitled",
      elements: [
        ScreenElement(
          id: "e0", role: "AXTextArea", label: "Editor", focused: true, actionable: true)
      ])
    let actions = ActionPolicy.candidates(screen: screen, apps: [:], texts: ["Hello Talkie"])
    struct State: Encodable, Sendable {
      var goal: String
      var screen: ScreenState
      var history: [String]
    }
    let result = try await client.ask(
      State(goal: "Type \"Hello Talkie\" into this document", screen: screen, history: []),
      questions: JevClient.actionQuestions(actions))
    XCTAssertEqual(actions.first { $0.id == result.answers["next"]?.choice }?.kind, .type)
    print("LIVE type: \(result.milliseconds) ms")
  }

  func testLiveConversation() async throws {
    _ = try jev()
    let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    guard !key.isEmpty else { throw XCTSkip("No OpenAI key.") }
    let reply = try await AssistantClient(key: key).reply(
      goal: "What result is shown?", screen: "Calculator display: 576", history: [], research: false
    )
    XCTAssertTrue(reply.text.contains("576"))
  }

  func testLiveArithmeticContinuesAfterFirstOperand() async throws {
    let client = try jev()
    struct State: Encodable, Sendable {
      var goal: String
      var screen: ScreenState
      var history: [String]
    }
    let labels = [
      "Delete", "Clear", "Percent", "Divide", "7", "8", "9", "Multiply",
      "4", "5", "6", "Subtract", "1", "2", "3", "Add", "Change Sign", "0", "Point", "Equals",
    ]
    let screen = ScreenState(
      app: "Calculator", bundleID: "com.apple.calculator",
      elements: [ScreenElement(id: "display", role: "AXStaticText", label: "", value: "48")]
        + labels.enumerated().map {
          ScreenElement(id: "e\($0.offset)", role: "AXButton", label: $0.element, actionable: true)
        })
    let actions = ActionPolicy.candidates(screen: screen, apps: [:], texts: [])
    for _ in 0..<3 {
      let result = try await client.chooseAction(
        State(
          goal: "calculate 48 times 12 in calculator", screen: screen,
          history: ["1. Button: 4 [executed]", "2. Button: 8 [executed]"]),
        candidates: actions)
      XCTAssertEqual(result.answers["next"]?.choice, "e7")
    }
  }

  func testLiveDraftJudgment() async throws {
    let client = try jev()
    for (request, expected) in [
      ("Write a short poem about autumn in TextEdit", true),
      ("Type hello world into TextEdit", false),
    ] {
      let result = try await client.ask(
        ["request": request],
        questions: [
          "draft": .noul(
            "Does the user ask to compose NEW original text (such as an email, poem or note) to put in an app, rather than type supplied words or discuss the screen?"
          )
        ])
      XCTAssertEqual((result.answers["draft"]?.noul ?? 0) > 0.8, expected)
    }
  }

  func testLiveWebResearchIncludesSources() async throws {
    _ = try jev()
    let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    guard !key.isEmpty else { throw XCTSkip("No OpenAI key.") }
    let reply = try await AssistantClient(key: key).reply(
      goal: "Find Apple's official page about macOS accessibility. Include a source.", screen: "",
      history: [], research: true)
    XCTAssertFalse(reply.sources.isEmpty)
    XCTAssertTrue(
      reply.sources.contains { URL(string: $0.url)?.host?.contains("apple.com") == true })
  }
}
