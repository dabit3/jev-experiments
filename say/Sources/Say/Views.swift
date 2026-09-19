import AppKit
import SayCore
import SwiftUI

@MainActor
enum SayBrand {
  static let mark: NSImage = {
    let image =
      Bundle.main.url(forResource: "SayMark", withExtension: "pdf")
      .flatMap { NSImage(contentsOf: $0) }
      ?? NSImage(systemSymbolName: "bubble.right.fill", accessibilityDescription: "Say")!
    image.isTemplate = true
    image.accessibilityDescription = "Say"
    return image
  }()
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
        Color(nsColor: .windowBackgroundColor)
      } else {
        NativeMaterial()
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: radius, style: .continuous)
        .strokeBorder(.primary.opacity(contrast == .increased ? 0.6 : 0.12), lineWidth: 0.5)
    )
    .accessibilityHidden(true)
  }
}

struct SayMark: View {
  var size: CGFloat = 32
  var active = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.16, paused: !active || reduceMotion)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      Image(nsImage: SayBrand.mark)
        .resizable().renderingMode(.template).scaledToFit()
        .frame(width: size, height: size)
        .scaleEffect(active && !reduceMotion ? 0.95 + 0.05 * sin(time * 3) : 1)
        .opacity(active && !reduceMotion ? 0.85 + 0.15 * sin(time * 3) : 1)
    }
    .accessibilityHidden(true)
  }
}

struct RootView: View {
  @ObservedObject var model: SayModel

  var body: some View {
    NavigationSplitView {
      ConversationSidebar(model: model)
    } detail: {
      ConversationDetail(model: model)
    }
    .frame(minWidth: 760, minHeight: 500)
    .onExitCommand { model.stop() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in model.refreshPermissions() }
  }
}

struct ConversationSidebar: View {
  @ObservedObject var model: SayModel

  private var locked: Bool { model.busy || model.listening || model.pending != nil }
  private var conversations: [Conversation] { model.conversations.filter { !$0.messages.isEmpty } }
  private var selection: Binding<UUID?> {
    Binding(
      get: { model.currentID },
      set: { id in
        guard let id, id != model.currentID,
          let conversation = model.conversations.first(where: { $0.id == id })
        else { return }
        model.select(conversation)
      })
  }

  var body: some View {
    List(selection: selection) {
      ForEach(conversations) { conversation in
        Label(conversation.title, systemImage: "bubble.left")
          .lineLimit(1)
          .tag(conversation.id)
      }
    }
    .listStyle(.sidebar)
    .disabled(locked)
    .overlay {
      if conversations.isEmpty {
        Text("No Conversations").foregroundStyle(.secondary)
      }
    }
    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    .toolbar {
      ToolbarItem {
        Button {
          model.newConversation()
        } label: {
          Label("New Conversation", systemImage: "square.and.pencil")
        }
        .disabled(locked)
        .help("New Conversation")
      }
    }
  }
}

struct ConversationDetail: View {
  @ObservedObject var model: SayModel

  private var title: String {
    model.conversations.first(where: { $0.id == model.currentID })?.title ?? ""
  }

  var body: some View {
    VStack(spacing: 0) {
      if model.messages.isEmpty {
        emptyState
      } else {
        Transcript(model: model)
      }
      if let notice = model.notice {
        NoticeBar(text: notice) { model.notice = nil }
          .padding(.horizontal, 20).padding(.bottom, 12)
      }
      if let pending = model.pending {
        ApprovalView(model: model, pending: pending)
          .padding(.horizontal, 20).padding(.bottom, 12)
      }
      Divider()
      HStack(spacing: 8) {
        VoiceControlView(model: model)
        SayMenu(model: model)
      }
      .padding(.horizontal, 20).padding(.vertical, 12)
      .background(.bar)
    }
    .navigationTitle("Say")
    .navigationSubtitle(model.messages.isEmpty ? "" : title)
    .toolbar {
      if model.speaker.speaking {
        ToolbarItem {
          Button {
            model.speaker.stop()
          } label: {
            Label("Stop Speaking", systemImage: "speaker.slash")
          }
          .help("Stop Speaking")
        }
      }
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label {
        Text("Say Something")
      } icon: {
        SayMark(size: 52).foregroundStyle(.secondary)
      }
    } description: {
      Text("Hold ⌃ ⌥ Space and speak, or click the microphone.")
      Text("Try “Open Calculator” or “Explain my screen.”")
    } actions: {
      if !model.connected {
        Button("Open Settings…") { model.showSettings?() }
      } else if !model.accessGranted {
        Button("Allow Accessibility…") { model.showSettings?() }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct Transcript: View {
  @ObservedObject var model: SayModel

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          ForEach(model.messages) { message in
            MessageView(message: message).id(message.id)
          }
          if model.busy {
            HStack(spacing: 10) {
              SayMark(size: 18, active: true).foregroundStyle(.secondary)
              Text(model.status).foregroundStyle(.secondary)
              Spacer()
              Button("Stop") { model.stop() }.controlSize(.small)
            }
            .id("working")
          }
        }
        .padding(.horizontal, 28).padding(.vertical, 20)
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .onChange(of: model.messages.count) { _, _ in
        if let last = model.messages.last {
          withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
      }
      .onChange(of: model.busy) { _, busy in
        if busy { proxy.scrollTo("working", anchor: .bottom) }
      }
    }
  }
}

struct NoticeBar: View {
  let text: String
  let dismiss: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill").symbolRenderingMode(.multicolor)
      Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      Spacer(minLength: 0)
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss notice")
    }
    .font(.callout)
    .padding(10)
    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
  }
}

struct MessageView: View {
  let message: Message
  var compact = false
  @State private var expanded = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if !compact {
        Group {
          if message.role == "assistant" {
            SayMark(size: 18)
          } else {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 18))
          }
        }
        .foregroundStyle(.secondary).frame(width: 22, height: 22)
      }
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
          Text(message.role == "assistant" ? "Say" : "You").font(.headline)
          if message.isError {
            Label("Needs attention", systemImage: "exclamationmark.circle")
              .font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Text(message.date, style: .time).font(.caption).foregroundStyle(.tertiary)
        }
        Text(.init(message.text)).textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
        if !message.sources.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(message.sources, id: \.url) { source in
              if let url = ActionPolicy.webURL(source.url) {
                Link(destination: url) {
                  Label(source.title, systemImage: "link").lineLimit(1)
                }
                .font(.callout)
              }
            }
          }
        }
        if !message.activities.isEmpty {
          DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 5) {
              ForEach(message.activities) { activity in
                HStack(alignment: .firstTextBaseline) {
                  Text(activity.text).lineLimit(3)
                  Spacer()
                  if let ms = activity.milliseconds {
                    Text("\(ms) ms").monospacedDigit().foregroundStyle(.tertiary)
                  }
                }
              }
            }
            .padding(.top, 4)
          } label: {
            Text("\(message.activities.count) steps")
          }
          .font(.caption).foregroundStyle(.secondary)
        }
        if message.role == "assistant" {
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
          } label: {
            Label("Copy", systemImage: "doc.on.doc")
          }
          .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
        }
      }
    }
  }
}
