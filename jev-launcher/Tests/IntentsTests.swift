import XCTest

@testable import JevLauncher

enum PeopleFixtures {
  static let sarah = Contact(name: "Sarah Chen", email: "sarah@northwind.co", phone: "+1 555 0100")
  static let sam = Contact(name: "Sam Ortiz", email: "sam@example.com")
  static let mom = Contact(name: "Linda Park", nickname: "Mom", phone: "+1 555 0199")
  static let noHandles = Contact(name: "Sarah Blank")
  static let all = [sarah, sam, mom, noHandles]

  static let scoredFiles: [(Candidate, Double)] = [
    (Fixtures.invoice, 0.9), (Fixtures.roadmap, 0.2),
  ]
}

final class SendParsingTests: XCTestCase {
  func testSendSplitsItemAndPerson() {
    let request = Intents.parseSend("send the invoice to sarah")
    XCTAssertEqual(
      request,
      Intents.SendRequest(
        channels: [.email, .message], recipientText: "sarah", itemText: "the invoice"))
  }

  func testEmailVerbFixesChannel() {
    XCTAssertEqual(Intents.parseSend("email the roadmap to sam")?.channels, [.email])
    XCTAssertEqual(Intents.parseSend("text mom I'm running late")?.channels, [.message])
    XCTAssertEqual(Intents.parseSend("airdrop the pdf")?.channels, [.airDrop])
  }

  func testPersonFirstForm() {
    let request = Intents.parseSend("text mom I'm running late")
    XCTAssertEqual(request?.recipientText, "mom")
    XCTAssertEqual(request?.itemText, "I'm running late")
  }

  func testAirDropIgnoresRecipient() {
    let request = Intents.parseSend("airdrop the invoice to my phone")
    XCTAssertEqual(request?.recipientText, "")
    XCTAssertEqual(request?.itemText, "the invoice")
  }

  func testOrdinaryQueriesAreNotSends() {
    XCTAssertNil(Intents.parseSend("the pdf I just downloaded"))
    XCTAssertNil(Intents.parseSend("messages"))
    XCTAssertNil(Intents.parseSend("send"))
  }
}

final class ContactMatchingTests: XCTestCase {
  func testFirstNamePrefixAndNickname() {
    let sarahs = Intents.matchContacts("sar", in: PeopleFixtures.all).map(\.name)
    XCTAssertEqual(sarahs, ["Sarah Blank", "Sarah Chen"])
    XCTAssertEqual(Intents.matchContacts("mom", in: PeopleFixtures.all).map(\.name), ["Linda Park"])
  }

  func testFullNameBeatsPrefix() {
    let matched = Intents.matchContacts("sarah chen", in: PeopleFixtures.all).map(\.name)
    XCTAssertEqual(matched, ["Sarah Chen"])
  }

  func testUnknownPersonMatchesNobody() {
    XCTAssertEqual(Intents.matchContacts("zoltan", in: PeopleFixtures.all), [])
  }
}

final class DeliveryTests: XCTestCase {
  func testInvoiceToSarahBecomesEmailAndMessage() {
    let rows = Intents.deliveries(
      query: "send the invoice to sarah", contacts: PeopleFixtures.all,
      files: PeopleFixtures.scoredFiles)
    XCTAssertEqual(rows.map(\.channel), [.email, .message])
    XCTAssertTrue(rows.allSatisfy { $0.recipient == PeopleFixtures.sarah })
    XCTAssertTrue(rows.allSatisfy { $0.attachment == Fixtures.invoice.fileURL })
    XCTAssertEqual(rows[0].title, "Email invoice-2026-08.pdf to Sarah Chen")
    XCTAssertEqual(rows[0].subtitle, "New message in Mail · sarah@northwind.co")
    XCTAssertEqual(rows[1].title, "Message invoice-2026-08.pdf to Sarah Chen")
  }

  func testContactWithoutHandlesIsSkipped() {
    let rows = Intents.deliveries(
      query: "email the invoice to sarah blank", contacts: PeopleFixtures.all,
      files: PeopleFixtures.scoredFiles)
    XCTAssertEqual(rows, [])
  }

  func testTextWithoutAFileCarriesTheBody() {
    let rows = Intents.deliveries(
      query: "text mom I'm running late", contacts: PeopleFixtures.all, files: [])
    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].channel, .message)
    XCTAssertEqual(rows[0].body, "I'm running late")
    XCTAssertNil(rows[0].attachment)
    XCTAssertEqual(rows[0].title, "Text Linda Park: “I'm running late”")
  }

  func testWeakFileMatchInAMessageIsTreatedAsText() {
    let rows = Intents.deliveries(
      query: "text sarah the roadmap looks great", contacts: PeopleFixtures.all,
      files: [(Fixtures.roadmap, 0.4)])
    XCTAssertEqual(rows.count, 1)
    XCTAssertNil(rows[0].attachment)
    XCTAssertEqual(rows[0].body, "the roadmap looks great")
  }

  func testAirDropNeedsNoContact() {
    let rows = Intents.deliveries(
      query: "airdrop the invoice", contacts: [], files: PeopleFixtures.scoredFiles)
    XCTAssertEqual(rows.map(\.channel), [.airDrop])
    XCTAssertNil(rows[0].recipient)
    XCTAssertEqual(rows[0].title, "AirDrop invoice-2026-08.pdf")
  }

  func testNothingWhenNobodyMatches() {
    XCTAssertEqual(
      Intents.deliveries(
        query: "send the invoice to zoltan", contacts: PeopleFixtures.all,
        files: PeopleFixtures.scoredFiles), [])
  }

  func testRecipientHandlePerChannel() {
    XCTAssertEqual(Sharing.recipientHandle(PeopleFixtures.mom, channel: .message), "+1 555 0199")
    XCTAssertNil(Sharing.recipientHandle(PeopleFixtures.mom, channel: .email))
    XCTAssertEqual(
      Sharing.recipientHandle(PeopleFixtures.sam, channel: .message), "sam@example.com")
    XCTAssertNil(Sharing.recipientHandle(PeopleFixtures.sarah, channel: .airDrop))
  }
}

final class ReminderParsingTests: XCTestCase {
  // Wednesday 2026-09-16 10:30 local.
  let now = Calendar.current.date(
    from: DateComponents(year: 2026, month: 9, day: 16, hour: 10, minute: 30))!

  private func components(_ date: Date?) -> DateComponents {
    Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date!)
  }

  func testTomorrowAtNine() {
    let reminder = Intents.parseReminder("remind me to call the dentist tomorrow at 9", now: now)
    XCTAssertEqual(reminder?.title, "Call the dentist")
    let due = components(reminder?.due)
    XCTAssertEqual([due.day, due.hour, due.minute], [17, 9, 0])
  }

  func testAfternoonNumbersReadAsPM() {
    let reminder = Intents.parseReminder("remind me to submit the report friday at 2", now: now)
    XCTAssertEqual(reminder?.title, "Submit the report")
    let due = components(reminder?.due)
    XCTAssertEqual([due.day, due.hour], [18, 14])
  }

  func testRelativeMinutes() {
    let reminder = Intents.parseReminder("remind me in 20 minutes to check the oven", now: now)
    XCTAssertEqual(reminder?.title, "Check the oven")
    XCTAssertEqual(reminder?.due, now.addingTimeInterval(20 * 60))
  }

  func testTonightDefaultsToEvening() {
    let reminder = Intents.parseReminder("remind me to water the plants tonight", now: now)
    XCTAssertEqual(reminder?.title, "Water the plants")
    XCTAssertEqual(components(reminder?.due).hour, 20)
  }

  func testPastTimeTodayRollsToTomorrow() {
    let reminder = Intents.parseReminder("remind me to stretch at 8am", now: now)
    let due = components(reminder?.due)
    XCTAssertEqual([due.day, due.hour], [17, 8])
  }

  func testBareNumbersStayInTheTitle() {
    let reminder = Intents.parseReminder("remind me to buy 2 tickets", now: now)
    XCTAssertEqual(reminder?.title, "Buy 2 tickets")
    XCTAssertNil(reminder?.due)
  }

  func testNotAReminder() {
    XCTAssertNil(Intents.parseReminder("reminders", now: now))
    XCTAssertNil(Intents.parseReminder("the pdf I just downloaded", now: now))
  }
}

final class IntentRankingTests: XCTestCase {
  func testSendRowsJoinThePrefilterWithTheirParts() {
    let prefiltered = Ranker.prefilter(
      query: "send the invoice to sarah", index: Fixtures.index, contacts: PeopleFixtures.all)
    let ids = prefiltered.candidates.map(\.id)
    let sendRows = prefiltered.candidates.filter { $0.kind == .send }
    XCTAssertEqual(sendRows.count, 2)
    XCTAssertTrue(ids.contains(Fixtures.invoice.id))
    XCTAssertTrue(ids.contains(Ranker.webSearchID))
    XCTAssertEqual(prefiltered.fuzzy[sendRows[0].id], Ranker.intentFuzzy)
    XCTAssertGreaterThan(
      prefiltered.fuzzy[sendRows[0].id] ?? 0, prefiltered.fuzzy[Fixtures.invoice.id] ?? 0)
  }

  func testNoContactsMeansNoSendRows() {
    let prefiltered = Ranker.prefilter(query: "send the invoice to sarah", index: Fixtures.index)
    XCTAssertFalse(prefiltered.candidates.contains { $0.kind == .send })
    XCTAssertTrue(prefiltered.candidates.contains { $0.id == Fixtures.invoice.id })
  }

  func testSendRowsOnlyInAllScope() {
    let prefiltered = Ranker.prefilter(
      query: "send the invoice to sarah", index: Fixtures.index, scope: .files,
      contacts: PeopleFixtures.all)
    XCTAssertFalse(prefiltered.candidates.contains { $0.kind == .send })
  }

  func testReminderRowLeadsLocally() {
    let prefiltered = Ranker.prefilter(
      query: "remind me to call the dentist tomorrow at 9", index: Fixtures.index)
    let hits = Ranker.rank(prefiltered, judgment: nil)
    XCTAssertEqual(hits.first?.candidate.kind, .remind)
    XCTAssertEqual(hits.first?.candidate.title, "Remind me: Call the dentist")
  }

  func testJevTargetLiftsTheSendRowAboveTheFile() {
    let prefiltered = Ranker.prefilter(
      query: "send the invoice to sarah", index: Fixtures.index, contacts: PeopleFixtures.all)
    let email = prefiltered.candidates.first { $0.kind == .send }!
    let judgment = JevJudgment(
      targetProbabilities: [email.id: 0.9, Fixtures.invoice.id: 0.08],
      noneProbability: 0.02, targetConfidence: 0.9, action: .send,
      actionProbabilities: [.send: 0.9, .openFile: 0.1], actionConfidence: 0.9, ready: 0.95)
    let hits = Ranker.rank(prefiltered, judgment: judgment)
    XCTAssertEqual(hits.first?.id, email.id)
    XCTAssertFalse(hits.contains { $0.id == Ranker.groupID })
  }

  func testSendAndRemindRowsGetNoMatchQuestions() {
    let prefiltered = Ranker.prefilter(
      query: "send the invoice to sarah", index: Fixtures.index, contacts: PeopleFixtures.all)
    let context = LaunchContext(
      frontmostApp: "Finder", recentApps: [], clipboardKind: "empty", timeOfDay: "morning",
      weekday: "Monday")
    let request = JevQuestions.buildRequest(
      query: "send the invoice to sarah", context: context, candidates: prefiltered.candidates)
    for (index, candidate) in prefiltered.candidates.enumerated() where candidate.kind == .send {
      XCTAssertNil(request.questions[JevQuestions.matchKey(index)])
    }
    XCTAssertTrue(request.questions["action"]!.instructions.contains("choose send"))
    if case .options(let options) = request.questions["action"]!.criteria {
      XCTAssertNotNil(options["send"])
      XCTAssertNotNil(options["remind"])
    } else {
      XCTFail("action question should list options")
    }
  }

  func testMissingAttachmentFailsValidation() {
    let delivery = Delivery(
      channel: .email, recipient: PeopleFixtures.sarah,
      attachment: URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString).pdf"),
      body: nil)
    XCTAssertNotNil(Executor.validationError(delivery.candidate))
    let text = Delivery(
      channel: .message, recipient: PeopleFixtures.mom, attachment: nil, body: "hi")
    XCTAssertNil(Executor.validationError(text.candidate))
    XCTAssertNil(Executor.copyText(text.candidate))
    XCTAssertEqual(delivery.candidate.fileURL, delivery.attachment)
  }
}
