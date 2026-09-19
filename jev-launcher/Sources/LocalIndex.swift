import Foundation

/// Builds the local candidate index: application bundles, recent user files, system toggles,
/// user Shortcuts and Chrome history. Pure code, no model involved. Rebuilt in the background
/// when the panel opens.
struct LocalIndex: Sendable {
  var candidates: [Candidate]

  static let appDirectories = [
    "/Applications", "/System/Applications", "/System/Applications/Utilities",
  ]
  static let fileDirectories = ["Downloads", "Desktop", "Documents"]
  static let maxFilesPerDirectory = 400

  static func build(
    fileManager: FileManager = .default, now: Date = Date(), includeHistory: Bool = true
  ) -> LocalIndex {
    var candidates: [Candidate] = []
    candidates.append(contentsOf: scanApps(fileManager: fileManager))
    candidates.append(contentsOf: scanFiles(fileManager: fileManager, now: now))
    candidates.append(contentsOf: SystemToggle.allCases.map(\.candidate))
    candidates.append(contentsOf: scanShortcuts())
    if includeHistory {
      candidates.append(
        contentsOf: ChromeHistory.candidates(
          from: ChromeHistory.load(fileManager: fileManager, now: now), now: now))
    }
    return LocalIndex(candidates: candidates)
  }

  static func scanApps(fileManager: FileManager) -> [Candidate] {
    var seen = Set<String>()
    var apps: [Candidate] = []
    for directory in appDirectories + [
      fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
    ] {
      guard let names = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
      for name in names where name.hasSuffix(".app") {
        let title = String(name.dropLast(4))
        guard seen.insert(title.lowercased()).inserted else { continue }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
        apps.append(
          Candidate(
            id: "app:\(url.path)", title: title, subtitle: "Application",
            kind: .openApp, keywords: ["app", "application"], payload: .app(url)))
      }
    }
    return apps
  }

  static func scanFiles(fileManager: FileManager, now: Date) -> [Candidate] {
    let home = fileManager.homeDirectoryForCurrentUser
    var files: [Candidate] = []
    let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .isHiddenKey]
    for folder in fileDirectories {
      let root = home.appendingPathComponent(folder)
      var urls: [URL] = []
      guard
        let top = try? fileManager.contentsOfDirectory(
          at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
      else { continue }
      for url in top {
        urls.append(url)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true, !url.pathExtension.contains("app"),
          let children = try? fileManager.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        {
          urls.append(contentsOf: children)
        }
      }
      urls.sort {
        let lhs = try? $0.resourceValues(forKeys: [.contentModificationDateKey])
        let rhs = try? $1.resourceValues(forKeys: [.contentModificationDateKey])
        return (lhs?.contentModificationDate ?? .distantPast)
          > (rhs?.contentModificationDate ?? .distantPast)
      }
      for url in urls.prefix(maxFilesPerDirectory) {
        files.append(fileCandidate(url: url, folder: folder, now: now))
      }
    }
    return files
  }

  static func fileCandidate(
    url: URL, folder: String, now: Date, metadata: NSMetadataItem? = nil
  ) -> Candidate {
    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
    let isDirectory = values?.isDirectory ?? false
    let modified = values?.contentModificationDate ?? .distantPast
    let item = metadata ?? NSMetadataItem(url: url)
    let lastOpened = item?.value(forAttribute: "kMDItemLastUsedDate") as? Date
    let added = item?.value(forAttribute: "kMDItemDateAdded") as? Date
    let ageDays = max(0, now.timeIntervalSince(modified)) / 86_400
    let ext = url.pathExtension.lowercased()
    var keywords = [folder.lowercased(), "file"]
    if folder == "Downloads" { keywords.append(contentsOf: ["downloaded", "download"]) }
    if isDirectory {
      keywords.append("folder")
    } else if !ext.isEmpty {
      keywords.append(ext)
      keywords.append(contentsOf: fileTypeWords(ext))
    }
    if ageDays < 1 { keywords.append(contentsOf: ["recent", "latest", "new", "today"]) }
    let location = url.deletingLastPathComponent().path.replacingOccurrences(
      of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    var subtitle = "\(isDirectory ? "Folder" : fileTypeLabel(ext)) in \(location)"
    if let lastOpened {
      subtitle +=
        " · "
        + recency(max(0, now.timeIntervalSince(lastOpened)) / 86_400)
        .replacingOccurrences(of: "modified", with: "opened")
    }
    if let added {
      subtitle +=
        " · "
        + recency(max(0, now.timeIntervalSince(added)) / 86_400)
        .replacingOccurrences(of: "modified", with: "added")
    }
    subtitle += " · \(recency(ageDays))"
    return Candidate(
      id: "file:\(url.path)", title: url.lastPathComponent, subtitle: subtitle, kind: .openFile,
      keywords: keywords, payload: .file(url), ageDays: ageDays, modifiedAt: modified,
      lastOpenedAt: lastOpened, addedAt: added)
  }

  static func fileTypeWords(_ ext: String) -> [String] {
    switch ext {
    case "pdf": return ["document", "paper"]
    case "png", "jpg", "jpeg", "gif", "heic", "webp":
      return ["image", "picture", "photo", "screenshot"]
    case "mov", "mp4", "m4v": return ["video", "movie", "recording"]
    case "zip", "dmg", "pkg", "tar", "gz": return ["archive", "installer"]
    case "md", "txt", "rtf": return ["text", "notes"]
    case "csv", "xlsx", "numbers": return ["spreadsheet", "data"]
    case "swift", "ts", "js", "py": return ["code", "source"]
    default: return []
    }
  }

  static func fileTypeLabel(_ ext: String) -> String {
    ext.isEmpty ? "File" : ext.uppercased()
  }

  /// A human-readable recency phrase. Jev reads recency far better as words than as timestamps.
  static func recency(_ ageDays: Double) -> String {
    let minutes = ageDays * 24 * 60
    if minutes < 2 { return "modified just now" }
    if minutes < 60 { return "modified \(Int(minutes)) min ago" }
    if ageDays < 1 { return "modified \(Int(minutes / 60)) h ago" }
    if ageDays < 2 { return "modified yesterday" }
    if ageDays < 30 { return "modified \(plural(Int(ageDays), "day")) ago" }
    if ageDays < 365 { return "modified \(plural(Int(ageDays / 30), "month")) ago" }
    return "modified over a year ago"
  }

  private static func plural(_ count: Int, _ unit: String) -> String {
    count == 1 ? "1 \(unit)" : "\(count) \(unit)s"
  }

  static func scanShortcuts() -> [Candidate] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    process.arguments = ["list"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return [] }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard let output = String(data: data, encoding: .utf8) else { return [] }
    return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.prefix(200).map {
      name in
      Candidate(
        id: "shortcut:\(name)", title: name, subtitle: "Shortcut", kind: .runShortcut,
        keywords: ["shortcut", "automation"], payload: .shortcut(name))
    }
  }
}
