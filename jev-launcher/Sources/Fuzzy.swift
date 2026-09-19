import Foundation

/// Fast, deterministic fuzzy matcher used to prefilter the local index before anything is sent
/// to Jev, and as the complete ranking when Jev is off or unavailable.
enum Fuzzy {
  static let stopwords: Set<String> = [
    "the", "a", "an", "i", "my", "me", "to", "of", "that", "just", "please", "open", "launch",
    "run", "go", "show", "find", "get", "up", "it", "ve", "s", "d", "ll", "re", "m", "in", "on",
    "from", "for", "with", "all", "every", "everything", "any", "and", "was", "were", "been",
    "have", "had", "ive", "did", "about", "at", "page", "pages", "site", "sites", "stuff",
    "thing", "things", "read", "looked", "saw", "some", "those", "these", "them", "this",
    "opened", "used", "last", "edited", "modified", "working", "worked",
  ]

  static func tokens(_ text: String) -> [String] {
    text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" }).map {
      String($0)
    }
  }

  /// Score in 0...1. Zero means the candidate should not be shown for this query.
  static func score(query: String, candidate: Candidate) -> Double {
    let all = tokens(query)
    guard !all.isEmpty else { return 0 }
    var meaningful = all.filter { !stopwords.contains($0) }
    if meaningful.isEmpty { meaningful = all }

    let terms = candidate.searchTerms
    let titleTokens = tokens(candidate.title)
    let joinedTitle = titleTokens.joined()
    let initials = String(titleTokens.compactMap(\.first))

    var total = 0.0
    var unmatched = 0
    for token in meaningful {
      let best = bestMatch(
        token: token, terms: terms, joinedTitle: joinedTitle, initials: initials)
      if best == 0 { unmatched += 1 }
      total += best
    }
    guard total > 0 else { return 0 }
    var score = total / Double(meaningful.count)
    if unmatched > 0 { score *= 0.5 }
    // Prefer shorter titles when everything else is equal.
    score += 0.02 * max(0, 1 - Double(candidate.title.count) / 40)
    return min(1, score)
  }

  private static func bestMatch(
    token: String, terms: [String], joinedTitle: String, initials: String
  )
    -> Double
  {
    var best = 0.0
    for term in terms {
      if term == token {
        return 1
      }
      if token.hasSuffix("s"), String(token.dropLast()) == term {
        best = max(best, 0.98)
      }
      if term.hasPrefix(token) {
        best = max(best, 0.8 + 0.15 * Double(token.count) / Double(term.count))
      }
    }
    if best > 0 { return best }
    if token.count >= 2, initials.hasPrefix(token) {
      return 0.7
    }
    if joinedTitle.contains(token) {
      return 0.55
    }
    if token.count >= 3, let contiguity = subsequenceContiguity(token, in: joinedTitle) {
      return 0.2 + 0.2 * contiguity
    }
    return 0
  }

  /// Returns the fraction of adjacent matches when `needle` is a subsequence of `haystack`.
  static func subsequenceContiguity(_ needle: String, in haystack: String) -> Double? {
    var needleIndex = needle.startIndex
    var lastMatch: String.Index?
    var adjacent = 0
    for index in haystack.indices where needleIndex < needle.endIndex {
      if haystack[index] == needle[needleIndex] {
        if let last = lastMatch, haystack.index(after: last) == index { adjacent += 1 }
        lastMatch = index
        needleIndex = needle.index(after: needleIndex)
      }
    }
    guard needleIndex == needle.endIndex else { return nil }
    return needle.count > 1 ? Double(adjacent) / Double(needle.count - 1) : 1
  }
}
