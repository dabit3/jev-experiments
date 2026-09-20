import AppKit
import Contacts
import EventKit
import Foundation

/// Reads the address book once so that "send … to sarah" can resolve a person in code.
enum ContactsIndex {
  static let maxContacts = 2_000

  static func load() async -> [Contact] {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    if status == .notDetermined {
      let granted = (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
      guard granted else { return [] }
    } else if status != .authorized {
      return []
    }
    return await Task.detached(priority: .userInitiated) { fetch(store: CNContactStore()) }.value
  }

  static func fetch(store: CNContactStore) -> [Contact] {
    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactNicknameKey as CNKeyDescriptor, CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    request.sortOrder = .givenName
    var contacts: [Contact] = []
    try? store.enumerateContacts(with: request) { person, stop in
      let name = [person.givenName, person.familyName].filter { !$0.isEmpty }
        .joined(separator: " ")
      guard !name.isEmpty else { return }
      contacts.append(
        Contact(
          name: name, nickname: person.nickname.isEmpty ? nil : person.nickname,
          email: person.emailAddresses.first.map { String($0.value) },
          phone: person.phoneNumbers.first?.value.stringValue))
      if contacts.count >= maxContacts { stop.pointee = true }
    }
    return contacts
  }
}

/// Hands a delivery to the system share sheet for the chosen channel. Mail, Messages and
/// AirDrop each open their own UI; nothing is sent without the user confirming there.
enum Sharing {
  @MainActor
  static func perform(_ delivery: Delivery) -> Executor.Outcome {
    let name: NSSharingService.Name
    switch delivery.channel {
    case .email: name = .composeEmail
    case .message: name = .composeMessage
    case .airDrop: name = .sendViaAirDrop
    }
    guard let service = NSSharingService(named: name) else {
      return Executor.Outcome(
        succeeded: false, message: "\(label(delivery.channel)) is not available on this Mac.")
    }
    var items: [Any] = []
    if let body = delivery.body { items.append(body) }
    if let url = delivery.attachment { items.append(url) }
    if let handle = delivery.recipient.flatMap({ recipientHandle($0, channel: delivery.channel) }) {
      service.recipients = [handle]
    }
    if delivery.channel == .email, let attachment = delivery.attachment {
      service.subject = attachment.deletingPathExtension().lastPathComponent
    }
    guard service.canPerform(withItems: items) else {
      return Executor.Outcome(
        succeeded: false,
        message: "\(label(delivery.channel)) cannot take this item. Check the app is set up.")
    }
    NSApp.activate(ignoringOtherApps: true)
    service.perform(withItems: items)
    return Executor.Outcome(succeeded: true, message: delivery.title)
  }

  static func recipientHandle(_ contact: Contact, channel: Delivery.Channel) -> String? {
    switch channel {
    case .email: return contact.email
    case .message: return contact.phone ?? contact.email
    case .airDrop: return nil
    }
  }

  static func label(_ channel: Delivery.Channel) -> String {
    switch channel {
    case .email: return "Mail"
    case .message: return "Messages"
    case .airDrop: return "AirDrop"
    }
  }
}

/// Creates reminders in the default list. The title and due time were parsed in code.
enum Reminders {
  static func create(_ reminder: Reminder, store: EKEventStore = EKEventStore()) async
    -> Executor.Outcome
  {
    let granted: Bool
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .fullAccess, .authorized: granted = true
    case .notDetermined: granted = (try? await store.requestFullAccessToReminders()) ?? false
    default: granted = false
    }
    guard granted else {
      return Executor.Outcome(
        succeeded: false,
        message: "Allow Launcher to access Reminders in System Settings › Privacy & Security.")
    }
    guard let calendar = store.defaultCalendarForNewReminders() else {
      return Executor.Outcome(succeeded: false, message: "No Reminders list is available.")
    }
    let item = EKReminder(eventStore: store)
    item.title = reminder.title
    item.calendar = calendar
    if let due = reminder.due {
      item.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: due)
      item.addAlarm(EKAlarm(absoluteDate: due))
    }
    do {
      try store.save(item, commit: true)
    } catch {
      return Executor.Outcome(succeeded: false, message: error.localizedDescription)
    }
    return Executor.Outcome(succeeded: true, message: "Reminder added: \(reminder.title)")
  }
}
