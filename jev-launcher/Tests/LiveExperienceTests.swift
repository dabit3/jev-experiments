import XCTest

@testable import JevLauncher

final class LiveExperienceTests: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipUnless(
      JevClient.apiKey() != nil && ProcessInfo.processInfo.environment["JEV_LIVE"] == "1",
      "Set TYPESAFE_API_KEY and JEV_LIVE=1 to run live probes")
  }

  private func judge(_ query: String, candidates: [Candidate]) async throws -> [RankedHit] {
    let prefiltered = Ranker.prefilter(query: query, index: candidates)
    let request = JevQuestions.buildRequest(
      query: query,
      context: .init(
        frontmostApp: "Finder", recentApps: [], clipboardKind: "empty",
        timeOfDay: "afternoon", weekday: "Saturday"),
      candidates: prefiltered.candidates, window: prefiltered.window)
    let result = try await JevClient().ask(request)
    let judgment = try XCTUnwrap(
      JevQuestions.parse(result.response, candidates: prefiltered.candidates))
    let hits = Ranker.rank(prefiltered, judgment: judgment)
    print(
      "Live query: \(query); top: \(hits.first?.candidate.title ?? "none"); \(Int(result.latencyMs)) ms; \(result.response.usage.inputTokens) tokens"
    )
    return hits
  }

  func testOpenedDocumentBeatsRecentlyEditedDocument() async throws {
    let now = Date()
    let read = Candidate(
      id: "read", title: "Annual-report.pdf",
      subtitle: "PDF in Documents · opened 2 min ago · modified 2 months ago",
      kind: .openFile, keywords: ["pdf", "file"],
      payload: .file(URL(fileURLWithPath: "/fixtures/annual.pdf")),
      modifiedAt: now.addingTimeInterval(-5_000_000), lastOpenedAt: now.addingTimeInterval(-120))
    let edited = Candidate(
      id: "edited", title: "Budget.pdf",
      subtitle: "PDF in Documents · opened 7 days ago · modified just now",
      kind: .openFile, keywords: ["pdf", "file"],
      payload: .file(URL(fileURLWithPath: "/fixtures/budget.pdf")),
      modifiedAt: now, lastOpenedAt: now.addingTimeInterval(-604_800))
    let hits = try await judge("the last pdf I opened", candidates: [read, edited])
    XCTAssertEqual(hits.first?.id, read.id)
    XCTAssertFalse(hits.contains(where: \.isGroup))
  }

  func testDownloadedRecencyDistinguishesMatchingRoundedLabels() async throws {
    let now = Date()
    let newest = Candidate(
      id: "newest", title: "Gamma.pdf",
      subtitle: "PDF in Downloads · added 7 min ago · modified 14 days ago",
      kind: .openFile, keywords: ["pdf", "downloaded"],
      payload: .file(URL(fileURLWithPath: "/fixtures/gamma.pdf")),
      modifiedAt: now.addingTimeInterval(-1_209_600), addedAt: now.addingTimeInterval(-421))
    let edited = Candidate(
      id: "edited", title: "Beta.pdf",
      subtitle: "PDF in Downloads · added 7 min ago · modified just now",
      kind: .openFile, keywords: ["pdf", "downloaded"],
      payload: .file(URL(fileURLWithPath: "/fixtures/beta.pdf")),
      modifiedAt: now, addedAt: now.addingTimeInterval(-446))
    let hits = try await judge("the pdf I just downloaded", candidates: [edited, newest])
    XCTAssertEqual(hits.first?.id, newest.id)
  }

  func testNamedWorkspaceIsASingleTarget() async throws {
    let workspace = await MainActor.run {
      PersonalLibrary.Workspace(
        id: "workspace:writing", name: "Writing", members: [Fixtures.safari, Fixtures.roadmap]
      ).candidate
    }
    let hits = try await judge(
      "open my writing workspace", candidates: [workspace, Fixtures.safari])
    XCTAssertEqual(hits.first?.id, workspace.id)
    XCTAssertFalse(hits.contains { $0.id == Ranker.groupID })
  }

  func testRecentOpenedFilesCanFormAGroup() async throws {
    let files = (1...3).map { index in
      Candidate(
        id: "file:\(index)", title: "Project-notes-\(index).pdf",
        subtitle: "PDF in Documents · opened \(index) min ago · modified 1 month ago",
        kind: .openFile, keywords: ["pdf", "file", "document"],
        payload: .file(URL(fileURLWithPath: "/fixtures/\(index).pdf")),
        modifiedAt: Date().addingTimeInterval(-2_600_000),
        lastOpenedAt: Date().addingTimeInterval(-Double(index * 60)))
    }
    let hits = try await judge("open all the pdfs I used in the last hour", candidates: files)
    let top = try XCTUnwrap(hits.first)
    guard case .group(let members) = top.candidate.payload else { return XCTFail("Expected group") }
    XCTAssertEqual(members.count, 3)
  }
}
