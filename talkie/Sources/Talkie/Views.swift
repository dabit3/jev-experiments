import AppKit
import SwiftUI
import TalkieCore

enum Palette {
  static let paper = Color(nsColor: .windowBackgroundColor)
  static let surface = Color(nsColor: .controlBackgroundColor)
  static let ink = Color.primary
  static let secondary = Color.secondary
  static let line = Color.primary.opacity(0.12)
}

struct NativeMaterial: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .hudWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.material = material
  }
}

struct PanelSurface: View {
  var radius: CGFloat = 20
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    Group {
      if reduceTransparency {
        Palette.paper
      } else {
        NativeMaterial()
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .strokeBorder(Palette.ink.opacity(contrast == .increased ? 0.6 : 0.14), lineWidth: 0.5)
    )
    .accessibilityHidden(true)
  }
}

struct ActionButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 12).padding(.vertical, 7)
      .foregroundStyle(Palette.paper)
      .background(Palette.ink, in: RoundedRectangle(cornerRadius: 7))
      .opacity(!isEnabled ? 0.35 : configuration.isPressed ? 0.7 : 1)
  }
}

struct TalkieMark: View {
  var size: CGFloat = 32
  var active = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.16, paused: !active || reduceMotion)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      HStack(spacing: size * 0.067) {
        ForEach(0..<5) { index in
          Capsule()
            .fill(Palette.ink)
            .frame(
              width: size * 0.068,
              height: size
                * (active && !reduceMotion
                  ? 0.22 + 0.20 * abs(sin(time * 4 + Double(index)))
                  : [0.19, 0.34, 0.47, 0.34, 0.19][index]))
        }
      }
      .frame(width: size, height: size)
    }
    .accessibilityHidden(true)
  }
}

struct QuietButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Palette.secondary)
      .padding(8)
      .background(
        configuration.isPressed ? Palette.line : .clear, in: RoundedRectangle(cornerRadius: 8)
      )
      .contentShape(Rectangle())
  }
}

struct RootView: View {
  @ObservedObject var model: TalkieModel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Rectangle().fill(Palette.line).frame(width: 1)
      VStack(spacing: 0) {
        header
        if model.showingSettings {
          SettingsView(model: model)
        } else {
          if model.messages.isEmpty { welcome } else { conversation }
          if let notice = model.notice {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "info.circle")
              Text(notice).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
              Button {
                model.notice = nil
              } label: {
                Image(systemName: "xmark")
              }.buttonStyle(.plain)
                .accessibilityLabel("Dismiss notice")
            }
            .foregroundStyle(Palette.secondary).padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24).padding(.bottom, 8)
          }
          if let pending = model.pending {
            ApprovalView(model: model, pending: pending).frame(height: 160).padding(24)
          }
          voiceControls
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .foregroundStyle(Palette.ink).tint(Palette.ink)
    .font(.system(size: 13))
    .frame(minWidth: 700, minHeight: 520)
    .onExitCommand { model.stop() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in model.refreshPermissions() }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      List {
        Button {
          model.showingSettings = false
        } label: {
          Label("History", systemImage: "clock")
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
        }
        .listRowBackground(!model.showingSettings ? Palette.line : .clear)
        Button {
          model.showingSettings = true
          model.refreshPermissions()
        } label: {
          Label("Settings", systemImage: "gearshape")
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
        }
        .keyboardShortcut(",", modifiers: .command)
        .listRowBackground(model.showingSettings ? Palette.line : .clear)
        Section("Recent") {
          if model.conversations.allSatisfy({ $0.messages.isEmpty }) {
            Text("No conversations").font(.system(size: 12)).foregroundStyle(Palette.secondary)
          }
          ForEach(model.conversations.filter { !$0.messages.isEmpty }) { conversation in
            Button {
              model.select(conversation)
            } label: {
              Label(conversation.title, systemImage: "bubble.left")
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 3)
            }
            .disabled(model.busy || model.listening || model.pending != nil)
            .listRowBackground(
              conversation.id == model.currentID && !model.showingSettings
                ? Palette.line : .clear)
          }
        }
      }
      .listStyle(.sidebar).scrollContentBackground(.hidden).buttonStyle(.plain)
      Divider()
      Button {
        model.newConversation()
      } label: {
        HStack {
          Label("New Conversation", systemImage: "square.and.pencil")
          Spacer()
          Text("⌘N").foregroundStyle(Palette.secondary)
        }.font(.system(size: 12)).padding(14)
      }
      .buttonStyle(.plain).keyboardShortcut("n", modifiers: .command)
      .disabled(model.busy || model.listening || model.pending != nil)
    }
    .frame(width: 200)
    .background {
      if reduceTransparency { Palette.paper } else { NativeMaterial(material: .sidebar) }
    }
  }

  private var header: some View {
    HStack {
      Text(model.showingSettings ? "Settings" : "History")
        .font(.system(size: 17, weight: .semibold))
      Spacer()
      if model.speaker.speaking {
        Button {
          model.speaker.stop()
        } label: {
          Label("Stop speaking", systemImage: "speaker.slash")
        }
        .buttonStyle(QuietButtonStyle())
      }
    }.padding(.horizontal, 24).frame(height: 56)
  }

  private var welcome: some View {
    VStack(spacing: 12) {
      Image(systemName: "waveform").font(.system(size: 36, weight: .light))
        .foregroundStyle(Palette.secondary).padding(.bottom, 4)
      Text("What can I help with?").font(.system(size: 21, weight: .semibold))
      Text("Hold ⌃ ⌥ Space, or click the microphone.")
        .foregroundStyle(Palette.secondary)
      Text("Try “Open Calculator” or “Explain my screen.”")
        .font(.system(size: 12)).foregroundStyle(Palette.secondary).padding(.top, 8)
      if !model.connected || !model.accessGranted {
        Button("Open Settings") {
          model.showingSettings = true
        }.buttonStyle(.bordered).padding(.top, 4)
      }
    }.multilineTextAlignment(.center).padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var conversation: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 25) {
          ForEach(model.messages) { message in
            MessageView(message: message).id(message.id)
          }
          if model.busy {
            HStack(spacing: 10) {
              TalkieMark(size: 24, active: true)
              Text(model.status).font(.system(size: 12)).foregroundStyle(Palette.secondary)
              Spacer()
              Button("Stop") { model.stop() }.buttonStyle(QuietButtonStyle())
            }.id("working")
          }
        }.padding(.horizontal, 36).padding(.vertical, 20)
      }
      .onChange(of: model.messages.count) { _, _ in
        if let last = model.messages.last {
          withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
      }
      .onChange(of: model.busy) { _, busy in if busy { proxy.scrollTo("working", anchor: .bottom) }
      }
    }
  }

  private var voiceControls: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(spacing: 12) {
        VoiceControlView(model: model)
        TalkieMenu(model: model)
      }.padding(.horizontal, 24).padding(.vertical, 16)
    }
  }
}

struct MessageView: View {
  let message: Message
  var compact = false
  @State private var expanded = false
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if !compact {
        Image(systemName: message.role == "assistant" ? "waveform" : "person.crop.circle")
          .font(.system(size: 17)).foregroundStyle(Palette.secondary).frame(width: 25)
      }
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(message.role == "assistant" ? "Talkie" : "You").font(
            .system(size: 11, weight: .semibold))
          if message.isError {
            Label("Needs attention", systemImage: "exclamationmark.circle")
              .font(.system(size: 11)).foregroundStyle(Palette.secondary)
          }
          Spacer()
          Text(message.date, style: .time).font(.system(size: 9)).foregroundStyle(
            Palette.secondary.opacity(0.6))
        }
        Text(.init(message.text)).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
          .tint(Palette.ink).fixedSize(horizontal: false, vertical: true)
        if !message.sources.isEmpty {
          ForEach(message.sources, id: \.url) { source in
            if let url = ActionPolicy.webURL(source.url) {
              Link(destination: url) {
                Label(source.title, systemImage: "arrow.up.right").font(.system(size: 11))
                  .lineLimit(2).foregroundStyle(Palette.ink).underline()
              }
            }
          }
        }
        if !message.activities.isEmpty {
          DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 7) {
              ForEach(message.activities) { activity in
                HStack(alignment: .top) {
                  Text(activity.text).lineLimit(3)
                  Spacer()
                  if let ms = activity.milliseconds {
                    Text("\(ms) ms").monospacedDigit().foregroundStyle(
                      Palette.secondary.opacity(0.7))
                  }
                }.font(.system(size: 10))
              }
            }.padding(.top, 8)
          } label: {
            Text("\(message.activities.count) steps · View activity").font(.system(size: 10))
          }.foregroundStyle(Palette.secondary).tint(Palette.secondary)
        }
        if message.role == "assistant" {
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
          } label: {
            Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10))
          }
          .buttonStyle(.plain).foregroundStyle(Palette.secondary.opacity(0.7))
        }
      }
    }
  }
}

struct SettingsView: View {
  @ObservedObject var model: TalkieModel
  @State private var jev = ""
  @State private var openAI = ""
  @State private var saveMessage = ""
  @State private var deleting = false
  var body: some View {
    Form {
      Section("Connections") {
        keyField(.jev, value: $jev, detail: "Understands requests and chooses Mac actions.")
        keyField(
          .openAI, value: $openAI, detail: "Optional · conversation, web research, drafts.")
        if !saveMessage.isEmpty {
          Text(saveMessage).font(.system(size: 11)).foregroundStyle(Palette.secondary)
        }
      }
      Section("Permissions") {
        permission(
          "Accessibility", detail: "Read controls and take action in your apps.",
          granted: model.accessGranted
        ) {
          DesktopAccess.requestTrust()
          openPrivacy("Privacy_Accessibility")
        }
        permission(
          "Screen Recording", detail: "Optional · read text in apps with limited accessibility.",
          granted: model.screenGranted
        ) {
          CGRequestScreenCaptureAccess()
          openPrivacy("Privacy_ScreenCapture")
        }
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Microphone & speech").fontWeight(.medium)
            Text("Requested the first time you talk. On-device recognition.")
              .font(.system(size: 11)).foregroundStyle(Palette.secondary)
          }
          Spacer()
          Button("Set up") { openPrivacy("Privacy_Microphone") }.buttonStyle(.bordered)
        }
        Button("Refresh permissions") { model.refreshPermissions() }.font(.system(size: 11))
        if !model.shortcutAvailable {
          Label(
            "The shortcut is in use by another app. You can still use the microphone button.",
            systemImage: "exclamationmark.circle"
          ).font(.system(size: 11)).foregroundStyle(Palette.secondary)
        }
      }
      Section("General") {
        Toggle("Speak answers aloud", isOn: $model.preferences.speak)
          .onChange(of: model.preferences.speak) { _, enabled in
            if !enabled { model.speaker.stop() }
          }
        Toggle("Keep companion visible while idle", isOn: $model.preferences.companion)
        Toggle("Include screen context when I ask", isOn: $model.preferences.screenContext)
      }
      Section {
        Toggle("Remember conversations on this Mac", isOn: $model.preferences.keepHistory)
          .onChange(of: model.preferences.keepHistory) { _, _ in model.historyPreferenceChanged()
          }
        Button("Delete All Conversations…") { deleting = true }
          .confirmationDialog("Delete all conversations from this Mac?", isPresented: $deleting) {
            Button("Delete conversations", role: .destructive) { model.clearHistory() }
          }
      } header: {
        Text("Privacy")
      } footer: {
        Text(
          "Live audio stays on your Mac. On-screen text goes to Jev and, for conversations, OpenAI only when requested. Screenshots are processed locally and never saved."
        )
        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
      }
      HStack {
        Text("Talkie 1.0").font(.system(size: 11, weight: .medium))
        Spacer()
        Button("Quit Talkie") { NSApplication.shared.terminate(nil) }.font(.system(size: 11))
      }.foregroundStyle(Palette.secondary)
    }
    .formStyle(.grouped).toggleStyle(.switch).controlSize(.small).tint(Palette.ink)
  }
  private func keyField(_ credential: Credential, value: Binding<String>, detail: String)
    -> some View
  {
    let present =
      credential == .jev ? !model.preferences.jevKey.isEmpty : !model.preferences.openAIKey.isEmpty
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(credential.title).fontWeight(.medium)
        Spacer()
        Text(
          present
            ? (credential.environmentValue != nil ? "From environment" : "Saved in Keychain")
            : "Not connected"
        )
        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
      }
      Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary)
      if credential.environmentValue == nil {
        HStack {
          SecureField("Paste \(credential.title) API key", text: value).textFieldStyle(
            .roundedBorder
          )
          .accessibilityLabel("\(credential.title) API key")
          Button("Save") {
            do {
              try credential.save(value.wrappedValue)
              if credential == .jev {
                model.preferences.jevKey = credential.read()
              } else {
                model.preferences.openAIKey = credential.read()
              }
              value.wrappedValue = ""
              saveMessage = "Updated \(credential.title) in Keychain."
            } catch { saveMessage = error.localizedDescription }
          }.disabled(value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          Button("Remove") {
            do {
              try credential.save("")
              if credential == .jev {
                model.preferences.jevKey = ""
              } else {
                model.preferences.openAIKey = ""
              }
              saveMessage = "Removed \(credential.title) key."
            } catch { saveMessage = error.localizedDescription }
          }.disabled(!present)
        }
      }
    }
  }
  private func permission(
    _ title: String, detail: String, granted: Bool, action: @escaping () -> Void
  ) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).fontWeight(.medium)
        Text(detail).font(.system(size: 11)).foregroundStyle(Palette.secondary)
      }
      Spacer()
      if granted {
        Image(systemName: "checkmark").foregroundStyle(Palette.secondary)
          .accessibilityLabel("\(title) allowed")
      }
      Button(granted ? "Manage…" : "Allow…", action: action).buttonStyle(.bordered)
    }
  }
  private func openPrivacy(_ pane: String) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
      NSWorkspace.shared.open(url)
    }
  }
}

struct VoiceControlView: View {
  @ObservedObject var model: TalkieModel

  var body: some View {
    HStack(spacing: 12) {
      Button {
        model.busy ? model.stop() : model.toggleMicrophone()
      } label: {
        Image(systemName: model.busy || model.listening ? "stop.fill" : "mic.fill")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(Palette.paper).frame(width: 40, height: 40)
          .background(Palette.ink, in: Circle())
      }
      .buttonStyle(.plain).disabled(model.pending != nil)
      .accessibilityLabel(
        model.busy ? "Stop task" : model.listening ? "Finish recording" : "Start microphone"
      )
      .help(model.listening ? "Finish recording" : model.busy ? "Stop task" : "Start microphone")
      VStack(alignment: .leading, spacing: 4) {
        Text(
          model.listening
            ? "Listening…"
            : model.busy
              ? model.status : model.mode == .auto ? "Talkie" : "Talkie · \(model.mode.rawValue)"
        )
        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
        if model.listening, !model.voice.transcript.isEmpty {
          Text(model.voice.transcript).font(.system(size: 11))
            .foregroundStyle(Palette.secondary).lineLimit(2)
            .accessibilityLabel("Live transcript")
            .accessibilityValue(model.voice.transcript)
        } else {
          Text(
            model.listening
              ? "Click to finish · Esc to cancel"
              : model.busy ? "Esc to cancel" : "Hold ⌃ ⌥ Space to talk"
          )
          .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }.frame(minHeight: 48)
  }
}

struct TalkieMenu: View {
  @ObservedObject var model: TalkieModel

  var body: some View {
    Menu {
      Button("New Conversation") { model.newConversation() }
        .keyboardShortcut("n", modifiers: .command)
        .disabled(model.busy || model.listening || model.pending != nil)
      Button("History & Activity") { model.showHistory?() }
      Divider()
      Picker("Mode", selection: $model.mode) {
        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }.disabled(model.busy || model.listening || model.pending != nil)
      Text(model.preferences.screenContext ? model.contextApp : "Screen context off")
      if model.speaker.speaking {
        Button("Stop Speaking") { model.speaker.stop() }
      }
      Divider()
      Button("Settings…") { model.showSettings?() }
        .keyboardShortcut(",", modifiers: .command)
      Button("Dismiss") { model.dismissQuick?() }
      Divider()
      Button("Quit Talkie") { NSApplication.shared.terminate(nil) }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 15, weight: .medium))
        .frame(width: 28, height: 28).contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    .foregroundStyle(Palette.secondary).accessibilityLabel("Talkie menu").help("More options")
  }
}

struct ApprovalView: View {
  @ObservedObject var model: TalkieModel
  let pending: PendingAction

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Allow this action?", systemImage: "hand.raised")
        .font(.system(size: 13, weight: .semibold))
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(pending.action.label).textSelection(.enabled)
          Text("In \(pending.appName)").foregroundStyle(Palette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      HStack {
        Button("Cancel") { model.confirm(false) }.buttonStyle(.bordered)
        Spacer()
        Button("Allow this action") { model.confirm(true) }.buttonStyle(ActionButtonStyle())
      }
    }.font(.system(size: 12))
  }
}

struct QuickView: View {
  @ObservedObject var model: TalkieModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 4) {
        VoiceControlView(model: model)
        TalkieMenu(model: model)
      }
      if let pending = model.pending {
        Divider()
        ApprovalView(model: model, pending: pending)
      } else if let reply = model.quickReply {
        Divider()
        ScrollView { MessageView(message: reply, compact: true).padding(.trailing, 4) }
      } else if let notice = model.notice {
        Divider()
        ScrollView {
          Label(notice, systemImage: "info.circle")
            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
      } else if !model.connected {
        Button("Set up Talkie…") { model.showSettings?() }.buttonStyle(.plain)
          .font(.system(size: 12)).foregroundStyle(Palette.secondary)
      }
    }
    .padding(20).frame(width: model.quickWidth, height: model.quickHeight)
    .foregroundStyle(Palette.ink).tint(Palette.ink)
    .background(PanelSurface())
    .onExitCommand { model.dismissQuick?() }
  }
}

struct CompanionView: View {
  @ObservedObject var model: TalkieModel
  var body: some View {
    HStack(spacing: 10) {
      Button {
        model.showWindow?()
      } label: {
        TalkieMark(size: 29, active: model.listening || model.busy)
      }
      .buttonStyle(.plain).accessibilityLabel("Ask Talkie")
      VStack(alignment: .leading, spacing: 3) {
        Text(
          model.listening
            ? "Listening…"
            : model.busy ? "Working…" : model.quickReply != nil ? "Done" : "Talkie"
        )
        .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
        Text(
          model.listening && !model.voice.transcript.isEmpty
            ? model.voice.transcript
            : model.busy
              ? model.status : model.quickReply != nil ? "Click to review" : "Hold ⌃ ⌥ space"
        )
        .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
      }
      Spacer(minLength: 0)
      Button {
        model.busy ? model.stop() : model.toggleMicrophone()
      } label: {
        Image(systemName: model.busy || model.listening ? "stop.fill" : "mic")
          .font(.system(size: 12)).foregroundStyle(Palette.ink)
          .frame(width: 28, height: 28).background(Palette.line, in: Circle())
      }.buttonStyle(.plain).accessibilityLabel(
        model.busy ? "Stop task" : model.listening ? "Finish recording" : "Start microphone")
    }
    .padding(.horizontal, 15).frame(width: 260, height: 60)
    .background(PanelSurface(radius: 20))
  }
}
