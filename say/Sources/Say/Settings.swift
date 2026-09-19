import AVFoundation
import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable {
  case general, connections, privacy

  var title: String {
    switch self {
    case .general: "General"
    case .connections: "Connections"
    case .privacy: "Privacy"
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .connections: "key"
    case .privacy: "hand.raised"
    }
  }

  var size: CGSize {
    switch self {
    case .general: CGSize(width: 600, height: 268)
    case .connections: CGSize(width: 600, height: 366)
    case .privacy: CGSize(width: 600, height: 434)
    }
  }

  @MainActor func view(model: SayModel) -> AnyView {
    switch self {
    case .general: AnyView(GeneralSettingsView(model: model))
    case .connections: AnyView(ConnectionsSettingsView(model: model))
    case .privacy: AnyView(PrivacySettingsView(model: model))
    }
  }
}

@MainActor
final class SettingsWindowController: NSWindowController {
  private let model: SayModel

  init(model: SayModel) {
    self.model = model
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    for pane in SettingsPane.allCases {
      let host = NSHostingController(
        rootView: pane.view(model: model).frame(width: pane.size.width, height: pane.size.height))
      host.title = pane.title
      host.preferredContentSize = pane.size
      let item = NSTabViewItem(viewController: host)
      item.label = pane.title
      item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
      tabs.addTabViewItem(item)
    }
    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.setContentSize(SettingsPane.general.size)
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Settings window is created in code.")
  }

  func show() {
    guard let window else { return }
    model.refreshPermissions()
    if !window.isVisible { window.center() }
    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}

struct GeneralSettingsView: View {
  @ObservedObject var model: SayModel

  var body: some View {
    Form {
      Section {
        LabeledContent {
          Text("⌃ ⌥ Space").foregroundStyle(.secondary)
        } label: {
          Text("Talk to Say")
          Text("Hold the keys while you speak, then release.")
        }
        Toggle(isOn: $model.preferences.speak) {
          Text("Speak answers aloud")
        }
        .onChange(of: model.preferences.speak) { _, enabled in
          if !enabled { model.speaker.stop() }
        }
        Toggle(isOn: $model.preferences.companion) {
          Text("Show companion when idle")
          Text("A small status panel stays near the bottom of your screen.")
        }
      } footer: {
        if !model.shortcutAvailable {
          Text("Another app is using this shortcut. Use the microphone button in the Say panel.")
        }
      }
      Section {
        Toggle(isOn: $model.preferences.screenContext) {
          Text("Use what is on your screen")
          Text("Say reads the front window to choose controls and explain your screen.")
        }
      }
    }
    .formStyle(.grouped)
  }
}

struct ConnectionsSettingsView: View {
  @ObservedObject var model: SayModel

  var body: some View {
    Form {
      CredentialSection(
        model: model, credential: .jev, title: "Jev",
        description:
          "Jev understands your request and chooses each Mac action. [Get a key at typesafe.ai](https://typesafe.ai/)"
      )
      CredentialSection(
        model: model, credential: .openAI, title: "OpenAI",
        description:
          "OpenAI transcribes your voice and handles conversation, research, and drafts. The key needs access to gpt-live-transcribe. [Manage keys](https://platform.openai.com/api-keys)\n\nKeys are saved to your Keychain when you press Return. Clear a field to remove its key."
      )
    }
    .formStyle(.grouped)
  }
}

struct CredentialSection: View {
  @ObservedObject var model: SayModel
  let credential: Credential
  let title: String
  let description: LocalizedStringKey
  @State private var draft = ""
  @State private var problem: String?
  @FocusState private var editing: Bool

  private var saved: String {
    credential == .jev ? model.preferences.jevKey : model.preferences.openAIKey
  }
  private var environmentName: String? {
    credential.environmentNames.first {
      !(ProcessInfo.processInfo.environment[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
  }
  private var status: String {
    if let environmentName { return "Provided by \(environmentName)" }
    return saved.isEmpty ? "Not connected" : "Connected"
  }

  var body: some View {
    Section {
      SecureField("API Key", text: $draft, prompt: Text("Required"))
        .focused($editing)
        .onSubmit(commit)
        .disabled(environmentName != nil)
        .accessibilityLabel("\(title) API key")
      LabeledContent("Status") {
        HStack(spacing: 6) {
          Circle()
            .fill(saved.isEmpty ? Color.secondary.opacity(0.35) : Color.green)
            .frame(width: 8, height: 8)
          Text(status)
        }
        .foregroundStyle(.secondary)
      }
    } header: {
      Text(title)
    } footer: {
      VStack(alignment: .leading, spacing: 6) {
        Text(description)
        if let problem { Text(problem).foregroundStyle(.red) }
      }
    }
    .onAppear { draft = saved }
    .onChange(of: saved) { _, value in draft = value }
    .onChange(of: editing) { _, focused in
      if !focused { commit() }
    }
  }

  private func commit() {
    let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value != saved else { return }
    do {
      try credential.save(value)
      let stored = credential.read()
      if credential == .jev {
        model.preferences.jevKey = stored
      } else {
        model.preferences.openAIKey = stored
      }
      draft = stored
      problem = nil
    } catch {
      problem = error.localizedDescription
    }
  }
}

struct PrivacySettingsView: View {
  @ObservedObject var model: SayModel
  @State private var deleting = false

  var body: some View {
    Form {
      Section("Permissions") {
        PermissionRow(
          title: "Microphone",
          detail: "Needed to hear you. Audio streams to OpenAI only while you record.",
          granted: model.microphoneGranted, pane: "Privacy_Microphone"
        ) {
          AVCaptureDevice.requestAccess(for: .audio) { _ in }
        }
        PermissionRow(
          title: "Accessibility",
          detail: "Lets Say read controls and act in your apps.",
          granted: model.accessGranted, pane: "Privacy_Accessibility"
        ) {
          DesktopAccess.requestTrust()
        }
        PermissionRow(
          title: "Screen Recording",
          detail: "Optional. Reads on-screen text in apps that expose few controls.",
          granted: model.screenGranted, pane: "Privacy_ScreenCapture"
        ) {
          CGRequestScreenCaptureAccess()
        }
      }
      Section {
        Toggle(isOn: $model.preferences.keepHistory) {
          Text("Remember conversations")
          Text("Saved only on this Mac. Turning this off deletes the saved file.")
        }
        .onChange(of: model.preferences.keepHistory) { _, _ in model.historyPreferenceChanged() }
        LabeledContent("Saved conversations") {
          Button("Delete All…", role: .destructive) { deleting = true }
            .confirmationDialog(
              "Delete all conversations from this Mac?", isPresented: $deleting
            ) {
              Button("Delete", role: .destructive) { model.clearHistory() }
            }
        }
      } header: {
        Text("History")
      } footer: {
        Text(
          "Say never saves audio. While you record, audio streams to OpenAI for transcription. On-screen text goes to Jev, and to OpenAI only when you ask a question. Screenshots stay on your Mac."
        )
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshPermissions() }
  }
}

struct PermissionRow: View {
  let title: String
  let detail: String
  let granted: Bool
  let pane: String
  let request: () -> Void

  var body: some View {
    LabeledContent {
      HStack(spacing: 10) {
        Text(granted ? "Allowed" : "Not allowed").foregroundStyle(.secondary)
        Button(granted ? "Open System Settings…" : "Allow…") {
          if !granted { request() }
          openPrivacy()
        }
      }
    } label: {
      Text(title)
      Text(detail)
    }
    .accessibilityElement(children: .combine)
  }

  private func openPrivacy() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
      NSWorkspace.shared.open(url)
    }
  }
}
