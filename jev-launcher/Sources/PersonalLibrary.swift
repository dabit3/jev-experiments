import Combine
import Foundation

@MainActor
final class PersonalLibrary: ObservableObject {
  struct Record: Codable, Equatable {
    var candidate: Candidate
    var count = 0
    var lastOpened: Date?
    var pinned = false
    var queries: [String] = []
  }

  struct Workspace: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var members: [Candidate]

    var candidate: Candidate {
      Candidate(
        id: id, title: name,
        subtitle:
          "\(members.count) items · \(members.prefix(3).map(\.title).joined(separator: ", ")) · Saved workspace",
        kind: .openFile, keywords: ["workspace", "project", "session"] + members.map(\.title),
        payload: .group(members))
    }
  }

  struct Snapshot: Codable {
    var records: [String: Record] = [:]
    var workspaces: [Workspace] = []
  }

  static let storageKey = "launcher.library.v1"
  @Published private(set) var snapshot: Snapshot
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    snapshot =
      defaults.data(forKey: Self.storageKey)
      .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
  }

  func isPinned(_ candidate: Candidate) -> Bool {
    snapshot.records[candidate.id]?.pinned == true
  }

  func togglePin(_ candidate: Candidate) {
    guard candidate.isOpenable || candidate.id.hasPrefix("workspace:") else { return }
    var record = snapshot.records[candidate.id] ?? Record(candidate: candidate)
    record.pinned.toggle()
    snapshot.records[candidate.id] = record
    save()
  }

  func record(_ candidate: Candidate, query: String, now: Date = Date()) {
    if case .group(let members) = candidate.payload {
      for member in members { record(member, query: "", now: now) }
      if !candidate.id.hasPrefix("workspace:") { return }
    }
    guard candidate.isOpenable || candidate.id.hasPrefix("workspace:") else { return }
    var record = snapshot.records[candidate.id] ?? Record(candidate: candidate)
    record.candidate = candidate
    record.count += 1
    record.lastOpened = now
    let normalized = Self.normalize(query)
    if !normalized.isEmpty {
      record.queries.removeAll { $0 == normalized }
      record.queries.insert(normalized, at: 0)
      record.queries = Array(record.queries.prefix(8))
    }
    snapshot.records[candidate.id] = record
    save()
  }

  @discardableResult
  func saveWorkspace(name: String, members: [Candidate]) -> Bool {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    var seen = Set<String>()
    let members = members.filter { $0.isOpenable && seen.insert($0.id).inserted }
    guard !name.isEmpty, members.count >= 2, members.count <= Ranker.maximumSetSize,
      snapshot.workspaces.count < 20
    else { return false }
    snapshot.workspaces.append(
      Workspace(
        id: "workspace:\(UUID().uuidString)", name: String(name.prefix(80)), members: members))
    save()
    return true
  }

  func deleteWorkspace(id: String) {
    snapshot.workspaces.removeAll { $0.id == id }
    snapshot.records.removeValue(forKey: id)
    save()
  }

  func clearHistory() {
    snapshot.records = snapshot.records.filter { $0.value.pinned }.mapValues {
      Record(candidate: $0.candidate, pinned: true)
    }
    save()
  }

  func candidates(now: Date = Date()) -> [Candidate] {
    let items = snapshot.records.values.compactMap { record -> Candidate? in
      guard !record.candidate.id.hasPrefix("workspace:") else { return nil }
      if let url = record.candidate.fileURL {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if record.candidate.kind == .openFile {
          let fresh = LocalIndex.fileCandidate(
            url: url, folder: url.deletingLastPathComponent().lastPathComponent, now: now)
          let opened = [fresh.lastOpenedAt, record.lastOpened].compactMap { $0 }.max()
          var detail = fresh.subtitle
          if let date = record.lastOpened, date > (fresh.lastOpenedAt ?? .distantPast) {
            detail +=
              " · "
              + LocalIndex.recency(max(0, now.timeIntervalSince(date)) / 86_400)
              .replacingOccurrences(of: "modified", with: "opened in launcher")
          }
          return Candidate(
            id: fresh.id, title: fresh.title, subtitle: detail, kind: fresh.kind,
            keywords: fresh.keywords, payload: fresh.payload, ageDays: fresh.ageDays,
            modifiedAt: fresh.modifiedAt,
            lastOpenedAt: opened,
            addedAt: fresh.addedAt)
        }
      }
      return record.candidate
    }
    return items + snapshot.workspaces.map(\.candidate)
  }

  func home(candidates: [Candidate], scope: SearchScope) -> [RankedHit] {
    candidates.filter { candidate in
      scope.includes(candidate)
        && (snapshot.records[candidate.id] != nil || candidate.id.hasPrefix("workspace:"))
    }
    .sorted {
      let lhs = snapshot.records[$0.id]
      let rhs = snapshot.records[$1.id]
      if (lhs?.pinned ?? false) != (rhs?.pinned ?? false) { return lhs?.pinned == true }
      if lhs?.lastOpened != rhs?.lastOpened {
        return (lhs?.lastOpened ?? .distantPast) > (rhs?.lastOpened ?? .distantPast)
      }
      return $0.title < $1.title
    }
    .prefix(8)
    .map {
      RankedHit(
        candidate: $0, fuzzy: 0, jevProbability: nil, matchProbability: nil, inSet: false, score: 0)
    }
  }

  func boosts(query: String, now: Date = Date()) -> [String: Double] {
    let normalized = Self.normalize(query)
    return snapshot.records.mapValues { record in
      if record.queries.contains(normalized) { return 0.35 }
      let age = now.timeIntervalSince(record.lastOpened ?? .distantPast) / 86_400
      return (record.pinned ? 0.04 : 0) + 0.06 * exp(-max(0, age) / 7)
        + min(0.04, Double(record.count) * 0.005)
    }
  }

  static func normalize(_ query: String) -> String {
    String(Fuzzy.tokens(query).joined(separator: " ").prefix(160))
  }

  private func save() {
    let retained = snapshot.records.sorted {
      if $0.value.pinned != $1.value.pinned { return $0.value.pinned }
      return ($0.value.lastOpened ?? .distantPast) > ($1.value.lastOpened ?? .distantPast)
    }.prefix(200)
    snapshot.records = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
    if let data = try? JSONEncoder().encode(snapshot) {
      defaults.set(data, forKey: Self.storageKey)
    }
  }
}
