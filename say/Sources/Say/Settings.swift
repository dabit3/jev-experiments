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
    case .general: CGSize(width: 600, height: 380)
    case .connections: CGSize(width: 600, height: 400)
    case .privacy: CGSize(width: 600, height: 460)
    }
  }

  @MainActor func view(model: SayModel) -> AnyView {
    AnyView(SettingsPage(pane: self, model: model))
  }
}

@MainActor
private final class SettingsTabs: NSTabViewController {
  var didSelect: (() -> Void)?

  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, didSelect: tabViewItem)
    didSelect?()
  }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  private let model: SayModel
  private let tabs = SettingsTabs()
  private var hasPositioned = false

  var selectedPane: SettingsPane { SettingsPane.allCases[tabs.selectedTabViewItemIndex] }

  init(model: SayModel) {
    self.model = model
    super.init(window: nil)
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
    window.delegate = self
    self.window = window
    tabs.didSelect = { [weak self] in self?.sizeToPane() }
    sizeToPane()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The Settings window is created in code.")
  }

  func select(_ pane: SettingsPane) {
    tabs.selectedTabViewItemIndex = SettingsPane.allCases.firstIndex(of: pane)!
    sizeToPane()
  }

  func show(pane: SettingsPane? = nil) {
    guard let window else { return }
    if let pane { select(pane) }
    model.refreshPermissions()
    if !hasPositioned {
      window.center()
      hasPositioned = true
    }
    showWindow(nil)
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  func windowDidBecomeKey(_ notification: Notification) { model.refreshPermissions() }

  private func sizeToPane() {
    guard let window else { return }
    window.title = selectedPane.title
    var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: selectedPane.size))
    frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
    window.setFrame(frame, display: true, animate: window.isVisible)
  }
}

struct SettingsPage: View {
  let pane: SettingsPane
  @ObservedObject var model: SayModel

  var body: some View {
    VStack(spacing: 0) {
      Group {
        switch pane {
        case .general: GeneralSettingsView(model: model)
        case .connections: ConnectionsSettingsView(model: model)
        case .privacy: PrivacySettingsView(model: model)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      HStack(spacing: 12) {
        Text("Say stays in your menu bar.").font(.caption).foregroundStyle(.secondary)
        Spacer(minLength: 0)
        Button("Open Listener") { model.openListener() }
        Button("Quit Say") { model.quit() }
      }
      .padding(.horizontal, 20).padding(.vertical, 14)
    }
  }
}

struct GeneralSettingsView: View {
  @ObservedObject var model: SayModel

  var body: some View {
    Form {
      Section {
        HStack(spacing: 12) {
          SayMark(size: 44).foregroundStyle(Color.accentColor)
          VStack(alignment: .leading, spacing: 3) {
            Text("Say").font(.title2.weight(.semibold))
            Text("Voice control for your Mac.").foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
        LabeledContent {
          Text("⌃ ⌥ Space").font(.body.monospaced()).foregroundStyle(.secondary)
        } label: {
          Text("Hold to talk")
          Text("Release to send. Press Escape to cancel.")
        }
      } footer: {
        if !model.shortcutAvailable {
          Text(
            "Another app is using this shortcut. Open the listener and use its microphone button.")
        }
      }
      Section {
        Toggle("Speak answers aloud", isOn: $model.preferences.speak)
          .onChange(of: model.preferences.speak) { _, enabled in
            if !enabled { model.speaker.stop() }
          }
        Toggle(isOn: $model.preferences.companion) {
          Text("Keep status indicator visible")
          Text("Show the floating indicator even when idle.")
        }
        Toggle(isOn: $model.preferences.screenContext) {
          Text("Use screen context")
          Text("Read the front window when you ask for help.")
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
        model: model, credential: .jev,
        description:
          "Chooses controls and actions in your Mac apps. [Get a TypeSafe key](https://typesafe.ai/)."
      )
      CredentialSection(
        model: model, credential: .openAI,
        description:
          "Voice transcription, answers, and web research. Requires gpt-live-transcribe access. [Manage OpenAI keys](https://platform.openai.com/api-keys)."
      )
      Section {
        Text("Keys stay in your Mac’s Keychain. API usage is billed to your provider accounts.")
          .font(.callout).foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

struct CredentialSection: View {
  @ObservedObject var model: SayModel
  let credential: Credential
  let description: LocalizedStringKey
  @State private var editing = false
  @State private var removing = false
  @State private var problem: String?

  private var saved: Bool { !model.preferences.key(for: credential).isEmpty }
  private var environmentName: String? { model.preferences.credentialEnvironment(credential) }

  var body: some View {
    Section {
      LabeledContent("API key") {
        HStack(spacing: 10) {
          Text(
            environmentName != nil ? "From environment" : saved ? "Saved in Keychain" : "Not added"
          )
          .foregroundStyle(.secondary)
          if environmentName == nil {
            Button(saved ? "Change…" : "Add Key…") { editing = true }
            if saved {
              Menu {
                Button("Remove Key…", role: .destructive) { removing = true }
              } label: {
                Image(systemName: "ellipsis.circle")
              }
              .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
              .accessibilityLabel("\(credential.title) key options")
            }
          }
        }
      }
    } header: {
      Text(credential.title)
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        Text(description)
        if let environmentName {
          Text(
            "Provided by \(environmentName). Change it in your launch environment and restart Say.")
        }
        if let problem { Text(problem).foregroundStyle(.red) }
      }
    }
    .sheet(isPresented: $editing) {
      CredentialEditor(title: credential.title) { value in
        try model.preferences.setKey(value, for: credential)
        problem = nil
      }
    }
    .confirmationDialog("Remove the \(credential.title) API key?", isPresented: $removing) {
      Button("Remove Key", role: .destructive) {
        do {
          try model.preferences.setKey("", for: credential)
          problem = nil
        } catch { problem = error.localizedDescription }
      }
    } message: {
      Text("Say will need a new key before you can use it again.")
    }
  }
}

struct CredentialEditor: View {
  let title: String
  let save: (String) throws -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var draft = ""
  @State private var problem: String?
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("\(title) API Key").font(.headline)
      Text("Saved securely in your Mac’s Keychain.").foregroundStyle(.secondary)
      SecureField("Paste your API key", text: $draft)
        .textFieldStyle(.roundedBorder).focused($focused)
        .accessibilityLabel("\(title) API key")
        .onSubmit(commit)
      if let problem { Text(problem).font(.callout).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
        Button("Save", action: commit).keyboardShortcut(.defaultAction)
          .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24).frame(width: 440)
    .onAppear { focused = true }
  }

  private func commit() {
    let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    do {
      try save(value)
      draft = ""
      dismiss()
    } catch { problem = error.localizedDescription }
  }
}

struct PrivacySettingsView: View {
  @ObservedObject var model: SayModel
  @State private var deleting = false

  private var microphoneStatus: String {
    switch model.microphoneStatus {
    case .authorized: "Allowed"
    case .notDetermined: "Not requested"
    case .restricted: "Restricted"
    default: "Not allowed"
    }
  }

  var body: some View {
    Form {
      Section("Permissions") {
        PermissionRow(
          title: "Microphone", detail: "Hear your voice when you record.",
          status: microphoneStatus,
          button: model.microphoneStatus == .notDetermined ? "Allow…" : "Manage…",
          action: requestMicrophone)
        PermissionRow(
          title: "Accessibility", detail: "Read controls and act in your apps.",
          status: model.accessGranted ? "Allowed" : "Not enabled",
          button: model.accessGranted ? "Manage…" : "Allow…"
        ) {
          if model.accessGranted {
            openPrivacy("Privacy_Accessibility")
          } else {
            DesktopAccess.requestTrust()
          }
        }
        PermissionRow(
          title: "Screen Recording", detail: "Optional. Read text in apps with limited access.",
          status: model.screenGranted ? "Allowed" : "Not enabled",
          button: model.screenGranted ? "Manage…" : "Allow…"
        ) {
          if model.screenGranted {
            openPrivacy("Privacy_ScreenCapture")
          } else {
            CGRequestScreenCaptureAccess()
            model.refreshPermissions()
          }
        }
      }
      Section {
        Toggle(isOn: $model.preferences.keepHistory) {
          Text("Remember conversations")
          Text("Stored on this Mac. Turning this off deletes saved history.")
        }
        .onChange(of: model.preferences.keepHistory) { _, _ in model.historyPreferenceChanged() }
        LabeledContent("Conversations") {
          Button("Delete All…", role: .destructive) { deleting = true }
            .disabled(model.conversations.allSatisfy { $0.messages.isEmpty })
            .confirmationDialog("Delete all conversations from this Mac?", isPresented: $deleting) {
              Button("Delete All", role: .destructive) { model.clearHistory() }
            }
        }
      } header: {
        Text("History")
      } footer: {
        Text(
          "Audio goes to OpenAI while you record. Screen text goes to Jev and OpenAI when needed for your request. Say does not save audio or upload screenshots."
        )
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshPermissions() }
  }

  private func requestMicrophone() {
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
      openPrivacy("Privacy_Microphone")
      return
    }
    AVCaptureDevice.requestAccess(for: .audio) { _ in
      Task { @MainActor in model.refreshPermissions() }
    }
  }

  private func openPrivacy(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
      NSWorkspace.shared.open(url)
    }
  }
}

struct PermissionRow: View {
  let title: String
  let detail: String
  let status: String
  let button: String
  let action: () -> Void

  var body: some View {
    LabeledContent {
      HStack(spacing: 10) {
        Text(status).foregroundStyle(.secondary)
        Button(button, action: action)
      }
    } label: {
      Text(title)
      Text(detail)
    }
  }
}
