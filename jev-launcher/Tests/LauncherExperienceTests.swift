import XCTest

@testable import JevLauncher

final class RetrievalTests: XCTestCase {
  func testRequestPreservesPreciseRecencyAndItsActualSource() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let added = Candidate(
      id: "added", title: "New.pdf", subtitle: "added 7 min ago", kind: .openFile,
      payload: .file(URL(fileURLWithPath: "/fixtures/new.pdf")),
      modifiedAt: now.addingTimeInterval(-1_209_600),
      addedAt: now.addingTimeInterval(-421))
    let fallback = Candidate(
      id: "fallback", title: "Fallback.pdf", subtitle: "modified 7 min ago", kind: .openFile,
      payload: .file(URL(fileURLWithPath: "/fixtures/fallback.pdf")),
      modifiedAt: now.addingTimeInterval(-446))
    let request = JevQuestions.buildRequest(
      query: "the pdf I just downloaded",
      context: .init(
        frontmostApp: "", recentApps: [], clipboardKind: "empty", timeOfDay: "", weekday: ""),
      candidates: [added, fallback, Fixtures.safari], now: now)
    XCTAssertEqual(request.state.candidates[0].recency?.secondsAgo, 421)
    XCTAssertEqual(request.state.candidates[0].recency?.basis, "added")
    XCTAssertEqual(request.state.candidates[1].recency?.secondsAgo, 446)
    XCTAssertEqual(request.state.candidates[1].recency?.basis, "modified")
    XCTAssertNil(request.state.candidates[2].recency)
  }

  let now = Date(timeIntervalSince1970: 1_800_000_000)

  func testRetryAfterAcceptsSecondsAndHTTPDate() {
    XCTAssertEqual(JevClient.retryDelay("45", now: now), 45)
    XCTAssertEqual(JevClient.retryDelay(nil, now: now), 15)
    XCTAssertEqual(JevClient.retryDelay("-1", now: now), 1)
    XCTAssertEqual(JevClient.retryDelay("not a date", now: now), 15)
    let date = Date(timeIntervalSince1970: 0)
    XCTAssertEqual(
      JevClient.retryDelay("Thu, 01 Jan 1970 00:00:30 GMT", now: date), 30)
  }

  func file(_ id: String, modified: TimeInterval, opened: TimeInterval?, added: TimeInterval? = nil)
    -> Candidate
  {
    Candidate(
      id: id, title: "\(id).pdf", subtitle: "PDF", kind: .openFile,
      keywords: ["pdf", "file", "downloaded"], payload: .file(URL(fileURLWithPath: "/\(id).pdf")),
      modifiedAt: now.addingTimeInterval(-modified),
      lastOpenedAt: opened.map { now.addingTimeInterval(-$0) },
      addedAt: added.map { now.addingTimeInterval(-$0) })
  }

  func testOpenedWindowUsesLastUseInsteadOfModification() {
    let files = [
      file("read", modified: 100_000, opened: 60),
      file("edited", modified: 30, opened: 100_000),
      file("unknown", modified: 10, opened: nil),
    ]
    let filtered = Ranker.prefilter(
      query: "pdfs I opened in the last hour", index: files, now: now, scope: .files)
    XCTAssertEqual(filtered.candidates.map(\.id), ["read"])
  }

  func testDownloadWindowPrefersArrivalTime() {
    let files = [
      file("old-content", modified: 100_000, opened: nil, added: 60),
      file("recent-edit", modified: 60, opened: nil, added: 100_000),
    ]
    let filtered = Ranker.prefilter(
      query: "pdf downloaded in the last hour", index: files, now: now, scope: .files)
    XCTAssertEqual(filtered.candidates.map(\.id), ["old-content"])
  }

  func testUnknownLastOpenedIsNotPresentedAsRecent() {
    let filtered = Ranker.prefilter(
      query: "the last pdf I opened",
      index: [file("unknown", modified: 1, opened: nil)], now: now, scope: .files)
    XCTAssertTrue(filtered.candidates.isEmpty)
  }

  func testScopesExcludeUnrelatedKindsAndSyntheticFallbacks() {
    let workspace = Candidate(
      id: "workspace:1", title: "Safari project", subtitle: "2 items",
      kind: .openFile, payload: .group([Fixtures.roadmap, Fixtures.safari]))
    let apps = Ranker.prefilter(
      query: "safari", index: Fixtures.index + [workspace], scope: .apps)
    XCTAssertEqual(apps.candidates.map(\.id), [Fixtures.safari.id])
    XCTAssertFalse(SearchScope.files.includes(workspace))
    XCTAssertTrue(SearchScope.workspaces.includes(workspace))
  }

  func testPersonalBoostCannotIntroduceUnrelatedCandidateUnlessQueryWasLearned() {
    let weak = Ranker.prefilter(
      query: "research", index: [Fixtures.safari], boosts: [Fixtures.safari.id: 0.14])
    XCTAssertFalse(weak.candidates.contains { $0.id == Fixtures.safari.id })
    let learned = Ranker.prefilter(
      query: "research", index: [Fixtures.safari], boosts: [Fixtures.safari.id: 0.35])
    XCTAssertEqual(learned.candidates.first?.id, Fixtures.safari.id)
  }

  func testAutomaticGroupsCannotExecuteSystemCommands() {
    let filtered = Ranker.prefilter(query: "wifi", index: [Fixtures.wifiOn, Fixtures.wifiOff])
    let judgment = JevJudgment(
      targetProbabilities: [:], noneProbability: 0, targetConfidence: 1, action: .systemToggle,
      actionProbabilities: [.systemToggle: 1], actionConfidence: 1, ready: 1,
      setProbability: 1, matchProbabilities: [Fixtures.wifiOn.id: 1, Fixtures.wifiOff.id: 1])
    XCTAssertTrue(Ranker.setMembers(filtered, judgment: judgment).isEmpty)
  }

  @MainActor
  func testSpotlightExcludesPrivateAndGeneratedDirectories() {
    XCTAssertTrue(
      SpotlightSearch.allowed(path: "/Users/test/Projects/notes.pdf", home: "/Users/test"))
    for path in [
      "Library/Mail/notes", ".ssh/config", "project/node_modules/readme.md", "App.app/Contents/a",
    ] {
      XCTAssertFalse(SpotlightSearch.allowed(path: "/Users/test/" + path, home: "/Users/test"))
    }
    XCTAssertFalse(SpotlightSearch.allowed(path: "/Users/test2/report.pdf", home: "/Users/test"))
  }

  @MainActor
  func testSpotlightPredicatesAreAcceptedByMetadataQuery() {
    for text in ["pdf", "nebula", "the last pdf I opened", "folder", "pdf image nebula", "files"] {
      let query = NSMetadataQuery()
      query.predicate = SpotlightSearch.predicate(for: text)
      XCTAssertNotNil(query.predicate)
    }
  }

  func testValidationRejectsUnsafeAndMissingWorkspaceMembersBeforeOpening() {
    let unsafe = Candidate(
      id: "unsafe", title: "Script", subtitle: "", kind: .openURL,
      payload: .url(URL(string: "javascript:alert(1)")!))
    XCTAssertNotNil(Executor.validationError(unsafe))
    XCTAssertNotNil(Executor.validationError(Ranker.groupCandidate([Fixtures.darkMode])))
    let missing = Candidate(
      id: "missing", title: "Missing", subtitle: "", kind: .openFile,
      payload: .file(URL(fileURLWithPath: "/does-not-exist-\(UUID())")))
    XCTAssertNotNil(Executor.validationError(Ranker.groupCandidate([missing, Fixtures.safari])))
  }

  func testCopyGroupPreservesExactPathsAndURLs() {
    let link = Candidate(
      id: "url", title: "Example", subtitle: "", kind: .openURL,
      payload: .url(URL(string: "https://example.com/?q=hello%20world")!))
    let group = Ranker.groupCandidate([Fixtures.roadmap, link])
    XCTAssertEqual(
      Executor.copyText(group), "/tmp/Q3-Roadmap-Review.pdf\nhttps://example.com/?q=hello%20world")
  }
}

@MainActor
final class PersonalLibraryTests: XCTestCase {
  func testPinsHistoryAndWorkspacesSurviveRelaunchAndHistoryClearing() throws {
    let suite = "LibraryTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let library = PersonalLibrary(defaults: defaults)
    library.togglePin(Fixtures.safari)
    library.record(Fixtures.safari, query: "my research browser")
    XCTAssertEqual(library.boosts(query: "MY research browser")[Fixtures.safari.id], 0.35)
    XCTAssertTrue(
      library.saveWorkspace(name: "Research", members: [Fixtures.safari, Fixtures.roadmap]))
    let restored = PersonalLibrary(defaults: defaults)
    XCTAssertTrue(restored.isPinned(Fixtures.safari))
    XCTAssertEqual(
      restored.snapshot.workspaces.first?.members, [Fixtures.safari, Fixtures.roadmap])
    restored.clearHistory()
    XCTAssertTrue(restored.isPinned(Fixtures.safari))
    XCTAssertTrue(restored.snapshot.records[Fixtures.safari.id]?.queries.isEmpty ?? false)
    XCTAssertNil(restored.snapshot.records[Fixtures.safari.id]?.lastOpened)
    XCTAssertEqual(restored.snapshot.workspaces.count, 1)
    restored.deleteWorkspace(id: try XCTUnwrap(restored.snapshot.workspaces.first?.id))
    XCTAssertTrue(PersonalLibrary(defaults: defaults).snapshot.workspaces.isEmpty)
  }

  func testWorkspaceValidationAndMemberDeduplication() throws {
    let suite = "LibraryTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let library = PersonalLibrary(defaults: defaults)
    XCTAssertFalse(library.saveWorkspace(name: "", members: [Fixtures.safari, Fixtures.roadmap]))
    XCTAssertFalse(
      library.saveWorkspace(name: "bad", members: [Fixtures.darkMode, Fixtures.safari]))
    XCTAssertFalse(library.saveWorkspace(name: "one", members: [Fixtures.safari, Fixtures.safari]))
    XCTAssertTrue(
      library.saveWorkspace(
        name: "two", members: [Fixtures.safari, Fixtures.roadmap, Fixtures.safari]))
    XCTAssertEqual(library.snapshot.workspaces.first?.members.count, 2)
  }

  func testWorkspaceOpenRecordsMemberUsageWithoutAssigningGroupQueryToEachMember() throws {
    let suite = "LibraryTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let library = PersonalLibrary(defaults: defaults)
    XCTAssertTrue(
      library.saveWorkspace(name: "Writing", members: [Fixtures.safari, Fixtures.roadmap]))
    let workspace = try XCTUnwrap(library.snapshot.workspaces.first)
    library.record(workspace.candidate, query: "writing")
    XCTAssertEqual(library.snapshot.records[Fixtures.roadmap.id]?.count, 1)
    XCTAssertEqual(library.snapshot.records[Fixtures.roadmap.id]?.queries, [])
    XCTAssertEqual(library.snapshot.records[workspace.id]?.queries, ["writing"])
  }
}

private actor PendingJudgments {
  struct Pending {
    let request: JevRequest
    let continuation: CheckedContinuation<JevClient.Result, Error>
  }
  var pending: [String: Pending] = [:]

  func ask(_ request: JevRequest) async throws -> JevClient.Result {
    try await withCheckedThrowingContinuation {
      pending[request.state.query] = Pending(request: request, continuation: $0)
    }
  }

  func contains(_ query: String) -> Bool { pending[query] != nil }

  func finish(_ query: String, title: String) {
    guard let pending = pending.removeValue(forKey: query) else { return }
    let id = pending.request.state.candidates.first { $0.title == title }?.id ?? "none"
    let response = JevResponse(
      model: "test",
      answers: [
        "target": .init(
          type: "choice", choice: id, confidence: 1, probabilities: [id: 1], noul: nil),
        "ready": .init(type: "noul", choice: nil, confidence: nil, probabilities: nil, noul: 1),
      ], usage: .init(inputTokens: 10, outputTokens: 0))
    pending.continuation.resume(returning: .init(response: response, latencyMs: 10))
  }
}

@MainActor
final class LauncherConcurrencyTests: XCTestCase {
  private func waitUntil(_ condition: () async -> Bool) async {
    for _ in 0..<100 {
      if await condition() { return }
      try? await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("Timed out waiting for test state")
  }

  func testOlderQueryAndHiddenPanelRejectLateResponses() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let pending = PendingJudgments()
    let model = LauncherModel(defaults: defaults) { try await pending.ask($0) }
    model.replaceIndex(Fixtures.index)
    model.query = "dark"
    await waitUntil { await pending.contains("dark") }
    model.query = "wifi"
    await waitUntil { await pending.contains("wifi") }
    await pending.finish("dark", title: Fixtures.darkMode.title)
    await waitUntil { model.stats.staleDiscarded == 1 }
    XCTAssertNil(model.judgment)
    XCTAssertFalse(model.hits.contains { $0.id == Fixtures.darkMode.id })
    model.reset()
    await pending.finish("wifi", title: Fixtures.wifiOff.title)
    await waitUntil { model.stats.staleDiscarded == 2 }
    XCTAssertTrue(model.hits.isEmpty)
    XCTAssertEqual(model.inFlight, 0)
  }

  func testManualSelectionAndGroupEditSurviveFreshRanking() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let pending = PendingJudgments()
    let model = LauncherModel(defaults: defaults) { try await pending.ask($0) }
    model.replaceIndex([Fixtures.roadmap, Fixtures.invoice])
    model.query = "pdf"
    await waitUntil { await pending.contains("pdf") }
    let invoice = try XCTUnwrap(model.hits.firstIndex { $0.id == Fixtures.invoice.id })
    model.select(invoice)
    model.toggleMember(Fixtures.roadmap)
    model.toggleMember(Fixtures.invoice)
    model.toggleMember(Fixtures.roadmap)
    await pending.finish("pdf", title: Fixtures.roadmap.title)
    await waitUntil { model.judgmentIsFresh }
    XCTAssertEqual(model.topHit?.id, Fixtures.invoice.id)
    XCTAssertEqual(model.selectedMembers.map(\.id), [Fixtures.invoice.id])
    XCTAssertFalse(model.isReady)
  }

  func testLocalModeUsesNoNetworkAndStillOffersCalculation() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "localOnly")
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let pending = PendingJudgments()
    let model = LauncherModel(defaults: defaults) { try await pending.ask($0) }
    model.query = "15% of 240"
    XCTAssertEqual(model.topHit?.candidate.title, "= 36")
    XCTAssertEqual(model.inFlight, 0)
    let sent = await pending.contains("15% of 240")
    XCTAssertFalse(sent)
  }

  func testEmptyTrashNeedsAnAdditionalExplicitConfirmation() throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "localOnly")
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = LauncherModel(defaults: defaults)
    model.replaceIndex([SystemToggle.emptyTrash.candidate])
    model.query = "empty trash"
    model.executeSelection()
    XCTAssertEqual(model.confirmation?.id, SystemToggle.emptyTrash.candidate.id)
    XCTAssertFalse(model.isExecuting)
    XCTAssertTrue(model.cancelOverlay())
    XCTAssertNil(model.confirmation)
  }

  func testSavedWorkspaceCanBeReviewedWithoutOpeningAnyMember() throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "localOnly")
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = LauncherModel(defaults: defaults)
    let workspace = PersonalLibrary.Workspace(
      id: "workspace:test", name: "Research", members: [Fixtures.roadmap, Fixtures.safari])
    model.replaceIndex([workspace.candidate])
    model.query = "Research"
    XCTAssertEqual(model.topHit?.id, workspace.id)
    XCTAssertTrue(model.availableActions.contains(.reviewGroup))
    model.reviewGroup()
    XCTAssertEqual(model.selectedMembers.count, 2)
    model.toggleMember(Fixtures.safari)
    XCTAssertEqual(model.selectedMembers.map(\.id), [Fixtures.roadmap.id])
    XCTAssertFalse(model.isExecuting)
    XCTAssertFalse(model.isReady)
    model.reset()
    XCTAssertTrue(model.hits.isEmpty)
  }

  func testFailureFallsBackAndRateLimitSuppressesSubsequentRequests() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = LauncherModel(defaults: defaults) { _ in throw JevClient.Failure.rateLimited(60) }
    model.replaceIndex(Fixtures.index)
    model.query = "dark"
    await waitUntil { model.lastError != nil }
    XCTAssertEqual(model.topHit?.id, Fixtures.darkMode.id)
    XCTAssertFalse(model.judgmentIsFresh)
    model.query = "wifi off"
    XCTAssertEqual(model.inFlight, 0)
    XCTAssertNotNil(model.lastError)
    XCTAssertEqual(model.stats.requests, 1)
  }

  func testLocalOnlySwitchInvalidatesAnOutstandingJudgment() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let pending = PendingJudgments()
    let model = LauncherModel(defaults: defaults) { try await pending.ask($0) }
    model.replaceIndex(Fixtures.index)
    model.query = "dark"
    await waitUntil { await pending.contains("dark") }
    defaults.set(true, forKey: "localOnly")
    model.preferencesChanged()
    await pending.finish("dark", title: Fixtures.darkMode.title)
    await waitUntil { model.stats.staleDiscarded == 1 }
    XCTAssertNil(model.judgment)
    XCTAssertEqual(model.inFlight, 0)
    XCTAssertEqual(model.topHit?.id, Fixtures.darkMode.id)
  }

  func testLateExecutionRecordsOriginalQueryWithoutClosingNewSearch() async throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "localOnly")
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    var finish: CheckedContinuation<Executor.Outcome, Never>?
    var executed: [String] = []
    let model = LauncherModel(
      defaults: defaults,
      execute: { candidate in
        executed.append(candidate.id)
        return await withCheckedContinuation { finish = $0 }
      })
    var closed = false
    model.onExecute = { closed = true }
    model.replaceIndex(Fixtures.index)
    model.query = "safari"
    model.executeSelection()
    model.executeSelection()
    await waitUntil { finish != nil }
    model.query = "wifi"
    finish?.resume(returning: .init(succeeded: true, message: "Opened"))
    await waitUntil { !model.isExecuting }
    XCTAssertEqual(executed, [Fixtures.safari.id])
    XCTAssertFalse(closed)
    XCTAssertNil(model.status)
    XCTAssertEqual(model.query, "wifi")
    XCTAssertEqual(model.library.snapshot.records[Fixtures.safari.id]?.queries, ["safari"])
  }

  func testKeyboardActionsRoutePreviewAndPinForSelectedFile() throws {
    let suite = "LauncherTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.set(true, forKey: "localOnly")
    defaults.set(false, forKey: "includeSpotlight")
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = LauncherModel(defaults: defaults)
    model.replaceIndex([Fixtures.roadmap])
    model.query = "roadmap"
    var previewed: URL?
    model.onPreview = { previewed = $0 }
    model.actionsVisible = true
    model.moveActionSelection(by: 1)
    XCTAssertEqual(model.availableActions[model.actionSelection], .preview)
    model.performSelectedAction()
    XCTAssertEqual(previewed, Fixtures.roadmap.fileURL)
    XCTAssertFalse(model.actionsVisible)
    model.actionsVisible = true
    model.moveActionSelection(by: try XCTUnwrap(model.availableActions.firstIndex(of: .pin)))
    model.performSelectedAction()
    XCTAssertTrue(model.library.isPinned(Fixtures.roadmap))
  }
}
