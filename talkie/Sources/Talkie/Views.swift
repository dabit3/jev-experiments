import AppKit
import SwiftUI
import TalkieCore

enum Palette {
  static let paper = Color(red: 0.975, green: 0.965, blue: 0.947)
  static let sidebar = Color(red: 0.949, green: 0.937, blue: 0.914)
  static let ink = Color(red: 0.18, green: 0.20, blue: 0.18)
  static let secondary = Color(red: 0.47, green: 0.48, blue: 0.44)
  static let orange = Color(red: 0.88, green: 0.32, blue: 0.15)
  static let line = Color.black.opacity(0.07)
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
            .fill(.white.opacity(index == 2 ? 1 : 0.88))
            .frame(
              width: size * 0.068,
              height: size
                * (active && !reduceMotion
                  ? 0.22 + 0.20 * abs(sin(time * 4 + Double(index)))
                  : [0.19, 0.34, 0.47, 0.34, 0.19][index]))
        }
      }
      .frame(width: size, height: size)
      .background(
        LinearGradient(
          colors: [Color(red: 0.99, green: 0.53, blue: 0.30), Palette.orange],
          startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: size * 0.32))
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
            .background(Palette.sidebar, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32).padding(.bottom, 8)
          }
          if let pending = model.pending { approval(pending) }
          voiceControls
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Palette.paper)
    .foregroundStyle(Palette.ink)
    .font(.system(size: 13))
    .preferredColorScheme(.light)
    .frame(minWidth: 760, minHeight: 560)
    .onExitCommand { model.stop() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in model.refreshPermissions() }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        TalkieMark(size: 28)
        Text("talkie").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.8)
      }.padding(.top, 42).padding(.bottom, 34)
      Button {
        model.newConversation()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "plus")
          Text("New conversation").font(.system(size: 12, weight: .medium)).lineLimit(1)
            .layoutPriority(1)
          Spacer(minLength: 0)
          Text("⌘N").font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize()
        }.padding(.vertical, 11).padding(.horizontal, 10)
          .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
      }.buttonStyle(.plain).keyboardShortcut("n", modifiers: .command)
      Text("RECENT").font(.system(size: 9, weight: .semibold)).tracking(1.7)
        .foregroundStyle(Palette.secondary).padding(.top, 30).padding(.bottom, 12)
      ScrollView {
        VStack(alignment: .leading, spacing: 5) {
          if model.conversations.allSatisfy({ $0.messages.isEmpty }) {
            Text("A little space for your thoughts.")
              .font(.system(size: 12)).foregroundStyle(Palette.secondary.opacity(0.75))
              .lineSpacing(5).padding(.horizontal, 4)
          }
          ForEach(model.conversations.filter { !$0.messages.isEmpty }) { conversation in
            Button {
              model.select(conversation)
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "bubble.left").font(.system(size: 11))
                Text(conversation.title).lineLimit(1)
                Spacer(minLength: 0)
              }
              .font(.system(size: 12))
              .padding(10)
              .background(
                conversation.id == model.currentID && !model.showingSettings
                  ? Color.white.opacity(0.65) : .clear,
                in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
          }
        }
      }
      Spacer(minLength: 20)
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 4) {
          ForEach(["⌃", "⌥", "space"], id: \.self) { key in
            Text(key).font(.system(size: key == "space" ? 10 : 13, weight: .medium))
              .padding(.horizontal, 6).frame(height: 23)
              .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
              .overlay(RoundedRectangle(cornerRadius: 4).stroke(Palette.line))
          }
        }
        Text("Hold to talk. Anywhere.").font(.system(size: 11)).foregroundStyle(Palette.secondary)
      }.padding(.bottom, 22)
      Rectangle().fill(Palette.line).frame(height: 1)
      Button {
        model.showingSettings.toggle()
        model.refreshPermissions()
      } label: {
        HStack(spacing: 9) {
          Image(systemName: "slider.horizontal.3")
          Text("Settings")
          Spacer()
          Circle().fill(
            model.connected ? Color(red: 0.39, green: 0.53, blue: 0.36) : Palette.orange
          )
          .frame(width: 5, height: 5)
        }.padding(.vertical, 18)
      }.buttonStyle(.plain).keyboardShortcut(",", modifiers: .command)
    }
    .padding(.horizontal, 20).frame(width: 230).background(Palette.sidebar)
  }

  private var header: some View {
    HStack {
      HStack(spacing: 6) {
        Circle().fill(
          model.busy || model.listening ? Palette.orange : Color(red: 0.45, green: 0.57, blue: 0.40)
        )
        .frame(width: 5, height: 5)
        Text(model.showingSettings ? "Make it yours" : model.status)
          .font(.system(size: 11)).lineLimit(1)
      }.foregroundStyle(Palette.secondary)
      Spacer()
      if model.speaker.speaking {
        Button {
          model.speaker.stop()
        } label: {
          Label("Stop speaking", systemImage: "speaker.slash")
        }
        .buttonStyle(QuietButtonStyle())
      }
      Text("YOUR MAC, A LITTLE MORE HUMAN").font(.system(size: 8, weight: .medium)).tracking(1.6)
        .foregroundStyle(Palette.secondary.opacity(0.65))
    }.padding(.horizontal, 32).frame(height: 68)
  }

  private var welcome: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 440
      ScrollView {
        VStack(spacing: 0) {
          Spacer(minLength: 14)
          ZStack {
            Circle().fill(Palette.orange.opacity(0.035)).frame(
              width: compact ? 88 : 148, height: compact ? 88 : 148)
            Circle().stroke(Palette.orange.opacity(0.08), lineWidth: 1).frame(
              width: compact ? 78 : 124, height: compact ? 78 : 124)
            TalkieMark(size: compact ? 52 : 76, active: model.listening)
              .rotationEffect(.degrees(-7))
              .shadow(color: Palette.orange.opacity(0.17), radius: 20, x: 0, y: 12)
          }.padding(.bottom, compact ? 10 : 16)
          Text("A little voice.\nA lot less clicking.")
            .font(.system(size: compact ? 30 : 37, weight: .regular, design: .serif))
            .tracking(-1.3).lineSpacing(-1).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
          Text("Ask a question. Find your way. Get things done.\nJust say the word.")
            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
            .lineSpacing(6).multilineTextAlignment(.center).padding(.top, compact ? 8 : 15)
            .fixedSize(horizontal: false, vertical: true)
          VStack(spacing: 8) {
            Text("TRY SAYING").font(.system(size: 9, weight: .medium)).tracking(1.4)
              .foregroundStyle(Palette.secondary)
            Text("“Explain my screen” · “Open Calculator”")
              .font(.system(size: 12)).multilineTextAlignment(.center)
          }.padding(.top, compact ? 18 : 28)
          if !model.connected || !model.accessGranted {
            Button {
              model.showingSettings = true
            } label: {
              HStack(spacing: 6) {
                Image(systemName: "sparkle")
                Text(
                  model.connected
                    ? "One last thing: connect your Mac" : "Let’s get Talkie connected")
                Image(systemName: "arrow.right")
              }.font(.system(size: 11)).foregroundStyle(Palette.orange)
            }.buttonStyle(.plain).padding(.top, 24)
          }
          Spacer(minLength: 14)
        }.frame(maxWidth: .infinity, minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }
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
    VStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 13) {
        VoiceControlView(model: model)
        HStack(spacing: 10) {
          Menu {
            ForEach(Mode.allCases, id: \.self) { mode in
              Button(mode.rawValue) { model.mode = mode }
            }
          } label: {
            HStack(spacing: 5) {
              Image(systemName: "sparkle")
              Text(model.mode.rawValue)
              Image(systemName: "chevron.down").font(.system(size: 8))
            }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
          }.menuStyle(.borderlessButton).fixedSize().disabled(model.busy || model.listening)
            .accessibilityLabel("Request mode")
          Rectangle().fill(Palette.line).frame(width: 1, height: 12)
          Label(
            model.preferences.screenContext ? model.contextApp : "Screen context off",
            systemImage: model.preferences.screenContext ? "macwindow" : "eye.slash"
          )
          .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
        }
      }
      .padding(16)
      .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 17))
      .overlay(
        RoundedRectangle(cornerRadius: 17).stroke(
          model.listening ? Palette.orange.opacity(0.5) : Palette.line)
      )
      .shadow(color: .black.opacity(0.025), radius: 12, y: 4)
      HStack(spacing: 5) {
        Text("A quiet companion.").foregroundStyle(Palette.secondary.opacity(0.7))
        Text("Powered by Jev").foregroundStyle(Palette.secondary)
        if let latency = model.lastLatency {
          Text("· \(latency) ms").monospacedDigit().foregroundStyle(Palette.secondary.opacity(0.6))
        }
      }.font(.system(size: 9))
    }.padding(.horizontal, 32).padding(.top, 12).padding(.bottom, 22)
  }

  private func approval(_ pending: PendingAction) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Your go-ahead").font(.system(size: 14, weight: .medium))
      Text("\(pending.action.label)\nIn \(pending.appName)").font(.system(size: 12)).textSelection(
        .enabled)
      HStack {
        Button("Cancel") { model.confirm(false) }
        Spacer()
        Button("Allow this action") { model.confirm(true) }.tint(Palette.orange).buttonStyle(
          .borderedProminent)
      }
    }.padding(16).background(Palette.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 32)
  }
}

struct MessageView: View {
  let message: Message
  @State private var expanded = false
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if message.role == "assistant" {
        TalkieMark(size: 25)
      } else {
        Image(systemName: "person.crop.circle").font(.system(size: 23, weight: .ultraLight))
          .foregroundStyle(Palette.secondary).frame(width: 25)
      }
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(message.role == "assistant" ? "Talkie" : "You").font(
            .system(size: 11, weight: .semibold))
          if message.isError {
            Text("Needs your attention").font(.system(size: 10)).foregroundStyle(Palette.orange)
          }
          Spacer()
          Text(message.date, style: .time).font(.system(size: 9)).foregroundStyle(
            Palette.secondary.opacity(0.6))
        }
        Text(.init(message.text)).font(.system(size: 14)).lineSpacing(5).textSelection(.enabled)
          .tint(Palette.orange).fixedSize(horizontal: false, vertical: true)
        if !message.sources.isEmpty {
          ForEach(message.sources, id: \.url) { source in
            if let url = ActionPolicy.webURL(source.url) {
              Link(destination: url) {
                Label(source.title, systemImage: "arrow.up.right").font(.system(size: 11))
                  .lineLimit(2).foregroundStyle(Palette.orange)
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
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        VStack(alignment: .leading, spacing: 6) {
          Text("A little more you.").font(.system(size: 29, design: .serif)).tracking(-0.8)
          Text("Everything Talkie needs. Nothing it doesn’t.").foregroundStyle(Palette.secondary)
        }
        section("CONNECTIONS") {
          keyField(.jev, value: $jev, detail: "Understands requests and chooses Mac actions.")
          Divider().overlay(Palette.line)
          keyField(
            .openAI, value: $openAI, detail: "Optional · conversation, web research, drafts.")
          if !saveMessage.isEmpty {
            Text(saveMessage).font(.system(size: 11)).foregroundStyle(Palette.secondary)
          }
        }
        section("AT HOME ON YOUR MAC") {
          permission(
            "Accessibility", detail: "Read controls and take action in your apps.",
            granted: model.accessGranted
          ) {
            DesktopAccess.requestTrust()
            openPrivacy("Privacy_Accessibility")
          }
          Divider()
          permission(
            "Screen Recording", detail: "Optional · read text in apps with limited accessibility.",
            granted: model.screenGranted
          ) {
            CGRequestScreenCaptureAccess()
            openPrivacy("Privacy_ScreenCapture")
          }
          Divider()
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
            Text("The global shortcut is in use by another app. The microphone button still works.")
              .font(.system(size: 11)).foregroundStyle(Palette.orange)
          }
        }
        section("THE LITTLE THINGS") {
          Toggle("Speak answers aloud", isOn: $model.preferences.speak)
            .onChange(of: model.preferences.speak) { _, enabled in
              if !enabled { model.speaker.stop() }
            }
          Toggle("Keep companion visible while idle", isOn: $model.preferences.companion)
          Toggle("Include screen context when I ask", isOn: $model.preferences.screenContext)
          Toggle("Remember conversations on this Mac", isOn: $model.preferences.keepHistory)
            .onChange(of: model.preferences.keepHistory) { _, _ in model.historyPreferenceChanged()
            }
          Text(
            "Live audio stays on your Mac. On-screen text goes to Jev and, for conversations, OpenAI only when requested. Screenshots are processed locally and never saved. Imported audio is sent to OpenAI."
          )
          .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
          Button("Delete all conversations") { deleting = true }.foregroundStyle(Palette.orange)
            .confirmationDialog("Delete all conversations from this Mac?", isPresented: $deleting) {
              Button("Delete conversations", role: .destructive) { model.clearHistory() }
            }
        }
        HStack {
          Text("Talkie 1.0").font(.system(size: 11, weight: .medium))
          Spacer()
          Button("Quit Talkie") { NSApplication.shared.terminate(nil) }.font(.system(size: 11))
        }.foregroundStyle(Palette.secondary)
      }.padding(.horizontal, 36).padding(.bottom, 30)
    }.toggleStyle(.switch).controlSize(.small)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 13) {
      Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(
        Palette.secondary)
      VStack(alignment: .leading, spacing: 15, content: content).padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
    }
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
        .font(.system(size: 10)).foregroundStyle(present ? Palette.secondary : Palette.orange)
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
      Button(granted ? "Allowed" : "Allow", action: action).buttonStyle(.bordered)
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
          .foregroundStyle(.white).frame(width: 40, height: 40)
          .background(model.listening ? Palette.orange : Palette.ink, in: Circle())
      }
      .buttonStyle(.plain).disabled(model.pending != nil)
      .accessibilityLabel(
        model.busy ? "Stop task" : model.listening ? "Finish recording" : "Start microphone")
      VStack(alignment: .leading, spacing: 5) {
        Text(model.listening ? "Listening…" : model.busy ? model.status : "Speak to Talkie")
          .font(.system(size: 14, weight: .medium)).lineLimit(1)
        if model.listening, !model.voice.transcript.isEmpty {
          Text(model.voice.transcript).font(.system(size: 11))
            .foregroundStyle(Palette.secondary).lineLimit(2)
            .accessibilityLabel("Live transcript")
            .accessibilityValue(model.voice.transcript)
        } else {
          Text(
            model.listening
              ? "Finish recording to send · Esc to cancel"
              : model.busy ? "Esc to cancel" : "Click the mic or hold ⌃ ⌥ space"
          )
          .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }.frame(height: 56)
  }
}

struct QuickView: View {
  @ObservedObject var model: TalkieModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        TalkieMark(size: 24, active: model.listening || model.busy)
        Text(model.busy ? model.status : "Talkie").font(.system(size: 13, weight: .medium))
          .lineLimit(1)
        Spacer()
        Menu {
          Button("New conversation") { model.newConversation() }
            .keyboardShortcut("n", modifiers: .command)
          Button("History & activity") { model.showHistory?() }
          Button("Settings…") { model.showSettings?() }
            .keyboardShortcut(",", modifiers: .command)
          Divider()
          Button("Quit Talkie") { NSApplication.shared.terminate(nil) }
        } label: {
          Image(systemName: "ellipsis").frame(width: 22)
        }
        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Talkie menu")
        Button {
          model.dismissQuick?()
        } label: {
          Image(systemName: "xmark").frame(width: 22, height: 22)
        }.buttonStyle(.plain).foregroundStyle(Palette.secondary).accessibilityLabel(
          "Dismiss Talkie")
      }

      if let pending = model.pending {
        Text("Your go-ahead").font(.system(size: 16, weight: .medium))
        ScrollView {
          Text("\(pending.action.label)\n\nIn \(pending.appName)")
            .font(.system(size: 13)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack {
          Button("Cancel") { model.confirm(false) }
          Spacer()
          Button("Allow this action") { model.confirm(true) }
            .buttonStyle(.borderedProminent).tint(Palette.orange)
        }
      } else {
        if let reply = model.quickReply {
          ScrollView { MessageView(message: reply).padding(.trailing, 4) }
        } else if let notice = model.notice {
          ScrollView {
            Text(notice).font(.system(size: 12)).foregroundStyle(Palette.secondary)
              .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
          }
        }
        VoiceControlView(model: model)
      }

      HStack(spacing: 12) {
        if !model.connected {
          Button("Set up Talkie") { model.showSettings?() }
            .foregroundStyle(Palette.orange)
        } else {
          Text(model.preferences.screenContext ? model.contextApp : "Screen context off")
            .lineLimit(1)
        }
        Spacer()
        if model.pending == nil {
          Picker("Mode", selection: $model.mode) {
            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          .labelsHidden().fixedSize().disabled(model.busy || model.listening)
          .accessibilityLabel("Mode")
        }
        Button {
          model.showSettings?()
        } label: {
          Image(systemName: "gearshape")
        }.accessibilityLabel("Settings")
      }
      .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Palette.secondary)
    }
    .padding(20).frame(width: 420, height: model.quickHeight)
    .foregroundStyle(Palette.ink)
    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 20))
    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    .preferredColorScheme(.light)
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
            ? "I’m listening"
            : model.busy ? "On it…" : model.quickReply != nil ? "Done" : "Say the word"
        )
        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
        Text(
          model.listening && !model.voice.transcript.isEmpty
            ? model.voice.transcript
            : model.busy
              ? model.status : model.quickReply != nil ? "Click to review" : "Hold ⌃ ⌥ space"
        )
        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
      }
      Spacer(minLength: 0)
      Button {
        model.busy ? model.stop() : model.toggleMicrophone()
      } label: {
        Image(systemName: model.busy || model.listening ? "stop.fill" : "mic")
          .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
          .frame(width: 28, height: 28).background(.white.opacity(0.08), in: Circle())
      }.buttonStyle(.plain).accessibilityLabel(
        model.busy ? "Stop task" : model.listening ? "Finish recording" : "Start microphone")
    }
    .padding(.horizontal, 15).frame(width: 235, height: 58)
    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 19))
    .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.12)))
  }
}
