import Foundation

/// A person from the user's address book. Loaded once per panel session; never sent to Jev
/// except as the title/detail of a synthesized candidate.
struct Contact: Hashable, Codable, Sendable {
  let name: String
  let nickname: String?
  let email: String?
  let phone: String?

  init(name: String, nickname: String? = nil, email: String? = nil, phone: String? = nil) {
    self.name = name
    self.nickname = nickname
    self.email = email
    self.phone = phone
  }

  /// First name, last name, full name and nickname, lower-cased, for matching a typed name.
  var nameTerms: [String] {
    var terms = Fuzzy.tokens(name)
    terms.append(name.lowercased())
    if let nickname { terms.append(contentsOf: Fuzzy.tokens(nickname)) }
    return terms
  }

  var handle: String? { email ?? phone }
}

/// Something to hand to a person or device. Assembled in code from a verb, a contact and a
/// file; Jev picks between the assembled rows, never composes them.
struct Delivery: Hashable, Codable, Sendable {
  enum Channel: String, Codable, Sendable {
    case email
    case message
    case airDrop
  }

  let channel: Channel
  let recipient: Contact?
  let attachment: URL?
  let body: String?

  var title: String {
    let item = attachment?.lastPathComponent
    switch channel {
    case .airDrop:
      return "AirDrop \(item ?? "a file")"
    case .email:
      guard let recipient else { return "Email \(item ?? "")" }
      if let item { return "Email \(item) to \(recipient.name)" }
      return "Email \(recipient.name)"
    case .message:
      guard let recipient else { return "Message \(item ?? "")" }
      if let item { return "Message \(item) to \(recipient.name)" }
      if let body { return "Text \(recipient.name): “\(body)”" }
      return "Message \(recipient.name)"
    }
  }

  var subtitle: String {
    switch channel {
    case .airDrop: return "Opens the AirDrop picker"
    case .email:
      return ["New message in Mail", recipient?.email].compactMap { $0 }.joined(separator: " · ")
    case .message:
      return ["iMessage", recipient?.phone ?? recipient?.email].compactMap { $0 }
        .joined(separator: " · ")
    }
  }

  var id: String {
    let who = recipient?.handle ?? recipient?.name ?? "-"
    let what = attachment?.path ?? body ?? "-"
    return "send:\(channel.rawValue):\(who):\(what)"
  }

  var candidate: Candidate {
    Candidate(id: id, title: title, subtitle: subtitle, kind: .send, payload: .send(self))
  }
}

/// A reminder parsed entirely in code: "remind me to call the dentist tomorrow at 9".
struct Reminder: Hashable, Codable, Sendable {
  let title: String
  let due: Date?

  var subtitle: String {
    guard let due else { return "Adds to Reminders with no due time" }
    let formatter = DateFormatter()
    formatter.doesRelativeDateFormatting = true
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return "\(formatter.string(from: due)) · Reminders"
  }

  var candidate: Candidate {
    Candidate(
      id: "remind:\(title.lowercased()):\(due?.timeIntervalSince1970 ?? 0)",
      title: "Remind me: \(title)", subtitle: subtitle, kind: .remind, payload: .reminder(self))
  }
}

/// Deterministic parsing of compound requests. Everything here is string handling; the
/// resulting rows are candidates like any other, so Jev decides which one the user means.
enum Intents {
  static let maxContacts = 3
  static let maxAttachments = 2
  /// A file mentioned in a message must match clearly, otherwise the words are the text body.
  static let attachmentFloor = 0.3
  static let messageAttachmentFloor = 0.5
  static let fuzzyScore = 0.6

  private static let sendPattern = try! NSRegularExpression(
    pattern:
      #"^\s*(?:please\s+)?(send|share|email|e-mail|mail|text|message|imessage|airdrop|air\s*drop)\s+(.*)$"#,
    options: [.caseInsensitive])

  struct SendRequest: Equatable, Sendable {
    let channels: [Delivery.Channel]
    let recipientText: String
    let itemText: String
  }

  /// Splits "send the invoice to sarah" / "text mom I'm running late" / "airdrop the pdf" into
  /// channel(s), the words naming the person and the words naming the item or body.
  static func parseSend(_ query: String) -> SendRequest? {
    let range = NSRange(query.startIndex..., in: query)
    guard let match = sendPattern.firstMatch(in: query, range: range),
      let verbRange = Range(match.range(at: 1), in: query),
      let restRange = Range(match.range(at: 2), in: query)
    else { return nil }
    let verb = query[verbRange].lowercased().replacingOccurrences(of: " ", with: "")
    let rest = query[restRange].trimmingCharacters(in: .whitespaces)
    let channels: [Delivery.Channel]
    switch verb {
    case "email", "e-mail", "mail": channels = [.email]
    case "text", "message", "imessage": channels = [.message]
    case "airdrop": channels = [.airDrop]
    default: channels = [.email, .message]
    }
    if channels == [.airDrop] {
      let item = rest.replacingOccurrences(
        of: #"\s+to\s+.*$"#, with: "", options: .regularExpression)
      return SendRequest(channels: channels, recipientText: "", itemText: item)
    }
    if let toRange = rest.range(of: #"\s+to\s+"#, options: [.regularExpression, .backwards]) {
      let item = String(rest[..<toRange.lowerBound])
      let person = String(rest[toRange.upperBound...])
      if !person.isEmpty {
        return SendRequest(channels: channels, recipientText: person, itemText: item)
      }
    }
    // "text mom I'm running late": the person comes first, everything after is the item/body.
    let words = rest.split(separator: " ", maxSplits: 1).map(String.init)
    guard let first = words.first, !first.isEmpty else { return nil }
    return SendRequest(
      channels: channels, recipientText: first, itemText: words.count > 1 ? words[1] : "")
  }

  /// Contacts whose first name, last name or nickname starts with what was typed.
  static func matchContacts(_ text: String, in contacts: [Contact]) -> [Contact] {
    let tokens = Fuzzy.tokens(text).filter { !["mr", "ms", "dr"].contains($0) }
    guard !tokens.isEmpty else { return [] }
    var scored: [(Contact, Double)] = []
    for contact in contacts {
      let terms = contact.nameTerms
      var total = 0.0
      for token in tokens {
        if terms.contains(token) {
          total += 1
        } else if let term = terms.first(where: { $0.hasPrefix(token) }) {
          total += 0.7 + 0.3 * Double(token.count) / Double(term.count)
        } else {
          total = 0
          break
        }
      }
      if total > 0 { scored.append((contact, total / Double(tokens.count))) }
    }
    scored.sort { lhs, rhs in
      if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
      return lhs.0.name < rhs.0.name
    }
    return scored.prefix(maxContacts).map(\.0)
  }

  /// Files from the already-scored index that the item words describe, best first.
  static func matchAttachments(
    _ text: String, in scored: [(Candidate, Double)], floor: Double
  ) -> [URL] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return [] }
    let meaningful = Fuzzy.tokens(trimmed).filter { !Fuzzy.stopwords.contains($0) }
    guard !meaningful.isEmpty else { return [] }
    return scored.lazy
      .filter { candidate, score in
        guard case .file(let url) = candidate.payload, score >= floor else { return false }
        return !url.hasDirectoryPath
      }
      .prefix(maxAttachments)
      .compactMap { candidate, _ in candidate.fileURL }
  }

  /// Rows for a send request, or none when the query is not one or nothing resolves.
  static func deliveries(
    query: String, contacts: [Contact], files: [(Candidate, Double)]
  ) -> [Delivery] {
    guard let request = parseSend(query) else { return [] }
    var deliveries: [Delivery] = []
    if request.channels == [.airDrop] {
      for url in matchAttachments(request.itemText, in: files, floor: attachmentFloor) {
        deliveries.append(Delivery(channel: .airDrop, recipient: nil, attachment: url, body: nil))
      }
      return deliveries
    }
    let people = matchContacts(request.recipientText, in: contacts)
    guard !people.isEmpty else { return [] }
    let body = request.itemText.trimmingCharacters(in: .whitespaces)
    for channel in request.channels {
      let floor = channel == .message ? messageAttachmentFloor : attachmentFloor
      let attachments = matchAttachments(request.itemText, in: files, floor: floor)
      for person in people {
        guard channel == .email ? person.email != nil : person.handle != nil else { continue }
        if attachments.isEmpty {
          deliveries.append(
            Delivery(
              channel: channel, recipient: person, attachment: nil,
              body: body.isEmpty ? nil : body))
        } else {
          for url in attachments {
            deliveries.append(
              Delivery(channel: channel, recipient: person, attachment: url, body: nil))
          }
        }
      }
    }
    return deliveries
  }

  private static let remindPattern = try! NSRegularExpression(
    pattern: #"^\s*(?:remind\s+me\s+(?:to\s+)?|reminder\s+(?:to\s+)?|remember\s+to\s+)(.+)$"#,
    options: [.caseInsensitive])

  static func parseReminder(_ query: String, now: Date = Date(), calendar: Calendar = .current)
    -> Reminder?
  {
    let range = NSRange(query.startIndex..., in: query)
    guard let match = remindPattern.firstMatch(in: query, range: range),
      let bodyRange = Range(match.range(at: 1), in: query)
    else { return nil }
    let parsed = DueDate.parse(String(query[bodyRange]), now: now, calendar: calendar)
    let title = parsed.remainder.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return nil }
    return Reminder(title: title.prefix(1).uppercased() + title.dropFirst(), due: parsed.date)
  }
}

/// A due time parsed from words such as "tomorrow at 9", "in 20 minutes", "friday at 2pm",
/// "tonight". Date math lives here, in code.
enum DueDate {
  struct Parsed: Equatable {
    let date: Date?
    let remainder: String
  }

  private static let relativePattern = try! NSRegularExpression(
    pattern:
      #"\bin\s+(\d+|a|an|one|two|three|five|ten|fifteen|twenty|thirty)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?)\b"#,
    options: [.caseInsensitive])
  private static let dayPattern = try! NSRegularExpression(
    pattern:
      #"\b(?:on\s+)?(today|tonight|tomorrow|this\s+evening|this\s+afternoon|next\s+week|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thurs|fri|sat|sun)\b"#,
    options: [.caseInsensitive])
  private static let timePattern = try! NSRegularExpression(
    pattern: #"\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b|\b(noon|midnight)\b"#,
    options: [.caseInsensitive])

  private static let numberWords: [String: Int] = [
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "five": 5, "ten": 10, "fifteen": 15,
    "twenty": 20, "thirty": 30,
  ]
  private static let weekdays: [String: Int] = [
    "sunday": 1, "sun": 1, "monday": 2, "mon": 2, "tuesday": 3, "tue": 3, "tues": 3,
    "wednesday": 4, "wed": 4, "thursday": 5, "thu": 5, "thurs": 5, "friday": 6, "fri": 6,
    "saturday": 7, "sat": 7,
  ]

  static func parse(_ text: String, now: Date, calendar: Calendar) -> Parsed {
    var remainder = text
    let fullRange = NSRange(text.startIndex..., in: text)
    if let match = relativePattern.firstMatch(in: text, range: fullRange),
      let countRange = Range(match.range(at: 1), in: text),
      let unitRange = Range(match.range(at: 2), in: text),
      let phrase = Range(match.range, in: text)
    {
      let word = text[countRange].lowercased()
      let count = Double(Int(word) ?? numberWords[word] ?? 1)
      let unit = text[unitRange].lowercased()
      let seconds: TimeInterval
      if unit.hasPrefix("min") {
        seconds = 60
      } else if unit.hasPrefix("h") {
        seconds = 3_600
      } else if unit.hasPrefix("d") {
        seconds = 86_400
      } else {
        seconds = 604_800
      }
      remainder.removeSubrange(phrase)
      return Parsed(date: now.addingTimeInterval(count * seconds), remainder: tidy(remainder))
    }

    var day = calendar.startOfDay(for: now)
    var sawDay = false
    var defaultHour = 9
    if let match = dayPattern.firstMatch(in: text, range: fullRange),
      let wordRange = Range(match.range(at: 1), in: text),
      let phrase = Range(match.range, in: text)
    {
      let word = text[wordRange].lowercased().split(separator: " ").joined(separator: " ")
      sawDay = true
      switch word {
      case "today": break
      case "tonight", "this evening": defaultHour = 20
      case "this afternoon": defaultHour = 15
      case "tomorrow": day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
      case "next week": day = calendar.date(byAdding: .day, value: 7, to: day) ?? day
      default:
        if let weekday = weekdays[word] {
          let current = calendar.component(.weekday, from: now)
          var delta = (weekday - current + 7) % 7
          if delta == 0 { delta = 7 }
          day = calendar.date(byAdding: .day, value: delta, to: day) ?? day
        }
      }
      remainder = replacing(phrase, in: text, with: remainder)
    }

    var hour: Int?
    var minute = 0
    let searchRange = NSRange(remainder.startIndex..., in: remainder)
    if let match = timePattern.firstMatch(in: remainder, range: searchRange),
      let phrase = Range(match.range, in: remainder)
    {
      if let namedRange = Range(match.range(at: 4), in: remainder) {
        hour = remainder[namedRange].lowercased() == "noon" ? 12 : 0
      } else if let hourRange = Range(match.range(at: 1), in: remainder),
        let value = Int(remainder[hourRange]), value <= 23
      {
        let explicit = remainder[phrase].lowercased().hasPrefix("at")
        let meridiem = Range(match.range(at: 3), in: remainder).map {
          remainder[$0].lowercased().replacingOccurrences(of: ".", with: "")
        }
        // A bare number without "at" or am/pm is part of the title ("buy 2 tickets").
        if explicit || meridiem != nil || sawDay {
          var resolved = value
          if meridiem == "pm", value < 12 { resolved += 12 }
          if meridiem == "am", value == 12 { resolved = 0 }
          if meridiem == nil, value >= 1, value <= 6 { resolved += 12 }
          hour = resolved
          if let minuteRange = Range(match.range(at: 2), in: remainder) {
            minute = Int(remainder[minuteRange]) ?? 0
          }
        }
      }
      if hour != nil { remainder.removeSubrange(phrase) }
    }

    guard sawDay || hour != nil else { return Parsed(date: nil, remainder: tidy(remainder)) }
    var components = calendar.dateComponents([.year, .month, .day], from: day)
    components.hour = hour ?? defaultHour
    components.minute = minute
    var date = calendar.date(from: components) ?? day
    if !sawDay, date <= now { date = calendar.date(byAdding: .day, value: 1, to: date) ?? date }
    return Parsed(date: date, remainder: tidy(remainder))
  }

  private static func replacing(
    _ range: Range<String.Index>, in original: String, with text: String
  )
    -> String
  {
    let phrase = String(original[range])
    return text.replacingOccurrences(of: phrase, with: " ")
  }

  private static func tidy(_ text: String) -> String {
    text.split(separator: " ").joined(separator: " ")
      .replacingOccurrences(of: #"\s+(at|on|by)\s*$"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"^to\s+"#, with: "", options: .regularExpression)
  }
}
