import Foundation

enum SearchScope: String, CaseIterable, Identifiable {
  case all = "All"
  case files = "Files"
  case apps = "Apps"
  case links = "Links"
  case workspaces = "Workspaces"

  var id: String { rawValue }

  func includes(_ candidate: Candidate) -> Bool {
    switch self {
    case .all: return true
    case .files: return candidate.kind == .openFile && candidate.fileURL != nil
    case .apps: return candidate.kind == .openApp
    case .links: return candidate.kind == .openURL
    case .workspaces: return candidate.id.hasPrefix("workspace:")
    }
  }
}

enum FileRecency {
  case modified, opened, added

  init(query: String) {
    let words = Set(Fuzzy.tokens(query))
    if !words.isDisjoint(with: ["opened", "used", "working", "worked"]) {
      self = .opened
    } else if !words.isDisjoint(with: ["downloaded", "download", "added"]) {
      self = .added
    } else {
      self = .modified
    }
  }
}
