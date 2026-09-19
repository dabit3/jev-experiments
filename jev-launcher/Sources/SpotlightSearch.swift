import Foundation

@MainActor
final class SpotlightSearch {
  private var query: NSMetadataQuery?
  private var observers: [NSObjectProtocol] = []
  private var timeout: Task<Void, Never>?
  private var completion: (([Candidate]) -> Void)?
  private var generation = 0

  func search(_ text: String, completion: @escaping ([Candidate]) -> Void) {
    stop()
    let generation = generation
    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUserHomeScope]
    query.predicate = Self.predicate(for: text)
    let dateKey: String
    switch FileRecency(query: text) {
    case .opened: dateKey = "kMDItemLastUsedDate"
    case .added: dateKey = "kMDItemDateAdded"
    case .modified: dateKey = "kMDItemFSContentChangeDate"
    }
    query.sortDescriptors = [NSSortDescriptor(key: dateKey, ascending: false)]
    self.query = query
    self.completion = completion
    observers = [
      NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
      ) { [weak self] _ in
        Task { @MainActor in self?.finish(generation: generation) }
      }
    ]
    guard query.start() else {
      finish(generation: generation)
      return
    }
    timeout = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self?.finish(generation: generation)
    }
  }

  func stop() {
    generation += 1
    timeout?.cancel()
    timeout = nil
    query?.stop()
    query = nil
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
    completion = nil
  }

  private func finish(generation: Int) {
    guard generation == self.generation, let query else { return }
    query.disableUpdates()
    var candidates: [Candidate] = []
    for index in 0..<min(query.resultCount, 600) {
      guard let item = query.result(at: index) as? NSMetadataItem,
        let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
        Self.allowed(path: path)
      else { continue }
      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: path) else { continue }
      candidates.append(
        LocalIndex.fileCandidate(
          url: url, folder: url.deletingLastPathComponent().lastPathComponent,
          now: Date(), metadata: item))
      if candidates.count == 150 { break }
    }
    let callback = completion
    stop()
    callback?(candidates)
  }

  static func allowed(path: String, home: String = NSHomeDirectory()) -> Bool {
    guard path.hasPrefix(home + "/") else { return false }
    let relative = String(path.dropFirst(home.count + 1))
    let components = relative.split(separator: "/")
    return components.first != "Library"
      && !components.contains(where: { $0.hasPrefix(".") || $0.hasSuffix(".app") })
      && !components.contains("node_modules")
  }

  static func predicate(for text: String) -> NSPredicate {
    let remainder = TimeWindow.parse(text)?.remainder ?? text
    let ignored = Fuzzy.stopwords.union([
      "last", "latest", "recent", "recently", "opened", "used", "modified", "edited",
      "downloaded", "download", "file", "files", "document", "documents", "folder",
    ])
    let typeWords = [
      "pdf": "com.adobe.pdf", "paper": "com.adobe.pdf",
      "image": "public.image", "photo": "public.image", "picture": "public.image",
      "video": "public.movie", "movie": "public.movie",
      "spreadsheet": "public.spreadsheet", "folder": "public.folder",
    ]
    let tokens = Fuzzy.tokens(remainder).map {
      $0.hasSuffix("s") && typeWords[String($0.dropLast())] != nil ? String($0.dropLast()) : $0
    }
    let types = Set(tokens.compactMap { typeWords[$0] })
    let words = tokens.filter { !ignored.contains($0) && typeWords[$0] == nil && $0.count >= 2 }
    var predicates: [NSPredicate] = [
      NSCompoundPredicate(orPredicateWithSubpredicates: [
        NSPredicate(format: "kMDItemContentTypeTree == %@", "public.content"),
        NSPredicate(format: "kMDItemContentTypeTree == %@", "public.folder"),
      ])
    ]
    if !types.isEmpty {
      predicates.append(
        NSCompoundPredicate(
          orPredicateWithSubpredicates: types.sorted().map {
            NSPredicate(format: "kMDItemContentTypeTree == %@", $0)
          }))
    }
    if !words.isEmpty {
      let names = words.prefix(6).map {
        NSPredicate(format: "kMDItemFSName CONTAINS[cd] %@", $0)
      }
      predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: names))
    }
    if FileRecency(query: text) == .opened {
      predicates.append(NSPredicate(format: "kMDItemLastUsedDate != nil"))
    }
    return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
  }
}
