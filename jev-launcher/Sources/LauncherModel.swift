import AppKit
import Combine
import Foundation

@MainActor
final class LauncherModel: ObservableObject {
  static let readyThreshold = 0.6
  static let certainTargetThreshold = 0.9
  static let certainSetThreshold = 0.75

  @Published var query = "" {
    didSet { if query != oldValue { queryChanged() } }
  }
  @Published var scope: SearchScope = .all {
    didSet { if scope != oldValue { queryChanged() } }
  }
  @Published private(set) var hits: [RankedHit] = []
  @Published var selection = 0
  @Published private(set) var judgment: JevJudgment?
  @Published private(set) var judgmentIsFresh = false
  @Published private(set) var stats = LatencyStats()
  @Published private(set) var inFlight = 0
  @Published private(set) var lastError: String?
  @Published private(set) var status: String?
  @Published private(set) var indexSize = 0
  @Published private(set) var isIndexing = false
  @Published var actionsVisible = false {
    didSet {
      if actionsVisible {
        actionSelection = 0
        manuallySelectedID = topHit?.id
      }
    }
  }
  @Published private(set) var actionSelection = 0
  @Published var workspaceName = ""
  @Published var savingWorkspace = false
  @Published private(set) var confirmation: Candidate?
  @Published private(set) var isExecuting = false

  let library: PersonalLibrary
  var onExecute: (() -> Void)?
  var onPreview: ((URL) -> Void)?

  private let defaults: UserDefaults
  private var index: [Candidate] = []
  private var spotlightCandidates: [Candidate] = []
  private var libraryCandidates: [Candidate] = []
  private var prefiltered = Ranker.Prefiltered(candidates: [], fuzzy: [:])
  private var sequence = 0
  private var queryGeneration = 0
  private var indexGeneration = 0
  private var manuallySelectedID: String?
  private var memberSelection: Set<String>?
  private var selectedMemberCandidates: [String: Candidate] = [:]
  private var reviewedGroup: [Candidate]?
  private var retryAfter = Date.distantPast
  private var backoff: TimeInterval = 0
  private var isShowing = false
  private var context = LaunchContext(
    frontmostApp: "", recentApps: [], clipboardKind: "empty", timeOfDay: "", weekday: "")
  private let ask: @Sendable (JevRequest) async throws -> JevClient.Result
  private let execute: @MainActor (Candidate) async -> Executor.Outcome
  private let spotlight = SpotlightSearch()
  private var indexTask: Task<Void, Never>?
  private var requestTask: Task<Void, Never>?
  private var subscriptions = Set<AnyCancellable>()

  init(
    defaults: UserDefaults = .standard,
    execute: (@MainActor (Candidate) async -> Executor.Outcome)? = nil,
    ask: (@Sendable (JevRequest) async throws -> JevClient.Result)? = nil
  ) {
    self.defaults = defaults
    library = PersonalLibrary(defaults: defaults)
    let client = JevClient()
    self.ask = ask ?? { try await client.ask($0) }
    self.execute = execute ?? { await Executor.perform($0) }
    NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self, self.isShowing else { return }
        self.preferencesChanged()
      }
      .store(in: &subscriptions)
    currentPreferences = preferences
    libraryCandidates = library.candidates()
  }

  private struct Preferences: Equatable {
    let history: Bool
    let spotlight: Bool
    let localOnly: Bool
  }

  private var preferences: Preferences {
    Preferences(
      history: defaults.object(forKey: "includeChromeHistory") as? Bool ?? true,
      spotlight: defaults.object(forKey: "includeSpotlight") as? Bool ?? true,
      localOnly: defaults.bool(forKey: "localOnly"))
  }

  private var currentPreferences = Preferences(history: true, spotlight: true, localOnly: false)
  var isLocalOnly: Bool { preferences.localOnly }
  var isEmptyQuery: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var hasAPIKey: Bool { JevClient.apiKey() != nil }
  var topHit: RankedHit? { hits.indices.contains(selection) ? hits[selection] : hits.first }
  var hasEditableGroup: Bool { memberSelection != nil || hits.contains { $0.id == Ranker.groupID } }

  var selectedMembers: [Candidate] {
    if case .group(let members) = topHit?.candidate.payload { return members }
    if let group = hits.first(where: { $0.id == Ranker.groupID }),
      case .group(let members) = group.candidate.payload
    {
      return members
    }
    return []
  }

  var availableActions: [LauncherAction] {
    guard let candidate = topHit?.candidate else { return [] }
    var actions: [LauncherAction] = [.open]
    if case .file = candidate.payload { actions.append(.preview) }
    if candidate.fileURL != nil { actions.append(.reveal) }
    if Executor.copyText(candidate) != nil { actions.append(.copy) }
    if candidate.isOpenable || candidate.id.hasPrefix("workspace:") { actions.append(.pin) }
    if candidate.isOpenable { actions.append(.member) }
    if case .group = candidate.payload { actions.append(.reviewGroup) }
    if selectedMembers.count >= 2 { actions.append(.saveWorkspace) }
    if candidate.id.hasPrefix("workspace:") { actions.append(.deleteWorkspace) }
    return actions
  }

  func moveActionSelection(by delta: Int) {
    actionSelection = min(max(0, actionSelection + delta), max(0, availableActions.count - 1))
  }

  func performSelectedAction() {
    guard availableActions.indices.contains(actionSelection) else { return }
    performAction(availableActions[actionSelection])
  }

  func performAction(_ action: LauncherAction) {
    switch action {
    case .open: executeSelection()
    case .preview: previewSelection()
    case .reveal: revealSelection()
    case .copy: copySelection()
    case .pin: togglePin()
    case .member:
      if let candidate = topHit?.candidate { toggleMember(candidate) }
      actionsVisible = false
    case .reviewGroup: reviewGroup()
    case .saveWorkspace:
      workspaceName = ""
      savingWorkspace = true
    case .deleteWorkspace: deleteWorkspace()
    }
  }

  var isReady: Bool {
    guard let judgment, judgmentIsFresh, selection == 0, let top = hits.first,
      !isExecuting, confirmation == nil, judgment.noneProbability < 0.5
    else { return false }
    if top.id == Ranker.groupID {
      return memberSelection == nil && judgment.setProbability >= Self.certainSetThreshold
    }
    return judgment.ready >= Self.readyThreshold
      || (top.jevProbability ?? 0) >= Self.certainTargetThreshold
  }

  func panelWillShow() {
    isShowing = true
    if currentPreferences != preferences {
      currentPreferences = preferences
      index = []
      spotlightCandidates = []
    }
    captureContext()
    status = nil
    libraryCandidates = library.candidates()
    refreshResults()
    rebuildIndex()
  }

  func rebuildIndex() {
    indexGeneration += 1
    let generation = indexGeneration
    indexTask?.cancel()
    isIndexing = true
    let includeHistory = preferences.history
    indexTask = Task { [weak self] in
      let built = await Task.detached(priority: .userInitiated) {
        LocalIndex.build(includeHistory: includeHistory)
      }.value
      guard let self, !Task.isCancelled, generation == self.indexGeneration else { return }
      self.isIndexing = false
      self.replaceIndex(built.candidates)
    }
  }

  func replaceIndex(_ candidates: [Candidate]) {
    index = candidates
    indexSize = candidates.count
    refreshResults()
    if !isEmptyQuery { requestJudgment() }
  }

  func preferencesChanged() {
    guard currentPreferences != preferences else { return }
    let historyChanged = currentPreferences.history != preferences.history
    if historyChanged {
      index = []
      indexGeneration += 1
      indexTask?.cancel()
      isIndexing = false
    }
    currentPreferences = preferences
    queryChanged()
    if isShowing && historyChanged { rebuildIndex() }
  }

  func reset() {
    isShowing = false
    indexGeneration += 1
    indexTask?.cancel()
    isIndexing = false
    query = ""
    queryGeneration += 1
    sequence += 1
    requestTask?.cancel()
    inFlight = 0
    spotlight.stop()
    hits = []
    selection = 0
    judgment = nil
    judgmentIsFresh = false
    confirmation = nil
    reviewedGroup = nil
    memberSelection = nil
    selectedMemberCandidates = [:]
    manuallySelectedID = nil
    actionsVisible = false
    savingWorkspace = false
    lastError = nil
  }

  func moveSelection(by delta: Int) {
    guard !hits.isEmpty else { return }
    select(min(max(selection + delta, 0), hits.count - 1))
  }

  func select(_ index: Int) {
    guard hits.indices.contains(index) else { return }
    selection = index
    manuallySelectedID = hits[index].id
    confirmation = nil
  }

  func cycleScope(backward: Bool = false) {
    let scopes = SearchScope.allCases
    let index = scopes.firstIndex(of: scope) ?? 0
    scope = scopes[(index + (backward ? scopes.count - 1 : 1)) % scopes.count]
  }

  func toggleMember(_ candidate: Candidate) {
    guard candidate.isOpenable else { return }
    if memberSelection == nil {
      selectedMemberCandidates = Dictionary(
        uniqueKeysWithValues: hits.filter(\.inSet).map { ($0.id, $0.candidate) })
    }
    var members = memberSelection ?? Set(hits.filter(\.inSet).map(\.id))
    if members.contains(candidate.id) {
      members.remove(candidate.id)
      selectedMemberCandidates.removeValue(forKey: candidate.id)
    } else if members.count < Ranker.maximumSetSize {
      members.insert(candidate.id)
      selectedMemberCandidates[candidate.id] = candidate
    }
    memberSelection = members
    confirmation = nil
    updateHits()
  }

  func reviewGroup() {
    guard case .group(let members) = topHit?.candidate.payload else { return }
    sequence += 1
    requestTask?.cancel()
    inFlight = 0
    judgment = nil
    judgmentIsFresh = false
    reviewedGroup = members
    memberSelection = Set(members.map(\.id))
    selectedMemberCandidates = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    manuallySelectedID = Ranker.groupID
    actionsVisible = false
    refreshResults()
  }

  func togglePin() {
    guard let candidate = topHit?.candidate else { return }
    library.togglePin(candidate)
    libraryCandidates = library.candidates()
    actionsVisible = false
    refreshResults()
  }

  func saveWorkspace() {
    guard library.saveWorkspace(name: workspaceName, members: selectedMembers) else {
      status = "Use a name and 2–25 items. Up to 20 workspaces can be saved."
      return
    }
    savingWorkspace = false
    actionsVisible = false
    workspaceName = ""
    status = "Workspace saved"
    libraryCandidates = library.candidates()
    refreshResults()
  }

  func deleteWorkspace() {
    guard let candidate = topHit?.candidate, candidate.id.hasPrefix("workspace:") else { return }
    library.deleteWorkspace(id: candidate.id)
    libraryCandidates = library.candidates()
    actionsVisible = false
    refreshResults()
  }

  func clearHistory() {
    library.clearHistory()
    libraryCandidates = library.candidates()
    refreshResults()
  }

  func revealSelection() {
    guard let url = topHit?.candidate.fileURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
    onExecute?()
  }

  func previewSelection() {
    guard let candidate = topHit?.candidate, case .file(let url) = candidate.payload else { return }
    actionsVisible = false
    onPreview?(url)
  }

  func copySelection() {
    guard let candidate = topHit?.candidate, let text = Executor.copyText(candidate) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    actionsVisible = false
    status = "Copied"
  }

  func cancelOverlay() -> Bool {
    if confirmation != nil {
      confirmation = nil
      return true
    }
    if savingWorkspace {
      savingWorkspace = false
      return true
    }
    if actionsVisible {
      actionsVisible = false
      return true
    }
    return false
  }

  func executeSelection() {
    guard !isExecuting, let hit = topHit else { return }
    let candidate = confirmation ?? hit.candidate
    if case .toggle(.emptyTrash) = candidate.payload, confirmation?.id != candidate.id {
      confirmation = candidate
      manuallySelectedID = candidate.id
      return
    }
    confirmation = nil
    let executedQuery = query
    let executionGeneration = queryGeneration
    isExecuting = true
    Task {
      let result = await execute(candidate)
      isExecuting = false
      if result.succeeded {
        library.record(candidate, query: executedQuery)
        libraryCandidates = library.candidates()
      }
      guard executionGeneration == queryGeneration else { return }
      status = result.succeeded ? result.message : nil
      if result.succeeded {
        onExecute?()
      } else {
        lastError = result.message
      }
    }
  }

  private func captureContext() {
    let workspace = NSWorkspace.shared
    let recent = workspace.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap(\.localizedName).filter { $0 != "Jev Launcher" }.prefix(8)
    let hour = Calendar.current.component(.hour, from: Date())
    context = LaunchContext(
      frontmostApp: workspace.frontmostApplication?.localizedName ?? "Finder",
      recentApps: Array(recent), clipboardKind: clipboardKind(),
      timeOfDay: LaunchContext.timeOfDay(hour: hour),
      weekday: Calendar.current.weekdaySymbols[
        Calendar.current.component(.weekday, from: Date()) - 1])
  }

  private func clipboardKind() -> String {
    let types = NSPasteboard.general.types ?? []
    if types.contains(.fileURL) { return "file" }
    if types.contains(.URL) { return "url" }
    if types.contains(.png) || types.contains(.tiff) { return "image" }
    if types.contains(.string) { return "text" }
    return types.isEmpty ? "empty" : "other"
  }

  private func queryChanged() {
    queryGeneration += 1
    let generation = queryGeneration
    manuallySelectedID = nil
    memberSelection = nil
    selectedMemberCandidates = [:]
    reviewedGroup = nil
    confirmation = nil
    actionsVisible = false
    savingWorkspace = false
    judgment = nil
    judgmentIsFresh = false
    status = nil
    lastError = nil
    selection = 0
    spotlightCandidates = []
    spotlight.stop()
    refreshResults()
    requestJudgment()
    if preferences.spotlight, !isEmptyQuery, scope == .all || scope == .files {
      spotlight.search(query) { [weak self] candidates in
        guard let self, generation == self.queryGeneration else { return }
        let previous = self.prefiltered
        self.spotlightCandidates = candidates
        self.refreshResults()
        if previous != self.prefiltered { self.requestJudgment() }
      }
    }
  }

  private func refreshResults() {
    if let reviewedGroup {
      prefiltered = Ranker.Prefiltered(
        candidates: reviewedGroup,
        fuzzy: Dictionary(uniqueKeysWithValues: reviewedGroup.map { ($0.id, 1) }))
      updateHits()
      return
    }
    var candidates: [String: Candidate] = [:]
    for item in index + spotlightCandidates + libraryCandidates { candidates[item.id] = item }
    let all = Array(candidates.values).sorted { $0.id < $1.id }
    if isEmptyQuery {
      hits = library.home(candidates: all, scope: scope)
      selection =
        manuallySelectedID.flatMap { id in hits.firstIndex { $0.id == id } }
        ?? min(selection, max(0, hits.count - 1))
      return
    }
    prefiltered = Ranker.prefilter(
      query: query, index: all, scope: scope, boosts: library.boosts(query: query))
    updateHits()
  }

  private func updateHits() {
    var ranked = Ranker.rank(prefiltered, judgment: judgment)
    if let memberSelection {
      ranked.removeAll { $0.id == Ranker.groupID }
      let visible = Set(ranked.map(\.id))
      for candidate in selectedMemberCandidates.values.sorted(by: { $0.id < $1.id })
      where !visible.contains(candidate.id) {
        ranked.append(
          RankedHit(
            candidate: candidate, fuzzy: 0, jevProbability: nil,
            matchProbability: nil, inSet: true, score: 0))
      }
      ranked = ranked.map {
        RankedHit(
          candidate: $0.candidate, fuzzy: $0.fuzzy, jevProbability: $0.jevProbability,
          matchProbability: $0.matchProbability, inSet: memberSelection.contains($0.id),
          score: $0.score)
      }
      let members = ranked.filter(\.inSet).map(\.candidate)
      if !members.isEmpty {
        ranked.insert(
          RankedHit(
            candidate: Ranker.groupCandidate(members), fuzzy: 0, jevProbability: nil,
            matchProbability: nil, inSet: false, score: 1), at: 0)
      }
    }
    hits = ranked
    selection = manuallySelectedID.flatMap { id in hits.firstIndex { $0.id == id } } ?? 0
  }

  private func requestJudgment() {
    sequence += 1
    let seq = sequence
    requestTask?.cancel()
    inFlight = 0
    judgmentIsFresh = false
    guard !isEmptyQuery, reviewedGroup == nil, !prefiltered.candidates.isEmpty, !isLocalOnly,
      Date() >= retryAfter
    else {
      if !isLocalOnly, Date() < retryAfter {
        lastError = "Jev is busy. Using local search until the cooldown ends."
      }
      return
    }
    let request = JevQuestions.buildRequest(
      query: query, context: context, candidates: prefiltered.candidates, window: prefiltered.window
    )
    let sent = prefiltered
    inFlight = 1
    requestTask = Task { [ask] in
      defer { if seq == sequence { inFlight = 0 } }
      do {
        let result = try await ask(request)
        stats.recordSuccess(
          latencyMs: result.latencyMs, inputTokens: result.response.usage.inputTokens,
          outputTokens: result.response.usage.outputTokens, at: Date().timeIntervalSince1970)
        guard seq == sequence, !Task.isCancelled else {
          stats.recordStale()
          return
        }
        guard let parsed = JevQuestions.parse(result.response, candidates: sent.candidates) else {
          lastError = "Jev returned no usable ranking. Local results are available."
          return
        }
        judgment = parsed
        backoff = 0
        judgmentIsFresh = true
        lastError = nil
        updateHits()
      } catch {
        guard seq == sequence, !Task.isCancelled else { return }
        stats.recordFailure()
        judgment = nil
        judgmentIsFresh = false
        if case JevClient.Failure.rateLimited(let delay) = error {
          backoff = max(delay, min(60, max(15, backoff * 2)))
          retryAfter = Date().addingTimeInterval(backoff)
        }
        lastError = describe(error)
        updateHits()
      }
    }
  }

  private func describe(_ error: Error) -> String {
    if let failure = error as? JevClient.Failure {
      switch failure {
      case .missingAPIKey: return "Add a TypeSafe key in Settings. Local search is available."
      case .rateLimited:
        return "Jev is busy. Using local search until the cooldown ends."
      case .http(let code): return "Jev returned HTTP \(code). Using local search."
      case .transport: return "Jev is unreachable. Using local search."
      }
    }
    return error.localizedDescription
  }
}
